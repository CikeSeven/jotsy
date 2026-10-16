import 'dart:convert';
import 'dart:io';

import 'package:node_diary/core/services/journal_import_cloud_http.dart';

/// 记录的一次请求。
class FakeCloudRequest {
  FakeCloudRequest(
    this.method,
    this.url,
    this.headers,
    this.body, {
    this.withCookies = true,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int>? body;
  final bool withCookies;

  String get bodyText => body == null ? '' : utf8.decode(body!);

  /// 表单正文解析成字段。
  Map<String, String> get form => Uri.splitQueryString(bodyText);

  Object? get json => jsonDecode(bodyText);
}

/// 按“方法 + 路径”（不含查询串）匹配的假 HTTP：处理函数返回响应，或抛出
/// [IOException] 模拟网络错误。未匹配的请求返回 404。
class FakeCloudHttp implements CloudNoteHttp {
  FakeCloudHttp({Map<String, String>? cookies}) : _cookies = cookies ?? {};

  final Map<String, String> _cookies;
  final Map<String, CloudNoteResponse Function(FakeCloudRequest request)>
  _routes = {};
  final List<FakeCloudRequest> requests = <FakeCloudRequest>[];

  void on(
    String method,
    String hostAndPath,
    CloudNoteResponse Function(FakeCloudRequest request) handler,
  ) => _routes['$method $hostAndPath'] = handler;

  /// 固定返回 JSON 对象。
  void json(String method, String hostAndPath, Object? body) =>
      on(method, hostAndPath, (_) => jsonResponse(body));

  @override
  Future<CloudNoteResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool withCookies = true,
  }) async {
    final request = FakeCloudRequest(
      method,
      url,
      headers,
      body,
      withCookies: withCookies,
    );
    requests.add(request);
    final handler = _routes['$method ${url.host}${url.path}'];
    if (handler == null) return CloudNoteResponse(404, utf8.encode('{}'));
    return handler(request);
  }

  @override
  String? cookie(String name) => _cookies[name];

  @override
  void setCookie(String name, String value, String host) =>
      _cookies[name] = value;

  @override
  void close() {}
}

CloudNoteResponse jsonResponse(Object? body, {int status = 200}) =>
    CloudNoteResponse(status, utf8.encode(jsonEncode(body)));

CloudNoteResponse bytesResponse(List<int> bytes, {int status = 200}) =>
    CloudNoteResponse(status, bytes);

/// 模拟网络中断。
class FakeNetworkError implements IOException {
  const FakeNetworkError();
}

const fakeJpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];
