import 'dart:io';

import 'cloud_backup_app_keys.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// OneDrive：Microsoft 身份平台设备码授权 + Microsoft Graph。
///
/// - 权限 `Files.ReadWrite.AppFolder`：只能访问应用专属文件夹
///   （`/me/drive/special/approot`，网盘里显示为“应用/<应用名>”，首次访问时
///   自动创建）；个人账号已确认可用，工作/学校账号视租户策略而定；
/// - 每次刷新都会轮换刷新令牌，新令牌由 [CloudOAuthSession] 交给调用方落盘；
/// - 上传用上传会话，分片为 320 KiB 的整数倍（10 MiB）；往会话地址 PUT 时
///   不能带 Authorization 头，否则可能被拒；
/// - 下载取文件的 `@microsoft.graph.downloadUrl`（预授权、短时有效），同样
///   不带令牌。删除的文件进入 OneDrive 回收站。
class OneDriveProvider extends CloudDriveProvider {
  OneDriveProvider({
    String? clientId,
    String? tenant,
    Uri? authorityBase,
    Uri? graphBase,
  }) : _clientId = clientId ?? CloudBackupAppKeys.microsoftClientId,
       _authority =
           authorityBase ??
           Uri.parse(
             'https://login.microsoftonline.com/'
             '${tenant ?? CloudBackupAppKeys.microsoftTenant}/oauth2/v2.0/',
           ),
       _graphBase = graphBase ?? Uri.parse('https://graph.microsoft.com/v1.0/');

  static const scope = 'Files.ReadWrite.AppFolder User.Read offline_access';

  final String _clientId;
  final Uri _authority;
  final Uri _graphBase;

  @override
  CloudBackupKind get kind => CloudBackupKind.oneDrive;

  @override
  bool get isAvailable => _clientId.isNotEmpty;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) {
    return CloudDeviceCodeAuthorization(
      start: () async {
        final response = await http.sendForm(_authority.resolve('devicecode'), {
          'client_id': _clientId,
          'scope': scope,
        });
        if (!response.isSuccess) throwTokenError(response);
        return CloudDeviceAuthorization.fromResponse(
          response.requireJsonObject(),
        );
      },
      poll: (authorization) =>
          pollDeviceTokenWithForm(http, _authority.resolve('token'), {
            'client_id': _clientId,
            'device_code': authorization.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          }),
    );
  }

  @override
  Future<CloudOAuthToken> refresh(CloudBackupHttp http, CloudOAuthToken token) {
    return refreshWithForm(http, _authority.resolve('token'), token, {
      'client_id': _clientId,
      'scope': scope,
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
        _graphBase.resolve('me?\$select=displayName,mail,userPrincipalName'),
        headers: auth,
      ),
    );
    if (!response.isSuccess) return null;
    final json = response.jsonObject;
    return jsonString(json['mail']) ??
        jsonString(json['userPrincipalName']) ??
        jsonString(json['displayName']);
  }

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) {
    return OneDriveRemote(http: http, session: session, graphBase: _graphBase);
  }
}

class OneDriveRemote implements CloudBackupRemote {
  OneDriveRemote({
    required this._http,
    required this._session,
    required this._graphBase,
    this.chunkSize = 32 * 320 * 1024,
  });

  final CloudBackupHttp _http;
  final CloudOAuthSession _session;
  final Uri _graphBase;

  /// 上传分片大小，必须是 320 KiB 的整数倍且单次小于 60 MiB。
  final int chunkSize;

  @override
  Future<void> prepare() async {
    _ensureSuccess(await _get(_graph('me/drive/special/approot?\$select=id')));
  }

  @override
  Future<List<CloudBackupEntry>> list() async {
    final entries = <CloudBackupEntry>[];
    Uri? next = _graph(
      'me/drive/special/approot/children'
      '?\$select=id,name,size,file,createdDateTime,lastModifiedDateTime'
      '&\$top=200',
    );
    while (next != null) {
      final response = await _get(next);
      _ensureSuccess(response);
      final json = response.requireJsonObject();
      for (final item in (json['value'] as List?) ?? const []) {
        if (item is! Map || item['file'] == null) continue;
        final id = jsonString(item['id']);
        final name = jsonString(item['name']);
        if (id == null || name == null || !isCloudBackupFileName(name)) {
          continue;
        }
        final modified = jsonDateTime(item['lastModifiedDateTime']);
        entries.add(
          CloudBackupEntry(
            fileName: name,
            remoteId: id,
            size: jsonInt(item['size']),
            createdAt:
                cloudBackupCreatedAtFromFileName(name) ??
                jsonDateTime(item['createdDateTime']) ??
                modified,
            updatedAt: modified,
          ),
        );
      }
      final link = jsonString(json['@odata.nextLink']);
      next = link == null ? null : Uri.tryParse(link);
    }
    return sortCloudBackups(entries);
  }

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) async {
    final length = await file.length();
    final created = await sendAuthorized(
      _session,
      (auth) => _http.sendJson(
        'POST',
        _graph(
          'me/drive/special/approot:/${Uri.encodeComponent(fileName)}'
          ':/createUploadSession',
        ),
        {
          'item': {'@microsoft.graph.conflictBehavior': 'replace'},
        },
        headers: auth,
      ),
    );
    _ensureSuccess(created);
    final uploadUrl = Uri.tryParse(
      jsonString(created.requireJsonObject()['uploadUrl']) ?? '',
    );
    if (uploadUrl == null || !uploadUrl.hasScheme) {
      throw const CloudBackupException(
        CloudBackupFailure.protocol,
        'uploadUrl',
      );
    }
    try {
      CloudHttpResponse? last;
      for (var start = 0; start < length; start += chunkSize) {
        final end = start + chunkSize < length ? start + chunkSize : length;
        last = await _http.upload(
          'PUT',
          uploadUrl,
          body: fileRangeStream(
            file,
            start: start,
            end: end,
            onProgress: onProgress,
            total: length,
          ),
          length: end - start,
          headers: {
            HttpHeaders.contentRangeHeader: 'bytes $start-${end - 1}/$length',
          },
        );
        _ensureSuccess(last);
      }
      final item = last?.jsonObject ?? const <String, Object?>{};
      return CloudBackupEntry(
        fileName: fileName,
        remoteId: jsonString(item['id']) ?? '',
        size: jsonInt(item['size']) ?? length,
        createdAt: cloudBackupCreatedAtFromFileName(fileName),
        updatedAt: jsonDateTime(item['lastModifiedDateTime']),
      );
    } catch (_) {
      try {
        await _http.send('DELETE', uploadUrl);
      } catch (_) {
        // 取消会话失败时它会自行过期，不能掩盖原始错误。
      }
      rethrow;
    }
  }

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) async {
    final meta = await _get(_item(entry.remoteId));
    _ensureSuccess(meta);
    final url = Uri.tryParse(
      jsonString(meta.requireJsonObject()['@microsoft.graph.downloadUrl']) ??
          '',
    );
    if (url == null || !url.hasScheme) {
      throw const CloudBackupException(
        CloudBackupFailure.protocol,
        'downloadUrl',
      );
    }
    final response = await _http.download(url, target, onProgress: onProgress);
    _ensureSuccess(response);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    final response = await sendAuthorized(
      _session,
      (auth) => _http.send('DELETE', _item(entry.remoteId), headers: auth),
    );
    if (response.statusCode == HttpStatus.notFound) return;
    _ensureSuccess(response);
  }

  @override
  void close() => _http.close();

  Uri _graph(String path) => _graphBase.resolve(path);

  Uri _item(String id) => _graph('me/drive/items/${Uri.encodeComponent(id)}');

  Future<CloudHttpResponse> _get(Uri uri) =>
      sendAuthorized(_session, (auth) => _http.send('GET', uri, headers: auth));

  /// Graph 错误体：`{"error":{"code":"quotaLimitReached",...}}`。
  static void _ensureSuccess(CloudHttpResponse response) {
    if (response.isSuccess) return;
    final error = response.jsonObject['error'];
    final code = error is Map ? jsonString(error['code']) : null;
    final failure = switch (code) {
      'quotaLimitReached' ||
      'insufficientStorage' => CloudBackupFailure.storageFull,
      'activityLimitReached' => CloudBackupFailure.rateLimited,
      'itemNotFound' => CloudBackupFailure.notFound,
      'accessDenied' || 'unauthenticated' => CloudBackupFailure.unauthorized,
      _ => null,
    };
    if (failure != null) {
      throw CloudBackupException(failure, code, response.statusCode);
    }
    throw CloudBackupException.forStatus(response.statusCode, code);
  }
}
