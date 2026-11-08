import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_failure.dart';
import 'ai_models.dart';
import 'ai_tool_call_assembler.dart';

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
      for (final message in request.messages) ..._messages(message),
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
      if (request.hasTools)
        'tools': [
          for (final tool in request.tools)
            <String, Object?>{
              'type': 'function',
              'function': <String, Object?>{
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.parameters,
              },
            },
        ],
      // 默认就是 auto；只在禁止调用时才写，部分兼容服务不认显式的 auto。
      if (request.hasTools && request.toolChoice == AiToolChoice.none)
        'tool_choice': 'none',
    });
  }

  /// 一条消息可能编成多条：工具结果各自是一条 `role: tool`。
  List<Map<String, Object?>> _messages(AiMessage message) {
    if (message.role == AiRole.user) {
      final results = message.toolResults.toList();
      final rest = [
        for (final part in message.parts)
          if (part is AiTextPart || part is AiImagePart) part,
      ];
      return [
        for (final result in results)
          <String, Object?>{
            'role': 'tool',
            'tool_call_id': result.callId,
            'content': result.content,
          },
        if (rest.isNotEmpty || results.isEmpty)
          _content('user', AiMessage(AiRole.user, rest)),
      ];
    }
    final calls = message.toolCalls.toList();
    if (calls.isEmpty) return [_content('assistant', message)];
    final text = message.text;
    return [
      <String, Object?>{
        'role': 'assistant',
        'content': text.isEmpty ? null : text,
        'tool_calls': [
          for (final call in calls)
            <String, Object?>{
              'id': call.id,
              'type': 'function',
              'function': <String, Object?>{
                'name': call.name,
                'arguments': jsonEncode(
                  call.arguments ?? const <String, Object?>{},
                ),
              },
            },
        ],
        // 思考模式带工具时 DeepSeek / Kimi 等要求把同一轮的思考原样带回；
        // 只放在带工具调用的消息里，普通消息带这个字段会被部分服务拒绝。
        for (final replay in message.replayFor(AiProtocol.openAi))
          ...replay.data,
      },
    ];
  }

  Map<String, Object?> _content(String role, AiMessage message) {
    if (!message.hasImages) {
      return <String, Object?>{'role': role, 'content': message.text};
    }
    return <String, Object?>{
      'role': role,
      'content': [
        for (final part in message.parts)
          if (part case AiTextPart(:final text))
            <String, Object?>{'type': 'text', 'text': text}
          else if (part case AiImagePart(:final bytes, :final mimeType))
            <String, Object?>{
              'type': 'image_url',
              'image_url': <String, Object?>{
                'url': 'data:$mimeType;base64,${base64Encode(bytes)}',
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
        toolCalls: chunk.toolCalls,
        toolCallStarted: chunk.toolCallStarted,
        replay: chunk.replay,
      );
    }

    if (!response.isEventStream) {
      final json = await response.readJsonObject();
      yield split(parseCompletion(json));
    } else {
      final state = OpenAiChatStreamState();
      yield* parseEventStream(
        response,
        (_, data) => <AiChunk>[state.add(data)],
      ).map(split);
      final rest = splitter.close();
      if (rest.text.isNotEmpty || rest.reasoning.isNotEmpty) {
        yield AiChunk(text: rest.text, reasoning: rest.reasoning);
      }
      final end = state.finish();
      if (!end.isEmpty) yield end;
      return;
    }
    final rest = splitter.close();
    if (rest.text.isNotEmpty || rest.reasoning.isNotEmpty) {
      yield AiChunk(text: rest.text, reasoning: rest.reasoning);
    }
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
    final state = OpenAiChatStreamState()
      ..addToolCalls(jsonList(message?['tool_calls']), snapshot: true)
      ..addReasoning(message);
    final end = state.finish(
      finish: _finish(jsonString(choice?['finish_reason'])),
    );
    return AiChunk(
      text: _contentText(message?['content']),
      reasoning:
          jsonString(message?['reasoning_content']) ??
          jsonString(message?['reasoning']) ??
          '',
      usage: _usage(data['usage']),
      finishReason:
          end.finishReason ?? _finish(jsonString(choice?['finish_reason'])),
      toolCalls: end.toolCalls,
      replay: end.replay,
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
    'tool_calls' || 'function_call' => AiFinishReason.toolCalls,
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

/// Chat 兼容接口一次流式响应的状态：正文与思考直接吐出，工具调用片段与
/// 需要回传的思考字段攒到流结束再给（[finish]）。
class OpenAiChatStreamState {
  final AiToolCallAssembler _calls = AiToolCallAssembler();
  final StringBuffer _reasoning = StringBuffer();
  String? _reasoningField;
  final List<Map<String, Object?>> _details = <Map<String, Object?>>[];
  final Map<int, int> _detailSlots = <int, int>{};
  AiFinishReason? _finish;

  /// 流式的一块：`choices[0].delta` + 可能附带的 `usage`。
  AiChunk add(Map<String, Object?> data) {
    OpenAiChatClient._throwIfError(data);
    final choices = jsonList(data['choices']);
    final choice = choices.isEmpty ? null : jsonMap(choices.first);
    final delta = jsonMap(choice?['delta']) ?? jsonMap(choice?['message']);
    final started = addToolCalls(jsonList(delta?['tool_calls']));
    final reasoning = addReasoning(delta);
    final finish = OpenAiChatClient._finish(
      jsonString(choice?['finish_reason']),
    );
    _finish = finish ?? _finish;
    return AiChunk(
      text: OpenAiChatClient._contentText(delta?['content']),
      reasoning: reasoning,
      usage: OpenAiChatClient._usage(data['usage']),
      finishReason: finish,
      toolCallStarted: started,
    );
  }

  /// `tool_calls[]` 的片段。没有 `index` 的服务（个别兼容接口）按在数组里
  /// 的位置区分；[snapshot] 为 true 时是一次性响应里的完整调用。
  AiToolCallStart? addToolCalls(List<Object?> items, {bool snapshot = false}) {
    AiToolCallStart? started;
    for (var i = 0; i < items.length; i++) {
      final item = jsonMap(items[i]);
      if (item == null) continue;
      final function = jsonMap(item['function']);
      final index = item['index'];
      final arguments = function?['arguments'];
      // 先调用再合并：`??=` 会短路，同一块里的第二个调用就丢了。
      final start = _calls.add(
        index is int ? index : i,
        id: jsonString(item['id']),
        name: jsonString(function?['name']),
        // 少数服务直接给对象而不是 JSON 字符串。
        arguments: arguments is String
            ? arguments
            : encodeAiToolArguments(arguments),
        replaceArguments: snapshot,
      );
      started ??= start;
    }
    return started;
  }

  /// 读出思考增量并记下来源字段，流结束后作为回放数据带回。
  String addReasoning(Map<String, Object?>? delta) {
    if (delta == null) return '';
    for (final raw in jsonList(delta['reasoning_details'])) {
      final detail = jsonMap(raw);
      if (detail != null) _mergeDetail(detail);
    }
    for (final field in const ['reasoning_content', 'reasoning']) {
      final text = jsonString(delta[field]);
      if (text == null) continue;
      _reasoningField ??= field;
      if (field == _reasoningField) _reasoning.write(text);
      return text;
    }
    return '';
  }

  /// OpenRouter 的 `reasoning_details` 分片按 `index` 合并：文字类字段拼接，
  /// 其他字段以后到的为准。
  void _mergeDetail(Map<String, Object?> detail) {
    final index = detail['index'];
    final slot = index is int ? _detailSlots[index] : null;
    if (slot == null) {
      if (index is int) _detailSlots[index] = _details.length;
      _details.add(<String, Object?>{...detail});
      return;
    }
    final merged = _details[slot];
    detail.forEach((key, value) {
      final previous = merged[key];
      merged[key] =
          value is String &&
              previous is String &&
              const {'text', 'summary', 'data', 'signature'}.contains(key)
          ? previous + value
          : value;
    });
  }

  /// 流结束：完整的工具调用与回放数据。只有协议正常收尾时才标为
  /// [AiFinishReason.toolCalls]；截断或中断时保持原结束原因（或没有），
  /// 调用方据此不执行这些调用。
  AiChunk finish({AiFinishReason? finish}) {
    final ended = finish ?? _finish;
    final calls = _calls.finish();
    final replay = <String, Object?>{
      if (_reasoningField != null && _reasoning.isNotEmpty)
        _reasoningField!: _reasoning.toString(),
      if (_details.isNotEmpty) 'reasoning_details': _details,
    };
    return AiChunk(
      toolCalls: calls,
      replay: replay.isEmpty
          ? const <AiReplayPart>[]
          : <AiReplayPart>[AiReplayPart(AiProtocol.openAi, replay)],
      finishReason: calls.isNotEmpty && (ended?.isComplete ?? false)
          ? AiFinishReason.toolCalls
          : null,
    );
  }
}
