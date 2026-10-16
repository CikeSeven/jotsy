import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cloud_backup_models.dart';

/// 网盘客户端共用的 HTTP 层（基于 dart:io HttpClient）。
///
/// 职责边界：
/// - 控制类请求整体超时 [timeout]；大文件传输按“数据块间隔”判定空闲
///   [idleTimeout]，慢网络下的大备份不会被整体超时误杀；
/// - 上传从文件流读、下载写入文件流，不把备份整包读入内存；
/// - 网络层异常（断网、超时、TLS）统一转成 [CloudBackupFailure.network]；
///   HTTP 状态码不在这里判定，交给各网盘按自己的错误格式归类。
class CloudBackupHttp {
  CloudBackupHttp({
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 120),
    this.userAgent = 'Jotsy Cloud Backup',
  }) : _client = (clientFactory ?? HttpClient.new)()
         ..connectionTimeout = timeout;

  final HttpClient _client;
  final Duration timeout;
  final Duration idleTimeout;
  final String userAgent;

  /// 控制类响应体上限：列表、令牌与错误信息都远小于此，超出说明地址指向了
  /// 错误的资源（例如误把文件下载地址当接口）。
  static const int maxBufferedBody = 16 * 1024 * 1024;

  /// 发送请求并读完响应体（只用于小响应）。
  Future<CloudHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
    bool followRedirects = true,
  }) {
    return _guard(() async {
      final request = await _open(method, uri, headers, followRedirects);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      } else if (method != 'GET' && method != 'HEAD') {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(timeout);
      return _buffer(response, timeout);
    });
  }

  /// 以 `application/x-www-form-urlencoded` 发送表单。
  Future<CloudHttpResponse> sendForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String> headers = const <String, String>{},
  }) {
    return send(
      'POST',
      uri,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
        ...headers,
      },
      body: utf8.encode(Uri(queryParameters: fields).query),
    );
  }

  /// 以 JSON 发送请求体。
  Future<CloudHttpResponse> sendJson(
    String method,
    Uri uri,
    Object? json, {
    Map<String, String> headers = const <String, String>{},
  }) {
    return send(
      method,
      uri,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        ...headers,
      },
      body: utf8.encode(jsonEncode(json)),
    );
  }

  /// 流式上传 [length] 字节的 [body]；响应体按小响应读完返回。
  Future<CloudHttpResponse> upload(
    String method,
    Uri uri, {
    required Stream<List<int>> body,
    required int length,
    Map<String, String> headers = const <String, String>{},
  }) {
    return _guard(() async {
      final request = await _open(method, uri, headers, true);
      request.contentLength = length;
      await request.addStream(body.timeout(idleTimeout));
      final response = await request.close().timeout(idleTimeout);
      return _buffer(response, idleTimeout);
    });
  }

  /// 下载到 [target]。成功（2xx）时写完文件并返回不带响应体的结果；失败时
  /// 不创建文件，返回带错误响应体的结果，由调用方按平台格式归类。
  Future<CloudHttpResponse> download(
    Uri uri,
    File target, {
    String method = 'GET',
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
    CloudBackupProgress? onProgress,
    bool followRedirects = true,
  }) {
    return _guard(() async {
      final request = await _open(method, uri, headers, followRedirects);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      } else if (method != 'GET') {
        // Dropbox 的下载接口是无请求体的 POST，不能以分块编码发送空体。
        request.contentLength = 0;
      }
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _buffer(response, timeout);
      }
      await target.parent.create(recursive: true);
      final sink = target.openWrite();
      final total = response.contentLength >= 0 ? response.contentLength : null;
      try {
        await response
            .timeout(idleTimeout)
            .transform(countingTransformer(onProgress, total: total))
            .pipe(sink);
      } catch (_) {
        await sink.close().catchError((Object _) {});
        if (await target.exists()) await target.delete();
        rethrow;
      }
      return CloudHttpResponse(response.statusCode, response.headers, const []);
    });
  }

  void close() => _client.close(force: true);

  Future<HttpClientRequest> _open(
    String method,
    Uri uri,
    Map<String, String> headers,
    bool followRedirects,
  ) async {
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.followRedirects = followRedirects;
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value, preserveHeaderCase: true);
    }
    return request;
  }

  Future<CloudHttpResponse> _buffer(
    HttpClientResponse response,
    Duration wait,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response.timeout(wait)) {
      bytes.addAll(chunk);
      if (bytes.length > maxBufferedBody) {
        throw const CloudBackupException(
          CloudBackupFailure.protocol,
          'response too large',
        );
      }
    }
    return CloudHttpResponse(response.statusCode, response.headers, bytes);
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CloudBackupException {
      rethrow;
    } on SocketException catch (error) {
      throw CloudBackupException(CloudBackupFailure.network, '$error');
    } on TimeoutException catch (error) {
      throw CloudBackupException(CloudBackupFailure.network, '$error');
    } on HandshakeException catch (error) {
      throw CloudBackupException(CloudBackupFailure.network, '$error');
    } on HttpException catch (error) {
      throw CloudBackupException(CloudBackupFailure.network, '$error');
    } on FileSystemException {
      rethrow;
    }
  }
}

/// 统计流经的字节数并回调进度；[base] 用于分片上传时累计之前分片的字节。
StreamTransformer<List<int>, List<int>> countingTransformer(
  CloudBackupProgress? onProgress, {
  int base = 0,
  int? total,
}) {
  var transferred = base;
  return StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (chunk, sink) {
      transferred += chunk.length;
      onProgress?.call(transferred, total);
      sink.add(chunk);
    },
  );
}

/// 读取 [file] 的 `[start, end)` 区间并回调累计进度。
Stream<List<int>> fileRangeStream(
  File file, {
  int start = 0,
  int? end,
  CloudBackupProgress? onProgress,
  int? total,
}) {
  return file
      .openRead(start, end)
      .transform(countingTransformer(onProgress, base: start, total: total));
}

class CloudHttpResponse {
  const CloudHttpResponse(this.statusCode, this.headers, this.bodyBytes);

  final int statusCode;
  final HttpHeaders headers;
  final List<int> bodyBytes;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String get text => utf8.decode(bodyBytes, allowMalformed: true);

  /// 响应体按 JSON 对象解析；空响应或非对象返回空 Map（错误响应常不是 JSON）。
  Map<String, Object?> get jsonObject {
    if (bodyBytes.isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map
          ? decoded.cast<String, Object?>()
          : const <String, Object?>{};
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  /// 成功响应必须是 JSON 对象，否则视为协议不符。
  Map<String, Object?> requireJsonObject() {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on FormatException {
      // 落到下方统一抛出。
    }
    throw CloudBackupException(
      CloudBackupFailure.protocol,
      'expected JSON object',
      statusCode,
    );
  }
}

/// JSON 字段的宽松读取：网盘接口的数字字段有时以字符串返回。
int? jsonInt(Object? value) => switch (value) {
  int raw => raw,
  num raw => raw.toInt(),
  String raw => int.tryParse(raw.trim()),
  _ => null,
};

String? jsonString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? jsonDateTime(Object? value) {
  final raw = jsonString(value);
  return raw == null ? null : DateTime.tryParse(raw);
}
