import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_presets.dart';
import 'package:node_diary/core/services/ai/ai_usage_ledger.dart';

AiProviderConfig _provider(String id, {bool enabled = true}) =>
    AiProviderConfig(
      id: id,
      name: id,
      protocol: AiProtocol.openAi,
      baseUrl: 'https://example.com/v1',
      enabled: enabled,
      models: [
        AiModelConfig(id: '$id-a'),
        AiModelConfig(id: '$id-b'),
      ],
    );

void main() {
  group('AiLocalConfig', () {
    test('round-trips through encode and decode', () {
      final config = AiLocalConfig(
        providers: [
          _provider('x').copyWith(
            apiKey: 'k',
            proxy: '127.0.0.1:7890',
            headers: const {'A': 'b'},
            extraBody: '{"a":1}',
            stream: false,
            retries: 2,
          ),
        ],
        defaultModel: const AiModelRef('x', 'x-a'),
        fastModel: const AiModelRef('x', 'x-b'),
        taskModels: const {AiTaskKind.chat: AiModelRef('x', 'x-b')},
        acknowledgedHosts: const {'example.com'},
      );
      expect(AiLocalConfig.decode(config.encode()), config);
    });

    test('drops broken entries and tolerates wrong types', () {
      final config = AiLocalConfig.decode('''
        {"providers": [
          {"id": "ok", "protocol": "gemini", "baseUrl": "https://g",
           "stream": "yes", "retries": 99,
           "models": [{"id": "m"}, {"id": ""}, {"id": "m"}, 3]},
          {"id": "noProtocol"},
          "junk"
        ],
        "tasks": {"chat": {"provider": "ok", "model": "m"}, "nope": {}},
        "default": "bad"}
      ''');
      final provider = config.providers.single;
      expect(provider.protocol, AiProtocol.gemini);
      expect(provider.stream, isTrue);
      expect(provider.retries, AiProviderConfig.maxRetries);
      expect(provider.models.map((m) => m.id), ['m']);
      expect(config.taskModels.keys, [AiTaskKind.chat]);
      expect(config.defaultModel, isNull);
      expect(AiLocalConfig.decode('not json'), AiLocalConfig.empty);
    });

    test('resolves tasks through explicit, fast, default then first', () {
      final config = AiLocalConfig(
        providers: [_provider('off', enabled: false), _provider('a')],
        fastModel: const AiModelRef('a', 'a-b'),
        taskModels: const {AiTaskKind.reply: AiModelRef('gone', 'x')},
      );
      expect(
        config.resolveTask(AiTaskKind.chat)!.ref,
        const AiModelRef('a', 'a-a'),
      );
      expect(
        config.resolveTask(AiTaskKind.suggest)!.ref,
        const AiModelRef('a', 'a-b'),
      );
      // 指向已删除服务商的路由退回默认。
      expect(
        config.resolveTask(AiTaskKind.reply)!.ref,
        const AiModelRef('a', 'a-a'),
      );

      final withDefault = config.copyWith(
        defaultModel: const AiModelRef('a', 'a-b'),
      );
      expect(withDefault.resolveTask(AiTaskKind.chat)!.model.id, 'a-b');
    });

    test('removing a provider clears routes to it', () {
      final config = AiLocalConfig(
        providers: [_provider('a'), _provider('b')],
        defaultModel: const AiModelRef('a', 'a-a'),
        fastModel: const AiModelRef('b', 'b-a'),
        taskModels: const {
          AiTaskKind.chat: AiModelRef('a', 'a-b'),
          AiTaskKind.recap: AiModelRef('b', 'b-b'),
        },
      );
      final next = config.withoutProvider('a');
      expect(next.providers.map((p) => p.id), ['b']);
      expect(next.defaultModel, isNull);
      expect(next.fastModel, const AiModelRef('b', 'b-a'));
      expect(next.taskModels.keys, [AiTaskKind.recap]);
    });

    test('is not ready without a usable provider', () {
      expect(AiLocalConfig.empty.isReady, isFalse);
      expect(
        AiLocalConfig(
          providers: [_provider('a').copyWith(models: const [])],
        ).isReady,
        isFalse,
      );
      expect(AiLocalConfig(providers: [_provider('a')]).isReady, isTrue);
    });
  });

  test('models take images and think by default, stored sparsely', () {
    const model = AiModelConfig(id: 'any-model');
    expect(model.supportsVision, isTrue);
    expect(model.reasoning, isTrue);
    expect(model.toJson(), {'id': 'any-model'});
    // 只记关掉的；旧数据没有这两项时按开启读。
    const off = AiModelConfig(id: 'm', vision: false, reasoning: false);
    expect(off.toJson(), {'id': 'm', 'vision': false, 'reasoning': false});
    expect(AiModelConfig.fromJson(off.toJson()), off);
    expect(AiModelConfig.fromJson({'id': 'm'})!.reasoning, isTrue);
    expect(AiModelConfig.fromJson({'id': 'm'})!.supportsVision, isTrue);
  });

  test('presets have unique ids and create usable configs', () {
    final ids = aiProviderPresets.map((preset) => preset.id).toSet();
    expect(ids.length, aiProviderPresets.length);
    final claude = aiProviderPresetById(AiPresetIds.anthropic)!;
    final config = claude.create(id: 'c', name: 'Claude');
    expect(config.protocol, AiProtocol.anthropic);
    expect(config.sendTemperature, isFalse);
    expect(config.presetId, AiPresetIds.anthropic);
    // 预设不带模型（写死的推荐很快过时），新建后从服务商获取。
    for (final preset in aiProviderPresets) {
      expect(preset.create(id: 'x', name: 'x').models, isEmpty);
    }
    // OpenAI 走 Responses 接口，不发温度（推理模型不接受）。
    final openai = aiProviderPresetById(AiPresetIds.openai)!;
    expect(openai.protocol, AiProtocol.openAiResponses);
    expect(openai.sendTemperature, isFalse);
    expect(
      aiProviderPresetById(AiPresetIds.customOpenAiResponses)!.protocol,
      AiProtocol.openAiResponses,
    );
  });

  group('AiUsageLedger', () {
    test('accumulates per month and model and survives encoding', () {
      var ledger = AiUsageLedger.empty;
      final at = DateTime(2026, 3, 5);
      ledger = ledger.record(
        at: at,
        providerId: 'p',
        providerName: 'P',
        model: 'm',
        failed: false,
        usage: const AiUsage(inputTokens: 10, outputTokens: 5),
      );
      ledger = ledger.record(
        at: at,
        providerId: 'p',
        providerName: 'P2',
        model: 'm',
        failed: true,
      );
      final entry = AiUsageLedger.decode(
        ledger.encode(),
      ).entriesOf('2026-03').single;
      expect(entry.requests, 2);
      expect(entry.failures, 1);
      expect(entry.totalTokens, 15);
      expect(entry.providerName, 'P2');
    });

    test('keeps only the most recent months', () {
      var ledger = AiUsageLedger.empty;
      for (var i = 0; i < AiUsageLedger.maxMonths + 3; i++) {
        ledger = ledger.record(
          at: DateTime(2020, 1 + i),
          providerId: 'p',
          providerName: 'P',
          model: 'm',
          failed: false,
        );
      }
      expect(ledger.months.length, AiUsageLedger.maxMonths);
      expect(ledger.monthKeys.last, '2020-04');
    });
  });
}
