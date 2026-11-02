import 'package:node_diary/core/services/ai/ai_client.dart';
import 'package:node_diary/core/services/ai/ai_http.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/ai/ai_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';

/// 不联网的 AI 客户端：每次请求按 [reply] 吐出几块文字，记下收到的请求。
class FakeAiChatClient extends AiChatClient {
  FakeAiChatClient(this.reply, this.requests) : super(_config, AiHttp());

  static const AiProviderConfig _config = AiProviderConfig(
    id: 'fake',
    name: 'Fake',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://fake.test/v1',
  );

  final String Function(AiRequest request) reply;
  final List<AiRequest> requests;

  @override
  Stream<AiChunk> stream(
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async* {
    requests.add(request);
    final text = reply(request);
    final half = text.length ~/ 2;
    yield AiChunk(text: text.substring(0, half));
    yield AiChunk(
      text: text.substring(half),
      usage: const AiUsage(inputTokens: 10, outputTokens: 5),
      finishReason: AiFinishReason.stop,
    );
  }

  @override
  Future<List<AiRemoteModel>> listModels({
    HttpCancelToken? cancelToken,
  }) async => const <AiRemoteModel>[AiRemoteModel(id: 'fake-model')];
}

/// 一个可用的假服务商（主机已确认过，发送时不弹确认面板）。
const AiProviderConfig fakeAiProvider = AiProviderConfig(
  id: 'fake',
  name: 'Fake',
  protocol: AiProtocol.openAi,
  baseUrl: 'https://fake.test/v1',
  models: <AiModelConfig>[AiModelConfig(id: 'fake-model')],
);

/// 写入假服务商并把它的主机标为已确认。
Future<void> seedFakeAiProvider(AiProviderStore store) async {
  await store.saveProvider(fakeAiProvider);
  await store.acknowledgeHost(fakeAiProvider.host);
}

/// 用假客户端的 AiService（仍记账到 [store]）。
AiService fakeAiService(
  AiProviderStore store, {
  required String Function(AiRequest request) reply,
  List<AiRequest>? requests,
}) {
  final log = requests ?? <AiRequest>[];
  return AiService(
    store: store,
    clientFactory: (config, http) => FakeAiChatClient(reply, log),
  );
}
