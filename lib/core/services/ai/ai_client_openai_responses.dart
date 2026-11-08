import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_client_openai.dart';
import 'ai_failure.dart';
import 'ai_models.dart';
import 'ai_tool_call_assembler.dart';

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
      'input': [for (final message in request.messages) ..._input(message)],
      'stream': stream,
      'store': false,
      // 推理模型不接受温度：请求思考或指定了强度（含“关”，只有推理模型
      // 才有这个参数）时都不发。
      if (config.sendTemperature &&
          request.temperature != null &&
          !request.reasoning &&
          request.thinking == null)
        'temperature': request.temperature,
      if (request.maxOutputTokens != null)
        'max_output_tokens': request.maxOutputTokens,
      if (request.reasoning || request.thinking != null)
        'reasoning': <String, Object?>{
          if (request.thinking case final level?)
            'effort': level == AiThinkingLevel.off ? 'none' : level.name,
          if (request.reasoning) 'summary': 'auto',
        },
      // `store: false` 时推理条目只能靠加密内容带回下一步；只在带工具的
      // 请求里要，普通请求用不上。
      if (request.reasoning && request.hasTools)
        'include': ['reasoning.encrypted_content'],
      if (request.hasTools)
        'tools': [
          for (final tool in request.tools)
            <String, Object?>{
              'type': 'function',
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parameters,
              // 不让服务端把 schema 自动收紧成“每个参数都必填”。
              'strict': false,
            },
        ],
      if (request.hasTools && request.toolChoice == AiToolChoice.none)
        'tool_choice': 'none',
    });
  }

  /// 一条消息编成若干 input 条目。
  List<Map<String, Object?>> _input(AiMessage message) {
    if (message.role == AiRole.user) {
      final results = message.toolResults.toList();
      final rest = [
        for (final part in message.parts)
          if (part is AiTextPart || part is AiImagePart) part,
      ];
      return [
        for (final result in results)
          <String, Object?>{
            'type': 'function_call_output',
            'call_id': result.callId,
            'output': result.content,
          },
        if (rest.isNotEmpty || results.isEmpty)
          _message(AiMessage(AiRole.user, rest)),
      ];
    }
    // 有本步的原始输出条目时原样带回：推理条目与紧随其后的消息 / 调用
    // 条目要成对出现，自己重新拼会对不上。没有加密内容的推理条目在
    // `store: false` 下无从查起，丢掉。
    final items = [
      for (final replay in message.replayFor(AiProtocol.openAiResponses))
        for (final item in jsonList(replay.data['items']))
          if (jsonMap(item) case final map?)
            if (jsonString(map['type']) != 'reasoning' ||
                jsonString(map['encrypted_content']) != null)
              map,
    ];
    if (items.isNotEmpty) return items;
    final text = message.text;
    return [
      if (text.isNotEmpty || message.toolCalls.isEmpty) _message(message),
      for (final call in message.toolCalls)
        <String, Object?>{
          'type': 'function_call',
          if (jsonString(call.providerData?['id']) case final id?) 'id': id,
          'call_id': call.id,
          'name': call.name,
          'arguments': jsonEncode(call.arguments ?? const <String, Object?>{}),
        },
    ];
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
          if (part case AiTextPart(:final text))
            <String, Object?>{
              'type': user ? 'input_text' : 'output_text',
              'text': text,
            }
          else if (part case AiImagePart(:final bytes, :final mimeType))
            <String, Object?>{
              'type': 'input_image',
              'image_url': 'data:$mimeType;base64,${base64Encode(bytes)}',
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
    final state = OpenAiResponsesStreamState();
    yield* parseEventStream(response, (_, data) => <AiChunk>[state.add(data)]);
    final end = state.finish();
    if (!end.isEmpty) yield end;
  }

  /// 一次性响应：`output` 里的 `message`（正文）、`reasoning`（思考摘要）与
  /// `function_call`（工具调用）。
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
    final state = OpenAiResponsesStreamState()..addOutput(data['output']);
    final end = state.finish(finish: _finish(data));
    return AiChunk(
      text: text.toString(),
      reasoning: reasoning.join('\n\n'),
      usage: _usage(data['usage']),
      finishReason: end.finishReason ?? _finish(data),
      toolCalls: end.toolCalls,
      replay: end.replay,
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
    // 命中缓存的部分含在 input_tokens 里。
    final cached = jsonInt(
      jsonMap(usage['input_tokens_details'])?['cached_tokens'],
    );
    return AiUsage(
      inputTokens: input,
      outputTokens: output,
      cachedInputTokens: cached.clamp(0, input),
    );
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

/// Responses 一次流式响应的状态。事件类型以数据里的 `type` 为准：
/// - 正文 / 思考增量直接吐出；
/// - `function_call` 条目：`output_item.added` 报告开始，参数增量追加，
///   `function_call_arguments.done` 与 `output_item.done` 给出完整快照；
/// - 本步全部输出条目（`output_item.done`，没收到时取 `response.completed`
///   里的 `output`）攒起来作为回放数据，下一步原样带回。
class OpenAiResponsesStreamState {
  final AiToolCallAssembler _calls = AiToolCallAssembler();
  final Map<int, Map<String, Object?>> _items = <int, Map<String, Object?>>{};
  AiFinishReason? _finish;

  AiChunk add(Map<String, Object?> data) {
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
      case 'response.output_item.added':
        final item = jsonMap(data['item']);
        if (jsonString(item?['type']) != 'function_call') break;
        return AiChunk(
          toolCallStarted: _calls.add(
            _key(item?['id'], data['output_index']),
            id: jsonString(item?['call_id']),
            name: jsonString(item?['name']),
            arguments: jsonString(item?['arguments']),
          ),
        );
      case 'response.function_call_arguments.delta':
        _calls.add(
          _key(data['item_id'], data['output_index']),
          arguments: jsonString(data['delta']),
        );
      case 'response.function_call_arguments.done':
        _calls.add(
          _key(data['item_id'], data['output_index']),
          arguments: jsonString(data['arguments']),
          replaceArguments: true,
        );
      case 'response.output_item.done':
        final item = jsonMap(data['item']);
        if (item != null) _addItem(item, data['output_index']);
      case 'response.completed' || 'response.incomplete':
        final body = jsonMap(data['response']);
        if (_items.isEmpty) addOutput(body?['output']);
        _finish = OpenAiResponsesClient._finish(body);
        return AiChunk(
          usage: OpenAiResponsesClient._usage(body?['usage']),
          finishReason: _finish,
        );
      case 'response.failed':
        final error = jsonMap(jsonMap(data['response'])?['error']);
        throw OpenAiResponsesClient._error(error);
      case 'error':
        throw OpenAiResponsesClient._error(data);
    }
    return const AiChunk();
  }

  /// 一次性响应或 `response.completed` 里的整份 `output`。
  void addOutput(Object? output) {
    final items = jsonList(output);
    for (var i = 0; i < items.length; i++) {
      final item = jsonMap(items[i]);
      if (item != null) _addItem(item, i);
    }
  }

  void _addItem(Map<String, Object?> item, Object? outputIndex) {
    final index = outputIndex is int ? outputIndex : _items.length;
    _items[index] = item;
    if (jsonString(item['type']) != 'function_call') return;
    final id = jsonString(item['id']);
    _calls.add(
      _key(item['id'], outputIndex),
      id: jsonString(item['call_id']),
      name: jsonString(item['name']),
      arguments: jsonString(item['arguments']),
      replaceArguments: true,
      providerData: id == null ? null : <String, Object?>{'id': id},
    );
  }

  /// 条目 id 优先；个别转发服务不给 id 时退回输出下标。
  static Object _key(Object? itemId, Object? outputIndex) {
    if (itemId is String && itemId.isNotEmpty) return itemId;
    return 'output:$outputIndex';
  }

  /// 流结束：完整的工具调用，以及（有调用时）本步全部输出条目。
  AiChunk finish({AiFinishReason? finish}) {
    final ended = finish ?? _finish;
    final calls = _calls.finish();
    final ordered = _items.keys.toList()..sort();
    return AiChunk(
      toolCalls: calls,
      replay: calls.isEmpty || ordered.isEmpty
          ? const <AiReplayPart>[]
          : <AiReplayPart>[
              AiReplayPart(AiProtocol.openAiResponses, <String, Object?>{
                'items': [for (final index in ordered) _items[index]],
              }),
            ],
      finishReason: calls.isNotEmpty && (ended?.isComplete ?? false)
          ? AiFinishReason.toolCalls
          : null,
    );
  }
}
