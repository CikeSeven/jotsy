import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_failure.dart';
import 'ai_models.dart';

/// Anthropic Messages API（Claude，以及提供同格式接口的转发服务）。
///
/// - 路径：`{base}/v1/messages`、`{base}/v1/models`（地址已以 `/v1` 结尾时
///   不再重复）；
/// - 鉴权：`x-api-key` + `anthropic-version`。版本默认 `2023-06-01`，兼容
///   面最广（不少国内服务的 Claude 兼容接口只认这个），需要时在自定义请求头
///   里改写；
/// - `max_tokens` 必填：模型配置没写时取 [defaultMaxTokens]，所有在售模型
///   都接受这个值；
/// - 采样参数：较新的 Claude 模型会拒绝 `temperature`，Anthropic 预设默认
///   不发（服务商的“发送温度”开关）；
/// - 思考：只在用户为模型打开“思考过程”时发送
///   `thinking: {type: adaptive, display: summarized}`，旧模型不认这个写法，
///   默认不发。
class AnthropicChatClient extends AiChatClient {
  AnthropicChatClient(super.config, super.http);

  static const String defaultApiVersion = '2023-06-01';
  static const int defaultMaxTokens = 8192;

  String get _apiRoot => baseUrl.endsWith('/v1') ? baseUrl : '$baseUrl/v1';

  Map<String, String> get _headers => withCustomHeaders(<String, String>{
    if (config.apiKey.trim().isNotEmpty) 'x-api-key': config.apiKey.trim(),
    'anthropic-version': defaultApiVersion,
  });

  Map<String, Object?> buildBody(AiRequest request, {required bool stream}) {
    return withExtraBody(<String, Object?>{
      'model': request.model,
      'max_tokens': request.maxOutputTokens ?? defaultMaxTokens,
      if (request.system?.trim().isNotEmpty ?? false) 'system': request.system,
      'messages': [for (final message in request.messages) _message(message)],
      if (stream) 'stream': true,
      // 开着思考时 Claude 不接受温度。
      if (config.sendTemperature &&
          request.temperature != null &&
          !request.reasoning)
        'temperature': request.temperature,
      if (request.reasoning)
        'thinking': <String, Object?>{
          'type': 'adaptive',
          'display': 'summarized',
        },
    });
  }

  Map<String, Object?> _message(AiMessage message) {
    final role = message.role == AiRole.user ? 'user' : 'assistant';
    if (!message.hasImages) {
      return <String, Object?>{'role': role, 'content': message.text};
    }
    // 图片放在文字之前，模型理解得更好。
    final images = message.parts.whereType<AiImagePart>();
    final texts = message.parts.whereType<AiTextPart>();
    return <String, Object?>{
      'role': role,
      'content': [
        for (final image in images)
          <String, Object?>{
            'type': 'image',
            'source': <String, Object?>{
              'type': 'base64',
              'media_type': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          },
        for (final text in texts)
          <String, Object?>{'type': 'text', 'text': text.text},
      ],
    };
  }

  @override
  Stream<AiChunk> stream(
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async* {
    final response = await postJson(
      parseUri('$_apiRoot/messages'),
      buildBody(request, stream: config.stream),
      headers: _headers,
      cancelToken: cancelToken,
    );
    if (!response.isEventStream) {
      yield parseMessage(await response.readJsonObject());
      return;
    }
    yield* parseEventStream(
      response,
      (event, data) => <AiChunk>[parseStreamEvent(event, data)],
    );
  }

  /// 流式事件：
  /// - `message_start`：`message.usage.input_tokens`；
  /// - `content_block_delta`：`text_delta.text` / `thinking_delta.thinking`；
  /// - `message_delta`：`delta.stop_reason`、`usage.output_tokens`；
  /// - `error`：`error.type` / `error.message`，按错误类别抛出。
  static AiChunk parseStreamEvent(String? event, Map<String, Object?> data) {
    final type = jsonString(data['type']) ?? event;
    switch (type) {
      case 'error':
        throw _streamError(data);
      case 'message_start':
        final message = jsonMap(data['message']);
        return AiChunk(usage: _usage(message?['usage']));
      case 'content_block_delta':
        final delta = jsonMap(data['delta']);
        return switch (jsonString(delta?['type'])) {
          'text_delta' => AiChunk(text: jsonString(delta?['text']) ?? ''),
          'thinking_delta' => AiChunk(
            reasoning: jsonString(delta?['thinking']) ?? '',
          ),
          _ => const AiChunk(),
        };
      case 'message_delta':
        final delta = jsonMap(data['delta']);
        return AiChunk(
          usage: _usage(data['usage']),
          finishReason: _finish(jsonString(delta?['stop_reason'])),
        );
    }
    return const AiChunk();
  }

  static AiChunk parseMessage(Map<String, Object?> data) {
    if (jsonString(data['type']) == 'error') throw _streamError(data);
    final text = StringBuffer();
    final reasoning = StringBuffer();
    for (final block in jsonList(data['content'])) {
      final map = jsonMap(block);
      switch (jsonString(map?['type'])) {
        case 'text':
          text.write(jsonString(map?['text']) ?? '');
        case 'thinking':
          reasoning.write(jsonString(map?['thinking']) ?? '');
      }
    }
    return AiChunk(
      text: text.toString(),
      reasoning: reasoning.toString(),
      usage: _usage(data['usage']),
      finishReason: _finish(jsonString(data['stop_reason'])),
    );
  }

  static AiException _streamError(Map<String, Object?> data) {
    final error = jsonMap(data['error']);
    final status = switch (jsonString(error?['type'])) {
      'authentication_error' => 401,
      'permission_error' => 403,
      'not_found_error' => 404,
      'request_too_large' => 413,
      'rate_limit_error' => 429,
      'overloaded_error' => 529,
      'api_error' => 500,
      _ => 400,
    };
    return AiException.fromResponse(status, jsonEncode(data));
  }

  static AiUsage? _usage(Object? raw) {
    final usage = jsonMap(raw);
    if (usage == null) return null;
    // 命中缓存的输入单独计数，合起来才是这次读入的全部。
    final input =
        jsonInt(usage['input_tokens']) +
        jsonInt(usage['cache_read_input_tokens']) +
        jsonInt(usage['cache_creation_input_tokens']);
    final output = jsonInt(usage['output_tokens']);
    if (input == 0 && output == 0) return null;
    return AiUsage(inputTokens: input, outputTokens: output);
  }

  static AiFinishReason? _finish(String? raw) => switch (raw) {
    null => null,
    'end_turn' || 'stop_sequence' => AiFinishReason.stop,
    'max_tokens' => AiFinishReason.length,
    'refusal' => AiFinishReason.filtered,
    _ => AiFinishReason.other,
  };

  @override
  Future<List<AiRemoteModel>> listModels({HttpCancelToken? cancelToken}) async {
    final json = await getJson(
      parseUri('$_apiRoot/models?limit=1000'),
      headers: _headers,
      cancelToken: cancelToken,
    );
    final models = <AiRemoteModel>[];
    for (final item in jsonList(json['data'])) {
      final map = jsonMap(item);
      final id = jsonString(map?['id']);
      if (map == null || id == null || id.isEmpty) continue;
      final context = jsonInt(map['max_input_tokens']);
      final output = jsonInt(map['max_tokens']);
      models.add(
        AiRemoteModel(
          id: id,
          displayName: jsonString(map['display_name']),
          contextWindow: context > 0 ? context : null,
          maxOutputTokens: output > 0 ? output : null,
          supportsVision: id.startsWith('claude') ? true : null,
        ),
      );
    }
    return models;
  }
}
