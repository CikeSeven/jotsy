import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'cloud_backup_app_keys.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// 百度网盘：设备码授权 + xpan 开放接口。
///
/// - 设备码轮询与刷新都必须带 SecretKey（百度没有公开客户端模式），密钥
///   随安装包分发；
/// - 刷新令牌一次性：每次刷新返回新的，刷新失败旧的也随之作废，只能重新
///   授权（[CloudBackupFailure.sessionExpired]）；
/// - 只能读写应用目录 `/apps/<应用名>/`（网盘里显示为“我的应用数据”）；
/// - 上传三步：precreate（提交每个分片的 MD5）→ superfile2 逐片上传 →
///   create 合并，分片大小按会员等级取 4/16/32 MiB，最多 1024 片；
/// - 接口错误多以 HTTP 200 + `errno` 返回，令牌失效的 errno 触发一次刷新重试；
/// - 下载链接（dlink）要拼上 access_token 并带 `User-Agent: pan.baidu.com`，
///   否则被判为盗链。
/// 未经上线审核的应用最多 10 个用户、接口频控很严，正式使用前需提交审核。
class BaiduPanProvider extends CloudDriveProvider {
  BaiduPanProvider({
    String? appKey,
    String? secretKey,
    String? appDirectory,
    Uri? oauthBase,
    Uri? panBase,
    Uri? pcsBase,
  }) : _appKey = appKey ?? CloudBackupAppKeys.baiduAppKey,
       _secretKey = secretKey ?? CloudBackupAppKeys.baiduSecretKey,
       _appDirectory = appDirectory ?? CloudBackupAppKeys.baiduAppDirectory,
       _oauthBase =
           oauthBase ?? Uri.parse('https://openapi.baidu.com/oauth/2.0/'),
       _panBase = panBase ?? Uri.parse('https://pan.baidu.com/'),
       _pcsBase = pcsBase ?? Uri.parse('https://d.pcs.baidu.com/');

  final String _appKey;
  final String _secretKey;
  final String _appDirectory;
  final Uri _oauthBase;
  final Uri _panBase;
  final Uri _pcsBase;

  @override
  CloudBackupKind get kind => CloudBackupKind.baiduPan;

  @override
  bool get isAvailable => _appKey.isNotEmpty && _secretKey.isNotEmpty;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) {
    return CloudDeviceCodeAuthorization(
      start: () async {
        final response = await http.send(
          'GET',
          _oauth('device/code', {
            'response_type': 'device_code',
            'client_id': _appKey,
            'scope': 'basic,netdisk',
          }),
        );
        if (!response.isSuccess) throwTokenError(response);
        return CloudDeviceAuthorization.fromResponse(
          response.requireJsonObject(),
        );
      },
      poll: (authorization) async {
        final response = await http.send(
          'GET',
          _oauth('token', {
            'grant_type': 'device_token',
            'code': authorization.deviceCode,
            'client_id': _appKey,
            'client_secret': _secretKey,
          }),
        );
        final json = response.jsonObject;
        if (response.isSuccess && json['access_token'] != null) {
          return CloudDeviceGranted(CloudOAuthToken.fromResponse(json));
        }
        if (response.statusCode >= 500) {
          throw CloudBackupException(
            CloudBackupFailure.network,
            'device poll',
            response.statusCode,
          );
        }
        return classifyDevicePollError(
          jsonString(json['error']),
          response.statusCode,
        );
      },
    );
  }

  @override
  Future<CloudOAuthToken> refresh(
    CloudBackupHttp http,
    CloudOAuthToken token,
  ) async {
    final response = await http.send(
      'GET',
      _oauth('token', {
        'grant_type': 'refresh_token',
        'refresh_token': token.refreshToken!,
        'client_id': _appKey,
        'client_secret': _secretKey,
      }),
    );
    if (!response.isSuccess) throwTokenError(response);
    return CloudOAuthToken.fromResponse(
      response.requireJsonObject(),
      previousRefreshToken: token.refreshToken,
    );
  }

  @override
  Future<String?> fetchAccount(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) async {
    final remote = _remote(http, session);
    final json = await remote.userInfo();
    return jsonString(json['netdisk_name']) ?? jsonString(json['baidu_name']);
  }

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) => _remote(http, session);

  BaiduPanRemote _remote(CloudBackupHttp http, CloudOAuthSession session) =>
      BaiduPanRemote(
        http: http,
        session: session,
        appDirectory: _appDirectory,
        panBase: _panBase,
        pcsBase: _pcsBase,
      );

  Uri _oauth(String path, Map<String, String> query) =>
      _oauthBase.resolve(path).replace(queryParameters: query);
}

class BaiduPanRemote implements CloudBackupRemote {
  BaiduPanRemote({
    required this._http,
    required this._session,
    required String appDirectory,
    required this._panBase,
    required this._pcsBase,
  }) : _directory = '/apps/${appDirectory.trim()}';

  static const _headers = {'User-Agent': 'pan.baidu.com'};

  /// 令牌失效类 errno：-6 鉴权失败、111（旧语义）、20016 过期、20017 无效、
  /// 31045 校验失败。
  static const _tokenErrnos = {-6, 111, 20016, 20017, 31045};

  final CloudBackupHttp _http;
  final CloudOAuthSession _session;
  final String _directory;
  final Uri _panBase;
  final Uri _pcsBase;

  @override
  Future<void> prepare() async {
    await userInfo();
    await list();
  }

  Future<Map<String, Object?>> userInfo() => _api('GET', 'rest/2.0/xpan/nas', {
    'method': 'uinfo',
    'vip_version': 'v2',
  });

  @override
  Future<List<CloudBackupEntry>> list() async {
    const limit = 1000;
    final entries = <CloudBackupEntry>[];
    for (var start = 0; ; start += limit) {
      final Map<String, Object?> json;
      try {
        json = await _api('GET', 'rest/2.0/xpan/file', {
          'method': 'list',
          'dir': _directory,
          'order': 'time',
          'desc': '1',
          'start': '$start',
          'limit': '$limit',
        });
      } on CloudBackupException catch (error) {
        // 还没上传过备份时应用目录不存在。
        if (error.failure == CloudBackupFailure.notFound) break;
        rethrow;
      }
      final items = (json['list'] as List?) ?? const [];
      for (final item in items) {
        if (item is! Map || jsonInt(item['isdir']) == 1) continue;
        final name = jsonString(item['server_filename']);
        final path = jsonString(item['path']);
        final fsId = jsonInt(item['fs_id']);
        if (name == null ||
            path == null ||
            fsId == null ||
            !isCloudBackupFileName(name)) {
          continue;
        }
        final modified = _epoch(item['server_mtime']);
        entries.add(
          CloudBackupEntry(
            fileName: name,
            remoteId: encodeRemoteId(fsId, path),
            size: jsonInt(item['size']),
            createdAt:
                cloudBackupCreatedAtFromFileName(name) ??
                _epoch(item['server_ctime']) ??
                modified,
            updatedAt: modified,
          ),
        );
      }
      if (items.length < limit) break;
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
    final info = await userInfo();
    final sliceSize = switch (jsonInt(info['vip_type'])) {
      2 => 32 * 1024 * 1024,
      1 => 16 * 1024 * 1024,
      _ => 4 * 1024 * 1024,
    };
    if (length > sliceSize * 1024) {
      throw const CloudBackupException(CloudBackupFailure.fileTooLarge);
    }
    final ranges = <(int, int)>[
      for (var start = 0; start < length; start += sliceSize)
        (start, min(start + sliceSize, length)),
    ];
    final md5s = <String>[
      for (final (start, end) in ranges)
        (await md5.bind(file.openRead(start, end)).first).toString(),
    ];
    final path = '$_directory/$fileName';
    final blockList = jsonEncode(md5s);
    final created = await _api(
      'POST',
      'rest/2.0/xpan/file',
      {'method': 'precreate'},
      form: {
        'path': path,
        'size': '$length',
        'isdir': '0',
        'autoinit': '1',
        'rtype': '3',
        'block_list': blockList,
      },
    );
    final uploadId = jsonString(created['uploadid']);
    if (uploadId == null) {
      throw const CloudBackupException(CloudBackupFailure.protocol, 'uploadid');
    }
    final needed = [
      for (final index in (created['block_list'] as List?) ?? const [])
        ?jsonInt(index),
    ];
    final host = await _uploadHost(path, uploadId);
    for (final index
        in needed.isEmpty
            ? List<int>.generate(ranges.length, (i) => i)
            : needed) {
      final (start, end) = ranges[index];
      await _uploadSlice(
        host,
        path: path,
        uploadId: uploadId,
        partSeq: index,
        body: fileRangeStream(
          file,
          start: start,
          end: end,
          onProgress: onProgress,
          total: length,
        ),
        length: end - start,
      );
    }
    final result = await _api(
      'POST',
      'rest/2.0/xpan/file',
      {'method': 'create'},
      form: {
        'path': path,
        'size': '$length',
        'isdir': '0',
        'rtype': '3',
        'uploadid': uploadId,
        'block_list': blockList,
      },
    );
    final fsId = jsonInt(result['fs_id']);
    return CloudBackupEntry(
      fileName: fileName,
      remoteId: encodeRemoteId(fsId ?? 0, jsonString(result['path']) ?? path),
      size: length,
      createdAt: cloudBackupCreatedAtFromFileName(fileName),
      updatedAt: _epoch(result['mtime']),
    );
  }

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) async {
    final (fsId, _) = decodeRemoteId(entry.remoteId);
    final meta = await _api('GET', 'rest/2.0/xpan/multimedia', {
      'method': 'filemetas',
      'fsids': '[$fsId]',
      'dlink': '1',
    });
    final items = meta['list'];
    final dlink = items is List && items.isNotEmpty && items.first is Map
        ? jsonString((items.first as Map)['dlink'])
        : null;
    if (dlink == null) {
      throw const CloudBackupException(CloudBackupFailure.notFound, 'dlink');
    }
    final accessToken = await _session.accessToken();
    // dlink 已带签名参数，直接拼接，避免重新编码改动签名。
    final separator = dlink.contains('?') ? '&' : '?';
    final response = await _http.download(
      Uri.parse(
        '$dlink${separator}access_token='
        '${Uri.encodeQueryComponent(accessToken)}',
      ),
      target,
      headers: _headers,
      onProgress: onProgress,
    );
    if (!response.isSuccess) _throwForErrno(response.jsonObject, response);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    final (_, path) = decodeRemoteId(entry.remoteId);
    try {
      await _api(
        'POST',
        'rest/2.0/xpan/file',
        {'method': 'filemanager', 'opera': 'delete'},
        form: {
          'async': '0',
          'filelist': jsonEncode([path]),
        },
      );
    } on CloudBackupException catch (error) {
      if (error.failure != CloudBackupFailure.notFound) rethrow;
    }
  }

  @override
  void close() => _http.close();

  /// 文件需要 fs_id 才能取下载链接、需要路径才能删除，两者合在 remoteId 里：
  /// `<fs_id>:<path>`。
  static String encodeRemoteId(int fsId, String path) => '$fsId:$path';

  static (int, String) decodeRemoteId(String remoteId) {
    final separator = remoteId.indexOf(':');
    final fsId = separator > 0
        ? int.tryParse(remoteId.substring(0, separator))
        : null;
    if (fsId == null) {
      throw const CloudBackupException(CloudBackupFailure.notFound, 'fs_id');
    }
    return (fsId, remoteId.substring(separator + 1));
  }

  /// 调用 xpan 接口：令牌放在查询参数里，令牌失效时刷新一次再重试。
  Future<Map<String, Object?>> _api(
    String method,
    String path,
    Map<String, String> query, {
    Map<String, String>? form,
  }) async {
    Future<CloudHttpResponse> call(String token) {
      final uri = _panBase
          .resolve(path)
          .replace(queryParameters: {...query, 'access_token': token});
      return form == null
          ? _http.send(method, uri, headers: _headers)
          : _http.sendForm(uri, form, headers: _headers);
    }

    var token = await _session.accessToken();
    var response = await call(token);
    if (_isTokenRejected(response)) {
      token = await _session.refreshAfterRejection(token);
      response = await call(token);
    }
    final json = response.jsonObject;
    _throwForErrno(json, response);
    return json;
  }

  Future<Uri> _uploadHost(String path, String uploadId) async {
    try {
      final token = await _session.accessToken();
      final response = await _http.send(
        'GET',
        _pcsBase
            .resolve('rest/2.0/pcs/file')
            .replace(
              queryParameters: {
                'method': 'locateupload',
                'appid': '250528',
                'access_token': token,
                'path': path,
                'uploadid': uploadId,
                'upload_version': '2.0',
              },
            ),
        headers: _headers,
      );
      final servers = response.jsonObject['servers'];
      if (servers is List) {
        for (final server in servers) {
          final raw = server is Map ? jsonString(server['server']) : null;
          final uri = raw == null ? null : Uri.tryParse(raw);
          if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
            return uri;
          }
        }
      }
    } on CloudBackupException {
      // 取上传域名失败时退回默认域名，上传本身仍会报告真实错误。
    }
    return _pcsBase;
  }

  /// superfile2 分片上传：multipart/form-data，文件字段名 `file`。请求体是
  /// 文件流，不能重放，所以先确保令牌新鲜、不走自动重试。
  Future<void> _uploadSlice(
    Uri host, {
    required String path,
    required String uploadId,
    required int partSeq,
    required Stream<List<int>> body,
    required int length,
  }) async {
    final boundary =
        'jotsy${Random.secure().nextInt(1 << 32).toRadixString(16)}';
    final head = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; filename="part"\r\n'
      'Content-Type: application/octet-stream\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    Stream<List<int>> multipart() async* {
      yield head;
      yield* body;
      yield tail;
    }

    final token = await _session.accessToken();
    final response = await _http.upload(
      'POST',
      host
          .resolve('rest/2.0/pcs/superfile2')
          .replace(
            queryParameters: {
              'method': 'upload',
              'type': 'tmpfile',
              'access_token': token,
              'path': path,
              'uploadid': uploadId,
              'partseq': '$partSeq',
            },
          ),
      body: multipart(),
      length: head.length + length + tail.length,
      headers: {
        ..._headers,
        HttpHeaders.contentTypeHeader:
            'multipart/form-data; boundary=$boundary',
      },
    );
    _throwForErrno(response.jsonObject, response);
  }

  bool _isTokenRejected(CloudHttpResponse response) {
    if (response.statusCode == HttpStatus.unauthorized) return true;
    final json = response.jsonObject;
    final errno = jsonInt(json['errno']) ?? jsonInt(json['error_code']);
    return errno != null && _tokenErrnos.contains(errno);
  }

  /// xpan 用 `errno`，PCS 上传/下载用 `error_code`；0 或缺失表示成功。
  static void _throwForErrno(
    Map<String, Object?> json,
    CloudHttpResponse response,
  ) {
    final errno = jsonInt(json['errno']) ?? jsonInt(json['error_code']);
    if ((errno == null || errno == 0) && response.isSuccess) return;
    final failure = switch (errno) {
      -6 || 111 || 20016 || 20017 || 31045 => CloudBackupFailure.sessionExpired,
      -10 => CloudBackupFailure.storageFull,
      -9 || 31066 => CloudBackupFailure.notFound,
      31034 || 20012 => CloudBackupFailure.rateLimited,
      31064 => CloudBackupFailure.config,
      31364 || 31365 => CloudBackupFailure.fileTooLarge,
      20011 || 31326 => CloudBackupFailure.unauthorized,
      2 || 31023 => CloudBackupFailure.protocol,
      _ => null,
    };
    if (failure != null) {
      throw CloudBackupException(failure, 'errno $errno', response.statusCode);
    }
    if (!response.isSuccess) {
      throw CloudBackupException.forStatus(
        response.statusCode,
        errno == null ? null : 'errno $errno',
      );
    }
    throw CloudBackupException(
      CloudBackupFailure.protocol,
      'errno $errno',
      response.statusCode,
    );
  }

  static DateTime? _epoch(Object? seconds) {
    final value = jsonInt(seconds);
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
}
