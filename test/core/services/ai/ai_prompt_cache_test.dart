import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_client_anthropic.dart';
import 'package:node_diary/core/services/ai/ai_client_openai.dart';
import 'package:node_diary/core/services/ai/ai_client_openai_responses.dart';
import 'package:node_diary/core/services/ai/ai_http.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';

/// 提示缓存的请求写法：给了 `cacheKey` 的请求（智能体）在 Anthropic 打三个
/// 缓存断点、在 OpenAI 发 `prompt_cache_key`，一次性请求不打（写缓存要多
/// 计费）；DeepSeek 思考模式要求同一轮带回的 `reasoning_content` 空串也带。
void main() {
  AiProviderConfig provider(
    AiProtocol protocol, {
    String baseUrl = 'https://example.test/v1',
  }) => AiProviderConfig(
    id: 'p',
    name: 'Test',
    protocol: protocol,
    baseUrl: baseUrl,
    models: const [AiModelConfig(id: 'm')],
  );

  const tool = AiToolSpec(
    name: 'list_tags',
    description: 'List tags.',
    parameters: <String, Object?>{'type': 'object'},
  );
  const other = AiToolSpec(
    name: 'list_notebooks',
    description: 'List notebooks.',
    parameters: <String, Object?>{'type': 'object'},
  );

  AiRequest request({String? cacheKey}) => AiRequest(
    model: 'm',
    system: 'be kind',
    tools: const [tool, other],
    cacheKey: cacheKey,
    messages: [
      AiMessage.text(AiRole.user, 'hi'),
      const AiMessage(AiRole.assistant, [
        AiToolCallPart(
          AiToolCall(
            id: 'c1',
            name: 'list_tags',
            argumentsRaw: '{}',
            arguments: <String, Object?>{},
          ),
        ),
      ]),
      const AiMessage(AiRole.user, [
        AiToolResultPart(callId: 'c1', name: 'list_tags', content: '[]'),
      ]),
    ],
  );

  group('cache hints', () {
    test('Anthropic marks system, last tool and last user message', () {
      final client = AnthropicChatClient(
        provider(AiProtocol.anthropic),
        AiHttp(),
      );
      final body = client.buildBody(request(cacheKey: 'conv'), stream: true);
      expect(body['system'], [
        {
          'type': 'text',
          'text': 'be kind',
          'cache_control': {'type': 'ephemeral'},
        },
      ]);
      final tools = body['tools']! as List;
      expect((tools.first as Map).containsKey('cache_control'), isFalse);
      expect((tools.last as Map)['cache_control'], {'type': 'ephemeral'});
      final messages = body['messages']! as List;
      final first = messages.first as Map;
      // 只有最后一条用户消息打断点（总共三个，Anthropic 最多四个）。
      expect(first['content'], 'hi');
      final last = (messages.last as Map)['content'] as List;
      expect((last.last as Map)['type'], 'tool_result');
      expect((last.last as Map)['cache_control'], {'type': 'ephemeral'});
    });

    test('Anthropic one-off requests carry no breakpoints', () {
      final client = AnthropicChatClient(
        provider(AiProtocol.anthropic),
        AiHttp(),
      );
      final body = client.buildBody(request(), stream: true);
      expect(body['system'], 'be kind');
      expect(body.toString(), isNot(contains('cache_control')));
    });

    test('OpenAI gets prompt_cache_key; compatible services do not', () {
      final responses = OpenAiResponsesClient(
        provider(AiProtocol.openAiResponses),
        AiHttp(),
      );
      expect(
        responses.buildBody(
          request(cacheKey: 'conv'),
          stream: true,
        )['prompt_cache_key'],
        'conv',
      );
      expect(
        responses
            .buildBody(request(), stream: true)
            .containsKey('prompt_cache_key'),
        isFalse,
      );
      final openAi = OpenAiChatClient(
        provider(AiProtocol.openAi, baseUrl: 'https://api.openai.com/v1'),
        AiHttp(),
      );
      expect(
        openAi.buildBody(
          request(cacheKey: 'conv'),
          stream: true,
        )['prompt_cache_key'],
        'conv',
      );
      final deepSeek = OpenAiChatClient(
        provider(AiProtocol.openAi, baseUrl: 'https://api.deepseek.com'),
        AiHttp(),
      );
      expect(
        deepSeek
            .buildBody(request(cacheKey: 'conv'), stream: true)
            .containsKey('prompt_cache_key'),
        isFalse,
      );
    });
  });

  test('Chat compatible replays an empty reasoning_content it was given', () {
    // DeepSeek 思考模式下同一轮的工具调用消息缺 reasoning_content 会 400，
    // 这一步没有思考时它是空串，也得带回去。
    final state = OpenAiChatStreamState()
      ..add({
        'choices': [
          {
            'delta': {
              'reasoning_content': '',
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'c1',
                  'function': {'name': 'list_tags', 'arguments': '{}'},
                },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      });
    final end = state.finish();
    expect(end.replay.single.data, {'reasoning_content': ''});
  });
}
