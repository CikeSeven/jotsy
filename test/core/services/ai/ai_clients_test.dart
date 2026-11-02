import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_client.dart';
import 'package:node_diary/core/services/ai/ai_failure.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';

import 'ai_test_server.dart';

AiProviderConfig _provider(
  AiTestServer server,
  AiProtocol protocol, {
  String path = '',
  bool stream = true,
  bool sendTemperature = true,
}) {
  return AiProviderConfig(
    id: 'p',
    name: 'Test',
    protocol: protocol,
    baseUrl: '${server.baseUrl}$path',
    apiKey: 'secret',
    stream: stream,
    sendTemperature: sendTemperature,
    headers: const {'X-Extra': 'yes'},
    extraBody: '{"custom_flag": true}',
    models: const [AiModelConfig(id: 'm')],
  );
}

AiRequest _request({List<AiPart>? parts, bool reasoning = false}) => AiRequest(
  model: 'm',
  system: 'be kind',
  temperature: 0.5,
  reasoning: reasoning,
  messages: [
    AiMessage(AiRole.user, parts ?? const [AiTextPart('hi')]),
  ],
);

Future<AiCompletion> _collect(Stream<AiChunk> stream) async {
  final text = StringBuffer();
  final reasoning = StringBuffer();
  AiUsage? usage;
  AiFinishReason? finish;
  await for (final chunk in stream) {
    text.write(chunk.text);
    reasoning.write(chunk.reasoning);
    if (chunk.usage != null) {
      usage = (usage ?? const AiUsage()).merge(chunk.usage!);
    }
    finish = chunk.finishReason ?? finish;
  }
  return AiCompletion(
    text: text.toString(),
    reasoning: reasoning.toString(),
    usage: usage,
    finishReason: finish,
  );
}

void main() {
  late AiTestServer server;

  setUp(() async => server = await AiTestServer.start());
  tearDown(() => server.close());

  group('OpenAI compatible', () {
    test('streams text, reasoning and usage with the expected body', () async {
      server.handler = (request, response) => writeSse(response, [
        (null, '{"choices":[{"delta":{"reasoning_content":"think "}}]}'),
        (null, '{"choices":[{"delta":{"content":"Hel"}}]}'),
        (
          null,
          '{"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}]}',
        ),
        (
          null,
          '{"choices":[],"usage":{"prompt_tokens":7,"completion_tokens":3}}',
        ),
        (null, '[DONE]'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          _request(
            parts: [
              const AiTextPart('look'),
              AiImagePart(Uint8List.fromList([1, 2, 3]), 'image/png'),
            ],
          ),
        ),
      );
      expect(result.text, 'Hello');
      expect(result.reasoning, 'think ');
      expect(result.usage, const AiUsage(inputTokens: 7, outputTokens: 3));
      expect(result.finishReason, AiFinishReason.stop);

      final request = server.requests.single;
      expect(request.uri.path, '/v1/chat/completions');
      expect(request.headers.value('authorization'), 'Bearer secret');
      expect(request.headers.value('x-extra'), 'yes');
      final body = request.json;
      expect(body['stream'], isTrue);
      expect(body['stream_options'], {'include_usage': true});
      expect(body['temperature'], 0.5);
      expect(body['custom_flag'], isTrue);
      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.first, {'role': 'system', 'content': 'be kind'});
      final content = (messages[1]['content'] as List).cast<Map>();
      expect(content[0], {'type': 'text', 'text': 'look'});
      expect(
        (content[1]['image_url'] as Map)['url'],
        'data:image/png;base64,${base64Encode([1, 2, 3])}',
      );
    });

    test('falls back to a JSON response when streaming is off', () async {
      server.handler = (request, response) => writeJson(response, {
        'choices': [
          {
            'message': {'content': '<think>hmm</think>Answer'},
            'finish_reason': 'length',
          },
        ],
      });
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, stream: false),
      );
      final result = await _collect(client.stream(_request()));
      expect(result.text, 'Answer');
      expect(result.reasoning, 'hmm');
      expect(result.finishReason, AiFinishReason.length);
      expect(server.requests.single.json['stream'], isFalse);
    });

    test('maps error responses to failure kinds', () async {
      final cases = <int, AiFailureKind>{
        401: AiFailureKind.unauthorized,
        404: AiFailureKind.modelNotFound,
        429: AiFailureKind.rateLimited,
        503: AiFailureKind.server,
      };
      for (final entry in cases.entries) {
        server.handler = (request, response) => writeJson(response, {
          'error': {'message': 'nope ${entry.key}'},
        }, status: entry.key);
        final client = AiChatClient.forProvider(
          _provider(server, AiProtocol.openAi),
        );
        await expectLater(
          client.stream(_request()).drain<void>(),
          throwsA(
            isA<AiException>()
                .having((e) => e.kind, 'kind', entry.value)
                .having(
                  (e) => e.providerMessage,
                  'message',
                  'nope ${entry.key}',
                ),
          ),
        );
      }
    });

    test('recognises context length and quota errors by message', () async {
      server.handler = (request, response) => writeJson(response, {
        'error': {'message': "This model's maximum context length is 8192"},
      }, status: 400);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi),
      );
      await expectLater(
        client.stream(_request()).drain<void>(),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.contextTooLong,
          ),
        ),
      );
    });

    test('reports a cancelled stream as cancelled', () async {
      server.handler = (request, response) async {
        await writeSse(response, [
          (null, '{"choices":[{"delta":{"content":"a"}}]}'),
        ]);
        await Future<void>.delayed(const Duration(seconds: 2));
      };
      final token = HttpCancelToken();
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi),
      );
      final received = <String>[];
      await expectLater(
        client.stream(_request(), cancelToken: token).forEach((chunk) {
          received.add(chunk.text);
          token.cancel();
        }),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.cancelled,
          ),
        ),
      );
      expect(received, ['a']);
    });

    test('flags an HTML page returned with 200', () async {
      server.handler = (request, response) async {
        response.headers.contentType = ContentType.html;
        response.write('<html>console</html>');
      };
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi),
      );
      await expectLater(
        client.stream(_request()).drain<void>(),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.badResponse,
          ),
        ),
      );
    });

    test('lists models with context and modalities', () async {
      server.handler = (request, response) => writeJson(response, {
        'data': [
          {
            'id': 'b-model',
            'context_length': 32000,
            'architecture': {
              'input_modalities': ['text', 'image'],
            },
          },
          {'id': 'a-model'},
        ],
      });
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi),
      );
      final models = await client.listModels();
      expect(models.map((m) => m.id), ['a-model', 'b-model']);
      expect(models[1].contextWindow, 32000);
      expect(models[1].supportsVision, isTrue);
      expect(models[0].supportsVision, isNull);
      expect(server.requests.single.uri.path, '/models');
    });
  });

  group('Anthropic', () {
    test('streams messages events and sends the Messages body', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          'message_start',
          '{"type":"message_start","message":{"usage":{"input_tokens":12}}}',
        ),
        (
          'content_block_delta',
          '{"type":"content_block_delta","index":0,'
              '"delta":{"type":"thinking_delta","thinking":"hmm"}}',
        ),
        (
          'content_block_delta',
          '{"type":"content_block_delta","index":1,'
              '"delta":{"type":"text_delta","text":"Hi"}}',
        ),
        (
          'message_delta',
          '{"type":"message_delta","delta":{"stop_reason":"end_turn"},'
              '"usage":{"output_tokens":4}}',
        ),
        ('message_stop', '{"type":"message_stop"}'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.anthropic, sendTemperature: false),
      );
      final result = await _collect(
        client.stream(
          _request(
            reasoning: true,
            parts: [
              const AiTextPart('see'),
              AiImagePart(Uint8List.fromList([9]), 'image/jpeg'),
            ],
          ),
        ),
      );
      expect(result.text, 'Hi');
      expect(result.reasoning, 'hmm');
      expect(result.usage, const AiUsage(inputTokens: 12, outputTokens: 4));
      expect(result.finishReason, AiFinishReason.stop);

      final request = server.requests.single;
      expect(request.uri.path, '/v1/messages');
      expect(request.headers.value('x-api-key'), 'secret');
      expect(request.headers.value('anthropic-version'), '2023-06-01');
      final body = request.json;
      expect(body['max_tokens'], 8192);
      expect(body['system'], 'be kind');
      expect(body.containsKey('temperature'), isFalse);
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      final content =
          ((body['messages'] as List).single as Map)['content'] as List;
      expect((content.first as Map)['type'], 'image');
      expect((content.last as Map)['text'], 'see');
    });

    test('does not repeat /v1 and maps stream error events', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          'error',
          '{"type":"error","error":{"type":"overloaded_error",'
              '"message":"Overloaded"}}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.anthropic, path: '/v1'),
      );
      await expectLater(
        client.stream(_request()).drain<void>(),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.server,
          ),
        ),
      );
      expect(server.requests.single.uri.path, '/v1/messages');
    });

    test('lists models', () async {
      server.handler = (request, response) => writeJson(response, {
        'data': [
          {
            'id': 'claude-x',
            'display_name': 'Claude X',
            'max_input_tokens': 1000000,
          },
        ],
      });
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.anthropic),
      );
      final models = await client.listModels();
      expect(models.single.displayName, 'Claude X');
      expect(models.single.contextWindow, 1000000);
      expect(models.single.supportsVision, isTrue);
    });
  });

  group('Gemini', () {
    test('streams candidates with thoughts and usage', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"candidates":[{"content":{"parts":[{"text":"plan","thought":true},'
              '{"text":"Bon"}]}}]}',
        ),
        (
          null,
          '{"candidates":[{"content":{"parts":[{"text":"jour"}]},'
              '"finishReason":"STOP"}],'
              '"usageMetadata":{"promptTokenCount":5,"candidatesTokenCount":2,'
              '"thoughtsTokenCount":1}}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.gemini),
      );
      final result = await _collect(
        client.stream(_request().copyWith(model: 'models/gemini-x')),
      );
      expect(result.text, 'Bonjour');
      expect(result.reasoning, 'plan');
      expect(result.usage, const AiUsage(inputTokens: 5, outputTokens: 3));

      final request = server.requests.single;
      expect(request.uri.path, '/models/gemini-x:streamGenerateContent');
      expect(request.uri.queryParameters['alt'], 'sse');
      expect(request.headers.value('x-goog-api-key'), 'secret');
      final body = request.json;
      expect(body['systemInstruction'], {
        'parts': [
          {'text': 'be kind'},
        ],
      });
      expect((body['generationConfig'] as Map)['temperature'], 0.5);
    });

    test('reports blocked prompts as content filtered', () async {
      server.handler = (request, response) => writeSse(response, [
        (null, '{"promptFeedback":{"blockReason":"SAFETY"}}'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.gemini),
      );
      await expectLater(
        client.stream(_request()).drain<void>(),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.contentFiltered,
          ),
        ),
      );
    });

    test('lists only generateContent models without the prefix', () async {
      server.handler = (request, response) => writeJson(response, {
        'models': [
          {
            'name': 'models/gemini-a',
            'supportedGenerationMethods': ['generateContent'],
            'inputTokenLimit': 100,
          },
          {
            'name': 'models/embedding-b',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.gemini),
      );
      final models = await client.listModels();
      expect(models.single.id, 'gemini-a');
      expect(models.single.contextWindow, 100);
    });
  });

  group('OpenAI Responses', () {
    test('streams text, reasoning summaries and usage', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          'response.created',
          '{"type":"response.created","response":{"status":"in_progress"}}',
        ),
        (
          'response.reasoning_summary_text.delta',
          '{"type":"response.reasoning_summary_text.delta","delta":"think"}',
        ),
        (
          'response.reasoning_summary_part.done',
          '{"type":"response.reasoning_summary_part.done"}',
        ),
        (
          'response.output_text.delta',
          '{"type":"response.output_text.delta","delta":"Hel"}',
        ),
        (
          'response.output_text.delta',
          '{"type":"response.output_text.delta","delta":"lo"}',
        ),
        (
          'response.completed',
          '{"type":"response.completed","response":{"status":"completed",'
              '"usage":{"input_tokens":9,"output_tokens":4}}}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          _request(
            reasoning: true,
            parts: [
              const AiTextPart('look'),
              AiImagePart(Uint8List.fromList([1, 2, 3]), 'image/png'),
            ],
          ),
        ),
      );
      expect(result.text, 'Hello');
      expect(result.reasoning.trim(), 'think');
      expect(result.usage, const AiUsage(inputTokens: 9, outputTokens: 4));
      expect(result.finishReason, AiFinishReason.stop);

      final request = server.requests.single;
      expect(request.uri.path, '/v1/responses');
      expect(request.headers.value('authorization'), 'Bearer secret');
      final body = request.json;
      expect(body['instructions'], 'be kind');
      expect(body['store'], isFalse);
      expect(body['stream'], isTrue);
      expect(body['reasoning'], {'summary': 'auto'});
      // 开着思考不发温度（推理模型不接受）。
      expect(body.containsKey('temperature'), isFalse);
      expect(body['custom_flag'], isTrue);
      final input = (body['input'] as List).cast<Map>();
      final content = (input.single['content'] as List).cast<Map>();
      expect(content[0], {'type': 'input_text', 'text': 'look'});
      expect(content[1], {
        'type': 'input_image',
        'image_url': 'data:image/png;base64,${base64Encode([1, 2, 3])}',
      });
    });

    test('plain text history, temperature without thinking', () async {
      server.handler = (request, response) => writeSse(response, [
        (null, '{"type":"response.output_text.delta","delta":"ok"}'),
        (
          null,
          '{"type":"response.incomplete","response":{"status":"incomplete",'
              '"incomplete_details":{"reason":"max_output_tokens"}}}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses),
      );
      final result = await _collect(
        client.stream(
          const AiRequest(
            model: 'm',
            temperature: 0.4,
            messages: [
              AiMessage(AiRole.user, [AiTextPart('q1')]),
              AiMessage(AiRole.assistant, [AiTextPart('a1')]),
              AiMessage(AiRole.user, [AiTextPart('q2')]),
            ],
          ),
        ),
      );
      expect(result.text, 'ok');
      expect(result.finishReason, AiFinishReason.length);
      final body = server.requests.single.json;
      expect(body['temperature'], 0.4);
      expect(body.containsKey('reasoning'), isFalse);
      expect(body.containsKey('instructions'), isFalse);
      expect(body['input'], [
        {'role': 'user', 'content': 'q1'},
        {'role': 'assistant', 'content': 'a1'},
        {'role': 'user', 'content': 'q2'},
      ]);
    });

    test('reads a one-shot response when streaming is off', () async {
      server.handler = (request, response) => writeJson(response, {
        'status': 'completed',
        'output': [
          {
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': 'plan'},
            ],
          },
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': 'Answer'},
            ],
          },
        ],
        'usage': {'input_tokens': 5, 'output_tokens': 2},
      });
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses, stream: false),
      );
      final result = await _collect(client.stream(_request()));
      expect(result.text, 'Answer');
      expect(result.reasoning, 'plan');
      expect(result.usage, const AiUsage(inputTokens: 5, outputTokens: 2));
      expect(server.requests.single.json['stream'], isFalse);
    });

    test('maps failure events to errors', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"type":"response.failed","response":{"status":"failed",'
              '"error":{"code":"rate_limit_exceeded","message":"slow down"}}}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses),
      );
      await expectLater(
        _collect(client.stream(_request())),
        throwsA(
          isA<AiException>()
              .having((e) => e.kind, 'kind', AiFailureKind.rateLimited)
              .having((e) => e.providerMessage, 'message', 'slow down'),
        ),
      );
    });
  });
}
