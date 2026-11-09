import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_failure.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/core/services/ai/ai_usage_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_test_server.dart';

void main() {
  late AiTestServer server;
  late AiProviderStore store;

  AiProviderConfig provider({int retries = 1, bool vision = false}) =>
      AiProviderConfig(
        id: 'p1',
        name: 'Local',
        protocol: AiProtocol.openAi,
        baseUrl: server.baseUrl,
        retries: retries,
        models: [AiModelConfig(id: 'm1', vision: vision)],
      );

  AiService service() => AiService(
    store: store,
    backoff: (_, _) => const Duration(milliseconds: 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    server = await AiTestServer.start();
    store = await AiProviderStore.create();
  });
  tearDown(() async {
    store.dispose();
    await server.close();
  });

  test('retries a retryable failure before the first chunk', () async {
    var calls = 0;
    server.handler = (request, response) async {
      calls++;
      if (calls == 1) {
        await writeJson(response, {'error': 'busy'}, status: 503);
        return;
      }
      await writeSse(response, [
        (null, '{"choices":[{"delta":{"content":"ok"}}]}'),
        (
          null,
          '{"choices":[],"usage":{"prompt_tokens":3,"completion_tokens":1}}',
        ),
      ]);
    };
    final target = AiResolvedModel(provider(), provider().models.first);
    final result = await service().complete(
      target,
      AiRequest(
        model: 'ignored',
        messages: [AiMessage.text(AiRole.user, 'hi')],
      ),
    );
    expect(result.text, 'ok');
    expect(calls, 2);
    expect(server.requests.last.json['model'], 'm1');

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final month = AiUsageLedger.monthKey(DateTime.now());
    final entry = store.usage.entriesOf(month).single;
    expect(entry.requests, 1);
    expect(entry.failures, 0);
    expect(entry.inputTokens, 3);
  });

  test('does not retry a non-retryable failure', () async {
    var calls = 0;
    server.handler = (request, response) async {
      calls++;
      await writeJson(response, {'error': 'bad key'}, status: 401);
    };
    final target = AiResolvedModel(
      provider(retries: 3),
      provider().models.first,
    );
    await expectLater(
      service().complete(
        target,
        AiRequest(model: 'm1', messages: [AiMessage.text(AiRole.user, 'hi')]),
      ),
      throwsA(
        isA<AiException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.unauthorized,
        ),
      ),
    );
    expect(calls, 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final month = AiUsageLedger.monthKey(DateTime.now());
    expect(store.usage.entriesOf(month).single.failures, 1);
  });

  test('strips images when the model has no vision', () {
    final target = AiResolvedModel(provider(), provider().models.first);
    final prepared = AiService.prepareRequest(
      target,
      AiRequest(
        model: 'x',
        messages: [
          AiMessage(AiRole.user, [
            const AiTextPart('describe'),
            AiImagePart(Uint8List(1), 'image/png'),
          ]),
        ],
      ),
    );
    expect(prepared.hasImages, isFalse);
    // 图片换成说明，模型知道这里原本有图。
    expect(
      prepared.messages.single.text,
      'describe\n${AiRequest.defaultImageOmittedText}',
    );
    expect(prepared.model, 'm1');

    final vision = provider(vision: true);
    final kept = AiService.prepareRequest(
      AiResolvedModel(vision, vision.models.first),
      AiRequest(
        model: 'x',
        messages: [
          AiMessage(AiRole.user, [AiImagePart(Uint8List(1), 'image/png')]),
        ],
      ),
    );
    expect(kept.hasImages, isTrue);
  });

  test('require throws notConfigured without providers', () {
    expect(
      () => service().require(AiTaskKind.chat),
      throwsA(
        isA<AiException>().having(
          (e) => e.kind,
          'kind',
          AiFailureKind.notConfigured,
        ),
      ),
    );
  });

  test('store persists providers and keeps them out of other keys', () async {
    await store.saveProvider(provider());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {AiProviderStore.keyConfig});
    final reloaded = await AiProviderStore.create();
    expect(reloaded.config.providers.single.id, 'p1');
    reloaded.dispose();
  });

  test('omitted images become one note per run, in the request language', () {
    final target = AiResolvedModel(provider(), provider().models.first);
    final prepared = AiService.prepareRequest(
      target,
      AiRequest(
        model: 'x',
        imageOmittedText: '（图片未发送）',
        messages: [
          AiMessage(AiRole.user, [
            AiImagePart(Uint8List(1), 'image/png'),
            AiImagePart(Uint8List(1), 'image/png'),
            const AiTextPart('看这两张'),
            AiImagePart(Uint8List(1), 'image/jpeg'),
          ]),
          AiMessage.text(AiRole.assistant, '好的'),
        ],
      ),
    );
    final parts = prepared.messages.first.parts;
    expect(parts.whereType<AiImagePart>(), isEmpty);
    expect(
      [for (final part in parts) (part as AiTextPart).text],
      ['（图片未发送）', '看这两张', '（图片未发送）'],
    );
    // 没有图片的消息原样保留。
    expect(prepared.messages.last.text, '好的');
  });

  test('a 400 fixed by dropping images is remembered', () async {
    final bodies = <Map<String, Object?>>[];
    server.handler = (request, response) async {
      final body = request.json;
      bodies.add(body);
      final input = (body['input'] as List).cast<Map>();
      final hasImage = input.any(
        (m) =>
            m['content'] is List &&
            (m['content'] as List).any(
              (c) => (c as Map)['type'] == 'input_image',
            ),
      );
      if (hasImage) {
        await writeJson(response, {
          'error': {'message': 'Image input is not supported'},
        }, status: 400);
        return;
      }
      await writeSse(response, [
        (null, '{"type":"response.output_text.delta","delta":"ok"}'),
      ]);
    };
    final config = AiProviderConfig(
      id: 'r2',
      name: 'Responses',
      protocol: AiProtocol.openAiResponses,
      baseUrl: server.baseUrl,
      retries: 0,
      models: const [AiModelConfig(id: 'text-only')],
    );
    final target = AiResolvedModel(config, config.models.single);
    final ai = service();
    expect(ai.acceptsImages(target), isTrue);
    AiRequest request() => AiRequest(
      model: 'x',
      messages: [
        AiMessage(AiRole.user, [
          const AiTextPart('describe'),
          AiImagePart(Uint8List(1), 'image/png'),
        ]),
      ],
    );
    expect((await ai.complete(target, request())).text, 'ok');
    expect(bodies, hasLength(2));
    // 去图重发时图片位置换成说明。
    expect(jsonEncode(bodies[1]), contains('image omitted'));
    expect(ai.acceptsImages(target), isFalse);

    bodies.clear();
    await ai.complete(target, request());
    expect(bodies, hasLength(1));
  });

  test(
    'a 400 that persists without images does not blame the images',
    () async {
      final bodies = <Map<String, Object?>>[];
      server.handler = (request, response) async {
        final body = request.json;
        bodies.add(body);
        final input = (body['input'] as List).cast<Map>();
        final hasImage = input.any((m) => m['content'] is List);
        if (hasImage) {
          await writeJson(response, {
            'error': {'message': 'Image input is not supported'},
          }, status: 400);
          return;
        }
        if (body.containsKey('reasoning')) {
          await writeJson(response, {
            'error': {'message': "Unsupported parameter: 'reasoning.summary'"},
          }, status: 400);
          return;
        }
        await writeSse(response, [
          (null, '{"type":"response.output_text.delta","delta":"ok"}'),
        ]);
      };
      // 模型设置都是默认（看图、思考都开）。
      final config = AiProviderConfig(
        id: 'r1',
        name: 'Responses',
        protocol: AiProtocol.openAiResponses,
        baseUrl: server.baseUrl,
        retries: 0,
        models: const [AiModelConfig(id: 'text-only')],
      );
      final target = AiResolvedModel(config, config.models.single);
      final ai = service();
      AiRequest request() => AiRequest(
        model: 'x',
        messages: [
          AiMessage(AiRole.user, [
            const AiTextPart('describe'),
            AiImagePart(Uint8List(1), 'image/png'),
          ]),
        ],
      );
      final first = await ai.complete(target, request());
      expect(first.text, 'ok');
      expect(bodies, hasLength(3));
      expect(bodies[1].containsKey('reasoning'), isTrue);
      expect(bodies[2].containsKey('reasoning'), isFalse);
      // 去掉图片后仍被拒（思考参数的错）：不记“不认图片”，只记思考。
      expect(ai.acceptsImages(target), isTrue);

      // 下一次不带思考、先带着图片试：被拒后去图成功，这才记住。
      bodies.clear();
      await ai.complete(target, request());
      expect(bodies, hasLength(2));
      expect(bodies.every((body) => !body.containsKey('reasoning')), isTrue);
      expect(ai.acceptsImages(target), isFalse);

      // 之后图片与思考都不带，一次就成。
      bodies.clear();
      await ai.complete(target, request());
      expect(bodies, hasLength(1));
    },
  );

  group('tools', () {
    const tool = AiToolSpec(
      name: 'list_tags',
      description: 'List tags.',
      parameters: <String, Object?>{'type': 'object'},
    );

    test('a 400 after dropping images and thinking marks tools unsupported, '
        'without silently retrying without them', () async {
      final bodies = <Map<String, Object?>>[];
      server.handler = (request, response) async {
        bodies.add(request.json);
        await writeJson(response, {
          'error': {'message': 'tools are not supported'},
        }, status: 400);
      };
      final config = AiProviderConfig(
        id: 'a1',
        name: 'Claude-ish',
        protocol: AiProtocol.anthropic,
        baseUrl: server.baseUrl,
        retries: 0,
        models: const [AiModelConfig(id: 'old-model')],
      );
      final target = AiResolvedModel(config, config.models.single);
      final ai = service();
      expect(ai.supportsTools(target), isTrue);
      await expectLater(
        ai.complete(
          target,
          AiRequest(
            model: 'x',
            tools: const [tool],
            messages: [
              AiMessage(AiRole.user, [
                const AiTextPart('hi'),
                AiImagePart(Uint8List(1), 'image/png'),
              ]),
            ],
          ),
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiFailureKind.badRequest,
          ),
        ),
      );
      // 原请求、去掉图片、再去掉思考；之后不再去掉工具重发。
      expect(bodies, hasLength(3));
      expect(bodies.every((body) => body.containsKey('tools')), isTrue);
      expect(ai.supportsTools(target), isFalse);
      // 去图后仍被拒：图片不背锅。
      expect(ai.acceptsImages(target), isTrue);

      // 已知不支持后，带工具的请求不再发出去。
      bodies.clear();
      await expectLater(
        ai.complete(
          target,
          AiRequest(
            model: 'x',
            tools: const [tool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
        throwsA(isA<AiException>()),
      );
      expect(bodies, isEmpty);
    });

    test('a model with tools turned off does not support them', () {
      const config = AiProviderConfig(
        id: 'p',
        name: 'P',
        protocol: AiProtocol.openAi,
        baseUrl: 'http://localhost',
        models: [AiModelConfig(id: 'm', tools: false)],
      );
      final target = AiResolvedModel(config, config.models.single);
      expect(service().supportsTools(target), isFalse);
      expect(
        AiModelConfig.fromJson(config.models.single.toJson())!.tools,
        false,
      );
      expect(const AiModelConfig(id: 'm').toJson().containsKey('tools'), false);
    });

    test('dropping images keeps tool calls and results', () {
      final target = AiResolvedModel(provider(), provider().models.first);
      const call = AiToolCall(
        id: 'c1',
        name: 'list_tags',
        argumentsRaw: '',
        arguments: <String, Object?>{},
      );
      final prepared = AiService.prepareRequest(
        target,
        AiRequest(
          model: 'x',
          tools: const [tool],
          messages: [
            const AiMessage(AiRole.assistant, [AiToolCallPart(call)]),
            AiMessage(AiRole.user, [
              const AiToolResultPart(
                callId: 'c1',
                name: 'list_tags',
                content: '[]',
              ),
              AiImagePart(Uint8List(1), 'image/png'),
            ]),
          ],
        ),
      );
      expect(prepared.hasImages, isFalse);
      expect(prepared.tools.single.name, 'list_tags');
      expect(prepared.messages.first.toolCalls.single.id, 'c1');
      expect(prepared.messages.last.toolResults.single.callId, 'c1');
    });

    test('complete collects tool calls', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1",'
              '"function":{"name":"list_tags","arguments":"{}"}}]}}]}',
        ),
        (null, '{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}'),
      ]);
      final target = AiResolvedModel(provider(), provider().models.first);
      final result = await service().complete(
        target,
        AiRequest(
          model: 'x',
          tools: const [tool],
          messages: [AiMessage.text(AiRole.user, 'hi')],
        ),
      );
      expect(result.finishReason, AiFinishReason.toolCalls);
      expect(result.toolCalls.single.name, 'list_tags');
    });
  });

  test('other errors are not retried without images or thinking', () async {
    var calls = 0;
    server.handler = (request, response) async {
      calls++;
      await writeJson(response, {'error': 'bad key'}, status: 401);
    };
    final config = provider(retries: 0, vision: true);
    await expectLater(
      service().complete(
        AiResolvedModel(config, config.models.single),
        AiRequest(
          model: 'm1',
          reasoning: true,
          messages: [
            AiMessage(AiRole.user, [AiImagePart(Uint8List(1), 'image/png')]),
          ],
        ),
      ),
      throwsA(isA<AiException>()),
    );
    expect(calls, 1);
  });
}
