import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_s3_signer.dart';

/// S3 兼容对象存储的连接配置（AWS S3、Cloudflare R2、阿里云 OSS、腾讯云
/// COS、七牛、MinIO 等）。
class S3BackupConfig {
  const S3BackupConfig({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.prefix = 'jotsy/',
    this.pathStyle = false,
  });

  factory S3BackupConfig.fromJson(Map<String, Object?> json) {
    String text(String key, [String fallback = '']) =>
        json[key] is String ? json[key] as String : fallback;
    return S3BackupConfig(
      endpoint: text('endpoint'),
      region: text('region'),
      bucket: text('bucket'),
      accessKeyId: text('accessKeyId'),
      secretAccessKey: text('secretAccessKey'),
      prefix: text('prefix', 'jotsy/'),
      pathStyle: json['pathStyle'] == true,
    );
  }

  final String endpoint;

  /// SigV4 的区域名；留空按 `us-east-1`（MinIO 等自建服务的默认值）。
  final String region;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;

  /// 桶内的备份目录（对象键前缀），空串表示桶根目录。
  final String prefix;

  /// 路径风格（`endpoint/bucket/key`）；否则用虚拟主机风格
  /// （`bucket.endpoint/key`）。部分服务只支持其中一种，由预设决定默认值。
  final bool pathStyle;

  Map<String, Object?> toJson() => <String, Object?>{
    'endpoint': endpoint.trim(),
    'region': region.trim(),
    'bucket': bucket.trim(),
    'accessKeyId': accessKeyId.trim(),
    'secretAccessKey': secretAccessKey,
    'prefix': normalizedPrefix,
    'pathStyle': pathStyle,
  };

  String get signingRegion =>
      region.trim().isEmpty ? 'us-east-1' : region.trim();

  /// 去掉首尾斜杠与 `.`/`..` 段，非空时以 `/` 结尾。
  String get normalizedPrefix {
    final segments = prefix
        .replaceAll('\\', '/')
        .split('/')
        .map((segment) => segment.trim())
        .where(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        );
    final joined = segments.join('/');
    return joined.isEmpty ? '' : '$joined/';
  }

  Uri get endpointUri {
    var raw = endpoint.trim();
    if (raw.isEmpty) {
      throw const CloudBackupException(CloudBackupFailure.config, 'endpoint');
    }
    // 控制台常只给出主机名（如 oss-cn-hangzhou.aliyuncs.com），默认 HTTPS。
    if (!raw.contains('://')) raw = 'https://$raw';
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const CloudBackupException(CloudBackupFailure.config, 'endpoint');
    }
    return uri;
  }

  S3BackupConfig validate() {
    endpointUri;
    final name = bucket.trim();
    // 宽松校验：腾讯云 COS 的桶名带 APPID 后缀，七牛等允许更长的名字。
    if (!RegExp(r'^[a-z0-9][a-z0-9.\-_]{1,254}$').hasMatch(name)) {
      throw const CloudBackupException(CloudBackupFailure.config, 'bucket');
    }
    if (accessKeyId.trim().isEmpty || secretAccessKey.isEmpty) {
      throw const CloudBackupException(CloudBackupFailure.config, 'keys');
    }
    return this;
  }
}

/// S3 兼容对象存储客户端。
///
/// - 小于 [multipartThreshold] 的备份一次 PUT；更大的走分片上传（每片
///   [partSize]），失败时中止分片任务，不在桶里留下未完成的上传；
/// - 每个请求体都计算真实的 SHA-256 载荷摘要（分片先读一遍算摘要再上传），
///   不依赖 `UNSIGNED-PAYLOAD`，各家兼容实现都能验签；
/// - 只列出前缀目录下一层的 ZIP（`delimiter=/`）。
class S3BackupRemote implements CloudBackupRemote {
  S3BackupRemote({
    required S3BackupConfig config,
    CloudBackupHttp? http,
    DateTime Function()? clock,
    this.multipartThreshold = 32 * 1024 * 1024,
    this.partSize = 16 * 1024 * 1024,
  }) : _config = config.validate(),
       _http = http ?? CloudBackupHttp(),
       _clock = clock ?? DateTime.now,
       _signer = S3Signer(
         accessKeyId: config.accessKeyId.trim(),
         secretAccessKey: config.secretAccessKey,
         region: config.signingRegion,
       );

  final S3BackupConfig _config;
  final CloudBackupHttp _http;
  final DateTime Function() _clock;
  final S3Signer _signer;
  final int multipartThreshold;

  /// 分片大小；S3 要求除最后一片外不小于 5 MiB，最多 10000 片。
  final int partSize;

  @override
  Future<void> prepare() async {
    final response = await _request('GET', null, query: _listQuery(maxKeys: 1));
    _ensureSuccess(response);
  }

  @override
  Future<List<CloudBackupEntry>> list() async {
    final entries = <CloudBackupEntry>[];
    String? continuation;
    do {
      final response = await _request(
        'GET',
        null,
        query: _listQuery(continuation: continuation),
      );
      _ensureSuccess(response);
      final document = _parseXml(response);
      for (final item in document.findAllElements('Contents', namespace: '*')) {
        final key = _child(item, 'Key');
        if (key == null) continue;
        final fileName = key.substring(key.lastIndexOf('/') + 1);
        if (!isCloudBackupFileName(fileName)) continue;
        final modified = DateTime.tryParse(_child(item, 'LastModified') ?? '');
        entries.add(
          CloudBackupEntry(
            fileName: fileName,
            remoteId: key,
            size: jsonInt(_child(item, 'Size')),
            createdAt: cloudBackupCreatedAtFromFileName(fileName) ?? modified,
            updatedAt: modified,
          ),
        );
      }
      final truncated =
          _child(document.rootElement, 'IsTruncated')?.toLowerCase() == 'true';
      continuation = truncated
          ? _child(document.rootElement, 'NextContinuationToken')
          : null;
    } while (continuation != null);
    return sortCloudBackups(entries);
  }

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) async {
    final key = '${_config.normalizedPrefix}$fileName';
    final length = await file.length();
    if (length <= multipartThreshold) {
      final response = await _request(
        'PUT',
        key,
        payloadHash: await sha256OfFileRange(file),
        body: fileRangeStream(file, onProgress: onProgress, total: length),
        length: length,
      );
      _ensureSuccess(response);
    } else {
      await _multipartUpload(key, file, length, onProgress);
    }
    return CloudBackupEntry(
      fileName: fileName,
      remoteId: key,
      size: length,
      createdAt: cloudBackupCreatedAtFromFileName(fileName) ?? _clock(),
      updatedAt: _clock(),
    );
  }

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) async {
    final signed = _sign('GET', entry.remoteId);
    final response = await _http.download(
      signed.uri,
      target,
      headers: signed.headers,
      onProgress: onProgress,
      // 与其他请求一致：签名绑定主机，区域配错时的 301 按配置错误报告。
      followRedirects: false,
    );
    _ensureSuccess(response);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    final response = await _request('DELETE', entry.remoteId);
    // S3 删除不存在的对象也返回 204；个别兼容实现返回 404，同样视为已删除。
    if (response.statusCode == HttpStatus.notFound) return;
    _ensureSuccess(response);
  }

  @override
  void close() => _http.close();

  Future<void> _multipartUpload(
    String key,
    File file,
    int length,
    CloudBackupProgress? onProgress,
  ) async {
    final created = await _request('POST', key, query: const {'uploads': ''});
    _ensureSuccess(created);
    final uploadId = _child(_parseXml(created).rootElement, 'UploadId');
    if (uploadId == null) {
      throw const CloudBackupException(CloudBackupFailure.protocol, 'UploadId');
    }
    try {
      final etags = <String>[];
      for (var start = 0; start < length; start += partSize) {
        final end = start + partSize < length ? start + partSize : length;
        final response = await _request(
          'PUT',
          key,
          query: {'partNumber': '${etags.length + 1}', 'uploadId': uploadId},
          payloadHash: await sha256OfFileRange(file, start: start, end: end),
          body: fileRangeStream(
            file,
            start: start,
            end: end,
            onProgress: onProgress,
            total: length,
          ),
          length: end - start,
        );
        _ensureSuccess(response);
        final etag = response.headers.value('etag');
        if (etag == null) {
          throw const CloudBackupException(CloudBackupFailure.protocol, 'ETag');
        }
        etags.add(etag);
      }
      final xml = StringBuffer('<CompleteMultipartUpload>');
      for (var index = 0; index < etags.length; index++) {
        xml.write(
          '<Part><PartNumber>${index + 1}</PartNumber>'
          '<ETag>${_escapeXml(etags[index])}</ETag></Part>',
        );
      }
      xml.write('</CompleteMultipartUpload>');
      final bytes = utf8.encode(xml.toString());
      final completed = await _request(
        'POST',
        key,
        query: {'uploadId': uploadId},
        bytes: bytes,
      );
      _ensureSuccess(completed);
      // CompleteMultipartUpload 可能以 200 返回错误文档。
      if (completed.text.contains('<Error>')) {
        _throwForErrorDocument(completed);
      }
    } catch (_) {
      try {
        await _request('DELETE', key, query: {'uploadId': uploadId});
      } catch (_) {
        // 中止失败只会留下未完成的分片（多数服务按生命周期规则清理），不能
        // 掩盖原始错误。
      }
      rethrow;
    }
  }

  Map<String, String> _listQuery({String? continuation, int? maxKeys}) => {
    'list-type': '2',
    'delimiter': '/',
    'prefix': _config.normalizedPrefix,
    if (maxKeys != null) 'max-keys': '$maxKeys',
    if (continuation != null) 'continuation-token': continuation,
  };

  S3SignedRequest _sign(
    String method,
    String? key, {
    Map<String, String> query = const <String, String>{},
    String? payloadHash,
  }) {
    final endpoint = _config.endpointUri;
    final bucket = _config.bucket.trim();
    final keySegments = key == null ? const <String>[] : key.split('/');
    final baseSegments = endpoint.pathSegments.where((s) => s.isNotEmpty);
    final pathStyle = _config.pathStyle;
    return _signer.sign(
      method: method,
      scheme: endpoint.scheme,
      host: pathStyle ? endpoint.host : '$bucket.${endpoint.host}',
      port: endpoint.hasPort ? endpoint.port : null,
      pathSegments: [...baseSegments, if (pathStyle) bucket, ...keySegments],
      query: query,
      payloadHash: payloadHash ?? S3Signer.emptyPayloadHash,
      now: _clock(),
    );
  }

  Future<CloudHttpResponse> _request(
    String method,
    String? key, {
    Map<String, String> query = const <String, String>{},
    String? payloadHash,
    Stream<List<int>>? body,
    int? length,
    List<int>? bytes,
  }) {
    final hash = bytes != null
        ? S3Signer.sha256Hex(bytes)
        : payloadHash ?? S3Signer.emptyPayloadHash;
    final signed = _sign(method, key, query: query, payloadHash: hash);
    if (body != null) {
      return _http.upload(
        method,
        signed.uri,
        body: body,
        length: length!,
        headers: signed.headers,
      );
    }
    // 不跟随重定向：签名绑定了主机，跟过去也会验签失败；且区域或寻址风格
    // 不对时 S3 回 301 PermanentRedirect 却不带 Location，HttpClient 跟随时
    // 会抛 RedirectException 被当成网络错误，必须原样交给错误归类。
    return _http.send(
      method,
      signed.uri,
      headers: signed.headers,
      body: bytes,
      followRedirects: false,
    );
  }

  void _ensureSuccess(CloudHttpResponse response) {
    if (response.isSuccess) return;
    _throwForErrorDocument(response);
  }

  /// 按 S3 错误文档的 `<Code>` 归类；没有错误文档时按状态码。
  Never _throwForErrorDocument(CloudHttpResponse response) {
    String? code;
    try {
      code = _child(XmlDocument.parse(response.text).rootElement, 'Code');
    } catch (_) {
      code = null;
    }
    final failure = switch (code) {
      'InvalidAccessKeyId' ||
      'SignatureDoesNotMatch' ||
      'AccessDenied' ||
      'AllAccessDisabled' => CloudBackupFailure.unauthorized,
      'NoSuchBucket' ||
      'InvalidBucketName' ||
      'PermanentRedirect' ||
      'AuthorizationHeaderMalformed' ||
      'IllegalLocationConstraintException' ||
      'RequestTimeTooSkewed' => CloudBackupFailure.config,
      'NoSuchKey' => CloudBackupFailure.notFound,
      'EntityTooLarge' => CloudBackupFailure.fileTooLarge,
      'QuotaExceeded' ||
      'StorageQuotaExceeded' ||
      'InsufficientStorage' => CloudBackupFailure.storageFull,
      'SlowDown' || 'TooManyRequests' => CloudBackupFailure.rateLimited,
      _ => null,
    };
    if (failure != null) {
      throw CloudBackupException(failure, code, response.statusCode);
    }
    if (response.statusCode == HttpStatus.movedPermanently) {
      // 区域或寻址风格不对时 S3 以 301 指向正确的端点。
      throw CloudBackupException(
        CloudBackupFailure.config,
        code,
        response.statusCode,
      );
    }
    throw CloudBackupException.forStatus(response.statusCode, code);
  }

  static XmlDocument _parseXml(CloudHttpResponse response) {
    try {
      return XmlDocument.parse(response.text);
    } on XmlException {
      throw CloudBackupException(
        CloudBackupFailure.protocol,
        'invalid XML',
        response.statusCode,
      );
    }
  }

  static String? _child(XmlElement element, String name) =>
      element.getElement(name, namespace: '*')?.innerText.trim();

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
