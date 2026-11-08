import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_client.dart';
import 'package:node_diary/core/services/ai/ai_client_openai.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_usage_ledger.dart';

import 'ai_test_server.dart';

/// 命中提示缓存的输入：四种协议都读进 `AiUsage.cachedInputTokens`（含在
/// 输入里），记进回答 meta 与本机用量账本。
void main() {
  AiProviderConfig provider(AiProtocol protocol, {required String baseUrl}) =>
      AiProviderConfig(
        id: 'p',
        name: 'Test',
        protocol: protocol,
        baseUrl: baseUrl,
        models: const [AiModelConfig(id: 'm')],
      );

  group('usage with cached input', () {
    test('OpenAI compatible reads cached_tokens and DeepSeek hit tokens', () {
      final openAi = OpenAiChatClient.parseCompletion({
        'choices': [
          {
            'message': {'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 5,
          'prompt_tokens_details': {'cached_tokens': 64},
        },
      });
      expect(
        openAi.usage,
        const AiUsage(inputTokens: 100, outputTokens: 5, cachedInputTokens: 64),
      );
      final deepSeek = OpenAiChatClient.parseCompletion({
        'choices': [
          {
            'message': {'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': 300,
          'completion_tokens': 9,
          'prompt_cache_hit_tokens': 256,
          'prompt_cache_miss_tokens': 44,
        },
      });
      expect(deepSeek.usage?.cachedInputTokens, 256);
      expect(deepSeek.usage?.uncachedInputTokens, 44);
    });

    group('streamed', () {
      late AiTestServer server;
      setUp(() async => server = await AiTestServer.start());
      tearDown(() => server.close());

      Future<AiUsage?> usageOf(AiProtocol protocol) async {
        final client = AiChatClient.forProvider(
          provider(protocol, baseUrl: server.baseUrl),
        );
        AiUsage? usage;
        await for (final chunk in client.stream(
          AiRequest(model: 'm', messages: [AiMessage.text(AiRole.user, 'hi')]),
        )) {
          if (chunk.usage case final u?) {
            usage = (usage ?? const AiUsage()).merge(u);
          }
        }
        return usage;
      }

      test('Anthropic counts cache reads inside the input', () async {
        server.handler = (request, response) => writeSse(response, [
          (
            'message_start',
            '{"type":"message_start","message":{"usage":{"input_tokens":10,'
                '"cache_read_input_tokens":80,'
                '"cache_creation_input_tokens":20}}}',
          ),
          (
            'content_block_delta',
            '{"type":"content_block_delta","index":0,'
                '"delta":{"type":"text_delta","text":"Hi"}}',
          ),
          (
            'message_delta',
            '{"type":"message_delta","delta":{"stop_reason":"end_turn"},'
                '"usage":{"output_tokens":3}}',
          ),
          ('message_stop', '{"type":"message_stop"}'),
        ]);
        expect(
          await usageOf(AiProtocol.anthropic),
          const AiUsage(
            inputTokens: 110,
            outputTokens: 3,
            cachedInputTokens: 80,
          ),
        );
      });

      test('Gemini reads cachedContentTokenCount', () async {
        server.handler = (request, response) => writeSse(response, [
          (
            null,
            '{"candidates":[{"content":{"parts":[{"text":"ok"}]},'
                '"finishReason":"STOP"}],'
                '"usageMetadata":{"promptTokenCount":50,'
                '"cachedContentTokenCount":32,"candidatesTokenCount":2}}',
          ),
        ]);
        expect(
          await usageOf(AiProtocol.gemini),
          const AiUsage(
            inputTokens: 50,
            outputTokens: 2,
            cachedInputTokens: 32,
          ),
        );
      });

      test('Responses reads input_tokens_details.cached_tokens', () async {
        server.handler = (request, response) => writeSse(response, [
          (
            'response.output_text.delta',
            '{"type":"response.output_text.delta","delta":"ok"}',
          ),
          (
            'response.completed',
            '{"type":"response.completed","response":{"status":"completed",'
                '"usage":{"input_tokens":40,"output_tokens":4,'
                '"input_tokens_details":{"cached_tokens":24}}}}',
          ),
        ]);
        expect(
          await usageOf(AiProtocol.openAiResponses),
          const AiUsage(
            inputTokens: 40,
            outputTokens: 4,
            cachedInputTokens: 24,
          ),
        );
      });
    });

    test('meta and ledger keep the cached part', () {
      const usage = AiUsage(
        inputTokens: 100,
        outputTokens: 5,
        cachedInputTokens: 90,
      );
      expect(usage.toMeta(), {
        'inputTokens': 100,
        'outputTokens': 5,
        'cachedTokens': 90,
      });
      expect(const AiUsage(inputTokens: 3).toMeta(), {
        'inputTokens': 3,
        'outputTokens': 0,
      });
      final ledger = AiUsageLedger.empty
          .record(
            at: DateTime(2026, 11, 9),
            providerId: 'p',
            providerName: 'P',
            model: 'm',
            failed: false,
            usage: usage,
          )
          .record(
            at: DateTime(2026, 11, 9),
            providerId: 'p',
            providerName: 'P',
            model: 'm',
            failed: false,
            usage: usage,
          );
      final decoded = AiUsageLedger.decode(ledger.encode());
      expect(decoded.entriesOf('2026-11').single.cachedInputTokens, 180);
      expect(decoded.entriesOf('2026-11').single.inputTokens, 200);
    });
  });
}
