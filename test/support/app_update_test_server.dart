import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// 一条模拟线路对某个地址的行为。
enum FakeMirrorBehavior {
  /// 正常返回，支持 Range。
  ok,

  /// 忽略 Range，总是 200 返回全文。
  ignoreRange,

  /// 返回 404。
  notFound,

  /// 返回 502。
  badGateway,

  /// 200 但返回 HTML 错误页（镜像常见故障）。
  html,

  /// 只发出 [FakeMirrorServer.cutAfter] 字节后断开连接。
  cut,

  /// 每 500ms 只发 8 KB（约 16 KB/s，被限速）。dart:io 服务器不足 8 KB 的
  /// 写入即使 flush 也不发出，所以不能逐字节滴。
  drip,

  /// 发出 [FakeMirrorServer.cutAfter] 字节后不再发送，也不断开（失速）。
  stall,

  /// 一直不响应（直到服务器关闭）。
  hang,
}

/// 本地回环服务器，模拟“镜像前缀 + 原始地址”式的多条线路：
/// `http://127.0.0.1:<port>/<mirror>/https://github.com/...`。
///
/// 每条线路按“原始地址后缀 → 行为”配置；未配置的地址回 404。
/// 记录每个请求的线路、路径与 Range 头，供断言续传与切换。
class FakeMirrorServer {
  FakeMirrorServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeMirrorServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeMirrorServer._(server);
  }

  final HttpServer _server;
  final Map<String, Map<String, FakeMirrorBehavior>> _routes = {};
  final Map<String, Object> _bodies = {};
  final Map<String, String> _redirects = {};
  final List<FakeMirrorRequest> requests = <FakeMirrorRequest>[];
  final Set<HttpResponse> _hanging = <HttpResponse>{};

  /// [FakeMirrorBehavior.cut] 断开前发出的字节数。
  int cutAfter = 64 << 10;

  int get port => _server.port;

  /// 线路 [mirror] 的前缀（`http://127.0.0.1:<port>/<mirror>/`）。
  String prefix(String mirror) => 'http://127.0.0.1:$port/$mirror/';

  /// 设置 [suffix]（原始地址的路径末尾）返回的正文：字符串或字节。
  void body(String suffix, Object content) => _bodies[suffix] = content;

  /// [suffix] 以 302 跳到 [location]（不跟随跳转时的 Location）。
  void redirect(String suffix, String location) =>
      _redirects[suffix] = location;

  void route(String mirror, String suffix, FakeMirrorBehavior behavior) =>
      (_routes[mirror] ??= <String, FakeMirrorBehavior>{})[suffix] = behavior;

  Future<void> close() async {
    for (final response in _hanging.toList()) {
      try {
        await response.close();
      } catch (_) {}
    }
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final slash = path.indexOf('/', 1);
    final mirror = slash < 0 ? path.substring(1) : path.substring(1, slash);
    final rest = slash < 0 ? '' : path.substring(slash + 1);
    requests.add(
      FakeMirrorRequest(
        mirror,
        rest,
        request.headers.value(HttpHeaders.rangeHeader),
      ),
    );
    final routes = _routes[mirror] ?? const <String, FakeMirrorBehavior>{};
    String? suffix;
    for (final key in routes.keys) {
      if (rest.endsWith(key)) {
        suffix = key;
        break;
      }
    }
    final response = request.response;
    try {
      await request.drain<void>();
      final behavior = suffix == null ? null : routes[suffix];
      switch (behavior) {
        case null || FakeMirrorBehavior.notFound:
          response.statusCode = HttpStatus.notFound;
          await response.close();
        case FakeMirrorBehavior.badGateway:
          response.statusCode = HttpStatus.badGateway;
          await response.close();
        case FakeMirrorBehavior.html:
          response.headers.contentType = ContentType.html;
          response.write('<html><body>mirror error</body></html>');
          await response.close();
        case FakeMirrorBehavior.hang:
          _hanging.add(response);
        case FakeMirrorBehavior.ok ||
            FakeMirrorBehavior.ignoreRange ||
            FakeMirrorBehavior.cut ||
            FakeMirrorBehavior.drip ||
            FakeMirrorBehavior.stall:
          final redirect = _redirects[suffix];
          if (redirect != null) {
            response.statusCode = HttpStatus.found;
            response.headers.set(HttpHeaders.locationHeader, redirect);
            await response.close();
            return;
          }
          await _serveBody(request, response, suffix!, behavior);
      }
    } catch (_) {
      // 客户端主动断开（测速、取消）时写入会失败，忽略。
    }
  }

  Future<void> _serveBody(
    HttpRequest request,
    HttpResponse response,
    String suffix,
    FakeMirrorBehavior behavior,
  ) async {
    final content = _bodies[suffix];
    final bytes = content is String
        ? Uint8List.fromList(utf8.encode(content))
        : content as Uint8List;
    var start = 0;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    var end = bytes.length - 1;
    if (range != null && behavior != FakeMirrorBehavior.ignoreRange) {
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (match != null) {
        start = int.parse(match.group(1)!);
        if (match.group(2)!.isNotEmpty) {
          end = int.parse(match.group(2)!).clamp(0, bytes.length - 1);
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${bytes.length}',
        );
      }
    }
    response.headers.contentType = ContentType.binary;
    final slice = bytes.sublist(start, end + 1);
    response.contentLength = slice.length;
    switch (behavior) {
      case FakeMirrorBehavior.cut:
        final sent = slice.length < cutAfter ? slice.length ~/ 2 : cutAfter;
        response.add(slice.sublist(0, sent));
        await response.flush();
        // 少于 Content-Length 就关闭：服务器销毁连接，客户端读到中途断流。
        await response.close();
      case FakeMirrorBehavior.stall:
        response.add(slice.sublist(0, min(cutAfter, slice.length ~/ 2)));
        await response.flush();
        _hanging.add(response);
      case FakeMirrorBehavior.drip:
        const step = 8 << 10;
        for (var i = 0; i < slice.length; i += step) {
          response.add(slice.sublist(i, min(i + step, slice.length)));
          await response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        await response.close();
      default:
        response.add(slice);
        await response.close();
    }
  }
}

class FakeMirrorRequest {
  const FakeMirrorRequest(this.mirror, this.path, this.range);

  final String mirror;
  final String path;
  final String? range;
}
