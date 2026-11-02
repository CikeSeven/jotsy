import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_failure.dart';
import 'ai_models.dart';

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
      if (request.reasoning)
        'thinkingConfig': <String, Object?>{'includeThoughts': true},
    };
    return withExtraBody(<String, Object?>{
      'contents': [
        for (final message in request.messages)
          <String, Object?>{
            'role': message.role == AiRole.user ? 'user' : 'model',
            'parts': [
              for (final part in message.parts)
                switch (part) {
                  AiTextPart(:final text) => <String, Object?>{'text': text},
                  AiImagePart(:final bytes, :final mimeType) =>
                    <String, Object?>{
                      'inline_data': <String, Object?>{
                        'mime_type': mimeType,
                        'data': base64Encode(bytes),
                      },
                    },
                },
            ],
          },
      ],
      if (request.system?.trim().isNotEmpty ?? false)
        'systemInstruction': <String, Object?>{
          'parts': [
            <String, Object?>{'text': request.system},
          ],
        },
      if (generation.isNotEmpty) 'generationConfig': generation,
    });
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
      // 不带 alt=sse 的流式接口会返回整个 JSON 数组。
      for (final item in decoded) {
        final chunk = parseResponse(item);
        if (!chunk.isEmpty) yield chunk;
      }
      return;
    }
    yield* parseEventStream(
      response,
      (_, data) => <AiChunk>[parseResponse(data)],
    );
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
    return AiUsage(inputTokens: input, outputTokens: output);
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
