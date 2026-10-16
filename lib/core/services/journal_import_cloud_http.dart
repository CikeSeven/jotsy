import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'journal_import_cloud_cookie_jar.dart';

/// 云端读取失败的原因，界面据此给出具体提示。
enum CloudNoteFailure {
  /// 未登录、登录已失效或需要二次验证（HTTP 401、重定向、业务码）。
  sessionExpired,

  /// 平台拒绝此请求（HTTP 403），不一定是登录失效。
  forbidden,

  /// 请求过于频繁，重试后仍被限流。
  rateLimited,

  /// 平台服务暂时不可用（5xx），重试后仍失败。
  serverError,

  /// 平台拒绝了请求（其他 4xx 或业务错误）。
  rejected,

  /// 网络请求失败。
  network,

  /// 返回格式与已知协议不符，停止处理以免漏掉笔记。
  protocolChanged,

  /// 账号状态不支持读取（如小米笔记开启了加密）。
  unsupportedAccount,
}

class CloudNoteException implements Exception {
  const CloudNoteException(this.failure, [this.detail]);

  final CloudNoteFailure failure;

  /// 仅供日志排查的简短说明，不含 Cookie、令牌或笔记正文。
  final String? detail;

  @override
  String toString() =>
      'CloudNoteException(${failure.name}${detail == null ? '' : ', $detail'})';
}

/// 一次 HTTP 响应（正文已完整读入内存）。
class CloudNoteResponse {
  const CloudNoteResponse(
    this.statusCode,
    this.bytes, {
    this.headers = const {},
  });

  final int statusCode;
  final List<int> bytes;

  /// 小写响应头名 → 值（多值以逗号连接，`set-cookie` 除外已由 Cookie 罐吸收）。
  final Map<String, String> headers;

  String get text => utf8.decode(bytes, allowMalformed: true);
}

/// 发送原始 HTTP 请求：不跟随重定向，Cookie 由实现自行附带与更新。
/// [withCookies] 为 false 时不附带任何 Cookie（如发往对象存储的签名下载
/// 地址，账号凭据不应离开平台域名）。测试用假实现按请求返回预设响应。
abstract interface class CloudNoteHttp {
  Future<CloudNoteResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers,
    List<int>? body,
    bool withCookies,
  });

  /// Cookie 罐中名为 [name] 的唯一值；多个不同值或不存在时返回 null。
  String? cookie(String name);

  /// 写入或替换只对 [host] 生效的 Cookie（如华为轮换后的 CSRF 令牌）。
  void setCookie(String name, String value, String host);

  void close();
}

/// 带 Cookie 罐的 dart:io 实现。初始 Cookie 来自登录用的网页视图，服务端
/// 轮换的 Set-Cookie 在本次读取期间更新到罐中；会话结束后整体丢弃，不落盘。
class IoCloudNoteHttp implements CloudNoteHttp {
  IoCloudNoteHttp(this.jar, {HttpClient? client})
    : _client = client ?? HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 15);

  final CloudCookieJar jar;
  final HttpClient _client;

  @override
  Future<CloudNoteResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool withCookies = true,
  }) async {
    final request = await _client.openUrl(method, url);
    request.followRedirects = false;
    request.persistentConnection = true;
    headers.forEach(request.headers.set);
    final cookie = withCookies ? jar.header(url) : null;
    if (cookie != null) request.headers.set(HttpHeaders.cookieHeader, cookie);
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close().timeout(const Duration(seconds: 35));
    if (withCookies) {
      jar.absorb(
        url,
        response.headers[HttpHeaders.setCookieHeader] ?? const [],
      );
    }
    final bytes = await response
        .fold<BytesBuilder>(BytesBuilder(copy: false), (all, chunk) {
          all.add(chunk);
          return all;
        })
        .timeout(const Duration(minutes: 3));
    final values = <String, String>{};
    response.headers.forEach((name, list) {
      if (name != HttpHeaders.setCookieHeader) values[name] = list.join(', ');
    });
    return CloudNoteResponse(
      response.statusCode,
      bytes.takeBytes(),
      headers: values,
    );
  }

  @override
  String? cookie(String name) => jar.value(name);

  @override
  void setCookie(String name, String value, String host) =>
      jar.set(name, value, host);

  @override
  void close() {
    jar.clear();
    _client.close(force: true);
  }
}

/// 对一个平台接口源的只读请求，行为与参考实现（笔记互迁 `transport.py`）
/// 一致：
/// - 固定桌面浏览器 UA 与 `Referer: <源>/`，平台可另加请求头；
/// - 不跟随重定向：3xx 与 401 视为登录失效，403 为拒绝访问；
/// - 网络错误与 5xx 重试 3 次（间隔 1、2 秒），429 间隔 2、4 秒，仍失败则
///   报对应原因；其他 4xx 不重试。
class CloudNoteTransport {
  CloudNoteTransport(
    this.origin,
    this.http, {
    Map<String, String> headers = const {},
    Future<void> Function(Duration delay)? wait,
  }) : _headers = {
         'User-Agent': cloudNoteUserAgent,
         'Referer': '$origin/',
         ...headers,
       },
       _wait = wait ?? Future<void>.delayed;

  final String origin;
  final CloudNoteHttp http;
  final Map<String, String> _headers;
  final Future<void> Function(Duration delay) _wait;

  Future<CloudNoteResponse> request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    List<int>? body,
    bool returnRedirects = false,
  }) async {
    if (!path.startsWith('/') || path.startsWith('//')) {
      throw ArgumentError.value(path, 'path', '必须是同源的绝对路径');
    }
    final base = Uri.parse('$origin$path');
    final url = query.isEmpty
        ? base
        : base.replace(queryParameters: {...base.queryParameters, ...query});
    return requestUrl(
      method,
      url,
      headers: headers,
      body: body,
      returnRedirects: returnRedirects,
    );
  }

  /// 请求完整地址（如附件的签名下载地址），同样适用重试与状态映射。
  Future<CloudNoteResponse> requestUrl(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool returnRedirects = false,
    bool withCookies = true,
  }) async {
    const attempts = 3;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final last = attempt + 1 == attempts;
      final CloudNoteResponse response;
      try {
        response = await http.send(
          method,
          url,
          headers: {..._headers, ...headers},
          body: body,
          withCookies: withCookies,
        );
      } on IOException {
        if (last) throw const CloudNoteException(CloudNoteFailure.network);
        await _wait(Duration(seconds: 1 << attempt));
        continue;
      } on TimeoutException {
        if (last) throw const CloudNoteException(CloudNoteFailure.network);
        await _wait(Duration(seconds: 1 << attempt));
        continue;
      }
      final status = response.statusCode;
      if (status == 403) {
        throw CloudNoteException(CloudNoteFailure.forbidden, url.path);
      }
      if (returnRedirects && status >= 300 && status < 400) return response;
      if (status == 401 || (status >= 300 && status < 400)) {
        throw CloudNoteException(CloudNoteFailure.sessionExpired, url.path);
      }
      if (status == 429) {
        if (last) throw const CloudNoteException(CloudNoteFailure.rateLimited);
        await _wait(Duration(seconds: 2 << attempt));
        continue;
      }
      if (status >= 500) {
        if (last) {
          throw CloudNoteException(CloudNoteFailure.serverError, '$status');
        }
        await _wait(Duration(seconds: 1 << attempt));
        continue;
      }
      if (status >= 400) {
        throw CloudNoteException(CloudNoteFailure.rejected, '$status');
      }
      return response;
    }
    throw const CloudNoteException(CloudNoteFailure.network);
  }

  /// 请求并解析为 JSON 对象；不是 JSON 对象时视为协议变化。
  Future<Map<String, Object?>> json(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? jsonBody,
    Map<String, String>? form,
  }) async {
    final (body, contentType) = switch ((jsonBody, form)) {
      (final Object value, _) => (
        utf8.encode(jsonEncode(value)),
        'application/json;charset=UTF-8',
      ),
      (_, final Map<String, String> fields) => (
        utf8.encode(Uri(queryParameters: fields).query),
        'application/x-www-form-urlencoded;charset=UTF-8',
      ),
      _ => (null, null),
    };
    final response = await request(
      method,
      path,
      query: query,
      headers: {'Content-Type': ?contentType, ...headers},
      body: body,
    );
    return decodeCloudJson(response.text);
  }
}

/// 解析 JSON 对象；失败时抛出 [CloudNoteFailure.protocolChanged]。
Map<String, Object?> decodeCloudJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const CloudNoteException(CloudNoteFailure.protocolChanged, 'json');
  }
  if (decoded is! Map) {
    throw const CloudNoteException(CloudNoteFailure.protocolChanged, 'object');
  }
  return decoded.cast<String, Object?>();
}

/// 登录网页与接口请求共用的桌面浏览器 UA：各平台网页版在手机 UA 下会跳到
/// 应用下载页或精简页，接口也按桌面网页的请求校验。
const String cloudNoteUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36';
