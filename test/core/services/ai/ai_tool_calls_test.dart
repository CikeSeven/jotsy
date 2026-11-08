import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_client.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_tool_call_assembler.dart';

import 'ai_test_server.dart';

AiProviderConfig _provider(
  AiTestServer server,
  AiProtocol protocol, {
  String path = '',
}) {
  return AiProviderConfig(
    id: 'p',
    name: 'Test',
    protocol: protocol,
    baseUrl: '${server.baseUrl}$path',
    apiKey: 'secret',
    models: const [AiModelConfig(id: 'm')],
  );
}

const AiToolSpec _searchTool = AiToolSpec(
  name: 'search_diaries',
  description: 'Search diaries.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'query': <String, Object?>{'type': 'string'},
    },
    'required': <String>['query'],
  },
);

AiToolCall _call(
  String id, {
  bool fromProvider = true,
  Map<String, Object?>? providerData,
}) => parseAiToolCall(
  id: id,
  name: 'search_diaries',
  argumentsRaw: '{"query":"trip"}',
  idFromProvider: fromProvider,
  providerData: providerData,
);

/// 一步工具调用之后的请求：问题 → 助手（回放 + 正文 + 调用）→ 结果。
AiRequest _followUp({
  required List<AiReplayPart> replay,
  required AiToolCall call,
  bool error = false,
  bool reasoning = false,
}) => AiRequest(
  model: 'm',
  system: 'sys',
  reasoning: reasoning,
  tools: const [_searchTool],
  messages: [
    AiMessage.text(AiRole.user, 'find my trip'),
    AiMessage(AiRole.assistant, [
      ...replay,
      const AiTextPart('Let me check.'),
      AiToolCallPart(call),
    ]),
    AiMessage(AiRole.user, [
      AiToolResultPart(
        callId: call.id,
        name: call.name,
        content: '{"count":1}',
        isError: error,
      ),
    ]),
  ],
);

class _Collected {
  final StringBuffer text = StringBuffer();
  final StringBuffer reasoning = StringBuffer();
  final List<AiToolCall> calls = <AiToolCall>[];
  final List<AiReplayPart> replay = <AiReplayPart>[];
  final List<String> started = <String>[];
  AiFinishReason? finish;
}

Future<_Collected> _collect(Stream<AiChunk> stream) async {
  final result = _Collected();
  await for (final chunk in stream) {
    result.text.write(chunk.text);
    result.reasoning.write(chunk.reasoning);
    result.calls.addAll(chunk.toolCalls);
    result.replay.addAll(chunk.replay);
    if (chunk.toolCallStarted case final started?) {
      result.started.add(started.name);
    }
    result.finish = chunk.finishReason ?? result.finish;
  }
  return result;
}

String _json(Object value) => jsonEncode(value);

void main() {
  late AiTestServer server;

  setUp(() async => server = await AiTestServer.start());
  tearDown(() => server.close());

  group('OpenAI compatible tools', () {
    test('assembles fragmented parallel calls and keeps reasoning', () async {
      server.handler = (request, response) => writeSse(response, [
        (null, '{"choices":[{"delta":{"reasoning_content":"plan "}}]}'),
        (null, '{"choices":[{"delta":{"content":"Let me check."}}]}'),
        (
          null,
          _json({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call_a',
                      'type': 'function',
                      'function': {
                        'name': 'search_diaries',
                        'arguments': '{"que',
                      },
                    },
                  ],
                },
              },
            ],
          }),
        ),
        (
          null,
          _json({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'function': {'arguments': 'ry":"trip"}'},
                    },
                    {
                      'index': 1,
                      'id': 'call_b',
                      'function': {'name': 'list_tags', 'arguments': ''},
                    },
                  ],
                },
              },
            ],
          }),
        ),
        (null, '{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}'),
        (null, '[DONE]'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.text.toString(), 'Let me check.');
      expect(result.started, ['search_diaries', 'list_tags']);
      expect(result.finish, AiFinishReason.toolCalls);
      expect(result.calls.map((call) => call.id), ['call_a', 'call_b']);
      expect(result.calls.first.arguments, {'query': 'trip'});
      expect(result.calls.last.arguments, isEmpty);
      expect(result.replay.single.data, {'reasoning_content': 'plan '});

      final body = server.requests.single.json;
      expect(body['tools'], [
        {
          'type': 'function',
          'function': {
            'name': 'search_diaries',
            'description': 'Search diaries.',
            'parameters': _searchTool.parameters,
          },
        },
      ]);
      expect(body.containsKey('tool_choice'), isFalse);
    });

    test('sends calls, results and reasoning only with tool calls', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}',
        ),
        (null, '[DONE]'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, path: '/v1'),
      );
      final replay = [
        const AiReplayPart(AiProtocol.openAi, {'reasoning_content': 'plan'}),
      ];
      final request = _followUp(replay: replay, call: _call('call_a'));
      await _collect(
        client.stream(
          request.copyWith(
            messages: [
              // 不带调用的助手消息不回传思考字段。
              AiMessage(AiRole.assistant, [...replay, const AiTextPart('hey')]),
              ...request.messages,
            ],
          ),
        ),
      );
      final messages = (server.requests.single.json['messages'] as List)
          .cast<Map>();
      expect(messages[1], {'role': 'assistant', 'content': 'hey'});
      expect(messages[3], {
        'role': 'assistant',
        'content': 'Let me check.',
        'tool_calls': [
          {
            'id': 'call_a',
            'type': 'function',
            'function': {
              'name': 'search_diaries',
              'arguments': '{"query":"trip"}',
            },
          },
        ],
        'reasoning_content': 'plan',
      });
      expect(messages[4], {
        'role': 'tool',
        'tool_call_id': 'call_a',
        'content': '{"count":1}',
      });
    });

    test('truncated output is not complete and bad JSON is flagged', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          _json({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'function': {
                        'name': 'search_diaries',
                        'arguments': '{"query":"tr',
                      },
                    },
                  ],
                },
                'finish_reason': 'length',
              },
            ],
          }),
        ),
        (null, '[DONE]'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.finish, AiFinishReason.length);
      expect(result.finish!.isComplete, isFalse);
      final call = result.calls.single;
      expect(call.idFromProvider, isFalse);
      expect(call.id, isNotEmpty);
      expect(call.arguments, isNull);
      expect(call.argumentsError, isNotNull);
    });

    test('two new calls in one delta are both kept', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          _json({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call_a',
                      'function': {'name': 'list_tags', 'arguments': '{}'},
                    },
                    {
                      'index': 1,
                      'id': 'call_b',
                      'function': {'name': 'list_notebooks', 'arguments': ''},
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
          }),
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.calls.map((call) => call.name), [
        'list_tags',
        'list_notebooks',
      ]);
    });

    test('a stream that just stops has no finish reason', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          _json({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call_a',
                      'function': {'name': 'list_tags', 'arguments': '{}'},
                    },
                  ],
                },
              },
            ],
          }),
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAi, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.calls, hasLength(1));
      expect(result.finish, isNull);
    });
  });

  group('OpenAI Responses tools', () {
    test('assembles function calls and replays the output items', () async {
      final reasoningItem = {
        'type': 'reasoning',
        'id': 'rs_1',
        'summary': [
          {'type': 'summary_text', 'text': 'plan'},
        ],
        'encrypted_content': 'ENC',
      };
      final callItem = {
        'type': 'function_call',
        'id': 'fc_1',
        'call_id': 'call_a',
        'name': 'search_diaries',
        'arguments': '{"query":"trip"}',
        'status': 'completed',
      };
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          _json({
            'type': 'response.reasoning_summary_text.delta',
            'delta': 'plan',
          }),
        ),
        (
          null,
          _json({
            'type': 'response.output_item.done',
            'output_index': 0,
            'item': reasoningItem,
          }),
        ),
        (
          null,
          _json({
            'type': 'response.output_item.added',
            'output_index': 1,
            'item': {
              'type': 'function_call',
              'id': 'fc_1',
              'call_id': 'call_a',
              'name': 'search_diaries',
              'arguments': '',
            },
          }),
        ),
        (
          null,
          _json({
            'type': 'response.function_call_arguments.delta',
            'item_id': 'fc_1',
            'output_index': 1,
            'delta': '{"query":',
          }),
        ),
        (
          null,
          _json({
            'type': 'response.function_call_arguments.delta',
            'item_id': 'fc_1',
            'output_index': 1,
            'delta': '"trip"}',
          }),
        ),
        (
          null,
          _json({
            'type': 'response.output_item.done',
            'output_index': 1,
            'item': callItem,
          }),
        ),
        (
          null,
          _json({
            'type': 'response.completed',
            'response': {
              'status': 'completed',
              'usage': {'input_tokens': 5, 'output_tokens': 2},
              'output': <Object>[],
            },
          }),
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            reasoning: true,
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.reasoning.toString(), 'plan');
      expect(result.started, ['search_diaries']);
      expect(result.finish, AiFinishReason.toolCalls);
      final call = result.calls.single;
      expect(call.id, 'call_a');
      expect(call.arguments, {'query': 'trip'});
      expect(call.providerData, {'id': 'fc_1'});
      expect(result.replay.single.data['items'], [reasoningItem, callItem]);

      final body = server.requests.single.json;
      expect(body['include'], ['reasoning.encrypted_content']);
      expect(body['tools'], [
        {
          'type': 'function',
          'name': 'search_diaries',
          'description': 'Search diaries.',
          'parameters': _searchTool.parameters,
          'strict': false,
        },
      ]);
    });

    test('sends replayed items verbatim and function outputs', () async {
      server.handler = (request, response) => writeJson(response, {
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': 'ok'},
            ],
          },
        ],
      });
      final client = AiChatClient.forProvider(
        AiProviderConfig(
          id: 'p',
          name: 'Test',
          protocol: AiProtocol.openAiResponses,
          baseUrl: '${server.baseUrl}/v1',
          stream: false,
        ),
      );
      const encrypted = {
        'type': 'reasoning',
        'id': 'rs_1',
        'summary': [],
        'encrypted_content': 'ENC',
      };
      const plain = {'type': 'reasoning', 'id': 'rs_0', 'summary': []};
      const callItem = {
        'type': 'function_call',
        'id': 'fc_1',
        'call_id': 'call_a',
        'name': 'search_diaries',
        'arguments': '{"query":"trip"}',
      };
      final result = await _collect(
        client.stream(
          _followUp(
            replay: const [
              AiReplayPart(AiProtocol.openAiResponses, {
                'items': [plain, encrypted, callItem],
              }),
            ],
            call: _call('call_a'),
          ),
        ),
      );
      expect(result.text.toString(), 'ok');
      final input = (server.requests.single.json['input'] as List).cast<Map>();
      expect(input, [
        {'role': 'user', 'content': 'find my trip'},
        // 没有加密内容的推理条目丢掉，其余原样带回。
        encrypted,
        callItem,
        {
          'type': 'function_call_output',
          'call_id': 'call_a',
          'output': '{"count":1}',
        },
      ]);
    });

    test('rebuilds function calls when there is nothing to replay', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          _json({
            'type': 'response.completed',
            'response': {'status': 'completed', 'output': <Object>[]},
          }),
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses, path: '/v1'),
      );
      await _collect(
        client.stream(
          _followUp(
            replay: const [],
            call: _call('call_a', providerData: const {'id': 'fc_9'}),
          ),
        ),
      );
      final input = (server.requests.single.json['input'] as List).cast<Map>();
      expect(input[1], {'role': 'assistant', 'content': 'Let me check.'});
      expect(input[2], {
        'type': 'function_call',
        'id': 'fc_9',
        'call_id': 'call_a',
        'name': 'search_diaries',
        'arguments': '{"query":"trip"}',
      });
    });

    test('an incomplete response is not complete', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          _json({
            'type': 'response.output_item.done',
            'output_index': 0,
            'item': {
              'type': 'function_call',
              'id': 'fc_1',
              'call_id': 'call_a',
              'name': 'search_diaries',
              'arguments': '{"query":"tr',
            },
          }),
        ),
        (
          null,
          _json({
            'type': 'response.incomplete',
            'response': {
              'status': 'incomplete',
              'incomplete_details': {'reason': 'max_output_tokens'},
            },
          }),
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.openAiResponses, path: '/v1'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.finish, AiFinishReason.length);
      expect(result.calls.single.argumentsError, isNotNull);
    });
  });

  group('Anthropic tools', () {
    List<(String?, String)> toolStream({bool signed = true}) => [
      (
        'message_start',
        '{"type":"message_start","message":{"usage":{"input_tokens":9}}}',
      ),
      (
        null,
        '{"type":"content_block_start","index":0,'
            '"content_block":{"type":"thinking","thinking":""}}',
      ),
      (
        null,
        '{"type":"content_block_delta","index":0,'
            '"delta":{"type":"thinking_delta","thinking":"plan"}}',
      ),
      if (signed)
        (
          null,
          '{"type":"content_block_delta","index":0,'
              '"delta":{"type":"signature_delta","signature":"SIG"}}',
        ),
      (null, '{"type":"content_block_stop","index":0}'),
      (
        null,
        '{"type":"content_block_start","index":1,'
            '"content_block":{"type":"text","text":""}}',
      ),
      (
        null,
        '{"type":"content_block_delta","index":1,'
            '"delta":{"type":"text_delta","text":"Checking."}}',
      ),
      (
        null,
        '{"type":"content_block_start","index":2,"content_block":'
            '{"type":"tool_use","id":"toolu_1","name":"search_diaries",'
            '"input":{}}}',
      ),
      (
        null,
        _json({
          'type': 'content_block_delta',
          'index': 2,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': '{"query": "tr',
          },
        }),
      ),
      (
        null,
        _json({
          'type': 'content_block_delta',
          'index': 2,
          'delta': {'type': 'input_json_delta', 'partial_json': 'ip"}'},
        }),
      ),
      (null, '{"type":"content_block_stop","index":2}'),
      (
        null,
        '{"type":"message_delta","delta":{"stop_reason":"tool_use"},'
            '"usage":{"output_tokens":4}}',
      ),
      (null, '{"type":"message_stop"}'),
    ];

    test('assembles tool_use blocks and keeps signed thinking', () async {
      server.handler = (request, response) => writeSse(response, toolStream());
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.anthropic),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            reasoning: true,
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.text.toString(), 'Checking.');
      expect(result.reasoning.toString(), 'plan');
      expect(result.started, ['search_diaries']);
      expect(result.finish, AiFinishReason.toolCalls);
      expect(result.calls.single.id, 'toolu_1');
      expect(result.calls.single.arguments, {'query': 'trip'});
      expect(result.replay.single.data['block'], {
        'type': 'thinking',
        'thinking': 'plan',
        'signature': 'SIG',
      });
      expect(server.requests.single.json['tools'], [
        {
          'name': 'search_diaries',
          'description': 'Search diaries.',
          'input_schema': _searchTool.parameters,
        },
      ]);
    });

    test('drops thinking blocks without a signature', () async {
      server.handler = (request, response) =>
          writeSse(response, toolStream(signed: false));
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.anthropic),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.calls, hasLength(1));
      expect(result.replay, isEmpty);
    });

    test('sends thinking, tool_use and tool_result blocks', () async {
      server.handler = (request, response) => writeSse(response, [
        (null, '{"type":"message_delta","delta":{"stop_reason":"end_turn"}}'),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.anthropic),
      );
      const block = {
        'type': 'thinking',
        'thinking': 'plan',
        'signature': 'SIG',
      };
      await _collect(
        client.stream(
          _followUp(
            replay: const [
              AiReplayPart(AiProtocol.anthropic, {'block': block}),
            ],
            call: _call('toolu_1'),
            error: true,
          ),
        ),
      );
      final messages = (server.requests.single.json['messages'] as List)
          .cast<Map>();
      expect(messages[1], {
        'role': 'assistant',
        'content': [
          block,
          {'type': 'text', 'text': 'Let me check.'},
          {
            'type': 'tool_use',
            'id': 'toolu_1',
            'name': 'search_diaries',
            'input': {'query': 'trip'},
          },
        ],
      });
      expect(messages[2], {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'toolu_1',
            'content': '{"count":1}',
            'is_error': true,
          },
        ],
      });
    });
  });

  group('Gemini tools', () {
    test('collects whole function calls with their signatures', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"candidates":[{"content":{"role":"model",'
              '"parts":[{"text":"Checking."}]}}]}',
        ),
        (
          null,
          _json({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'search_diaries',
                        'args': {'query': 'trip'},
                      },
                      'thoughtSignature': 'SIG',
                    },
                    {
                      'functionCall': {'name': 'list_tags', 'args': {}},
                    },
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.gemini, path: '/v1beta'),
      );
      final result = await _collect(
        client.stream(
          AiRequest(
            model: 'm',
            tools: const [_searchTool],
            messages: [AiMessage.text(AiRole.user, 'hi')],
          ),
        ),
      );
      expect(result.text.toString(), 'Checking.');
      expect(result.finish, AiFinishReason.toolCalls);
      expect(result.calls.map((call) => call.name), [
        'search_diaries',
        'list_tags',
      ]);
      // 服务端没给 id：本地生成且互不相同。
      expect(result.calls.every((call) => !call.idFromProvider), isTrue);
      expect(result.calls.first.id, isNot(result.calls.last.id));
      expect(result.calls.first.arguments, {'query': 'trip'});
      expect(result.calls.first.providerData, {'thoughtSignature': 'SIG'});
      expect(server.requests.single.json['tools'], [
        {
          'functionDeclarations': [
            {
              'name': 'search_diaries',
              'description': 'Search diaries.',
              'parameters': _searchTool.parameters,
            },
          ],
        },
      ]);
    });

    test('sends calls with signatures and object responses', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"candidates":[{"content":{"parts":[{"text":"ok"}]},'
              '"finishReason":"STOP"}]}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.gemini, path: '/v1beta'),
      );
      await _collect(
        client.stream(
          _followUp(
            replay: const [],
            call: _call(
              'local_1',
              fromProvider: false,
              providerData: const {'thoughtSignature': 'SIG'},
            ),
          ),
        ),
      );
      final contents = (server.requests.single.json['contents'] as List)
          .cast<Map>();
      expect(contents[1], {
        'role': 'model',
        'parts': [
          {'text': 'Let me check.'},
          {
            'functionCall': {
              'name': 'search_diaries',
              'args': {'query': 'trip'},
            },
            'thoughtSignature': 'SIG',
          },
        ],
      });
      expect(contents[2], {
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': 'search_diaries',
              'response': {'count': 1},
            },
          },
        ],
      });
    });

    test('echoes provider ids and wraps errors', () async {
      server.handler = (request, response) => writeSse(response, [
        (
          null,
          '{"candidates":[{"content":{"parts":[{"text":"ok"}]},'
              '"finishReason":"STOP"}]}',
        ),
      ]);
      final client = AiChatClient.forProvider(
        _provider(server, AiProtocol.gemini, path: '/v1beta'),
      );
      await _collect(
        client.stream(
          _followUp(replay: const [], call: _call('fc_7'), error: true),
        ),
      );
      final contents = (server.requests.single.json['contents'] as List)
          .cast<Map>();
      final call = ((contents[1]['parts'] as List)[1] as Map)['functionCall'];
      expect((call as Map)['id'], 'fc_7');
      expect(
        ((contents[2]['parts'] as List).single as Map)['functionResponse'],
        {
          'name': 'search_diaries',
          'id': 'fc_7',
          'response': {
            'error': {'count': 1},
          },
        },
      );
    });
  });

  group('AiToolCallAssembler', () {
    test('replaces duplicate ids and treats blank arguments as empty', () {
      final assembler = AiToolCallAssembler()
        ..add(0, id: 'same', name: 'a', arguments: '')
        ..add(1, id: 'same', name: 'b', arguments: '  ')
        ..add(2, arguments: '{"x":1}');
      final calls = assembler.finish();
      // 没有名称的残片丢弃。
      expect(calls.map((call) => call.name), ['a', 'b']);
      expect(calls.first.id, 'same');
      expect(calls.last.id, isNot('same'));
      expect(calls.last.idFromProvider, isFalse);
      expect(calls.every((call) => call.arguments!.isEmpty), isTrue);
    });

    test('rejects arguments that are not an object', () {
      final call = parseAiToolCall(id: 'c', name: 'a', argumentsRaw: '[1]');
      expect(call.hasValidArguments, isFalse);
      expect(call.argumentsError, contains('object'));
    });
  });
}
