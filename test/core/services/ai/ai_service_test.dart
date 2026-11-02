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
    expect(prepared.messages.single.text, 'describe');
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
}
