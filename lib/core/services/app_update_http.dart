import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 更新流程失败的类别，界面按它给出对应的说明与下一步。
enum AppUpdateFailureKind {
  /// 所有线路都连不上或超时。
  network,

  /// 没有找到已发布的版本。
  notFound,

  /// Release 里没有适合本机 ABI 的安装包。
  noCompatibleApk,

  /// 下载的文件大小或 SHA-256 与发布时不符（被截断或被篡改）。
  integrity,

  /// 安装包的包名或签名与本机应用不同，系统会拒绝覆盖安装。
  signatureMismatch,

  /// 安装包并不比本机版本新。
  notNewer,

  /// 写入缓存目录失败（空间不足等）。
  storage,

  /// 当前平台不支持应用内安装（非 Android）或系统无法打开安装器。
  installUnavailable,

  /// 用户取消。
  cancelled,
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.kind, [this.detail]);

  final AppUpdateFailureKind kind;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AppUpdateException(${kind.name})'
      : 'AppUpdateException(${kind.name}: $detail)';
}

/// 取消一组进行中的请求：强制关闭登记的连接，阻塞中的读写随即抛错。
class AppUpdateCancelToken {
  final Set<HttpClient> _clients = <HttpClient>{};
  final Completer<void> _whenCancelled = Completer<void>();

  bool get isCancelled => _whenCancelled.isCompleted;

  /// 取消时完成，用于结束仍在等待的竞速。
  Future<void> get whenCancelled => _whenCancelled.future;

  void cancel() {
    if (isCancelled) {
      return;
    }
    _whenCancelled.complete();
    for (final client in _clients.toList(growable: false)) {
      client.close(force: true);
    }
    _clients.clear();
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const AppUpdateException(AppUpdateFailureKind.cancelled);
    }
  }

  void _attach(HttpClient client) {
    if (isCancelled) {
      client.close(force: true);
    } else {
      _clients.add(client);
    }
  }

  void _detach(HttpClient client) => _clients.remove(client);
}

/// 一次文本请求的结果。
class AppUpdateTextResponse {
  const AppUpdateTextResponse(this.statusCode, this.body, this.location);

  final int statusCode;
  final String body;

  /// 不跟随跳转时的 Location 头。
  final String? location;

  bool get ok => statusCode >= 200 && statusCode < 300;
}

/// 更新流程共用的 HTTP 出口：每个请求独立的 [HttpClient]，便于竞速时单独
/// 关闭落选的连接；统一 User-Agent 与超时。
class AppUpdateHttp {
  AppUpdateHttp({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  static const String userAgent = 'Jotsy-App-Updater/2.0';

  final HttpClient Function() _clientFactory;

  /// 读取一段文本（清单、接口、更新说明）。[maxBytes] 防止镜像返回的
  /// 异常大页面占满内存；整个请求（含读正文）受 [timeout] 限制。
  Future<AppUpdateTextResponse> getText(
    Uri uri, {
    required Duration timeout,
    bool followRedirects = true,
    String accept = '*/*',
    int maxBytes = 1 << 20,
    AppUpdateCancelToken? cancelToken,
  }) async {
    final client = _clientFactory();
    cancelToken?._attach(client);
    try {
      return await () async {
        client.connectionTimeout = timeout;
        final request = await client.getUrl(uri);
        request.followRedirects = followRedirects;
        request.headers
          ..set(HttpHeaders.userAgentHeader, userAgent)
          ..set(HttpHeaders.acceptHeader, accept);
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > maxBytes) {
            throw const HttpException('Response is too large');
          }
        }
        return AppUpdateTextResponse(
          response.statusCode,
          utf8.decode(bytes, allowMalformed: true),
          response.headers.value(HttpHeaders.locationHeader),
        );
      }().timeout(timeout);
    } finally {
      cancelToken?._detach(client);
      client.close(force: true);
    }
  }

  /// 打开一个下载流。返回的 [AppUpdateStream] 必须 [AppUpdateStream.close]。
  Future<AppUpdateStream> openStream(
    Uri uri, {
    required Duration connectTimeout,
    int? rangeStart,
    int? rangeEnd,
    AppUpdateCancelToken? cancelToken,
  }) async {
    final client = _clientFactory();
    cancelToken?._attach(client);
    try {
      client.connectionTimeout = connectTimeout;
      final request = await client.getUrl(uri).timeout(connectTimeout);
      request.headers
        ..set(HttpHeaders.userAgentHeader, userAgent)
        ..set(HttpHeaders.acceptHeader, '*/*')
        // 镜像与 CDN 对压缩传输的 Range 处理不一致，统一要原始字节。
        ..set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (rangeStart != null) {
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=$rangeStart-${rangeEnd ?? ''}',
        );
      }
      final response = await request.close().timeout(connectTimeout);
      return AppUpdateStream._(client, response, cancelToken);
    } catch (_) {
      cancelToken?._detach(client);
      client.close(force: true);
      rethrow;
    }
  }
}

/// 一个打开的下载响应。
class AppUpdateStream {
  AppUpdateStream._(this._client, this.response, this._cancelToken);

  final HttpClient _client;
  final AppUpdateCancelToken? _cancelToken;
  final HttpClientResponse response;

  int get statusCode => response.statusCode;

  /// 镜像出错时常以 200 返回一张 HTML 错误页，按内容类型排除。
  bool get looksLikeHtml =>
      response.headers.contentType?.mimeType == ContentType.html.mimeType;

  /// `Content-Range: bytes 0-99/12345` 里的总长度。
  int? get rangeTotal {
    final raw = response.headers.value(HttpHeaders.contentRangeHeader);
    final match = RegExp(r'/(\d+)\s*$').firstMatch(raw ?? '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// 正文长度；未知时为 null。
  int? get contentLength =>
      response.contentLength >= 0 ? response.contentLength : null;

  void close() {
    _cancelToken?._detach(_client);
    _client.close(force: true);
  }
}
