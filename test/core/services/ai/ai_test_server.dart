import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次被记录下来的请求。
class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;

  Map<String, Object?> get json =>
      (jsonDecode(body) as Map).cast<String, Object?>();
}

typedef TestHandler =
    Future<void> Function(RecordedRequest request, HttpResponse response);

/// 测试用的本地 HTTP 服务：记录请求，按 [handler] 返回响应。不经网络，
/// 只监听回环地址的随机端口。
class AiTestServer {
  AiTestServer._(this._server);

  final HttpServer _server;
  final List<RecordedRequest> requests = <RecordedRequest>[];
  TestHandler handler = (_, response) async {
    response.statusCode = 404;
  };

  static Future<AiTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final test = AiTestServer._(server);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final recorded = RecordedRequest(
        request.method,
        request.uri,
        request.headers,
        body,
      );
      test.requests.add(recorded);
      try {
        await test.handler(recorded, request.response);
      } finally {
        await request.response.close().catchError((Object _) {});
      }
    });
    return test;
  }

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  Future<void> close() => _server.close(force: true);
}

/// 写一串 SSE 事件。[events] 的每项为（事件名, data）。
Future<void> writeSse(
  HttpResponse response,
  List<(String?, String)> events, {
  Duration gap = Duration.zero,
}) async {
  response.headers.contentType = ContentType('text', 'event-stream');
  // 不缓冲：每个事件立刻发出，才能测出流式与中途停止。
  response.bufferOutput = false;
  for (final (event, data) in events) {
    if (event != null) response.write('event: $event\n');
    response.write('data: $data\n\n');
    await response.flush();
    if (gap > Duration.zero) await Future<void>.delayed(gap);
  }
}

Future<void> writeJson(
  HttpResponse response,
  Object json, {
  int status = 200,
}) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(json));
}
