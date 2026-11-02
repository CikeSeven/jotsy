import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_client_openai.dart';
import 'ai_failure.dart';
import 'ai_models.dart';

/// OpenAI Responses API（`/responses`，OpenAI 现行的主接口；也有部分转发
/// 服务提供同格式接口）。
///
/// - 路径：`{base}/responses`；模型列表与 Chat 接口相同（`{base}/models`）；
/// - 鉴权：`Authorization: Bearer <key>`；
/// - 请求：系统提示词放 `instructions`，对话放 `input`（文字直接写字符串，
///   带图片时为 `input_text` / `input_image` 片段）；`store: false`，不在
///   服务端保存这次对话；
/// - 思考：模型打开“思考过程”时发 `reasoning: {summary: auto}`，返回的思考
///   摘要作为思考过程；此时不发温度（推理模型不接受）。模型不支持这个参数
///   时服务端回 400，由 `AiService` 去掉思考再试一次；
/// - 流式事件：`response.output_text.delta`（正文）、
///   `response.reasoning_summary_text.delta` / `response.reasoning_text.delta`
///   （思考）、`response.completed` / `response.incomplete`（用量与结束原因）、
///   `response.failed` 与 `error`（出错）。事件类型以数据里的 `type` 为准，
///   不依赖 `event:` 行。
class OpenAiResponsesClient extends AiChatClient {
  OpenAiResponsesClient(super.config, super.http);

  Map<String, String> get _headers => withCustomHeaders(<String, String>{
    if (config.apiKey.trim().isNotEmpty)
      'Authorization': 'Bearer ${config.apiKey.trim()}',
  });

  Map<String, Object?> buildBody(AiRequest request, {required bool stream}) {
    return withExtraBody(<String, Object?>{
      'model': request.model,
      if (request.system?.trim().isNotEmpty ?? false)
        'instructions': request.system,
      'input': [for (final message in request.messages) _message(message)],
      'stream': stream,
      'store': false,
      if (config.sendTemperature &&
          request.temperature != null &&
          !request.reasoning)
        'temperature': request.temperature,
      if (request.maxOutputTokens != null)
        'max_output_tokens': request.maxOutputTokens,
      if (request.reasoning) 'reasoning': <String, Object?>{'summary': 'auto'},
    });
  }

  Map<String, Object?> _message(AiMessage message) {
    final user = message.role == AiRole.user;
    final role = user ? 'user' : 'assistant';
    if (!message.hasImages) {
      return <String, Object?>{'role': role, 'content': message.text};
    }
    return <String, Object?>{
      'role': role,
      'content': [
        for (final part in message.parts)
          switch (part) {
            AiTextPart(:final text) => <String, Object?>{
              'type': user ? 'input_text' : 'output_text',
              'text': text,
            },
            AiImagePart(:final bytes, :final mimeType) => <String, Object?>{
              'type': 'input_image',
              'image_url': 'data:$mimeType;base64,${base64Encode(bytes)}',
            },
          },
      ],
    };
  }

  @override
  Stream<AiChunk> stream(
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async* {
    final response = await postJson(
      parseUri('$baseUrl/responses'),
      buildBody(request, stream: config.stream),
      headers: _headers,
      cancelToken: cancelToken,
    );
    if (!response.isEventStream) {
      yield parseResponse(await response.readJsonObject());
      return;
    }
    yield* parseEventStream(response, (_, data) => <AiChunk>[parseEvent(data)]);
  }

  /// 流式的一个事件。
  static AiChunk parseEvent(Map<String, Object?> data) {
    final type = jsonString(data['type']) ?? '';
    switch (type) {
      case 'response.output_text.delta':
        return AiChunk(text: jsonString(data['delta']) ?? '');
      case 'response.reasoning_summary_text.delta' ||
          'response.reasoning_text.delta':
        return AiChunk(reasoning: jsonString(data['delta']) ?? '');
      case 'response.reasoning_summary_part.done':
        // 几段思考摘要之间空一行，读起来不粘在一起。
        return const AiChunk(reasoning: '\n\n');
      case 'response.completed' || 'response.incomplete':
        final body = jsonMap(data['response']);
        return AiChunk(
          usage: _usage(body?['usage']),
          finishReason: _finish(body),
        );
      case 'response.failed':
        final error = jsonMap(jsonMap(data['response'])?['error']);
        throw _error(error);
      case 'error':
        throw _error(data);
    }
    return const AiChunk();
  }

  /// 一次性响应：`output` 里的 `message`（正文）与 `reasoning`（思考摘要）。
  static AiChunk parseResponse(Map<String, Object?> data) {
    if (data['error'] != null && jsonString(data['status']) != 'completed') {
      final error = jsonMap(data['error']);
      if (error != null) throw _error(error);
    }
    final text = StringBuffer();
    final reasoning = <String>[];
    for (final item in jsonList(data['output'])) {
      final map = jsonMap(item);
      switch (jsonString(map?['type'])) {
        case 'message':
          for (final part in jsonList(map?['content'])) {
            final content = jsonMap(part);
            if (jsonString(content?['type']) == 'output_text') {
              text.write(jsonString(content?['text']) ?? '');
            }
          }
        case 'reasoning':
          for (final part in jsonList(map?['summary'])) {
            final summary = jsonString(jsonMap(part)?['text']);
            if (summary != null && summary.isNotEmpty) reasoning.add(summary);
          }
      }
    }
    if (text.isEmpty && jsonString(data['output_text']) != null) {
      text.write(jsonString(data['output_text']));
    }
    if (jsonList(data['output']).isEmpty && text.isEmpty) {
      throw AiException(
        AiFailureKind.badResponse,
        providerMessage: jsonEncode(data),
      );
    }
    return AiChunk(
      text: text.toString(),
      reasoning: reasoning.join('\n\n'),
      usage: _usage(data['usage']),
      finishReason: _finish(data),
    );
  }

  /// 出错事件转成 [AiException]：按错误码估一个 HTTP 状态再统一归类。
  static AiException _error(Map<String, Object?>? error) {
    final code = '${error?['code'] ?? error?['type'] ?? ''}'.toLowerCase();
    final status = switch (code) {
      'rate_limit_exceeded' => 429,
      'insufficient_quota' => 402,
      'invalid_api_key' => 401,
      'model_not_found' => 404,
      'server_error' || 'internal_error' => 500,
      _ => 400,
    };
    return AiException.fromResponse(
      status,
      jsonEncode(<String, Object?>{
        'error': error ?? const <String, Object?>{},
      }),
    );
  }

  static AiUsage? _usage(Object? raw) {
    final usage = jsonMap(raw);
    if (usage == null) return null;
    final input = jsonInt(usage['input_tokens']);
    final output = jsonInt(usage['output_tokens']);
    if (input == 0 && output == 0) return null;
    return AiUsage(inputTokens: input, outputTokens: output);
  }

  static AiFinishReason? _finish(Map<String, Object?>? response) {
    if (response == null) return null;
    switch (jsonString(response['status'])) {
      case 'completed':
        return AiFinishReason.stop;
      case 'incomplete':
        final reason = jsonString(
          jsonMap(response['incomplete_details'])?['reason'],
        );
        return switch (reason) {
          'max_output_tokens' => AiFinishReason.length,
          'content_filter' => AiFinishReason.filtered,
          _ => AiFinishReason.other,
        };
    }
    return null;
  }

  /// 模型列表与 Chat 接口相同。
  @override
  Future<List<AiRemoteModel>> listModels({HttpCancelToken? cancelToken}) =>
      OpenAiChatClient(config, http).listModels(cancelToken: cancelToken);
}
