import 'dart:convert';

import '../http_cancel_token.dart';
import 'ai_client_anthropic.dart';
import 'ai_client_gemini.dart';
import 'ai_client_openai.dart';
import 'ai_client_openai_responses.dart';
import 'ai_failure.dart';
import 'ai_http.dart';
import 'ai_models.dart';
import 'ai_provider_config.dart';
import 'ai_sse.dart';

/// 一种协议的客户端。界面与编排层只经它访问 AI 服务，协议差异（路径、
/// 鉴权头、请求体、流式事件）全部收在三个实现里。
///
/// 流式约定：
/// - [stream] 吐出的每块只含增量；用量可能出现在任意一块（取最大值合并）；
/// - 服务商关闭了流式，或服务端无视 `stream: true` 直接回了 JSON 时，按
///   一次性响应解析后整块吐出，调用方无需区分；
/// - 任何失败都以 [AiException] 抛出；令牌取消后抛 [AiFailureKind.cancelled]。
abstract class AiChatClient {
  AiChatClient(this.config, this.http);

  factory AiChatClient.forProvider(AiProviderConfig config, {AiHttp? http}) {
    final transport = http ?? AiHttp();
    return switch (config.protocol) {
      AiProtocol.openAi => OpenAiChatClient(config, transport),
      AiProtocol.openAiResponses => OpenAiResponsesClient(config, transport),
      AiProtocol.anthropic => AnthropicChatClient(config, transport),
      AiProtocol.gemini => GeminiChatClient(config, transport),
    };
  }

  final AiProviderConfig config;
  final AiHttp http;

  Stream<AiChunk> stream(AiRequest request, {HttpCancelToken? cancelToken});

  Future<List<AiRemoteModel>> listModels({HttpCancelToken? cancelToken});

  Duration get firstByteTimeout =>
      Duration(seconds: config.firstByteTimeoutSeconds);

  /// 接口根地址去掉末尾的 `/`。
  String get baseUrl {
    var base = config.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// 把服务商的额外请求体合并进 [body]（同名覆盖），用于服务商特有的开关。
  Map<String, Object?> withExtraBody(Map<String, Object?> body) {
    final extra = config.extraBodyMap;
    if (extra == null) return body;
    return <String, Object?>{...body, ...extra};
  }

  /// 内置头 + 服务商自定义头（自定义的同名头覆盖内置的）。
  Map<String, String> withCustomHeaders(Map<String, String> builtIn) {
    final merged = <String, String>{...builtIn};
    config.headers.forEach((name, value) {
      merged.removeWhere((key, _) => key.toLowerCase() == name.toLowerCase());
      merged[name] = value;
    });
    return merged;
  }

  Uri parseUri(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw AiException(
        AiFailureKind.badRequest,
        detail: 'Invalid API address: $raw',
      );
    }
    return uri;
  }

  /// 发出 POST 并在失败时抛出归类后的错误。
  Future<AiHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required Map<String, String> headers,
    HttpCancelToken? cancelToken,
  }) async {
    final response = await http.send(
      'POST',
      uri,
      headers: headers,
      jsonBody: body,
      proxy: config.proxy,
      firstByteTimeout: firstByteTimeout,
      cancelToken: cancelToken,
    );
    await response.throwIfFailed();
    return response;
  }

  Future<Map<String, Object?>> getJson(
    Uri uri, {
    required Map<String, String> headers,
    HttpCancelToken? cancelToken,
  }) async {
    final response = await http.send(
      'GET',
      uri,
      headers: headers,
      proxy: config.proxy,
      firstByteTimeout: const Duration(seconds: 30),
      cancelToken: cancelToken,
    );
    await response.throwIfFailed();
    return response.readJsonObject();
  }

  /// 逐个解析 SSE 的 data（JSON 对象）；不是 JSON 的行（如 `[DONE]`、心跳）
  /// 跳过。事件名一并交给 [onEvent]，Anthropic 靠它区分 error 事件。
  Stream<AiChunk> parseEventStream(
    AiHttpResponse response,
    Iterable<AiChunk> Function(String? event, Map<String, Object?> data)
    onEvent,
  ) async* {
    await for (final event in decodeAiSse(response.body)) {
      if (event.isDone) break;
      final data = decodeJsonObject(event.data);
      if (data == null) continue;
      for (final chunk in onEvent(event.event, data)) {
        if (!chunk.isEmpty) yield chunk;
      }
    }
  }
}

/// 解析一段 JSON 对象；不是对象时返回 null。
Map<String, Object?>? decodeJsonObject(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, Object?>();
  } on FormatException {
    return null;
  }
  return null;
}

Map<String, Object?>? jsonMap(Object? raw) =>
    raw is Map ? raw.cast<String, Object?>() : null;

List<Object?> jsonList(Object? raw) =>
    raw is List ? raw.cast<Object?>() : const <Object?>[];

String? jsonString(Object? raw) => raw is String ? raw : null;

int jsonInt(Object? raw) => switch (raw) {
  final int value => value,
  final double value when value.isFinite => value.round(),
  final String value => int.tryParse(value) ?? 0,
  _ => 0,
};

/// 把正文里的 `<think>…</think>` 挪到思考过程：部分推理模型经 OpenAI 兼容
/// 接口返回时不用 `reasoning_content`，而是把思考写在正文开头的标签里。
///
/// 流式时标签可能被切在两块之间，所以按字符状态机处理：只在正文最开头
/// （忽略前导空白）识别 `<think>`，之后的 `<think>` 当作普通文字。
class AiThinkTagSplitter {
  static const String _open = '<think>';
  static const String _close = '</think>';

  _ThinkState _state = _ThinkState.start;
  final StringBuffer _pending = StringBuffer();

  /// 输入一段正文增量，返回（正文, 思考）增量。
  ({String text, String reasoning}) add(String delta) {
    final text = StringBuffer();
    final reasoning = StringBuffer();
    _pending.write(delta);
    var buffer = _pending.toString();
    _pending.clear();
    while (buffer.isNotEmpty) {
      switch (_state) {
        case _ThinkState.start:
          final trimmed = buffer.trimLeft();
          if (trimmed.isEmpty) {
            _pending.write(buffer);
            buffer = '';
          } else if (trimmed.startsWith(_open)) {
            _state = _ThinkState.thinking;
            buffer = trimmed.substring(_open.length);
          } else if (_open.startsWith(trimmed)) {
            // 只收到 `<thi`，等下一块再判断。
            _pending.write(buffer);
            buffer = '';
          } else {
            _state = _ThinkState.text;
          }
        case _ThinkState.thinking:
          final end = buffer.indexOf(_close);
          if (end >= 0) {
            reasoning.write(buffer.substring(0, end));
            buffer = buffer.substring(end + _close.length).trimLeft();
            _state = _ThinkState.text;
          } else {
            // 末尾可能是半个 `</think>`，留到下一块。
            final keep = _partialSuffix(buffer, _close);
            reasoning.write(buffer.substring(0, buffer.length - keep));
            _pending.write(buffer.substring(buffer.length - keep));
            buffer = '';
          }
        case _ThinkState.text:
          text.write(buffer);
          buffer = '';
      }
    }
    return (text: text.toString(), reasoning: reasoning.toString());
  }

  /// 流结束：没等到闭合标签的内容按正文还回去（宁可多显示也不吞掉）。
  ({String text, String reasoning}) close() {
    final rest = _pending.toString();
    _pending.clear();
    if (_state == _ThinkState.thinking) {
      return (text: '', reasoning: rest);
    }
    return (text: rest, reasoning: '');
  }

  static int _partialSuffix(String buffer, String tag) {
    for (var length = tag.length - 1; length > 0; length--) {
      if (buffer.length >= length &&
          tag.startsWith(buffer.substring(buffer.length - length))) {
        return length;
      }
    }
    return 0;
  }
}

enum _ThinkState { start, thinking, text }
