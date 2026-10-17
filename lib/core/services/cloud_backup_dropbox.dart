import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'cloud_backup_app_keys.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// Dropbox：PKCE 授权码（粘贴回应用）+ Dropbox API v2。
///
/// - 授权页必须在系统浏览器打开（Dropbox 禁止内嵌网页，Google 账号也无法
///   在网页视图里登录）；不带 redirect_uri 时 Dropbox 直接把授权码显示给
///   用户，因此不需要回调地址或深链接；
/// - 应用使用“App folder”权限：路径相对于 `应用/<应用名>/`，根目录是空串；
/// - 刷新令牌长期有效、刷新时不轮换；
/// - 不超过 [singleUploadLimit] 的备份一次上传，更大的走上传会话。
class DropboxProvider extends CloudDriveProvider {
  DropboxProvider({
    String? appKey,
    Uri? authorizeBase,
    Uri? apiBase,
    Uri? contentBase,
  }) : _appKey = appKey ?? CloudBackupAppKeys.dropboxAppKey,
       _authorizeBase =
           authorizeBase ??
           Uri.parse('https://www.dropbox.com/oauth2/authorize'),
       _apiBase = apiBase ?? Uri.parse('https://api.dropboxapi.com/'),
       _contentBase =
           contentBase ?? Uri.parse('https://content.dropboxapi.com/');

  final String _appKey;
  final Uri _authorizeBase;
  final Uri _apiBase;
  final Uri _contentBase;

  @override
  CloudBackupKind get kind => CloudBackupKind.dropbox;

  @override
  bool get isAvailable => _appKey.isNotEmpty;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) {
    final pkce = CloudPkce.generate();
    return CloudCodePasteAuthorization(
      authorizeUri: _authorizeBase.replace(
        queryParameters: {
          'client_id': _appKey,
          'response_type': 'code',
          'token_access_type': 'offline',
          'code_challenge': pkce.challenge,
          'code_challenge_method': 'S256',
        },
      ),
      exchange: (code) async {
        final response = await http.sendForm(_apiBase.resolve('oauth2/token'), {
          'code': code.trim(),
          'grant_type': 'authorization_code',
          'code_verifier': pkce.verifier,
          'client_id': _appKey,
        });
        if (!response.isSuccess) {
          // 授权码粘贴错误或已过期时是 invalid_grant，提示重新获取授权码，
          // 而不是“授权已失效”。
          if (jsonString(response.jsonObject['error']) == 'invalid_grant') {
            throw CloudBackupException(
              CloudBackupFailure.authorizationExpired,
              'invalid_grant',
              response.statusCode,
            );
          }
          throwTokenError(response);
        }
        return CloudOAuthToken.fromResponse(response.requireJsonObject());
      },
    );
  }

  @override
  Future<CloudOAuthToken> refresh(CloudBackupHttp http, CloudOAuthToken token) {
    return refreshWithForm(http, _apiBase.resolve('oauth2/token'), token, {
      'client_id': _appKey,
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
        'POST',
        _apiBase.resolve('2/users/get_current_account'),
        headers: auth,
      ),
    );
    if (!response.isSuccess) return null;
    final json = response.jsonObject;
    final name = json['name'];
    return jsonString(json['email']) ??
        (name is Map ? jsonString(name['display_name']) : null);
  }

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) {
    return DropboxRemote(
      http: http,
      session: session,
      apiBase: _apiBase,
      contentBase: _contentBase,
    );
  }
}

class DropboxRemote implements CloudBackupRemote {
  DropboxRemote({
    required this._http,
    required this._session,
    required this._apiBase,
    required this._contentBase,
    this.singleUploadLimit = 140 * 1024 * 1024,
    this.chunkSize = 32 * 1024 * 1024,
  });

  final CloudBackupHttp _http;
  final CloudOAuthSession _session;
  final Uri _apiBase;
  final Uri _contentBase;

  /// 单次上传上限 150 MiB，留出余量。
  final int singleUploadLimit;

  /// 上传会话的分片（4 MiB 的整数倍，单次不超过 150 MiB）。
  final int chunkSize;

  @override
  Future<void> prepare() async {
    final response = await _rpc('2/files/list_folder', {
      'path': '',
      'limit': 1,
    });
    _ensureSuccess(response);
  }

  @override
  Future<List<CloudBackupEntry>> list() async {
    final entries = <CloudBackupEntry>[];
    var response = await _rpc('2/files/list_folder', {'path': ''});
    while (true) {
      _ensureSuccess(response);
      final json = response.requireJsonObject();
      for (final item in (json['entries'] as List?) ?? const []) {
        if (item is! Map || item['.tag'] != 'file') continue;
        final name = jsonString(item['name']);
        final path = jsonString(item['path_lower']) ?? jsonString(item['id']);
        if (name == null || path == null || !isCloudBackupFileName(name)) {
          continue;
        }
        final modified = jsonDateTime(item['server_modified']);
        entries.add(
          CloudBackupEntry(
            fileName: name,
            remoteId: path,
            size: jsonInt(item['size']),
            createdAt: cloudBackupCreatedAtFromFileName(name) ?? modified,
            updatedAt: modified,
          ),
        );
      }
      final cursor = jsonString(json['cursor']);
      if (json['has_more'] != true || cursor == null) break;
      response = await _rpc('2/files/list_folder/continue', {'cursor': cursor});
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
    final path = '/$fileName';
    final commit = {
      'path': path,
      'mode': 'overwrite',
      'autorename': false,
      'mute': true,
    };
    CloudHttpResponse result;
    if (length <= singleUploadLimit) {
      result = await _content(
        '2/files/upload',
        commit,
        fileRangeStream(file, onProgress: onProgress, total: length),
        length,
      );
    } else {
      Stream<List<int>> chunk(int start, int end) => fileRangeStream(
        file,
        start: start,
        end: end,
        onProgress: onProgress,
        total: length,
      );
      final firstEnd = min(chunkSize, length);
      final started = await _content(
        '2/files/upload_session/start',
        {'close': false},
        chunk(0, firstEnd),
        firstEnd,
      );
      _ensureSuccess(started);
      final sessionId = jsonString(started.requireJsonObject()['session_id']);
      if (sessionId == null) {
        throw const CloudBackupException(
          CloudBackupFailure.protocol,
          'session_id',
        );
      }
      var offset = firstEnd;
      // 最后一片随 finish 一起发送，中间的分片经 append_v2。
      while (length - offset > chunkSize) {
        final end = offset + chunkSize;
        final appended = await _content(
          '2/files/upload_session/append_v2',
          {
            'cursor': {'session_id': sessionId, 'offset': offset},
            'close': false,
          },
          chunk(offset, end),
          chunkSize,
        );
        _ensureSuccess(appended);
        offset = end;
      }
      result = await _content(
        '2/files/upload_session/finish',
        {
          'cursor': {'session_id': sessionId, 'offset': offset},
          'commit': commit,
        },
        chunk(offset, length),
        length - offset,
      );
    }
    _ensureSuccess(result);
    final json = result.requireJsonObject();
    return CloudBackupEntry(
      fileName: fileName,
      remoteId: jsonString(json['path_lower']) ?? path.toLowerCase(),
      size: jsonInt(json['size']) ?? length,
      createdAt: cloudBackupCreatedAtFromFileName(fileName),
      updatedAt: jsonDateTime(json['server_modified']),
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
        _contentBase.resolve('2/files/download'),
        target,
        method: 'POST',
        headers: {
          ...auth,
          'Dropbox-API-Arg': dropboxApiArg({'path': entry.remoteId}),
        },
        onProgress: onProgress,
      ),
    );
    _ensureSuccess(response);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    final response = await _rpc('2/files/delete_v2', {'path': entry.remoteId});
    if (response.statusCode == 409 &&
        _summary(response).contains('not_found')) {
      return;
    }
    _ensureSuccess(response);
  }

  @override
  void close() => _http.close();

  Future<CloudHttpResponse> _rpc(String endpoint, Map<String, Object?> args) {
    return sendAuthorized(
      _session,
      (auth) => _http.sendJson(
        'POST',
        _apiBase.resolve(endpoint),
        args,
        headers: auth,
      ),
    );
  }

  /// 内容上传接口：参数放在 `Dropbox-API-Arg` 头，请求体是文件内容。流不能
  /// 重放，所以先确保令牌新鲜，不走 401 自动重试。
  Future<CloudHttpResponse> _content(
    String endpoint,
    Map<String, Object?> args,
    Stream<List<int>> body,
    int length,
  ) async {
    final accessToken = await _session.accessToken();
    return _http.upload(
      'POST',
      _contentBase.resolve(endpoint),
      body: body,
      length: length,
      headers: {
        'Authorization': 'Bearer $accessToken',
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
        'Dropbox-API-Arg': dropboxApiArg(args),
      },
    );
  }

  static String _summary(CloudHttpResponse response) =>
      jsonString(response.jsonObject['error_summary']) ?? '';

  /// 409 的 `error_summary` 末尾会附加随机个数的 `.`，只能按前缀/包含匹配。
  static void _ensureSuccess(CloudHttpResponse response) {
    if (response.isSuccess) return;
    final summary = _summary(response);
    final failure = switch (response.statusCode) {
      HttpStatus.tooManyRequests => CloudBackupFailure.rateLimited,
      409 when summary.contains('insufficient_space') =>
        CloudBackupFailure.storageFull,
      409 when summary.contains('not_found') => CloudBackupFailure.notFound,
      409 when summary.contains('too_large') => CloudBackupFailure.fileTooLarge,
      409 when summary.contains('too_many_write_operations') =>
        CloudBackupFailure.rateLimited,
      409 when summary.contains('no_write_permission') =>
        CloudBackupFailure.unauthorized,
      409 => CloudBackupFailure.protocol,
      _ => null,
    };
    if (failure != null) {
      throw CloudBackupException(failure, summary, response.statusCode);
    }
    throw CloudBackupException.forStatus(response.statusCode, summary);
  }
}

/// `Dropbox-API-Arg` 头的 JSON：HTTP 头只能是 ASCII，非 ASCII 字符与 0x7F
/// 必须写成 `\uXXXX`（jsonEncode 默认不转义）。
String dropboxApiArg(Map<String, Object?> args) {
  final buffer = StringBuffer();
  for (final unit in jsonEncode(args).codeUnits) {
    if (unit >= 0x7F) {
      buffer.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}
