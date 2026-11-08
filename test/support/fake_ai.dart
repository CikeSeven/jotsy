import 'dart:convert';

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

/// 按队列回放的假客户端（照 Phase 的 `ScriptedProvider`）：每次请求取出
/// 队首的一段块，用 [textTurn] / [toolTurn] 构造；队列空了再请求就失败，
/// 免得测试悄悄多发请求。
class ScriptedAiChatClient extends AiChatClient {
  ScriptedAiChatClient(this.turns, this.requests)
    : super(FakeAiChatClient._config, AiHttp());

  final List<List<AiChunk>> turns;
  final List<AiRequest> requests;

  @override
  Stream<AiChunk> stream(
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async* {
    requests.add(request);
    if (turns.isEmpty) {
      throw StateError('No scripted turn left for request #${requests.length}');
    }
    for (final chunk in turns.removeAt(0)) {
      yield chunk;
    }
  }

  @override
  Future<List<AiRemoteModel>> listModels({
    HttpCancelToken? cancelToken,
  }) async => const <AiRemoteModel>[AiRemoteModel(id: 'fake-model')];
}

/// 一次只回答文字的响应。
List<AiChunk> textTurn(String text) => <AiChunk>[
  AiChunk(text: text),
  const AiChunk(
    usage: AiUsage(inputTokens: 10, outputTokens: 5),
    finishReason: AiFinishReason.stop,
  ),
];

/// 一次请求工具的响应：可选的正文，然后是完整的调用（与真实客户端一样
/// 在最后一块给出）。
List<AiChunk> toolTurn(
  List<({String id, String name, Map<String, Object?> args})> calls, {
  String text = '',
}) => <AiChunk>[
  if (text.isNotEmpty) AiChunk(text: text),
  for (var i = 0; i < calls.length; i++)
    AiChunk(
      toolCallStarted: AiToolCallStart(index: i, name: calls[i].name),
    ),
  AiChunk(
    toolCalls: [
      for (final call in calls)
        AiToolCall(
          id: call.id,
          name: call.name,
          argumentsRaw: jsonEncode(call.args),
          arguments: call.args,
        ),
    ],
    finishReason: AiFinishReason.toolCalls,
  ),
];

/// 用按队列回放的假客户端的 AiService。
AiService scriptedAiService(
  AiProviderStore store, {
  required List<List<AiChunk>> turns,
  List<AiRequest>? requests,
}) {
  final log = requests ?? <AiRequest>[];
  return AiService(
    store: store,
    clientFactory: (config, http) => ScriptedAiChatClient(turns, log),
  );
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
