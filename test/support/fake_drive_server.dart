import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:node_diary/core/services/cloud_backup_http.dart';

import 'webdav_test_server.dart';

/// 假网盘服务收到的一次请求（请求体已读完，测试数据都很小）。
class FakeDriveRequest {
  FakeDriveRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;

  /// 小写头名 → 值（多值以逗号连接）。
  final Map<String, String> headers;
  final List<int> body;

  String get text => utf8.decode(body, allowMalformed: true);

  Object? get json => body.isEmpty ? null : jsonDecode(text);

  Map<String, String> get form => Uri.splitQueryString(text);

  Map<String, String> get query => uri.queryParameters;
}

typedef FakeDriveHandler =
    FutureOr<void> Function(FakeDriveRequest request, HttpResponse response);

/// 本地回环的假网盘服务：按“方法 + 路径”（不含查询串）路由并记录请求，
/// 未登记的路由返回 404。调用方负责 [close]。
///
/// Flutter 的测试绑定默认拦截 HTTP，所以客户端一律经 [http] 创建，走真实
/// 传输（[realFixtureHttpClient]）。
class FakeDriveServer {
  FakeDriveServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeDriveServer> start() async =>
      FakeDriveServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final Map<String, FakeDriveHandler> _routes = {};
  final List<FakeDriveRequest> requests = <FakeDriveRequest>[];

  /// 形如 `http://127.0.0.1:12345/` 的根地址。
  Uri get base => Uri.parse('http://${_server.address.host}:${_server.port}/');

  /// 以根地址拼接相对路径（不以 `/` 开头）。
  Uri url(String path) => base.resolve(path);

  void on(String method, String path, FakeDriveHandler handler) =>
      _routes['$method $path'] = handler;

  /// 固定状态码 + JSON 响应；[body] 可按请求生成。
  void json(
    String method,
    String path,
    Object? Function(FakeDriveRequest request) body, {
    int status = 200,
  }) {
    on(method, path, (request, response) {
      response.statusCode = status;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body(request)));
    });
  }

  /// 某方法 + 路径收到的请求。
  List<FakeDriveRequest> received(String method, String path) => [
    for (final request in requests)
      if (request.method == method && request.uri.path == path) request,
  ];

  CloudBackupHttp http() =>
      CloudBackupHttp(clientFactory: realFixtureHttpClient);

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final body = <int>[];
    await for (final chunk in request) {
      body.addAll(chunk);
    }
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    final recorded = FakeDriveRequest(
      request.method,
      request.uri,
      headers,
      body,
    );
    requests.add(recorded);
    final handler = _routes['${request.method} ${request.uri.path}'];
    try {
      if (handler == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        await handler(recorded, request.response);
      }
    } finally {
      await request.response.close();
    }
  }
}
