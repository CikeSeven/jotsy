import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../http_cancel_token.dart';
import 'ai_failure.dart';

/// AI 请求共用的 HTTP 出口（`dart:io`，不引入第三方 HTTP 包）。
///
/// - 每个请求独立的 [HttpClient]：停止生成时经 [HttpCancelToken] 强制关闭
///   这一条连接，阻塞中的读取随即抛错，再按“已取消”上报；
/// - 三段超时：连接（[connectTimeout]）、首个字节（服务商可配，推理模型可能
///   先想很久）、两块之间的空闲（[idleTimeout]，防止连接半死不活地挂着）；
/// - 代理：服务商配置了 `host:port` 时一律经该 HTTP 代理，否则沿用
///   `dart:io` 的默认行为（读 `http_proxy` 等环境变量）。Android 不会自动
///   套用系统代理，所以要在服务商里单独填；
/// - 所有底层异常都映射成 [AiException]，界面只处理一种错误类型。
class AiHttp {
  AiHttp({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  static const String userAgent = 'Jotsy-AI/1.0';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration idleTimeout = Duration(seconds: 60);

  /// 非流式响应（模型列表、一次性生成、错误体）最多读这么多字节。
  static const int maxBufferedBytes = 8 << 20;

  final HttpClient Function() _clientFactory;

  /// 发出请求并等到响应头。返回的 [AiHttpResponse] 必须 [AiHttpResponse.close]
  /// （读完正文或出错时会自动关闭，重复关闭无害）。
  Future<AiHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Object? jsonBody,
    String? proxy,
    required Duration firstByteTimeout,
    HttpCancelToken? cancelToken,
  }) async {
    final client = _clientFactory();
    client.connectionTimeout = connectTimeout;
    client.idleTimeout = const Duration(seconds: 5);
    final proxyAddress = proxy?.trim();
    if (proxyAddress != null && proxyAddress.isNotEmpty) {
      client.findProxy = (_) => 'PROXY $proxyAddress';
    }
    cancelToken?.attach(client);
    try {
      final request = await client.openUrl(method, uri).timeout(connectTimeout);
      request.followRedirects = true;
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
      }
      headers.forEach((name, value) {
        if (name.trim().isNotEmpty) request.headers.set(name.trim(), value);
      });
      if (jsonBody != null) {
        final bytes = utf8.encode(jsonEncode(jsonBody));
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(firstByteTimeout);
      return AiHttpResponse._(client, response, cancelToken);
    } catch (error) {
      cancelToken?.detach(client);
      client.close(force: true);
      throw mapAiTransportError(error, cancelToken);
    }
  }
}

/// 一个已收到响应头的 AI 响应。
class AiHttpResponse {
  AiHttpResponse._(this._client, this._response, this._cancelToken);

  final HttpClient _client;
  final HttpClientResponse _response;
  final HttpCancelToken? _cancelToken;
  bool _closed = false;

  int get statusCode => _response.statusCode;

  bool get ok => statusCode >= 200 && statusCode < 300;

  /// 响应的 MIME（如 `text/event-stream`、`application/json`）。
  String? get mimeType => _response.headers.contentType?.mimeType;

  bool get isEventStream => mimeType == 'text/event-stream';

  bool get looksLikeHtml => mimeType == ContentType.html.mimeType;

  /// 正文字节流：两块之间超过 [AiHttp.idleTimeout] 视为超时；结束或出错
  /// 时关闭连接；底层异常映射为 [AiException]。只能监听一次。
  ///
  /// 停止要立刻生效：强制关闭 [HttpClient] 并不保证正在读的响应流马上
  /// 报错（实测会一直挂到服务端自己结束），所以这里同时等令牌，取消时
  /// 主动断开订阅并以 [AiFailureKind.cancelled] 结束。服务端恰好在取消后
  /// 正常结束时同样按“已取消”上报，调用方不会把半截内容当成完整结果。
  Stream<List<int>> get body {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;

    void finish([Object? error]) {
      if (controller.isClosed) return;
      unawaited(subscription?.cancel());
      if (error != null) controller.addError(error);
      unawaited(controller.close());
      close();
    }

    controller = StreamController<List<int>>(
      onListen: () {
        subscription = _response
            .timeout(
              AiHttp.idleTimeout,
              onTimeout: (sink) {
                sink.addError(const AiException(AiFailureKind.timeout));
                sink.close();
              },
            )
            .listen(
              controller.add,
              onError: (Object error) =>
                  finish(mapAiTransportError(error, _cancelToken)),
              onDone: () => finish(
                (_cancelToken?.isCancelled ?? false)
                    ? const AiException(AiFailureKind.cancelled)
                    : null,
              ),
              cancelOnError: true,
            );
        unawaited(
          _cancelToken?.whenCancelled.then(
            (_) => finish(const AiException(AiFailureKind.cancelled)),
          ),
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      // 不等底层订阅的取消完成：连接被强制关闭后它可能要等到服务端结束才
      // 完成，而调用方（如 Stream.forEach 出错时）会等这个 Future。
      onCancel: () {
        unawaited(subscription?.cancel());
        close();
      },
    );
    return controller.stream;
  }

  /// 读完整个正文为文本（最多 [AiHttp.maxBufferedBytes]）。
  Future<String> readText() async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body) {
      bytes.add(chunk);
      if (bytes.length > AiHttp.maxBufferedBytes) {
        close();
        throw const AiException(
          AiFailureKind.badResponse,
          detail: 'Response is too large',
        );
      }
    }
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  /// 读完正文并解析为 JSON 对象；不是对象时报 [AiFailureKind.badResponse]。
  Future<Map<String, Object?>> readJsonObject() async {
    final text = await readText();
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on FormatException {
      // 落到下面统一报错。
    }
    throw AiException(
      AiFailureKind.badResponse,
      statusCode: statusCode,
      providerMessage: text.length > 400 ? text.substring(0, 400) : text,
    );
  }

  /// 不是 2xx 时读出错误体并抛出归类后的 [AiException]。
  Future<void> throwIfFailed() async {
    if (ok && !looksLikeHtml) return;
    String text;
    try {
      text = await readText();
    } on AiException {
      text = '';
    }
    if (ok) {
      // 200 却是一张网页：地址多半填成了服务商的官网或控制台。
      throw AiException(
        AiFailureKind.badResponse,
        statusCode: statusCode,
        detail: 'HTML page instead of an API response',
      );
    }
    throw AiException.fromResponse(statusCode, text);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cancelToken?.detach(_client);
    _client.close(force: true);
  }
}

/// 把底层异常映射为 [AiException]；令牌已取消时一律视为用户停止。
AiException mapAiTransportError(Object error, HttpCancelToken? cancelToken) {
  if (cancelToken?.isCancelled ?? false) {
    return const AiException(AiFailureKind.cancelled);
  }
  if (error is AiException) return error;
  if (error is TimeoutException) {
    return const AiException(AiFailureKind.timeout);
  }
  if (error is HandshakeException || error is TlsException) {
    return AiException(AiFailureKind.network, detail: '$error');
  }
  if (error is SocketException ||
      error is HttpException ||
      error is IOException) {
    return AiException(AiFailureKind.network, detail: '$error');
  }
  if (error is ArgumentError || error is FormatException) {
    // 地址无法解析（缺少 scheme 等）。
    return AiException(AiFailureKind.badRequest, detail: '$error');
  }
  return AiException(AiFailureKind.network, detail: '$error');
}
