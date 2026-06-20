import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'webdav_models.dart';

/// 轻量 WebDAV 协议客户端。
///
/// 职责边界：
/// - 封装 WebDAV HTTP 方法、认证头、XML 解析和状态码映射；
/// - 上传/下载只通过 stream 传输文件，避免大 ZIP 备份读入内存；
/// - 不处理数据库、ZIP 生成、UI 文案和本地设置持久化。
class WebDavClient {
  WebDavClient({
    required WebDavConfig config,
    HttpClient Function()? clientFactory,
    Duration timeout = const Duration(seconds: 30),
    Duration idleTimeout = const Duration(seconds: 120),
  }) : _config = config.validate(),
       _clientFactory = clientFactory ?? HttpClient.new,
       _timeout = timeout,
       _idleTimeout = idleTimeout;

  final WebDavConfig _config;
  final HttpClient Function() _clientFactory;

  /// 建连/首响应等控制类请求的整体超时。
  final Duration _timeout;

  /// 大文件传输阶段的「无数据流动」空闲超时；按数据块间隔计时，
  /// 而非整包传输总耗时，避免慢网络下大备份被 [_timeout] 误杀。
  final Duration _idleTimeout;

  Future<void> ensureDirectory(String remoteDirectory) async {
    final normalized = WebDavConfig.normalizeRemoteDirectory(remoteDirectory);
    final segments = normalized
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    var current = '/';
    for (final segment in segments) {
      current = '$current$segment/';
      await _mkcol(current);
    }
  }

  Future<List<WebDavRemoteFile>> listFiles(String remoteDirectory) async {
    final uri = _config.resolveRemoteUri(remoteDirectory, directory: true);
    final response = await _send(
      method: 'PROPFIND',
      uri: uri,
      headers: <String, String>{'Depth': '1'},
      body: utf8.encode('''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:resourcetype />
    <D:getcontentlength />
    <D:getlastmodified />
    <D:getetag />
  </D:prop>
</D:propfind>'''),
      expectedStatuses: const <int>{207, HttpStatus.ok},
    );
    final body = await utf8.decoder.bind(response).join();
    return _parsePropfind(
      body,
      uri.path,
    ).where((file) => !file.isDirectory).toList(growable: false);
  }

  Future<void> putFile({required String remotePath, required File file}) async {
    if (!await file.exists()) {
      throw const FileSystemException('上传文件不存在');
    }
    final uri = _config.resolveRemoteUri(remotePath);
    final client = _createClient();
    try {
      final request = await client.openUrl('PUT', uri).timeout(_timeout);
      _applyHeaders(request);
      request.contentLength = await file.length();
      // 传输阶段按数据块间隔判定空闲，慢网络下的大备份不会被建连超时误杀。
      await request.addStream(file.openRead().timeout(_idleTimeout));
      final response = await request.close().timeout(_idleTimeout);
      await _ensureStatus(response, uri, const <int>{
        HttpStatus.ok,
        HttpStatus.created,
        HttpStatus.noContent,
      });
      await response.drain<void>();
    } on WebDavException {
      rethrow;
    } catch (error) {
      throw WebDavException('WebDAV 上传失败: $error', uri: uri);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> putText({
    required String remotePath,
    required String text,
  }) async {
    final uri = _config.resolveRemoteUri(remotePath);
    await _sendAndDrain(
      method: 'PUT',
      uri: uri,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
      body: utf8.encode(text),
      expectedStatuses: const <int>{
        HttpStatus.ok,
        HttpStatus.created,
        HttpStatus.noContent,
      },
    );
  }

  Future<String?> getTextOrNull(String remotePath) async {
    final uri = _config.resolveRemoteUri(remotePath);
    try {
      final response = await _send(
        method: 'GET',
        uri: uri,
        expectedStatuses: const <int>{HttpStatus.ok},
      );
      return utf8.decoder.bind(response).join();
    } on WebDavException catch (error) {
      if (error.isNotFound) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> downloadFile({
    required String remotePath,
    required File targetFile,
  }) async {
    final uri = _config.resolveRemoteUri(remotePath);
    final response = await _send(
      method: 'GET',
      uri: uri,
      expectedStatuses: const <int>{HttpStatus.ok},
    );
    await targetFile.parent.create(recursive: true);
    final sink = targetFile.openWrite();
    try {
      // 同样按数据块间隔判定空闲，避免大备份下载被整体超时打断。
      await response.timeout(_idleTimeout).pipe(sink);
    } catch (error) {
      await sink.close();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      throw WebDavException('WebDAV 下载失败: $error', uri: uri);
    }
  }

  Future<void> deleteFile(String remotePath) async {
    final uri = _config.resolveRemoteUri(remotePath);
    await _sendAndDrain(
      method: 'DELETE',
      uri: uri,
      expectedStatuses: const <int>{
        HttpStatus.ok,
        HttpStatus.noContent,
        HttpStatus.notFound,
      },
    );
  }

  Future<void> _mkcol(String remoteDirectory) async {
    final uri = _config.resolveRemoteUri(remoteDirectory, directory: true);
    await _sendAndDrain(
      method: 'MKCOL',
      uri: uri,
      expectedStatuses: const <int>{
        HttpStatus.created,
        HttpStatus.ok,
        HttpStatus.methodNotAllowed,
      },
    );
  }

  Future<Stream<List<int>>> _send({
    required String method,
    required Uri uri,
    Set<int> expectedStatuses = const <int>{HttpStatus.ok},
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
  }) async {
    final client = _createClient();
    try {
      final request = await client.openUrl(method, uri).timeout(_timeout);
      _applyHeaders(request);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(_timeout);
      await _ensureStatus(response, uri, expectedStatuses);
      return _AutoClosingStream(response, client);
    } on WebDavException {
      client.close(force: true);
      rethrow;
    } catch (error) {
      client.close(force: true);
      throw WebDavException('WebDAV 请求失败: $error', uri: uri);
    }
  }

  Future<void> _sendAndDrain({
    required String method,
    required Uri uri,
    Set<int> expectedStatuses = const <int>{HttpStatus.ok},
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
  }) async {
    final response = await _send(
      method: method,
      uri: uri,
      expectedStatuses: expectedStatuses,
      headers: headers,
      body: body,
    );
    await response.drain<void>();
  }

  Future<void> _ensureStatus(
    HttpClientResponse response,
    Uri uri,
    Set<int> expectedStatuses,
  ) async {
    if (expectedStatuses.contains(response.statusCode)) {
      return;
    }
    await response.drain<void>();
    throw WebDavException(
      _messageForStatus(response.statusCode),
      statusCode: response.statusCode,
      uri: uri,
    );
  }

  HttpClient _createClient() {
    final client = _clientFactory();
    client.connectionTimeout = _timeout;
    return client;
  }

  void _applyHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.userAgentHeader, 'Jotsy WebDAV Sync');
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    final token = base64Encode(
      utf8.encode('${_config.normalizedUsername}:${_config.password}'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
  }

  List<WebDavRemoteFile> _parsePropfind(String rawXml, String requestPath) {
    final document = XmlDocument.parse(rawXml);
    final responses = document
        .findAllElements('response', namespace: '*')
        .toList(growable: false);
    final files = <WebDavRemoteFile>[];
    final normalizedRequestPath = _normalizeResponsePath(requestPath);
    for (final response in responses) {
      final href =
          response.getElement('href', namespace: '*')?.innerText.trim();
      if (href == null || href.isEmpty) {
        continue;
      }
      final path = _pathFromHref(href);
      final normalizedPath = _normalizeResponsePath(path);
      if (normalizedPath == normalizedRequestPath) {
        continue;
      }
      final resourceType =
          response
              .findAllElements('resourcetype', namespace: '*')
              .map((node) => node.innerXml)
              .join();
      final isDirectory =
          resourceType.contains('collection') || normalizedPath.endsWith('/');
      final fileName = _lastPathSegment(normalizedPath);
      if (fileName.isEmpty) {
        continue;
      }
      files.add(
        WebDavRemoteFile(
          path: _stripBasePath(normalizedPath),
          fileName: fileName,
          isDirectory: isDirectory,
          size: _parseInt(
            response
                .findAllElements('getcontentlength', namespace: '*')
                .firstOrNull
                ?.innerText,
          ),
          lastModified: _parseHttpDate(
            response
                .findAllElements('getlastmodified', namespace: '*')
                .firstOrNull
                ?.innerText,
          ),
          etag:
              response
                  .findAllElements('getetag', namespace: '*')
                  .firstOrNull
                  ?.innerText
                  .trim(),
        ),
      );
    }
    files.sort((a, b) => a.fileName.compareTo(b.fileName));
    return files;
  }

  String _pathFromHref(String href) {
    final parsed = Uri.tryParse(href);
    final rawPath = parsed?.path ?? href;
    try {
      return Uri.decodeComponent(rawPath);
    } catch (_) {
      return rawPath;
    }
  }

  String _stripBasePath(String absolutePath) {
    final basePath = _normalizeResponsePath(_config.baseUri.path);
    var normalized = _normalizeResponsePath(absolutePath);
    if (basePath != '/' && normalized.startsWith(basePath)) {
      normalized = '/${normalized.substring(basePath.length)}';
    }
    return normalized.replaceAll(RegExp(r'/+'), '/');
  }

  String _normalizeResponsePath(String path) {
    final normalized = path
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/');
    if (normalized.isEmpty || normalized == '/') {
      return '/';
    }
    return normalized.startsWith('/') ? normalized : '/$normalized';
  }

  String _lastPathSegment(String path) {
    final trimmed =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final index = trimmed.lastIndexOf('/');
    return index < 0 ? trimmed : trimmed.substring(index + 1);
  }

  String _messageForStatus(int statusCode) {
    return switch (statusCode) {
      HttpStatus.unauthorized => 'WebDAV 认证失败，请检查用户名和密码/Token',
      HttpStatus.forbidden => 'WebDAV 无权限访问该目录',
      HttpStatus.notFound => 'WebDAV 路径不存在',
      507 => 'WebDAV 服务器存储空间不足',
      _ => 'WebDAV 服务器返回异常状态',
    };
  }

  int? _parseInt(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  DateTime? _parseHttpDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return DateTime.tryParse(value);
    }
  }
}

/// 自动在响应流消费完成后关闭 HttpClient。
class _AutoClosingStream extends Stream<List<int>> {
  _AutoClosingStream(this._delegate, this._client);

  final Stream<List<int>> _delegate;
  final HttpClient _client;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _delegate.listen(
      onData,
      onError: onError,
      onDone: () {
        _client.close(force: true);
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }
}

extension _XmlElementFirstOrNull on Iterable<XmlElement> {
  XmlElement? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
