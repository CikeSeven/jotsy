import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_client_anthropic.dart';
import 'package:node_diary/core/services/ai/ai_client_gemini.dart';
import 'package:node_diary/core/services/ai/ai_client_openai.dart';
import 'package:node_diary/core/services/ai/ai_client_openai_responses.dart';
import 'package:node_diary/core/services/ai/ai_http.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/ui/ai/models/ai_conversation_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_test_server.dart';

AiProviderConfig _config(AiProtocol protocol, {String baseUrl = 'http://x'}) =>
    AiProviderConfig(
      id: 'p',
      name: 'Test',
      protocol: protocol,
      baseUrl: baseUrl,
      retries: 0,
      models: const [AiModelConfig(id: 'm')],
    );

AiRequest _request({bool reasoning = true, AiThinkingLevel? thinking}) =>
    AiRequest(
      model: 'm',
      temperature: 0.5,
      reasoning: reasoning,
      thinking: thinking,
      messages: [AiMessage.text(AiRole.user, 'hi')],
    ).withThinking(thinking);

void main() {
  group('request bodies by thinking level', () {
    final http = AiHttp();

    test('OpenAI Chat sends reasoning_effort only when a level is set', () {
      final client = OpenAiChatClient(_config(AiProtocol.openAi), http);
      expect(
        client
            .buildBody(_request(), stream: true)
            .containsKey('reasoning_effort'),
        isFalse,
      );
      expect(
        client.buildBody(
          _request(thinking: AiThinkingLevel.high),
          stream: true,
        )['reasoning_effort'],
        'high',
      );
      expect(
        client.buildBody(
          _request(thinking: AiThinkingLevel.off),
          stream: true,
        )['reasoning_effort'],
        'none',
      );
    });

    test('Responses puts effort beside the summary and drops temperature', () {
      final client = OpenAiResponsesClient(
        _config(AiProtocol.openAiResponses),
        http,
      );
      final low = client.buildBody(
        _request(thinking: AiThinkingLevel.low),
        stream: true,
      );
      expect(low['reasoning'], {'effort': 'low', 'summary': 'auto'});
      expect(low.containsKey('temperature'), isFalse);
      final off = client.buildBody(
        _request(thinking: AiThinkingLevel.off),
        stream: true,
      );
      expect(off['reasoning'], {'effort': 'none'});
      expect(off.containsKey('temperature'), isFalse);
      final auto = client.buildBody(_request(), stream: true);
      expect(auto['reasoning'], {'summary': 'auto'});
    });

    test('Anthropic disables thinking explicitly and sends effort apart', () {
      final client = AnthropicChatClient(_config(AiProtocol.anthropic), http);
      final medium = client.buildBody(
        _request(thinking: AiThinkingLevel.medium),
        stream: true,
      );
      expect(medium['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(medium['output_config'], {'effort': 'medium'});
      final off = client.buildBody(
        _request(thinking: AiThinkingLevel.off),
        stream: true,
      );
      expect(off['thinking'], {'type': 'disabled'});
      expect(off.containsKey('output_config'), isFalse);
      expect(off['temperature'], 0.5);
      final auto = client.buildBody(_request(), stream: true);
      expect(auto.containsKey('output_config'), isFalse);
    });

    test('Gemini uses thinkingLevel, and a zero budget to turn it off', () {
      final client = GeminiChatClient(_config(AiProtocol.gemini), http);
      Map<Object?, Object?> config(AiRequest request) =>
          (client.buildBody(request)['generationConfig']!
                  as Map)['thinkingConfig']!
              as Map;
      expect(config(_request(thinking: AiThinkingLevel.high)), {
        'includeThoughts': true,
        'thinkingLevel': 'high',
      });
      expect(config(_request(thinking: AiThinkingLevel.off)), {
        'thinkingBudget': 0,
      });
      expect(config(_request()), {'includeThoughts': true});
    });
  });

  group('AiService.prepareRequest', () {
    AiResolvedModel target({bool reasoning = true}) {
      final config = AiProviderConfig(
        id: 'p',
        name: 'Test',
        protocol: AiProtocol.anthropic,
        baseUrl: 'http://x',
        models: [AiModelConfig(id: 'm', reasoning: reasoning)],
      );
      return AiResolvedModel(config, config.models.single);
    }

    test('off turns reasoning off even when the model asks for it', () {
      final prepared = AiService.prepareRequest(
        target(),
        _request(reasoning: false, thinking: AiThinkingLevel.off),
      );
      expect(prepared.reasoning, isFalse);
      expect(prepared.thinking, AiThinkingLevel.off);
    });

    test('a model with thinking switched off gets no level at all', () {
      final prepared = AiService.prepareRequest(
        target(reasoning: false),
        _request(reasoning: false, thinking: AiThinkingLevel.high),
      );
      expect(prepared.reasoning, isFalse);
      expect(prepared.thinking, isNull);
    });
  });

  group('effort fallback', () {
    late AiTestServer server;
    late AiProviderStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      server = await AiTestServer.start();
      store = await AiProviderStore.create();
    });
    tearDown(() async {
      store.dispose();
      await server.close();
    });

    test(
      'a 400 drops the level first, keeps thinking, and remembers',
      () async {
        final bodies = <Map<String, Object?>>[];
        server.handler = (request, response) async {
          final body = request.json;
          bodies.add(body);
          final reasoning = body['reasoning'];
          if (reasoning is Map && reasoning.containsKey('effort')) {
            await writeJson(response, {
              'error': {'message': "Unsupported parameter: 'reasoning.effort'"},
            }, status: 400);
            return;
          }
          await writeSse(response, [
            (null, '{"type":"response.output_text.delta","delta":"ok"}'),
          ]);
        };
        final config = _config(
          AiProtocol.openAiResponses,
          baseUrl: server.baseUrl,
        );
        final target = AiResolvedModel(config, config.models.single);
        final ai = AiService(
          store: store,
          backoff: (_, _) => const Duration(milliseconds: 1),
        );
        final first = await ai.complete(
          target,
          _request(reasoning: false, thinking: AiThinkingLevel.high),
        );
        expect(first.text, 'ok');
        expect(bodies, hasLength(2));
        expect(bodies.last['reasoning'], {'summary': 'auto'});

        bodies.clear();
        await ai.complete(
          target,
          _request(reasoning: false, thinking: AiThinkingLevel.low),
        );
        expect(bodies, hasLength(1));
        expect(bodies.single['reasoning'], {'summary': 'auto'});
      },
    );
  });

  group('AiConversationOptions', () {
    test('round-trips and stays sparse', () {
      const options = AiConversationOptions(
        model: AiModelRef('p', 'm'),
        thinking: AiThinkingLevel.medium,
      );
      expect(AiConversationOptions.decode(options.encode()), options);
      expect(AiConversationOptions.defaults.encode(), '{}');
    });

    test('tolerates bad JSON and unknown fields', () {
      expect(
        AiConversationOptions.decode('not json'),
        AiConversationOptions.defaults,
      );
      expect(
        AiConversationOptions.decode('{"thinking":"ultra","model":3}'),
        AiConversationOptions.defaults,
      );
      expect(
        AiConversationOptions.decode('{"thinking":"off"}').thinking,
        AiThinkingLevel.off,
      );
    });
  });
}
