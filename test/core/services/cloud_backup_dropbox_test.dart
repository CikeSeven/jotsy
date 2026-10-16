import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_dropbox.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';

import '../../support/fake_drive_server.dart';

void main() {
  late FakeDriveServer server;
  late CloudBackupHttp http;
  late DropboxProvider provider;
  late _FakeDropbox dropbox;
  late Directory tempDir;
  late List<CloudOAuthToken> refreshed;

  setUp(() async {
    server = await FakeDriveServer.start();
    http = server.http();
    provider = DropboxProvider(
      appKey: 'key',
      authorizeBase: server.url('oauth2/authorize'),
      apiBase: server.url('api/'),
      contentBase: server.url('content/'),
    );
    dropbox = _FakeDropbox(server);
    tempDir = await Directory.systemTemp.createTemp('jotsy_dropbox_test_');
    refreshed = <CloudOAuthToken>[];
  });

  tearDown(() async {
    http.close();
    await server.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CloudOAuthSession session({String accessToken = 'a1'}) => CloudOAuthSession(
    token: CloudOAuthToken(accessToken: accessToken, refreshToken: 'r1'),
    refresh: (token) => provider.refresh(http, token),
    onRefreshed: (token) async => refreshed.add(token),
  );

  CloudBackupRemote remote() => provider.createRemote(http, session());

  /// 直接构造以便用极小的阈值触发上传会话。
  DropboxRemote sessionRemote() => DropboxRemote(
    http: http,
    session: session(),
    apiBase: server.url('api/'),
    contentBase: server.url('content/'),
    singleUploadLimit: 4,
    chunkSize: 4,
  );

  Future<File> tempFile(List<int> bytes, [String name = 'local.zip']) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  Map<String, Object?> apiArg(FakeDriveRequest request) =>
      (jsonDecode(request.headers['dropbox-api-arg']!) as Map)
          .cast<String, Object?>();

  group('authorization', () {
    test('authorize URI asks for an offline PKCE code without redirect', () {
      final authorization = provider.beginAuthorization(http);

      expect(authorization, isA<CloudCodePasteAuthorization>());
      final uri = (authorization as CloudCodePasteAuthorization).authorizeUri;
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters, {
        'client_id': 'key',
        'response_type': 'code',
        'token_access_type': 'offline',
        'code_challenge': isNotEmpty,
        'code_challenge_method': 'S256',
      });
      // 不带 redirect_uri 时 Dropbox 才会把授权码直接显示给用户。
      expect(uri.queryParameters.containsKey('redirect_uri'), isFalse);
    });

    test(
      'exchange posts the code with a verifier matching the challenge',
      () async {
        final authorization =
            provider.beginAuthorization(http) as CloudCodePasteAuthorization;
        final challenge =
            authorization.authorizeUri.queryParameters['code_challenge']!;

        final token = await authorization.exchange('  code-123  ');

        expect(token.accessToken, 'a1');
        expect(token.refreshToken, 'r1');
        expect(token.expiresAt, isNotNull);
        final form = server.received('POST', '/api/oauth2/token').single.form;
        expect(form, {
          'code': 'code-123',
          'grant_type': 'authorization_code',
          'code_verifier': isNotEmpty,
          'client_id': 'key',
        });
        final verifier = form['code_verifier']!;
        expect(verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43,128}$')));
        expect(_s256(verifier), challenge);
        expect(challenge, isNot(contains('=')));
      },
    );

    test('exchange maps invalid_grant to authorizationExpired', () async {
      final authorization =
          provider.beginAuthorization(http) as CloudCodePasteAuthorization;

      await expectLater(
        authorization.exchange('stale-code'),
        _throwsFailure(CloudBackupFailure.authorizationExpired),
      );
    });
  });

  group('remote round trip', () {
    test('prepare lists the app folder root', () async {
      await remote().prepare();

      final request = server
          .received('POST', '/api/2/files/list_folder')
          .single;
      expect(request.json, {'path': '', 'limit': 1});
      expect(request.headers['authorization'], 'Bearer a1');
    });

    test('small files go through a single overwrite upload', () async {
      final bytes = utf8.encode('backup-body');
      final file = await tempFile(bytes);
      final progress = <int>[];

      final entry = await remote().upload(
        file: file,
        fileName: 'jotsy_backup_20260101_080000.zip',
        onProgress: (sent, total) {
          progress.add(sent);
          expect(total, bytes.length);
        },
      );

      final request = server.received('POST', '/content/2/files/upload').single;
      expect(apiArg(request), {
        'path': '/jotsy_backup_20260101_080000.zip',
        'mode': 'overwrite',
        'autorename': false,
        'mute': true,
      });
      expect(request.headers['content-type'], 'application/octet-stream');
      expect(request.headers['authorization'], 'Bearer a1');
      expect(request.body, bytes);
      expect(progress.last, bytes.length);
      expect(entry.remoteId, '/jotsy_backup_20260101_080000.zip');
      expect(entry.size, bytes.length);
      expect(entry.createdAt, DateTime(2026, 1, 1, 8));
      expect(
        server.received('POST', '/content/2/files/upload_session/start'),
        isEmpty,
      );
    });

    test('large files go through start, append_v2 and finish', () async {
      final bytes = List<int>.generate(10, (index) => index + 1);
      final file = await tempFile(bytes);
      final progress = <int>[];

      final entry = await sessionRemote().upload(
        file: file,
        fileName: 'jotsy_backup_20260101_080000.zip',
        onProgress: (sent, _) => progress.add(sent),
      );

      final start = server
          .received('POST', '/content/2/files/upload_session/start')
          .single;
      final appends = server.received(
        'POST',
        '/content/2/files/upload_session/append_v2',
      );
      final finish = server
          .received('POST', '/content/2/files/upload_session/finish')
          .single;
      expect(apiArg(start), {'close': false});
      expect(appends.map(apiArg), [
        {
          'cursor': {'session_id': 'session-1', 'offset': 4},
          'close': false,
        },
      ]);
      expect(apiArg(finish), {
        'cursor': {'session_id': 'session-1', 'offset': 8},
        'commit': {
          'path': '/jotsy_backup_20260101_080000.zip',
          'mode': 'overwrite',
          'autorename': false,
          'mute': true,
        },
      });
      expect([start, ...appends, finish].map((r) => r.body.length), [4, 4, 2]);
      expect([
        for (final request in [start, ...appends, finish]) ...request.body,
      ], bytes);
      expect(progress.last, bytes.length);
      expect(dropbox.files['/jotsy_backup_20260101_080000.zip'], bytes);
      expect(entry.size, bytes.length);
      expect(server.received('POST', '/content/2/files/upload'), isEmpty);
    });

    test(
      'an exact multiple of the chunk size sends the last chunk with finish',
      () async {
        final bytes = List<int>.generate(8, (index) => 100 + index);
        final file = await tempFile(bytes);

        await sessionRemote().upload(
          file: file,
          fileName: 'jotsy_backup_20260101_080000.zip',
        );

        expect(
          server.received('POST', '/content/2/files/upload_session/append_v2'),
          isEmpty,
        );
        final finish = server
            .received('POST', '/content/2/files/upload_session/finish')
            .single;
        expect((apiArg(finish)['cursor'] as Map)['offset'], 4);
        expect(finish.body, bytes.sublist(4));
        expect(dropbox.files['/jotsy_backup_20260101_080000.zip'], bytes);
      },
    );

    test(
      'list follows the cursor, keeps only zip files and sorts newest first',
      () async {
        server.json(
          'POST',
          '/api/2/files/list_folder',
          (_) => {
            'entries': [
              {'.tag': 'folder', 'name': 'old.zip', 'path_lower': '/old.zip'},
              {
                '.tag': 'file',
                'name': 'notes.txt',
                'path_lower': '/notes.txt',
                'size': 3,
              },
              {
                '.tag': 'file',
                'name': 'jotsy_backup_20260101_080000.zip',
                'path_lower': '/jotsy_backup_20260101_080000.zip',
                'size': 10,
                'server_modified': '2026-03-01T00:00:00Z',
              },
            ],
            'cursor': 'cursor-1',
            'has_more': true,
          },
        );
        server.json(
          'POST',
          '/api/2/files/list_folder/continue',
          (_) => {
            'entries': [
              {
                '.tag': 'file',
                'name': 'jotsy_backup_20260201_080000.zip',
                'id': 'id:newer',
                'size': 20,
              },
              {
                '.tag': 'file',
                'name': 'Manual.ZIP',
                'path_lower': '/manual.zip',
                'server_modified': '2025-12-01T00:00:00Z',
              },
            ],
            'cursor': 'cursor-2',
            'has_more': false,
          },
        );

        final entries = await remote().list();

        expect(
          server.received('POST', '/api/2/files/list_folder').single.json,
          {'path': ''},
        );
        expect(
          server
              .received('POST', '/api/2/files/list_folder/continue')
              .single
              .json,
          {'cursor': 'cursor-1'},
        );
        expect(entries.map((entry) => entry.fileName), [
          'jotsy_backup_20260201_080000.zip',
          'jotsy_backup_20260101_080000.zip',
          'Manual.ZIP',
        ]);
        // 没有 path_lower 时以文件 id 定位；创建时间优先取自文件名。
        expect(entries.first.remoteId, 'id:newer');
        expect(entries[1].createdAt, DateTime(2026, 1, 1, 8));
        expect(entries[1].updatedAt, DateTime.utc(2026, 3));
        expect(entries.last.createdAt, DateTime.utc(2025, 12));
      },
    );

    test(
      'download posts Dropbox-API-Arg with an empty body and writes the file',
      () async {
        final bytes = List<int>.generate(300, (index) => index % 256);
        dropbox.files['/jotsy_backup_20260101_080000.zip'] = bytes;
        final target = File('${tempDir.path}/restore/download.zip');
        final progress = <int>[];

        await remote().download(
          entry: const CloudBackupEntry(
            fileName: 'jotsy_backup_20260101_080000.zip',
            remoteId: '/jotsy_backup_20260101_080000.zip',
          ),
          target: target,
          onProgress: (received, _) => progress.add(received),
        );

        expect(await target.readAsBytes(), bytes);
        expect(progress.last, bytes.length);
        final request = server
            .received('POST', '/content/2/files/download')
            .single;
        expect(apiArg(request), {'path': '/jotsy_backup_20260101_080000.zip'});
        expect(request.headers['authorization'], 'Bearer a1');
        expect(request.headers['content-length'], '0');
        expect(request.body, isEmpty);
      },
    );

    test(
      'download of a missing file maps to notFound and leaves no file',
      () async {
        final target = File('${tempDir.path}/download.zip');

        await expectLater(
          remote().download(
            entry: const CloudBackupEntry(
              fileName: 'gone.zip',
              remoteId: '/gone.zip',
            ),
            target: target,
          ),
          _throwsFailure(CloudBackupFailure.notFound),
        );
        expect(await target.exists(), isFalse);
      },
    );

    test(
      'delete removes the file and treats path_lookup/not_found as done',
      () async {
        dropbox.files['/a.zip'] = [1, 2, 3];
        const entry = CloudBackupEntry(fileName: 'a.zip', remoteId: '/a.zip');
        final client = remote();

        await client.delete(entry);
        await client.delete(entry);

        expect(dropbox.files, isEmpty);
        final requests = server.received('POST', '/api/2/files/delete_v2');
        expect(requests.map((request) => request.json), [
          {'path': '/a.zip'},
          {'path': '/a.zip'},
        ]);
      },
    );

    test(
      'upload, list, download and delete round trip through the fake API',
      () async {
        final bytes = List<int>.generate(9, (index) => 200 + index);
        final file = await tempFile(bytes);
        final client = sessionRemote();

        await client.prepare();
        final uploaded = await client.upload(
          file: file,
          fileName: 'jotsy_backup_20260301_120000.zip',
        );
        final listed = await client.list();
        final target = File('${tempDir.path}/restored.zip');
        await client.download(entry: listed.single, target: target);
        await client.delete(listed.single);

        expect(listed.single.remoteId, uploaded.remoteId);
        expect(listed.single.size, bytes.length);
        expect(await target.readAsBytes(), bytes);
        expect(await client.list(), isEmpty);
      },
    );

    test('dropboxApiArg escapes non-ASCII characters as \\uXXXX', () async {
      const path = '/备份 😀.zip';
      final arg = dropboxApiArg({'path': path});

      // 中文与表情（UTF-16 代理对）都按码元写成反斜杠 + u + 四位十六进制。
      const slash = r'\';
      expect(arg, contains('${slash}u5907${slash}u4efd'));
      expect(arg, contains('${slash}ud83d${slash}ude00'));
      expect(arg.codeUnits.every((unit) => unit < 0x7F), isTrue);
      expect(jsonDecode(arg), {'path': path});

      // 经真实 HTTP 头发送后，服务端解析出的仍是原始中文文件名。
      final file = await tempFile([1, 2, 3]);
      await remote().upload(file: file, fileName: '备份 😀.zip');
      final request = server.received('POST', '/content/2/files/upload').single;
      expect(
        request.headers['dropbox-api-arg']!.codeUnits.every((u) => u < 0x7F),
        isTrue,
      );
      expect(apiArg(request)['path'], path);
    });
  });

  group('token refresh', () {
    test(
      'a 401 refreshes once, retries and keeps the old refresh token',
      () async {
        dropbox.validToken = 'a2';

        final entries = await remote().list();

        expect(entries, isEmpty);
        final tokenRequest = server
            .received('POST', '/api/oauth2/token')
            .single;
        expect(tokenRequest.form, {
          'grant_type': 'refresh_token',
          'refresh_token': 'r1',
          'client_id': 'key',
        });
        final listRequests = server.received(
          'POST',
          '/api/2/files/list_folder',
        );
        expect(listRequests.map((r) => r.headers['authorization']), [
          'Bearer a1',
          'Bearer a2',
        ]);
        expect(refreshed, hasLength(1));
        expect(refreshed.single.accessToken, 'a2');
        // Dropbox 刷新响应不带 refresh_token，必须沿用旧的。
        expect(refreshed.single.refreshToken, 'r1');
      },
    );

    test('a revoked refresh token surfaces sessionExpired', () async {
      dropbox.validToken = 'a2';
      dropbox.refreshTokenRevoked = true;

      await expectLater(
        remote().list(),
        _throwsFailure(CloudBackupFailure.sessionExpired),
      );
      expect(refreshed, isEmpty);
    });
  });

  group('error mapping', () {
    test('409 path/insufficient_space maps to storageFull', () async {
      server.json(
        'POST',
        '/content/2/files/upload',
        (_) => {
          'error_summary': 'path/insufficient_space/...',
          'error': {
            '.tag': 'path',
            'reason': {'.tag': 'insufficient_space'},
          },
        },
        status: 409,
      );
      final file = await tempFile([1, 2, 3]);

      await expectLater(
        remote().upload(file: file, fileName: 'a.zip'),
        _throwsFailure(CloudBackupFailure.storageFull),
      );
    });

    test('429 maps to rateLimited', () async {
      server.json(
        'POST',
        '/api/2/files/list_folder',
        (_) => {
          'error_summary': 'too_many_requests/..',
          'error': {
            'reason': {'.tag': 'too_many_requests'},
            'retry_after': 1,
          },
        },
        status: 429,
      );

      await expectLater(
        remote().list(),
        _throwsFailure(CloudBackupFailure.rateLimited),
      );
    });
  });
}

String _s256(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

Matcher _throwsFailure(CloudBackupFailure failure) => throwsA(
  isA<CloudBackupException>().having((e) => e.failure, 'failure', failure),
);

/// 只模拟客户端用到的 Dropbox API v2 行为：App folder 根目录下的平铺文件、
/// 上传会话的偏移校验、令牌端点与 Bearer 校验。
class _FakeDropbox {
  _FakeDropbox(this.server) {
    server.on('POST', '/api/oauth2/token', _token);
    _rpc('/api/2/files/list_folder', (_) => _listing());
    _rpc('/api/2/files/delete_v2', (body) {
      final path = (body['path'] as String).toLowerCase();
      if (files.remove(path) == null) {
        return _error409('path_lookup/not_found/..');
      }
      return {'metadata': _metadata(path)};
    });
    _content('/content/2/files/upload', (arg, bytes) {
      return _commit(arg, bytes);
    });
    _content('/content/2/files/upload_session/start', (arg, bytes) {
      final id = 'session-${++_sessionCount}';
      sessions[id] = [...bytes];
      return {'session_id': id};
    });
    _content('/content/2/files/upload_session/append_v2', (arg, bytes) {
      final cursor = arg['cursor'] as Map;
      final error = _appendAt(cursor, bytes);
      return error ?? 'null';
    });
    _content('/content/2/files/upload_session/finish', (arg, bytes) {
      final cursor = arg['cursor'] as Map;
      final error = _appendAt(cursor, bytes);
      if (error != null) return error;
      return _commit(
        (arg['commit'] as Map).cast<String, Object?>(),
        sessions.remove(cursor['session_id'])!,
      );
    });
    server.on('POST', '/content/2/files/download', (request, response) {
      if (!_authorized(request, response)) return;
      final arg = jsonDecode(request.headers['dropbox-api-arg']!) as Map;
      final bytes = files[(arg['path'] as String).toLowerCase()];
      if (bytes == null) {
        _write(response, _error409('path/not_found/...'));
        return;
      }
      response.headers.set(
        'Dropbox-API-Result',
        jsonEncode(_metadata(arg['path'] as String)),
      );
      response.contentLength = bytes.length;
      response.add(bytes);
    });
  }

  final FakeDriveServer server;

  /// 当前有效的访问令牌；刷新后签发 [_refreshedToken]。
  String validToken = 'a1';
  bool refreshTokenRevoked = false;
  final Map<String, List<int>> files = <String, List<int>>{};
  final Map<String, List<int>> sessions = <String, List<int>>{};
  int _sessionCount = 0;

  static const _refreshedToken = 'a2';

  void _token(FakeDriveRequest request, HttpResponse response) {
    final form = request.form;
    if (form['grant_type'] == 'authorization_code') {
      if (form['code'] != 'code-123') {
        _write(response, (
          400,
          {
            'error': 'invalid_grant',
            'error_description': "code doesn't exist or has expired",
          },
        ));
        return;
      }
      _write(response, (
        200,
        {
          'access_token': 'a1',
          'refresh_token': 'r1',
          'expires_in': 14400,
          'token_type': 'bearer',
        },
      ));
      return;
    }
    if (refreshTokenRevoked || form['refresh_token'] != 'r1') {
      _write(response, (400, {'error': 'invalid_grant'}));
      return;
    }
    validToken = _refreshedToken;
    _write(response, (
      200,
      {
        'access_token': _refreshedToken,
        'expires_in': 14400,
        'token_type': 'bearer',
      },
    ));
  }

  void _rpc(String path, Object? Function(Map<String, Object?> body) handler) {
    server.on('POST', path, (request, response) {
      if (!_authorized(request, response)) return;
      _write(response, handler((request.json! as Map).cast<String, Object?>()));
    });
  }

  void _content(
    String path,
    Object? Function(Map<String, Object?> arg, List<int> bytes) handler,
  ) {
    server.on('POST', path, (request, response) {
      if (!_authorized(request, response)) return;
      final arg = (jsonDecode(request.headers['dropbox-api-arg']!) as Map)
          .cast<String, Object?>();
      _write(response, handler(arg, request.body));
    });
  }

  bool _authorized(FakeDriveRequest request, HttpResponse response) {
    if (request.headers['authorization'] == 'Bearer $validToken') return true;
    _write(response, (
      401,
      {
        'error_summary': 'expired_access_token/',
        'error': {'.tag': 'expired_access_token'},
      },
    ));
    return false;
  }

  (int, Object?)? _appendAt(Map cursor, List<int> bytes) {
    final buffer = sessions[cursor['session_id']];
    if (buffer == null) return _error409('lookup_failed/not_found/');
    if (cursor['offset'] != buffer.length) {
      return _error409('incorrect_offset/');
    }
    buffer.addAll(bytes);
    return null;
  }

  Map<String, Object?> _commit(Map<String, Object?> commit, List<int> bytes) {
    final path = (commit['path'] as String).toLowerCase();
    files[path] = [...bytes];
    return _metadata(commit['path'] as String);
  }

  Map<String, Object?> _listing() => {
    'entries': [
      for (final path in files.keys) {'.tag': 'file', ..._metadata(path)},
    ],
    'cursor': 'cursor-0',
    'has_more': false,
  };

  Map<String, Object?> _metadata(String path) => {
    'name': path.substring(1),
    'path_lower': path.toLowerCase(),
    'path_display': path,
    'id': 'id:${path.hashCode}',
    'size': files[path.toLowerCase()]?.length ?? 0,
    'server_modified': '2026-03-01T00:00:00Z',
  };

  static (int, Object?) _error409(String summary) => (
    409,
    {
      'error_summary': summary,
      'error': {'.tag': summary.split('/').first},
    },
  );

  /// [result] 为 `(状态码, JSON)` 时按该状态返回，`'null'` 原样写出（append_v2
  /// 的成功响应体就是 `null`），其余按 200 JSON 返回。
  static void _write(HttpResponse response, Object? result) {
    final (status, body) = result is (int, Object?) ? result : (200, result);
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(body == 'null' ? 'null' : jsonEncode(body));
  }
}
