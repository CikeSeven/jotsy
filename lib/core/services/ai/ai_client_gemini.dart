import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_failure.dart';
import 'ai_models.dart';
import 'ai_tool_call_assembler.dart';

/// Google Gemini `generateContent`。
///
/// - 路径：`{base}/models/{model}:streamGenerateContent?alt=sse`（流式）或
///   `:generateContent`；`{base}/models` 列出模型。默认根地址为
///   `https://generativelanguage.googleapis.com/v1beta`；
/// - 鉴权：`x-goog-api-key`；
/// - 角色：助手写作 `model`；系统提示词放 `systemInstruction`；
/// - 图片：`inline_data`（base64）；
/// - 思考：`generationConfig.thinkingConfig.includeThoughts`，返回的部分带
///   `thought: true`。
class GeminiChatClient extends AiChatClient {
  GeminiChatClient(super.config, super.http);

  Map<String, String> get _headers => withCustomHeaders(<String, String>{
    if (config.apiKey.trim().isNotEmpty) 'x-goog-api-key': config.apiKey.trim(),
  });

  /// 模型 id 可能带着列表接口返回的 `models/` 前缀。
  static String modelPath(String model) =>
      model.startsWith('models/') ? model.substring('models/'.length) : model;

  Map<String, Object?> buildBody(AiRequest request) {
    final generation = <String, Object?>{
      if (config.sendTemperature && request.temperature != null)
        'temperature': request.temperature,
      if (request.maxOutputTokens != null)
        'maxOutputTokens': request.maxOutputTokens,
      // 关掉思考用预算 0（不能关的模型返回 400，由 AiService 去掉强度
      // 重试）；低 / 中 / 高为 Gemini 3 的 thinkingLevel（两者不能同时写）。
      if (request.thinking == AiThinkingLevel.off)
        'thinkingConfig': <String, Object?>{'thinkingBudget': 0}
      else if (request.reasoning || request.thinking != null)
        'thinkingConfig': <String, Object?>{
          if (request.reasoning) 'includeThoughts': true,
          if (request.thinking case final level?) 'thinkingLevel': level.name,
        },
    };
    // 结果只在调用带着服务商给的 id 时才回带 id（本地生成的 id 服务端
    // 不认识）。
    final providerIds = <String>{
      for (final message in request.messages)
        for (final call in message.toolCalls)
          if (call.idFromProvider) call.id,
    };
    return withExtraBody(<String, Object?>{
      'contents': [
        for (final message in request.messages)
          <String, Object?>{
            'role': message.role == AiRole.user ? 'user' : 'model',
            'parts': _parts(message, providerIds),
          },
      ],
      if (request.system?.trim().isNotEmpty ?? false)
        'systemInstruction': <String, Object?>{
          'parts': [
            <String, Object?>{'text': request.system},
          ],
        },
      if (generation.isNotEmpty) 'generationConfig': generation,
      if (request.hasTools)
        'tools': [
          <String, Object?>{
            'functionDeclarations': [
              for (final tool in request.tools)
                <String, Object?>{
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': tool.parameters,
                },
            ],
          },
        ],
      if (request.hasTools && request.toolChoice == AiToolChoice.none)
        'toolConfig': <String, Object?>{
          'functionCallingConfig': <String, Object?>{'mode': 'NONE'},
        },
    });
  }

  List<Map<String, Object?>> _parts(
    AiMessage message,
    Set<String> providerIds,
  ) {
    return [
      // 同一步的全部结果放进同一条消息。
      for (final result in message.toolResults)
        <String, Object?>{
          'functionResponse': <String, Object?>{
            'name': result.name,
            if (providerIds.contains(result.callId)) 'id': result.callId,
            'response': _response(result),
          },
        },
      for (final part in message.parts)
        // 带调用的助手消息里空的正文部分不发（Gemini 拒收空 text）。
        if (part is AiTextPart &&
            (part.text.isNotEmpty || message.toolCalls.isEmpty))
          <String, Object?>{'text': part.text}
        else if (part case AiImagePart(:final bytes, :final mimeType))
          <String, Object?>{
            'inline_data': <String, Object?>{
              'mime_type': mimeType,
              'data': base64Encode(bytes),
            },
          },
      // `thoughtSignature` 挂在调用所在的部分上，必须原样带回（Gemini 3
      // 起缺了会被拒）。
      for (final call in message.toolCalls)
        <String, Object?>{
          'functionCall': <String, Object?>{
            'name': call.name,
            if (call.idFromProvider) 'id': call.id,
            'args': call.arguments ?? const <String, Object?>{},
          },
          if (jsonString(call.providerData?['thoughtSignature'])
              case final signature?)
            'thoughtSignature': signature,
        },
    ];
  }

  /// `response` 必须是对象：结果本身是 JSON 对象时直接用，否则包一层。
  static Map<String, Object?> _response(AiToolResultPart result) {
    final decoded = decodeJsonObject(result.content);
    if (result.isError) {
      return <String, Object?>{'error': decoded ?? result.content};
    }
    return decoded ?? <String, Object?>{'result': result.content};
  }

  @override
  Stream<AiChunk> stream(
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async* {
    final model = Uri.encodeComponent(modelPath(request.model));
    final path = config.stream
        ? '$baseUrl/models/$model:streamGenerateContent?alt=sse'
        : '$baseUrl/models/$model:generateContent';
    final response = await postJson(
      parseUri(path),
      buildBody(request),
      headers: _headers,
      cancelToken: cancelToken,
    );
    if (!response.isEventStream) {
      final text = await response.readText();
      final decoded = _decode(text);
      final state = GeminiStreamState();
      // 不带 alt=sse 的流式接口会返回整个 JSON 数组。
      for (final item in decoded) {
        final chunk = state.add(item);
        if (!chunk.isEmpty) yield chunk;
      }
      final end = state.finish();
      if (!end.isEmpty) yield end;
      return;
    }
    final state = GeminiStreamState();
    yield* parseEventStream(response, (_, data) => <AiChunk>[state.add(data)]);
    final end = state.finish();
    if (!end.isEmpty) yield end;
  }

  static List<Map<String, Object?>> _decode(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw AiException(
        AiFailureKind.badResponse,
        providerMessage: text.length > 400 ? text.substring(0, 400) : text,
      );
    }
    if (decoded is Map) return <Map<String, Object?>>[decoded.cast()];
    if (decoded is List) {
      return [
        for (final item in decoded)
          if (item is Map) item.cast<String, Object?>(),
      ];
    }
    throw const AiException(AiFailureKind.badResponse);
  }

  /// 一块 `GenerateContentResponse`。
  static AiChunk parseResponse(Map<String, Object?> data) {
    if (data['error'] != null) {
      final error = jsonMap(data['error']);
      final code = jsonInt(error?['code']);
      throw AiException.fromResponse(
        code >= 400 ? code : 400,
        jsonEncode(data),
      );
    }
    final feedback = jsonMap(data['promptFeedback']);
    if (jsonString(feedback?['blockReason']) case final reason?) {
      throw AiException(AiFailureKind.contentFiltered, providerMessage: reason);
    }
    final candidates = jsonList(data['candidates']);
    final candidate = candidates.isEmpty ? null : jsonMap(candidates.first);
    final content = jsonMap(candidate?['content']);
    final text = StringBuffer();
    final reasoning = StringBuffer();
    for (final part in jsonList(content?['parts'])) {
      final map = jsonMap(part);
      final value = jsonString(map?['text']);
      if (value == null) continue;
      if (map?['thought'] == true) {
        reasoning.write(value);
      } else {
        text.write(value);
      }
    }
    return AiChunk(
      text: text.toString(),
      reasoning: reasoning.toString(),
      usage: _usage(data['usageMetadata']),
      finishReason: _finish(jsonString(candidate?['finishReason'])),
    );
  }

  static AiUsage? _usage(Object? raw) {
    final usage = jsonMap(raw);
    if (usage == null) return null;
    final input = jsonInt(usage['promptTokenCount']);
    final output =
        jsonInt(usage['candidatesTokenCount']) +
        jsonInt(usage['thoughtsTokenCount']);
    if (input == 0 && output == 0) return null;
    // 隐式缓存命中的部分（含在 promptTokenCount 里）。
    return AiUsage(
      inputTokens: input,
      outputTokens: output,
      cachedInputTokens: jsonInt(
        usage['cachedContentTokenCount'],
      ).clamp(0, input),
    );
  }

  static AiFinishReason? _finish(String? raw) => switch (raw) {
    null || 'FINISH_REASON_UNSPECIFIED' => null,
    'STOP' => AiFinishReason.stop,
    'MAX_TOKENS' => AiFinishReason.length,
    'SAFETY' ||
    'RECITATION' ||
    'BLOCKLIST' ||
    'PROHIBITED_CONTENT' ||
    'SPII' ||
    'IMAGE_SAFETY' => AiFinishReason.filtered,
    _ => AiFinishReason.other,
  };

  @override
  Future<List<AiRemoteModel>> listModels({HttpCancelToken? cancelToken}) async {
    final json = await getJson(
      parseUri('$baseUrl/models?pageSize=1000'),
      headers: _headers,
      cancelToken: cancelToken,
    );
    final models = <AiRemoteModel>[];
    for (final item in jsonList(json['models'])) {
      final map = jsonMap(item);
      final name = jsonString(map?['name']);
      if (map == null || name == null) continue;
      final methods = jsonList(map['supportedGenerationMethods']);
      if (methods.isNotEmpty && !methods.contains('generateContent')) continue;
      final context = jsonInt(map['inputTokenLimit']);
      final output = jsonInt(map['outputTokenLimit']);
      models.add(
        AiRemoteModel(
          id: modelPath(name),
          displayName: jsonString(map['displayName']),
          contextWindow: context > 0 ? context : null,
          maxOutputTokens: output > 0 ? output : null,
          supportsVision: modelPath(name).startsWith('gemini') ? true : null,
        ),
      );
    }
    return models;
  }
}

/// Gemini 一次流式响应的状态。`functionCall` 部分总是整块到达（未开启
/// 参数流式），每到一个记一个；`thoughtSignature` 挂在调用上一并记下。
/// Gemini 有调用时结束原因仍是 `STOP`，由 [finish] 改标为
/// [AiFinishReason.toolCalls]。
class GeminiStreamState {
  final AiToolCallAssembler _calls = AiToolCallAssembler();
  var _seen = 0;
  AiFinishReason? _finish;

  AiChunk add(Map<String, Object?> data) {
    final chunk = GeminiChatClient.parseResponse(data);
    _finish = chunk.finishReason ?? _finish;
    final candidates = jsonList(data['candidates']);
    final candidate = candidates.isEmpty ? null : jsonMap(candidates.first);
    AiToolCallStart? started;
    for (final raw in jsonList(jsonMap(candidate?['content'])?['parts'])) {
      final part = jsonMap(raw);
      final call = jsonMap(part?['functionCall']);
      if (part == null || call == null) continue;
      final signature =
          jsonString(part['thoughtSignature']) ??
          jsonString(part['thought_signature']);
      // 先调用再合并：`??=` 会短路，同一块里的第二个调用就丢了。
      final start = _calls.add(
        _seen++,
        id: jsonString(call['id']),
        name: jsonString(call['name']),
        arguments: encodeAiToolArguments(call['args']),
        providerData: signature == null
            ? null
            : <String, Object?>{'thoughtSignature': signature},
      );
      started ??= start;
    }
    if (started == null) return chunk;
    return AiChunk(
      text: chunk.text,
      reasoning: chunk.reasoning,
      usage: chunk.usage,
      finishReason: chunk.finishReason,
      toolCallStarted: started,
    );
  }

  AiChunk finish() {
    final calls = _calls.finish();
    return AiChunk(
      toolCalls: calls,
      finishReason: calls.isNotEmpty && (_finish?.isComplete ?? false)
          ? AiFinishReason.toolCalls
          : null,
    );
  }
}
