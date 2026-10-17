import 'dart:io';

import 'cloud_backup_app_keys.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_google_native.dart';
import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// Google Drive：授权 + Drive v3。
///
/// - 授权两条路径：装有 Google Play 服务的 Android 手机经系统账号选择器
///   授权（[GoogleDriveNativeAuth]，需 Android + Web 客户端），否则用设备码
///   （“电视和受限输入设备”客户端）；两者都配置时先试系统授权，不可用时
///   界面自动回落到设备码；
/// - 权限只申请 `drive.file`：应用只能看到自己创建的文件与文件夹，不读取
///   用户网盘里的其他内容（非敏感权限，只需基础的应用验证）；
/// - 备份放在网盘根目录的 `Jotsy` 文件夹，首次使用时创建；
/// - 上传用可续传会话：先创建会话拿 `Location`，再一次 PUT 整个文件；
/// - Google 不允许在内嵌网页中登录，所以不用网页视图。
/// 注意：OAuth 同意屏幕处于“测试”状态时刷新令牌 7 天过期，正式发布前需
/// 切到“正式版”。
class GoogleDriveProvider extends CloudDriveProvider {
  GoogleDriveProvider({
    String? clientId,
    String? clientSecret,
    Uri? oauthBase,
    Uri? apiBase,
    Uri? uploadBase,
    GoogleDriveNativeAuth? nativeAuth,
  }) : _nativeAuth = nativeAuth ?? PlayServicesGoogleDriveAuth(),
       _clientId = clientId ?? CloudBackupAppKeys.googleClientId,
       _clientSecret = clientSecret ?? CloudBackupAppKeys.googleClientSecret,
       _oauthBase = oauthBase ?? Uri.parse('https://oauth2.googleapis.com/'),
       _apiBase = apiBase ?? Uri.parse('https://www.googleapis.com/drive/v3/'),
       _uploadBase =
           uploadBase ??
           Uri.parse('https://www.googleapis.com/upload/drive/v3/');

  static const scope = 'https://www.googleapis.com/auth/drive.file';

  final GoogleDriveNativeAuth _nativeAuth;
  final String _clientId;
  final String _clientSecret;
  final Uri _oauthBase;
  final Uri _apiBase;
  final Uri _uploadBase;

  @override
  CloudBackupKind get kind => CloudBackupKind.googleDrive;

  @override
  bool get isAvailable => _deviceCodeConfigured || _nativeAuth.isSupported;

  bool get _deviceCodeConfigured =>
      _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) {
    final deviceCode = _deviceCodeConfigured ? _deviceCode(http) : null;
    if (!_nativeAuth.isSupported) return deviceCode!;
    return CloudNativeAuthorization(
      authorize: () => _nativeAuth.authorize(const [scope]),
      fallback: deviceCode,
    );
  }

  CloudDeviceCodeAuthorization _deviceCode(CloudBackupHttp http) {
    return CloudDeviceCodeAuthorization(
      start: () async {
        final response = await http.sendForm(
          _oauthBase.resolve('device/code'),
          {'client_id': _clientId, 'scope': scope},
        );
        if (!response.isSuccess) throwTokenError(response);
        return CloudDeviceAuthorization.fromResponse(
          response.requireJsonObject(),
        );
      },
      poll: (authorization) =>
          pollDeviceTokenWithForm(http, _oauthBase.resolve('token'), {
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'device_code': authorization.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          }),
    );
  }

  @override
  Future<CloudOAuthToken> refresh(CloudBackupHttp http, CloudOAuthToken token) {
    // 系统授权的令牌没有刷新令牌，向 Play 服务静默续期。
    if (token.platformManaged) {
      return _nativeAuth.refresh(token, const [scope]);
    }
    return refreshWithForm(http, _oauthBase.resolve('token'), token, {
      'client_id': _clientId,
      'client_secret': _clientSecret,
    });
  }

  @override
  Future<String?> fetchAccount(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) async {
    final response = await sendAuthorized(
      session,
      (auth) => http.send(
        'GET',
        _apiBase.resolve('about?fields=user(displayName,emailAddress)'),
        headers: auth,
      ),
    );
    if (!response.isSuccess) return null;
    final user = response.jsonObject['user'];
    if (user is! Map) return null;
    return jsonString(user['emailAddress']) ?? jsonString(user['displayName']);
  }

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) {
    return GoogleDriveRemote(
      http: http,
      session: session,
      apiBase: _apiBase,
      uploadBase: _uploadBase,
    );
  }
}

class GoogleDriveRemote implements CloudBackupRemote {
  GoogleDriveRemote({
    required this._http,
    required this._session,
    required this._apiBase,
    required this._uploadBase,
  });

  static const folderName = 'Jotsy';
  static const _folderMime = 'application/vnd.google-apps.folder';
  static const _fileFields = 'id,name,mimeType,size,createdTime,modifiedTime';

  final CloudBackupHttp _http;
  final CloudOAuthSession _session;
  final Uri _apiBase;
  final Uri _uploadBase;
  String? _folderId;

  @override
  Future<void> prepare() => _folder();

  @override
  Future<List<CloudBackupEntry>> list() async {
    final folderId = await _folder();
    final entries = <CloudBackupEntry>[];
    String? pageToken;
    do {
      final response = await _get(
        _apiBase.replace(
          path: '${_apiBase.path}files',
          queryParameters: {
            'q': "'$folderId' in parents and trashed = false",
            'fields': 'nextPageToken,files($_fileFields)',
            'pageSize': '1000',
            'pageToken': ?pageToken,
          },
        ),
      );
      final json = response.requireJsonObject();
      for (final file in (json['files'] as List?) ?? const []) {
        if (file is! Map) continue;
        final entry = _entry(file.cast<String, Object?>());
        if (entry != null) entries.add(entry);
      }
      pageToken = jsonString(json['nextPageToken']);
    } while (pageToken != null);
    return sortCloudBackups(entries);
  }

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) async {
    final folderId = await _folder();
    final length = await file.length();
    final created = await sendAuthorized(
      _session,
      (auth) => _http.sendJson(
        'POST',
        _uploadBase.replace(
          path: '${_uploadBase.path}files',
          queryParameters: {'uploadType': 'resumable', 'fields': _fileFields},
        ),
        {
          'name': fileName,
          'parents': [folderId],
        },
        headers: {
          ...auth,
          'X-Upload-Content-Type': 'application/zip',
          'X-Upload-Content-Length': '$length',
        },
      ),
    );
    _ensureSuccess(created);
    final location = Uri.tryParse(created.headers.value('location') ?? '');
    if (location == null || !location.hasScheme) {
      throw const CloudBackupException(
        CloudBackupFailure.protocol,
        'resumable session without Location',
      );
    }
    final accessToken = await _session.accessToken();
    final response = await _http.upload(
      'PUT',
      location,
      body: fileRangeStream(file, onProgress: onProgress, total: length),
      length: length,
      headers: {
        'Authorization': 'Bearer $accessToken',
        HttpHeaders.contentTypeHeader: 'application/zip',
      },
    );
    _ensureSuccess(response);
    return _entry(response.requireJsonObject()) ??
        CloudBackupEntry(
          fileName: fileName,
          remoteId: jsonString(response.jsonObject['id']) ?? '',
          size: length,
          createdAt: cloudBackupCreatedAtFromFileName(fileName),
        );
  }

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) async {
    final response = await sendAuthorized(
      _session,
      (auth) => _http.download(
        _fileUri(entry.remoteId, {'alt': 'media'}),
        target,
        headers: auth,
        onProgress: onProgress,
      ),
    );
    _ensureSuccess(response);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    final response = await sendAuthorized(
      _session,
      (auth) => _http.send('DELETE', _fileUri(entry.remoteId), headers: auth),
    );
    if (response.statusCode == HttpStatus.notFound) return;
    _ensureSuccess(response);
  }

  @override
  void close() => _http.close();

  /// 找到（或创建）根目录下的 Jotsy 文件夹；`drive.file` 下只能看到应用自己
  /// 创建的文件夹，多个同名时取最早创建的那个。
  Future<String> _folder() async {
    final cached = _folderId;
    if (cached != null) return cached;
    final found = await _get(
      _apiBase.replace(
        path: '${_apiBase.path}files',
        queryParameters: {
          'q':
              "name = '$folderName' and mimeType = '$_folderMime' "
              "and 'root' in parents and trashed = false",
          'fields': 'files(id)',
          'orderBy': 'createdTime',
          'pageSize': '1',
        },
      ),
    );
    final files = found.requireJsonObject()['files'];
    if (files is List && files.isNotEmpty && files.first is Map) {
      final id = jsonString((files.first as Map)['id']);
      if (id != null) return _folderId = id;
    }
    final created = await sendAuthorized(
      _session,
      (auth) => _http.sendJson(
        'POST',
        _apiBase.replace(
          path: '${_apiBase.path}files',
          queryParameters: {'fields': 'id'},
        ),
        {
          'name': folderName,
          'mimeType': _folderMime,
          'parents': ['root'],
        },
        headers: auth,
      ),
    );
    _ensureSuccess(created);
    final id = jsonString(created.requireJsonObject()['id']);
    if (id == null) {
      throw const CloudBackupException(
        CloudBackupFailure.protocol,
        'folder id',
      );
    }
    return _folderId = id;
  }

  Uri _fileUri(String id, [Map<String, String>? query]) => _apiBase.replace(
    path: '${_apiBase.path}files/${Uri.encodeComponent(id)}',
    queryParameters: query,
  );

  Future<CloudHttpResponse> _get(Uri uri) async {
    final response = await sendAuthorized(
      _session,
      (auth) => _http.send('GET', uri, headers: auth),
    );
    _ensureSuccess(response);
    return response;
  }

  static CloudBackupEntry? _entry(Map<String, Object?> file) {
    final id = jsonString(file['id']);
    final name = jsonString(file['name']);
    if (id == null ||
        name == null ||
        file['mimeType'] == _folderMime ||
        !isCloudBackupFileName(name)) {
      return null;
    }
    final modified = jsonDateTime(file['modifiedTime']);
    return CloudBackupEntry(
      fileName: name,
      remoteId: id,
      size: jsonInt(file['size']),
      createdAt:
          cloudBackupCreatedAtFromFileName(name) ??
          jsonDateTime(file['createdTime']) ??
          modified,
      updatedAt: modified,
    );
  }

  /// Google 的错误体：`{"error":{"errors":[{"reason":...}],"status":...}}`。
  static void _ensureSuccess(CloudHttpResponse response) {
    if (response.isSuccess) return;
    final error = response.jsonObject['error'];
    final reasons = <String>{};
    if (error is Map) {
      for (final item in (error['errors'] as List?) ?? const []) {
        if (item is Map && item['reason'] is String) {
          reasons.add(item['reason'] as String);
        }
      }
      if (error['status'] is String) reasons.add(error['status'] as String);
    }
    final failure = reasons.contains('storageQuotaExceeded')
        ? CloudBackupFailure.storageFull
        : reasons.any(
            (reason) =>
                reason == 'userRateLimitExceeded' ||
                reason == 'rateLimitExceeded' ||
                reason == 'RESOURCE_EXHAUSTED',
          )
        ? CloudBackupFailure.rateLimited
        : null;
    if (failure != null) {
      throw CloudBackupException(
        failure,
        reasons.join(','),
        response.statusCode,
      );
    }
    throw CloudBackupException.forStatus(
      response.statusCode,
      reasons.isEmpty ? null : reasons.join(','),
    );
  }
}
