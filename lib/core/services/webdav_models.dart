import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// WebDAV 同步相关纯模型与路径/manifest 编解码。
///
/// 职责边界：
/// - 只做配置校验、远程路径规范化、manifest JSON 解析；
/// - 不执行网络请求、不读写本地设置、不触碰数据库；
/// - 供 WebDAV 协议客户端、同步编排服务和设置页复用。
class WebDavConfig {
  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.remoteDirectory,
  });

  factory WebDavConfig.empty() {
    return const WebDavConfig(
      serverUrl: '',
      username: '',
      password: '',
      remoteDirectory: '/jotsy/',
    );
  }

  factory WebDavConfig.fromJson(Map<String, Object?> json) {
    return WebDavConfig(
      serverUrl: json['serverUrl']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      remoteDirectory: json['remoteDirectory']?.toString() ?? '/jotsy/',
    );
  }

  final String serverUrl;
  final String username;
  final String password;
  final String remoteDirectory;

  bool get isConfigured {
    return serverUrl.trim().isNotEmpty &&
        username.trim().isNotEmpty &&
        password.isNotEmpty &&
        remoteDirectory.trim().isNotEmpty;
  }

  Uri get baseUri {
    final parsed = _parseServerUri(serverUrl);
    final normalizedPath = _normalizeUriDirectoryPath(parsed.path);
    return parsed.replace(path: normalizedPath, query: null, fragment: null);
  }

  String get normalizedUsername => username.trim();
  String get normalizedRemoteDirectory =>
      normalizeRemoteDirectory(remoteDirectory);

  Uri get remoteDirectoryUri {
    return resolveRemoteUri(normalizedRemoteDirectory, directory: true);
  }

  String get remoteDirectoryPath {
    return remoteDirectoryUri.path;
  }

  WebDavConfig validate() {
    // 触发 getter 内部的 URL/路径校验，并补充凭据完整性检查。
    baseUri;
    if (normalizedUsername.isEmpty) {
      throw const WebDavConfigException('WebDAV 用户名不能为空');
    }
    if (password.isEmpty) {
      throw const WebDavConfigException('WebDAV 密码或 Token 不能为空');
    }
    if (normalizedRemoteDirectory == '/') {
      throw const WebDavConfigException('WebDAV 远程目录不能为根目录');
    }
    return this;
  }

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remoteDirectory,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDirectory: remoteDirectory ?? this.remoteDirectory,
    );
  }

  Map<String, Object?> toJson({bool includePassword = true}) {
    return <String, Object?>{
      'serverUrl': serverUrl.trim(),
      'username': normalizedUsername,
      if (includePassword) 'password': password,
      'remoteDirectory': normalizedRemoteDirectory,
    };
  }

  Uri resolveRemoteUri(String remotePath, {bool directory = false}) {
    final base = baseUri;
    final baseSegments = _pathSegments(base.path);
    final remoteSegments = _pathSegments(remotePath);
    final allSegments = <String>[...baseSegments, ...remoteSegments];
    if (directory) {
      allSegments.add('');
    }
    return base.replace(pathSegments: allSegments);
  }

  static String normalizeRemoteDirectory(String raw) {
    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) {
      throw const WebDavConfigException('WebDAV 远程目录不能为空');
    }
    final segments = _pathSegments(trimmed);
    if (segments.isEmpty) {
      return '/';
    }
    return '/${segments.join('/')}/';
  }

  static String normalizeRemoteFilePath(String raw) {
    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) {
      throw const WebDavConfigException('WebDAV 文件路径不能为空');
    }
    final segments = _pathSegments(trimmed);
    if (segments.isEmpty) {
      throw const WebDavConfigException('WebDAV 文件路径不能为空');
    }
    return '/${segments.join('/')}';
  }

  static Uri _parseServerUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const WebDavConfigException('WebDAV 地址不能为空');
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.trim().isEmpty) {
      throw const WebDavConfigException('WebDAV 地址格式错误');
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      throw const WebDavConfigException('WebDAV 地址仅支持 HTTP 或 HTTPS');
    }
    return parsed;
  }

  static String _normalizeUriDirectoryPath(String rawPath) {
    final segments = _pathSegments(rawPath);
    if (segments.isEmpty) {
      return '/';
    }
    return '/${segments.join('/')}/';
  }

  static List<String> _pathSegments(String rawPath) {
    return rawPath
        .split('/')
        .map(_safeDecodePathSegment)
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty && segment != '.')
        .where((segment) => segment != '..')
        .toList(growable: false);
  }

  static String _safeDecodePathSegment(String segment) {
    if (!segment.contains('%')) {
      return segment;
    }
    try {
      return Uri.decodeComponent(segment);
    } catch (_) {
      return segment;
    }
  }
}

class WebDavConfigException implements Exception {
  const WebDavConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode, this.uri});

  final String message;
  final int? statusCode;
  final Uri? uri;

  bool get isUnauthorized =>
      statusCode == HttpStatus.unauthorized ||
      statusCode == HttpStatus.forbidden;

  bool get isNotFound => statusCode == HttpStatus.notFound;

  bool get isInsufficientStorage => statusCode == 507;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    final target = uri == null ? '' : ' ${uri.toString()}';
    return '$message$status$target';
  }
}

class WebDavBackupEntry {
  const WebDavBackupEntry({
    required this.fileName,
    required this.remotePath,
    required this.size,
    required this.createdAt,
    this.updatedAt,
    this.etag,
  });

  factory WebDavBackupEntry.fromJson(Map<String, Object?> json) {
    final fileName = json['fileName']?.toString().trim() ?? '';
    final remotePath =
        (json['path'] ?? json['remotePath'])?.toString().trim() ?? '';
    if (fileName.isEmpty || remotePath.isEmpty) {
      throw const FormatException('WebDAV 备份条目缺少文件名或路径');
    }
    return WebDavBackupEntry(
      fileName: fileName,
      remotePath: remotePath,
      size: _parseInt(json['size']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      etag: _normalizeOptionalString(json['etag']),
    );
  }

  factory WebDavBackupEntry.fromRemoteFile(WebDavRemoteFile file) {
    final inferredTime = WebDavManifest.inferCreatedAtFromFileName(
      file.fileName,
    );
    return WebDavBackupEntry(
      fileName: file.fileName,
      remotePath: file.path,
      size: file.size,
      createdAt: inferredTime ?? file.lastModified,
      updatedAt: file.lastModified,
      etag: file.etag,
    );
  }

  final String fileName;
  final String remotePath;
  final int? size;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? etag;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fileName': fileName,
      'path': remotePath,
      if (size != null) 'size': size,
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      if (etag != null) 'etag': etag,
    };
  }

  WebDavBackupEntry mergeManifest(WebDavBackupEntry manifestEntry) {
    return WebDavBackupEntry(
      fileName: fileName,
      remotePath: remotePath,
      size: size ?? manifestEntry.size,
      createdAt: manifestEntry.createdAt ?? createdAt,
      updatedAt: updatedAt ?? manifestEntry.updatedAt,
      etag: etag ?? manifestEntry.etag,
    );
  }
}

class WebDavRemoteFile {
  const WebDavRemoteFile({
    required this.path,
    required this.fileName,
    required this.isDirectory,
    this.size,
    this.lastModified,
    this.etag,
  });

  final String path;
  final String fileName;
  final bool isDirectory;
  final int? size;
  final DateTime? lastModified;
  final String? etag;
}

class WebDavManifest {
  const WebDavManifest({
    required this.updatedAt,
    required this.backups,
    this.formatVersion = 1,
  });

  factory WebDavManifest.empty() {
    return WebDavManifest(updatedAt: DateTime.now().toUtc(), backups: const []);
  }

  factory WebDavManifest.fromJson(Map<String, Object?> json) {
    final rawBackups = json['backups'];
    final backups = <WebDavBackupEntry>[];
    if (rawBackups is List) {
      for (final rawBackup in rawBackups) {
        if (rawBackup is! Map) {
          continue;
        }
        try {
          backups.add(
            WebDavBackupEntry.fromJson(rawBackup.cast<String, Object?>()),
          );
        } catch (_) {
          // manifest 来自用户 NAS，坏条目不能阻断其他可用备份展示。
        }
      }
    }
    return WebDavManifest(
      formatVersion: _parseInt(json['formatVersion']) ?? 1,
      updatedAt: _parseDateTime(json['updatedAt']),
      backups: sortedBackups(backups),
    );
  }

  factory WebDavManifest.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('WebDAV manifest 格式错误');
    }
    return WebDavManifest.fromJson(decoded.cast<String, Object?>());
  }

  final int formatVersion;
  final DateTime? updatedAt;
  final List<WebDavBackupEntry> backups;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'formatVersion': formatVersion,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'backups': sortedBackups(
        backups,
      ).map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  String encode() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  WebDavManifest upsertBackup(WebDavBackupEntry entry) {
    final entries = <String, WebDavBackupEntry>{
      for (final backup in backups) backup.fileName: backup,
      entry.fileName: entry,
    };
    return WebDavManifest(
      updatedAt: DateTime.now().toUtc(),
      backups: sortedBackups(entries.values),
    );
  }

  WebDavManifest removeBackup(String fileName) {
    return WebDavManifest(
      updatedAt: DateTime.now().toUtc(),
      backups: sortedBackups(
        backups.where((entry) => entry.fileName != fileName),
      ),
    );
  }

  static List<WebDavBackupEntry> sortedBackups(
    Iterable<WebDavBackupEntry> entries,
  ) {
    final copied = entries.toList(growable: false);
    copied.sort((a, b) {
      final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = timeB.compareTo(timeA);
      if (byTime != 0) {
        return byTime;
      }
      return b.fileName.compareTo(a.fileName);
    });
    return copied;
  }

  static DateTime? inferCreatedAtFromFileName(String fileName) {
    final match = RegExp(
      r'jotsy_backup_(\d{8})_(\d{6})\.zip$',
    ).firstMatch(fileName);
    if (match == null) {
      return null;
    }
    final date = match.group(1)!;
    final time = match.group(2)!;
    return DateTime.tryParse(
      '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}T'
      '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}',
    );
  }
}

String buildWebDavBackupFileName(DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = now.toLocal();
  return 'jotsy_backup_'
      '${local.year}${two(local.month)}${two(local.day)}_'
      '${two(local.hour)}${two(local.minute)}${two(local.second)}.zip';
}

String webDavManifestFileName() => 'manifest.json';

String joinWebDavRemotePath(String directory, String fileName) {
  final normalizedDirectory = WebDavConfig.normalizeRemoteDirectory(directory);
  final sanitizedFileName = p.url.basename(fileName.trim());
  if (sanitizedFileName.isEmpty ||
      sanitizedFileName == '.' ||
      sanitizedFileName == '/') {
    throw const WebDavConfigException('WebDAV 文件名不能为空');
  }
  return '$normalizedDirectory$sanitizedFileName';
}

int? _parseInt(Object? value) {
  return switch (value) {
    int raw => raw,
    num raw => raw.toInt(),
    String raw => int.tryParse(raw.trim()),
    _ => null,
  };
}

DateTime? _parseDateTime(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String? _normalizeOptionalString(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}
