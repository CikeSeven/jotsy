import 'dart:io';

import 'cloud_backup_app_keys.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// 阿里云盘：授权码（`redirect_uri=oob`，在系统浏览器授权后粘贴授权码）+
/// 开放平台 openFile 接口。
///
/// - 未配置 App Secret 时走 PKCE 公开客户端：只发 30 天访问令牌、没有刷新
///   令牌，到期后提示重新授权；配置了 Secret 则刷新令牌 90 天且每次轮换；
/// - 备份放在 `default_drive_id` 下：授权时用户选了文件夹（文件夹级授权）
///   就用它，否则在根目录建 `Jotsy` 文件夹；
/// - 分片上传：`openFile/create` 拿每片的预签名地址（1 小时有效，传得久时用
///   `getUploadUrl` 续取），PUT 原始字节且不能带 Content-Type，全部完成后
///   `openFile/complete`；不支持覆盖，同名时自动重命名；
/// - 删除放入阿里云盘回收站。
class AliyunDriveProvider extends CloudDriveProvider {
  AliyunDriveProvider({String? clientId, String? clientSecret, Uri? apiBase})
    : _clientId = clientId ?? CloudBackupAppKeys.aliyunClientId,
      _clientSecret = clientSecret ?? CloudBackupAppKeys.aliyunClientSecret,
      _apiBase = apiBase ?? Uri.parse('https://openapi.alipan.com/');

  static const scope = 'user:base,file:all:read,file:all:write';

  final String _clientId;
  final String _clientSecret;
  final Uri _apiBase;

  bool get _hasSecret => _clientSecret.isNotEmpty;

  @override
  CloudBackupKind get kind => CloudBackupKind.aliyunDrive;

  @override
  bool get isAvailable => _clientId.isNotEmpty;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) {
    final pkce = _hasSecret ? null : CloudPkce.generate();
    return CloudCodePasteAuthorization(
      authorizeUri: _apiBase
          .resolve('oauth/authorize')
          .replace(
            queryParameters: {
              'client_id': _clientId,
              'redirect_uri': 'oob',
              'scope': scope,
              'response_type': 'code',
              'state': 'jotsy',
              if (pkce != null) ...{
                'code_challenge': pkce.challenge,
                'code_challenge_method': 'S256',
              },
            },
          ),
      exchange: (code) => _token(
        {
          'grant_type': 'authorization_code',
          'code': code.trim(),
          if (pkce != null) 'code_verifier': pkce.verifier,
        },
        http,
        exchanging: true,
      ),
    );
  }

  @override
  Future<CloudOAuthToken> refresh(CloudBackupHttp http, CloudOAuthToken token) {
    return _token(
      {'grant_type': 'refresh_token', 'refresh_token': token.refreshToken!},
      http,
      previousRefreshToken: token.refreshToken,
    );
  }

  @override
  Future<String?> fetchAccount(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) async {
    final response = await sendAuthorized(
      session,
      (auth) =>
          http.send('GET', _apiBase.resolve('oauth/users/info'), headers: auth),
    );
    if (!response.isSuccess) return null;
    return jsonString(response.jsonObject['name']);
  }

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) => AliyunDriveRemote(http: http, session: session, apiBase: _apiBase);

  /// 令牌端点（JSON 请求体）。错误以 `{code, message}` 返回：换授权码时
  /// 授权码无效/过期提示重新获取；刷新时令牌失效提示重新授权。
  Future<CloudOAuthToken> _token(
    Map<String, String> fields,
    CloudBackupHttp http, {
    bool exchanging = false,
    String? previousRefreshToken,
  }) async {
    final response = await http
        .sendJson('POST', _apiBase.resolve('oauth/access_token'), {
          'client_id': _clientId,
          if (_hasSecret) 'client_secret': _clientSecret,
          ...fields,
        });
    if (!response.isSuccess) {
      final code = jsonString(response.jsonObject['code']) ?? '';
      final failure = switch (code) {
        _ when code.contains('Code') && exchanging =>
          CloudBackupFailure.authorizationExpired,
        _ when code.contains('RefreshToken') || code.contains('Grant') =>
          CloudBackupFailure.sessionExpired,
        _ when code.contains('Client') || code.contains('App') =>
          CloudBackupFailure.appKeyMissing,
        _ when response.statusCode == 429 => CloudBackupFailure.rateLimited,
        _ when response.statusCode >= 500 => CloudBackupFailure.network,
        _ =>
          exchanging
              ? CloudBackupFailure.authorizationExpired
              : CloudBackupFailure.sessionExpired,
      };
      throw CloudBackupException(failure, code, response.statusCode);
    }
    return CloudOAuthToken.fromResponse(
      response.requireJsonObject(),
      previousRefreshToken: previousRefreshToken,
    );
  }
}

class AliyunDriveRemote implements CloudBackupRemote {
  AliyunDriveRemote({
    required this._http,
    required this._session,
    required this._apiBase,
    this.partSize = 16 * 1024 * 1024,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const folderName = 'Jotsy';

  final CloudBackupHttp _http;
  final CloudOAuthSession _session;
  final Uri _apiBase;
  final DateTime Function() _clock;

  /// 分片大小（单片 100 KB–5 GB，最多 10000 片）。
  final int partSize;

  String? _driveId;
  String? _folderId;

  @override
  Future<void> prepare() => _folder();

  @override
  Future<List<CloudBackupEntry>> list() async {
    final (driveId, folderId) = await _folder();
    final entries = <CloudBackupEntry>[];
    String? marker;
    do {
      final json = await _call('adrive/v1.0/openFile/list', {
        'drive_id': driveId,
        'parent_file_id': folderId,
        'limit': 100,
        'marker': ?marker,
      });
      for (final item in (json['items'] as List?) ?? const []) {
        if (item is! Map || item['type'] != 'file') continue;
        final id = jsonString(item['file_id']);
        final name = jsonString(item['name']);
        if (id == null || name == null || !isCloudBackupFileName(name)) {
          continue;
        }
        final modified = jsonDateTime(item['updated_at']);
        entries.add(
          CloudBackupEntry(
            fileName: name,
            remoteId: id,
            size: jsonInt(item['size']),
            createdAt:
                cloudBackupCreatedAtFromFileName(name) ??
                jsonDateTime(item['created_at']) ??
                modified,
            updatedAt: modified,
          ),
        );
      }
      marker = jsonString(json['next_marker']);
    } while (marker != null);
    return sortCloudBackups(entries);
  }

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) async {
    final (driveId, folderId) = await _folder();
    final length = await file.length();
    final partCount = length == 0 ? 1 : (length + partSize - 1) ~/ partSize;
    if (partCount > 10000) {
      throw const CloudBackupException(CloudBackupFailure.fileTooLarge);
    }
    final created = await _call('adrive/v1.0/openFile/create', {
      'drive_id': driveId,
      'parent_file_id': folderId,
      'name': fileName,
      'type': 'file',
      'check_name_mode': 'auto_rename',
      'size': length,
      'part_info_list': [
        for (var part = 1; part <= partCount; part++) {'part_number': part},
      ],
    });
    final fileId = jsonString(created['file_id']);
    final uploadId = jsonString(created['upload_id']);
    if (fileId == null) {
      throw const CloudBackupException(CloudBackupFailure.protocol, 'file_id');
    }
    // 秒传命中时服务端已有相同内容，无需上传分片。
    if (created['rapid_upload'] != true) {
      if (uploadId == null) {
        throw const CloudBackupException(
          CloudBackupFailure.protocol,
          'upload_id',
        );
      }
      var urls = _uploadUrls(created);
      var fetchedAt = _clock();
      for (var part = 1; part <= partCount; part++) {
        // 预签名地址 1 小时有效，提前 10 分钟为剩余分片续取。
        if (_clock().difference(fetchedAt) > const Duration(minutes: 50) ||
            urls[part] == null) {
          urls = _uploadUrls(
            await _call('adrive/v1.0/openFile/getUploadUrl', {
              'drive_id': driveId,
              'file_id': fileId,
              'upload_id': uploadId,
              'part_info_list': [
                for (var next = part; next <= partCount; next++)
                  {'part_number': next},
              ],
            }),
          );
          fetchedAt = _clock();
        }
        final url = urls[part];
        if (url == null) {
          throw const CloudBackupException(
            CloudBackupFailure.protocol,
            'upload_url',
          );
        }
        final start = (part - 1) * partSize;
        final end = start + partSize < length ? start + partSize : length;
        final response = await _http.upload(
          'PUT',
          url,
          body: fileRangeStream(
            file,
            start: start,
            end: end,
            onProgress: onProgress,
            total: length,
          ),
          length: end - start,
        );
        // 409 表示该分片已上传过（重试时），视为成功。
        if (!response.isSuccess && response.statusCode != HttpStatus.conflict) {
          _throwForCode(response);
        }
      }
      await _call('adrive/v1.0/openFile/complete', {
        'drive_id': driveId,
        'file_id': fileId,
        'upload_id': uploadId,
      });
    }
    return CloudBackupEntry(
      fileName: jsonString(created['file_name']) ?? fileName,
      remoteId: fileId,
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
    final (driveId, _) = await _folder();
    final json = await _call('adrive/v1.0/openFile/getDownloadUrl', {
      'drive_id': driveId,
      'file_id': entry.remoteId,
      'expire_sec': 900,
    });
    final url = Uri.tryParse(jsonString(json['url']) ?? '');
    if (url == null || !url.hasScheme) {
      throw const CloudBackupException(CloudBackupFailure.protocol, 'url');
    }
    final response = await _http.download(url, target, onProgress: onProgress);
    if (!response.isSuccess) _throwForCode(response);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    final (driveId, _) = await _folder();
    try {
      await _call('adrive/v1.0/openFile/recyclebin/trash', {
        'drive_id': driveId,
        'file_id': entry.remoteId,
      });
    } on CloudBackupException catch (error) {
      if (error.failure != CloudBackupFailure.notFound) rethrow;
    }
  }

  @override
  void close() => _http.close();

  /// 备份所在的 drive 与文件夹，每个客户端实例只查询一次。
  Future<(String, String)> _folder() async {
    final cachedDrive = _driveId;
    final cachedFolder = _folderId;
    if (cachedDrive != null && cachedFolder != null) {
      return (cachedDrive, cachedFolder);
    }
    final info = await _call('adrive/v1.0/user/getDriveInfo', const {});
    final driveId = jsonString(info['default_drive_id']);
    if (driveId == null) {
      throw const CloudBackupException(CloudBackupFailure.protocol, 'drive_id');
    }
    var folderId = jsonString(info['folder_id']);
    if (folderId == null) {
      try {
        final found = await _call('adrive/v1.0/openFile/get_by_path', {
          'drive_id': driveId,
          'file_path': '/$folderName',
        });
        folderId = jsonString(found['file_id']);
      } on CloudBackupException catch (error) {
        if (error.failure != CloudBackupFailure.notFound) rethrow;
      }
    }
    if (folderId == null) {
      final created = await _call('adrive/v1.0/openFile/create', {
        'drive_id': driveId,
        'parent_file_id': 'root',
        'name': folderName,
        'type': 'folder',
        'check_name_mode': 'refuse',
      });
      folderId = jsonString(created['file_id']);
    }
    if (folderId == null) {
      throw const CloudBackupException(CloudBackupFailure.protocol, 'folder');
    }
    _driveId = driveId;
    _folderId = folderId;
    return (driveId, folderId);
  }

  Future<Map<String, Object?>> _call(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await sendAuthorized(
      _session,
      (auth) =>
          _http.sendJson('POST', _apiBase.resolve(path), body, headers: auth),
    );
    if (!response.isSuccess) _throwForCode(response);
    return response.jsonObject;
  }

  static Map<int, Uri> _uploadUrls(Map<String, Object?> json) {
    final urls = <int, Uri>{};
    for (final part in (json['part_info_list'] as List?) ?? const []) {
      if (part is! Map) continue;
      final number = jsonInt(part['part_number']);
      final url = Uri.tryParse(jsonString(part['upload_url']) ?? '');
      if (number != null && url != null && url.hasScheme) urls[number] = url;
    }
    return urls;
  }

  /// 阿里云盘错误体：`{"code":"QuotaExhausted.Drive","message":...}`。
  static Never _throwForCode(CloudHttpResponse response) {
    final code = jsonString(response.jsonObject['code']) ?? '';
    final failure = switch (code) {
      _ when code.startsWith('QuotaExhausted') =>
        CloudBackupFailure.storageFull,
      _ when code.startsWith('NotFound') => CloudBackupFailure.notFound,
      'TooManyRequests' => CloudBackupFailure.rateLimited,
      'AccessTokenExpired' ||
      'AccessTokenInvalid' => CloudBackupFailure.sessionExpired,
      'PermissionDenied' ||
      'UserNotAllowedAccessDrive' ||
      'ForbiddenNoPermission' => CloudBackupFailure.unauthorized,
      _ => null,
    };
    if (failure != null) {
      throw CloudBackupException(failure, code, response.statusCode);
    }
    throw CloudBackupException.forStatus(
      response.statusCode,
      code.isEmpty ? null : code,
    );
  }
}
