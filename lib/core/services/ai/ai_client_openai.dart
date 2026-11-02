import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_failure.dart';
import 'ai_models.dart';

/// OpenAI Chat Completions 兼容协议。
///
/// - 路径：`{base}/chat/completions`、`{base}/models`；
/// - 鉴权：`Authorization: Bearer <key>`（密钥为空时不发，本地服务不需要）；
/// - 图片：`image_url` 的 data URL；
/// - 思考过程：`delta.reasoning_content`（DeepSeek、通义、Kimi 等）或
///   `delta.reasoning`（OpenRouter、Ollama 等），以及正文开头的 `<think>`；
/// - `max_tokens` 只在模型配置写明时发送：新版 OpenAI 推理模型不认它，
///   而大多数兼容服务的默认值已足够。
class OpenAiChatClient extends AiChatClient {
  OpenAiChatClient(super.config, super.http);

  Map<String, String> get _headers => withCustomHeaders(<String, String>{
    if (config.apiKey.trim().isNotEmpty)
      'Authorization': 'Bearer ${config.apiKey.trim()}',
  });

  Map<String, Object?> buildBody(AiRequest request, {required bool stream}) {
    final messages = <Map<String, Object?>>[
      if (request.system?.trim().isNotEmpty ?? false)
        <String, Object?>{'role': 'system', 'content': request.system},
      for (final message in request.messages) _message(message),
    ];
    return withExtraBody(<String, Object?>{
      'model': request.model,
      'messages': messages,
      'stream': stream,
      if (stream && config.includeUsage)
        'stream_options': <String, Object?>{'include_usage': true},
      if (config.sendTemperature && request.temperature != null)
        'temperature': request.temperature,
      if (request.maxOutputTokens != null)
        'max_tokens': request.maxOutputTokens,
    });
  }

  Map<String, Object?> _message(AiMessage message) {
    final role = message.role == AiRole.user ? 'user' : 'assistant';
    if (!message.hasImages) {
      return <String, Object?>{'role': role, 'content': message.text};
    }
    return <String, Object?>{
      'role': role,
      'content': [
        for (final part in message.parts)
          switch (part) {
            AiTextPart(:final text) => <String, Object?>{
              'type': 'text',
              'text': text,
            },
            AiImagePart(:final bytes, :final mimeType) => <String, Object?>{
              'type': 'image_url',
              'image_url': <String, Object?>{
                'url': 'data:$mimeType;base64,${base64Encode(bytes)}',
              },
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
    final uri = parseUri('$baseUrl/chat/completions');
    final response = await postJson(
      uri,
      buildBody(request, stream: config.stream),
      headers: _headers,
      cancelToken: cancelToken,
    );
    final splitter = AiThinkTagSplitter();
    AiChunk split(AiChunk chunk) {
      if (chunk.text.isEmpty) return chunk;
      final parts = splitter.add(chunk.text);
      return AiChunk(
        text: parts.text,
        reasoning: chunk.reasoning + parts.reasoning,
        usage: chunk.usage,
        finishReason: chunk.finishReason,
      );
    }

    if (!response.isEventStream) {
      final json = await response.readJsonObject();
      yield split(parseCompletion(json));
    } else {
      yield* parseEventStream(
        response,
        (_, data) => <AiChunk>[parseStreamChunk(data)],
      ).map(split);
    }
    final rest = splitter.close();
    if (rest.text.isNotEmpty || rest.reasoning.isNotEmpty) {
      yield AiChunk(text: rest.text, reasoning: rest.reasoning);
    }
  }

  /// 流式的一块：`choices[0].delta` + 可能附带的 `usage`。
  static AiChunk parseStreamChunk(Map<String, Object?> data) {
    _throwIfError(data);
    final choices = jsonList(data['choices']);
    final choice = choices.isEmpty ? null : jsonMap(choices.first);
    final delta = jsonMap(choice?['delta']) ?? jsonMap(choice?['message']);
    return AiChunk(
      text: _contentText(delta?['content']),
      reasoning:
          jsonString(delta?['reasoning_content']) ??
          jsonString(delta?['reasoning']) ??
          '',
      usage: _usage(data['usage']),
      finishReason: _finish(jsonString(choice?['finish_reason'])),
    );
  }

  /// 一次性响应：`choices[0].message`。
  static AiChunk parseCompletion(Map<String, Object?> data) {
    _throwIfError(data);
    final choices = jsonList(data['choices']);
    if (choices.isEmpty) {
      throw AiException(
        AiFailureKind.badResponse,
        providerMessage: jsonEncode(data),
      );
    }
    final choice = jsonMap(choices.first);
    final message = jsonMap(choice?['message']);
    return AiChunk(
      text: _contentText(message?['content']),
      reasoning:
          jsonString(message?['reasoning_content']) ??
          jsonString(message?['reasoning']) ??
          '',
      usage: _usage(data['usage']),
      finishReason: _finish(jsonString(choice?['finish_reason'])),
    );
  }

  /// `content` 可能是字符串，也可能是 `[{type: text, text}]`。
  static String _contentText(Object? content) {
    if (content is String) return content;
    if (content is List) {
      return [
        for (final part in content)
          if (jsonMap(part) case final map?) jsonString(map['text']) ?? '',
      ].join();
    }
    return '';
  }

  static void _throwIfError(Map<String, Object?> data) {
    if (data['error'] == null) return;
    throw AiException.fromResponse(
      jsonInt(jsonMap(data['error'])?['code']) >= 400
          ? jsonInt(jsonMap(data['error'])?['code'])
          : 400,
      jsonEncode(data),
    );
  }

  static AiUsage? _usage(Object? raw) {
    final usage = jsonMap(raw);
    if (usage == null) return null;
    final input = jsonInt(usage['prompt_tokens'] ?? usage['input_tokens']);
    final output = jsonInt(
      usage['completion_tokens'] ?? usage['output_tokens'],
    );
    if (input == 0 && output == 0) return null;
    return AiUsage(inputTokens: input, outputTokens: output);
  }

  static AiFinishReason? _finish(String? raw) => switch (raw) {
    null => null,
    'stop' => AiFinishReason.stop,
    'length' => AiFinishReason.length,
    'content_filter' || 'sensitive' => AiFinishReason.filtered,
    _ => AiFinishReason.other,
  };

  @override
  Future<List<AiRemoteModel>> listModels({HttpCancelToken? cancelToken}) async {
    final json = await getJson(
      parseUri('$baseUrl/models'),
      headers: _headers,
      cancelToken: cancelToken,
    );
    // 标准为 `{data: [...]}`；个别服务直接返回 `{models: [...]}`。
    final items = jsonList(json['data'] ?? json['models']);
    final models = <AiRemoteModel>[];
    for (final item in items) {
      final map = jsonMap(item);
      final id = jsonString(map?['id']) ?? jsonString(map?['name']);
      if (map == null || id == null || id.isEmpty) continue;
      // OpenRouter 等会写明上下文长度与输入模态。
      final architecture = jsonMap(map['architecture']);
      final modalities = jsonList(architecture?['input_modalities']);
      final context = jsonInt(map['context_length'] ?? map['context_window']);
      models.add(
        AiRemoteModel(
          id: id,
          displayName: jsonString(map['name']),
          contextWindow: context > 0 ? context : null,
          supportsVision: modalities.isEmpty
              ? null
              : modalities.contains('image'),
        ),
      );
    }
    models.sort((a, b) => a.id.compareTo(b.id));
    return models;
  }
}
