import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';
import 'package:node_diary/core/services/cloud_backup_onedrive.dart';

import '../../support/fake_drive_server.dart';

const _deviceGrant = 'urn:ietf:params:oauth:grant-type:device_code';
const _backupName = 'jotsy_backup_20261016_093000.zip';
const _approot = '/v1.0/me/drive/special/approot';
const _children = '$_approot/children';
const _createSession = '$_approot:/$_backupName:/createUploadSession';
const _uploadSession = '/upload-session';
const _devicePath = '/common/oauth2/v2.0/devicecode';
const _tokenPath = '/common/oauth2/v2.0/token';

void main() {
  late FakeDriveServer server;
  late CloudBackupHttp http;
  late Directory tempDir;
  late OneDriveProvider provider;
  late _OneDriveFake fake;
  late CloudOAuthSession session;
  late List<CloudOAuthToken> refreshed;

  setUp(() async {
    server = await FakeDriveServer.start();
    http = server.http();
    tempDir = await Directory.systemTemp.createTemp('jotsy_onedrive_test_');
    provider = OneDriveProvider(
      clientId: 'cid',
      authorityBase: server.url('common/oauth2/v2.0/'),
      graphBase: server.url('v1.0/'),
    );
    fake = _OneDriveFake(server);
    refreshed = <CloudOAuthToken>[];
    session = CloudOAuthSession(
      token: const CloudOAuthToken(accessToken: 'a1', refreshToken: 'r1'),
      refresh: (token) => provider.refresh(http, token),
      onRefreshed: (token) async => refreshed.add(token),
    );
  });

  tearDown(() async {
    http.close();
    await server.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CloudBackupRemote remote() => provider.createRemote(http, session);

  /// 直接构造以使用很小的分片，让测试文件跨多个分片。
  OneDriveRemote chunkedRemote(int chunkSize) => OneDriveRemote(
    http: http,
    session: session,
    graphBase: server.url('v1.0/'),
    chunkSize: chunkSize,
  );

  CloudDeviceCodeAuthorization deviceFlow() {
    final authorization = provider.beginAuthorization(http);
    expect(authorization, isA<CloudDeviceCodeAuthorization>());
    return authorization as CloudDeviceCodeAuthorization;
  }

  Future<File> writeBackup(List<int> bytes) async {
    final file = File('${tempDir.path}/$_backupName');
    await file.writeAsBytes(bytes);
    return file;
  }

  group('设备码授权', () {
    test(
      'start posts client id and scope without a secret and parses verification_uri',
      () async {
        server.json(
          'POST',
          _devicePath,
          (_) => {
            'user_code': 'FJ7RW3QDB',
            'device_code': 'dev-ms',
            'verification_uri': 'https://microsoft.com/devicelogin',
            'expires_in': 900,
            'interval': 5,
            'message': 'To sign in, use a web browser ...',
          },
        );

        final before = DateTime.now();
        final authorization = await deviceFlow().start();

        expect(authorization.deviceCode, 'dev-ms');
        expect(authorization.userCode, 'FJ7RW3QDB');
        expect(
          authorization.verificationUri,
          Uri.parse('https://microsoft.com/devicelogin'),
        );
        expect(authorization.interval, const Duration(seconds: 5));
        expect(
          authorization.expiresAt.isAfter(
            before.add(const Duration(minutes: 14)),
          ),
          isTrue,
        );
        expect(server.received('POST', _devicePath).single.form, {
          'client_id': 'cid',
          'scope': OneDriveProvider.scope,
        });
      },
    );

    test(
      'poll maps pending, slow_down and success with a public-client form',
      () async {
        fake.tokenReplies.addAll([
          (400, {'error': 'authorization_pending'}),
          (400, {'error': 'slow_down'}),
          (
            200,
            {
              'token_type': 'Bearer',
              'scope': 'Files.ReadWrite.AppFolder User.Read',
              'expires_in': 3600,
              'access_token': 'ms-access',
              'refresh_token': 'ms-refresh',
            },
          ),
        ]);
        final flow = deviceFlow();
        final authorization = _deviceAuthorization();

        expect(await flow.poll(authorization), isA<CloudDevicePending>());
        expect(await flow.poll(authorization), isA<CloudDeviceSlowDown>());
        final granted = await flow.poll(authorization);

        expect(granted, isA<CloudDeviceGranted>());
        final token = (granted as CloudDeviceGranted).token;
        expect(token.accessToken, 'ms-access');
        expect(token.refreshToken, 'ms-refresh');
        expect(token.expiresAt, isNotNull);
        final polls = server.received('POST', _tokenPath);
        expect(polls, hasLength(3));
        // 公共客户端：不发送 client_secret。
        for (final request in polls) {
          expect(request.form, {
            'client_id': 'cid',
            'device_code': 'dev-ms',
            'grant_type': _deviceGrant,
          });
        }
      },
    );

    test('poll throws for declined and expired device codes', () async {
      final cases = <(String, CloudBackupFailure)>[
        ('authorization_declined', CloudBackupFailure.authorizationDenied),
        ('access_denied', CloudBackupFailure.authorizationDenied),
        ('expired_token', CloudBackupFailure.authorizationExpired),
        ('bad_verification_code', CloudBackupFailure.authorizationExpired),
      ];
      final flow = deviceFlow();
      for (final (error, failure) in cases) {
        fake.tokenReplies.add((400, {'error': error}));
        await expectLater(
          flow.poll(_deviceAuthorization()),
          _throwsFailure(failure),
          reason: error,
        );
      }
    });
  });

  group('Graph 往返', () {
    test('prepare reads the app folder with the access token', () async {
      await remote().prepare();

      final request = server.received('GET', _approot).single;
      expect(request.query, {r'$select': 'id'});
      expect(request.headers['authorization'], 'Bearer a1');
    });

    test(
      'upload creates a session and PUTs chunks with Content-Range but no Authorization',
      () async {
        final bytes = List<int>.generate(1000, (i) => (i * 13 + 5) % 256);
        final file = await writeBackup(bytes);
        final progress = <(int, int?)>[];

        final entry = await chunkedRemote(320).upload(
          file: file,
          fileName: _backupName,
          onProgress: (sent, total) => progress.add((sent, total)),
        );

        final create = server.received('POST', _createSession).single;
        expect(create.headers['authorization'], 'Bearer a1');
        expect(create.json, {
          'item': {'@microsoft.graph.conflictBehavior': 'replace'},
        });
        final chunks = server.received('PUT', _uploadSession);
        expect(chunks.map((request) => request.headers['content-range']), [
          'bytes 0-319/1000',
          'bytes 320-639/1000',
          'bytes 640-959/1000',
          'bytes 960-999/1000',
        ]);
        for (final chunk in chunks) {
          // 预授权的会话地址带令牌会被拒，分片请求不能有 Authorization。
          expect(chunk.headers.containsKey('authorization'), isFalse);
          expect(chunk.headers['content-length'], '${chunk.body.length}');
          expect(chunk.query['sid'], fake.lastSessionId);
        }
        expect([for (final chunk in chunks) ...chunk.body], bytes);
        expect(server.received('DELETE', _uploadSession), isEmpty);

        expect(entry.fileName, _backupName);
        expect(entry.remoteId, fake.items.single['id']);
        expect(entry.size, 1000);
        expect(entry.createdAt, DateTime(2026, 10, 16, 9, 30));
        expect(entry.updatedAt, isNotNull);
        expect(fake.contents[entry.remoteId], bytes);
        expect(progress.last, (1000, 1000));
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i].$1, greaterThan(progress[i - 1].$1));
        }
      },
    );

    test(
      'upload of an exact multiple of the chunk size sends no empty trailing chunk',
      () async {
        final bytes = List<int>.generate(960, (i) => i % 256);
        final file = await writeBackup(bytes);

        await chunkedRemote(320).upload(file: file, fileName: _backupName);

        expect(
          server
              .received('PUT', _uploadSession)
              .map((request) => request.headers['content-range']),
          ['bytes 0-319/960', 'bytes 320-639/960', 'bytes 640-959/960'],
        );
        expect(fake.contents.values.single, bytes);
      },
    );

    test(
      'list follows @odata.nextLink, skips folders and non-zip files, newest first',
      () async {
        fake
          ..seed('jotsy_backup_20261001_080000.zip', size: 10)
          ..seed('Archive', folder: true)
          ..seed('notes.txt')
          ..seed(
            'manual.zip',
            size: 30,
            createdDateTime: '2026-09-01T12:00:00Z',
            lastModifiedDateTime: '2026-09-02T12:00:00Z',
          )
          ..seed('old-backups.zip', folder: true)
          ..seed('jotsy_backup_20261015_210000.zip', size: 20);

        final entries = await remote().list();

        expect(entries.map((entry) => entry.fileName), [
          'jotsy_backup_20261015_210000.zip',
          'jotsy_backup_20261001_080000.zip',
          'manual.zip',
        ]);
        expect(entries.map((entry) => entry.size), [20, 10, 30]);
        expect(entries.first.createdAt, DateTime(2026, 10, 15, 21));
        expect(entries.last.createdAt, DateTime.utc(2026, 9, 1, 12));
        expect(entries.last.updatedAt, DateTime.utc(2026, 9, 2, 12));
        final pages = server.received('GET', _children);
        expect(pages.map((request) => request.query[r'$skiptoken']), [
          null,
          '2',
          '4',
        ]);
        for (final page in pages) {
          expect(
            page.query[r'$select'],
            'id,name,size,file,createdDateTime,lastModifiedDateTime',
          );
          expect(page.query[r'$top'], '200');
          expect(page.headers['authorization'], 'Bearer a1');
        }
      },
    );

    test(
      'download fetches the pre-authenticated downloadUrl without Authorization',
      () async {
        final bytes = List<int>.generate(3000, (i) => (i * 7) % 256);
        final id = fake.seed('jotsy_backup_20261010_101010.zip', bytes: bytes);
        final target = File('${tempDir.path}/restore/nested/backup.zip');
        final progress = <int>[];

        await remote().download(
          entry: CloudBackupEntry(fileName: 'backup.zip', remoteId: id),
          target: target,
          onProgress: (received, _) => progress.add(received),
        );

        expect(await target.readAsBytes(), bytes);
        final meta = server.received('GET', '/v1.0/me/drive/items/$id').single;
        expect(meta.headers['authorization'], 'Bearer a1');
        final fetch = server.received('GET', '/download/$id').single;
        expect(fetch.query, {'tempauth': 'signed-$id'});
        expect(fetch.headers.containsKey('authorization'), isFalse);
        expect(progress.last, 3000);
      },
    );

    test(
      'download of a missing item throws notFound and leaves no file',
      () async {
        final id = fake.seed('jotsy_backup_20261010_101010.zip');
        fake.items.clear();
        final target = File('${tempDir.path}/restore/missing.zip');

        await expectLater(
          remote().download(
            entry: CloudBackupEntry(fileName: 'x.zip', remoteId: id),
            target: target,
          ),
          _throwsFailure(CloudBackupFailure.notFound),
        );
        expect(await target.exists(), isFalse);
        expect(server.received('GET', '/download/$id'), isEmpty);
      },
    );

    test('delete removes the item and treats 404 as already deleted', () async {
      final id = fake.seed('jotsy_backup_20261010_101010.zip');
      final entry = CloudBackupEntry(fileName: 'x.zip', remoteId: id);
      final drive = remote();

      await drive.delete(entry);
      expect(fake.items, isEmpty);
      await drive.delete(entry);

      final deletes = server.received('DELETE', '/v1.0/me/drive/items/$id');
      expect(deletes, hasLength(2));
      expect(deletes.first.headers['authorization'], 'Bearer a1');
    });
  });

  group('令牌刷新', () {
    test(
      'a 401 refreshes once, retries and keeps the rotated refresh token',
      () async {
        fake.validToken = 'a2';
        fake.tokenReplies.add((
          200,
          {
            'token_type': 'Bearer',
            'expires_in': 3600,
            'access_token': 'a2',
            'refresh_token': 'r2',
          },
        ));

        await remote().prepare();

        final refresh = server.received('POST', _tokenPath).single;
        expect(refresh.form, {
          'grant_type': 'refresh_token',
          'refresh_token': 'r1',
          'client_id': 'cid',
          'scope': OneDriveProvider.scope,
        });
        expect(
          server
              .received('GET', _approot)
              .map((request) => request.headers['authorization']),
          ['Bearer a1', 'Bearer a2'],
        );
        expect(refreshed.single.accessToken, 'a2');
        expect(refreshed.single.refreshToken, 'r2');
        expect(session.token.refreshToken, 'r2');

        // 旧刷新令牌已被轮换作废，下一次刷新必须用 r2。
        fake.validToken = 'a3';
        fake.tokenReplies.add((
          200,
          {'access_token': 'a3', 'refresh_token': 'r3'},
        ));
        await remote().list();

        expect(
          server.received('POST', _tokenPath).last.form['refresh_token'],
          'r2',
        );
        expect(refreshed.map((token) => token.refreshToken), ['r2', 'r3']);
      },
    );

    test(
      'a refresh rejected with invalid_grant surfaces as sessionExpired',
      () async {
        fake.validToken = 'a2';
        fake.tokenReplies.add((
          400,
          {
            'error': 'invalid_grant',
            'error_description': 'AADSTS70000: The refresh token has expired.',
          },
        ));

        await expectLater(
          remote().prepare(),
          _throwsFailure(CloudBackupFailure.sessionExpired),
        );
        expect(refreshed, isEmpty);
        expect(session.token.refreshToken, 'r1');
      },
    );
  });

  group('错误归类', () {
    test(
      'quotaLimitReached on createUploadSession maps to storageFull',
      () async {
        fake.createSessionError = (
          403,
          {
            'error': {
              'code': 'quotaLimitReached',
              'message': 'Insufficient Space Available',
            },
          },
        );
        final file = await writeBackup(const [1, 2, 3]);

        await expectLater(
          remote().upload(file: file, fileName: _backupName),
          throwsA(
            isA<CloudBackupException>()
                .having(
                  (e) => e.failure,
                  'failure',
                  CloudBackupFailure.storageFull,
                )
                .having((e) => e.statusCode, 'statusCode', 403),
          ),
        );
        expect(server.received('PUT', _uploadSession), isEmpty);
      },
    );

    test(
      'HTTP 507 on an upload chunk maps to storageFull and cancels the session',
      () async {
        fake.chunkErrorAt = (1, 507);
        final file = await writeBackup(List<int>.filled(1000, 9));

        await expectLater(
          chunkedRemote(320).upload(file: file, fileName: _backupName),
          _throwsFailure(CloudBackupFailure.storageFull),
        );
        expect(server.received('PUT', _uploadSession), hasLength(2));
        final cancel = server.received('DELETE', _uploadSession).single;
        expect(cancel.query['sid'], fake.lastSessionId);
        expect(cancel.headers.containsKey('authorization'), isFalse);
        expect(fake.items, isEmpty);
      },
    );
  });
}

Matcher _throwsFailure(CloudBackupFailure failure) => throwsA(
  isA<CloudBackupException>().having((e) => e.failure, 'failure', failure),
);

CloudDeviceAuthorization _deviceAuthorization() => CloudDeviceAuthorization(
  deviceCode: 'dev-ms',
  userCode: 'FJ7RW3QDB',
  verificationUri: Uri.parse('https://microsoft.com/devicelogin'),
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
  interval: const Duration(seconds: 5),
);

void _reply(HttpResponse response, int status, [Object? body]) {
  response.statusCode = status;
  if (body == null) return;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
}

/// 只模拟客户端用到的 Microsoft 身份平台与 Graph 接口：按 Bearer 令牌鉴权、
/// 应用文件夹、`@odata.nextLink` 分页、上传会话分片、预授权下载地址与删除。
/// 处理器里不做断言（异常会脱离测试上下文），测试结束后检查记录的请求。
class _OneDriveFake {
  _OneDriveFake(this.server) {
    server.on('POST', _tokenPath, (request, response) {
      if (tokenReplies.isEmpty) {
        return _reply(response, 400, {'error': 'unexpected_token_request'});
      }
      final (status, body) = tokenReplies.removeAt(0);
      _reply(response, status, body);
    });
    server.on('GET', _approot, (request, response) {
      if (!_authorized(request, response)) return;
      _reply(response, 200, {'id': 'approot-id'});
    });
    server.on('GET', _children, _listChildren);
    server.on('POST', _createSession, _createUploadSession);
    server.on('PUT', _uploadSession, _uploadChunk);
    server.on('DELETE', _uploadSession, (request, response) {
      _reply(response, HttpStatus.noContent);
    });
  }

  final FakeDriveServer server;
  String validToken = 'a1';

  /// 列表每页条数，故意很小以覆盖分页。
  int pageSize = 2;

  /// 令牌端点（设备码轮询与刷新）依次返回的响应。
  final List<(int, Object?)> tokenReplies = [];

  /// 非空时创建上传会话按此失败。
  (int, Object?)? createSessionError;

  /// （分片序号, 状态码）：该分片以无响应体的错误状态失败。
  (int, int)? chunkErrorAt;

  String? lastSessionId;
  final List<Map<String, Object?>> items = [];
  final Map<String, List<int>> contents = {};
  final List<int> _pending = [];
  int _chunkIndex = 0;
  int _sequence = 0;

  /// 直接放入应用文件夹的一项，返回其 id。
  String seed(
    String name, {
    bool folder = false,
    int? size,
    List<int>? bytes,
    String createdDateTime = '2026-10-01T00:00:00Z',
    String? lastModifiedDateTime,
  }) {
    final id = 'item-${++_sequence}';
    items.add({
      'id': id,
      'name': name,
      'size': size ?? bytes?.length ?? 0,
      'createdDateTime': createdDateTime,
      'lastModifiedDateTime': lastModifiedDateTime ?? createdDateTime,
      if (folder) 'folder': {'childCount': 0} else 'file': {'mimeType': 'x'},
    });
    if (bytes != null) contents[id] = bytes;
    _installItemRoutes(id);
    return id;
  }

  bool _authorized(FakeDriveRequest request, HttpResponse response) {
    if (request.headers['authorization'] == 'Bearer $validToken') return true;
    _reply(response, 401, {
      'error': {
        'code': 'InvalidAuthenticationToken',
        'message': 'Access token has expired or is not yet valid.',
      },
    });
    return false;
  }

  static Map<String, Object?> _notFound() => {
    'error': {'code': 'itemNotFound', 'message': 'Item not found'},
  };

  void _listChildren(FakeDriveRequest request, HttpResponse response) {
    if (!_authorized(request, response)) return;
    final offset = int.parse(request.query[r'$skiptoken'] ?? '0');
    final end = offset + pageSize;
    _reply(response, 200, {
      'value': items.skip(offset).take(pageSize).toList(),
      // Graph 的下一页是保留原查询参数的绝对地址。
      if (end < items.length)
        '@odata.nextLink': server
            .url(_children.substring(1))
            .replace(queryParameters: {...request.query, r'$skiptoken': '$end'})
            .toString(),
    });
  }

  void _createUploadSession(FakeDriveRequest request, HttpResponse response) {
    if (!_authorized(request, response)) return;
    final error = createSessionError;
    if (error != null) return _reply(response, error.$1, error.$2);
    final sessionId = 'session-${++_sequence}';
    lastSessionId = sessionId;
    _pending.clear();
    _chunkIndex = 0;
    _reply(response, 200, {
      'uploadUrl': server
          .url(_uploadSession.substring(1))
          .replace(queryParameters: {'sid': sessionId})
          .toString(),
      'expirationDateTime': '2026-10-17T00:00:00Z',
      'nextExpectedRanges': ['0-'],
    });
  }

  void _uploadChunk(FakeDriveRequest request, HttpResponse response) {
    // 上传会话地址自带授权，带 Authorization 头时按真实服务拒绝。
    if (request.headers.containsKey('authorization') ||
        request.query['sid'] != lastSessionId) {
      return _reply(response, 401, {
        'error': {'code': 'unauthenticated'},
      });
    }
    final error = chunkErrorAt;
    if (error != null && error.$1 == _chunkIndex) {
      return _reply(response, error.$2);
    }
    _chunkIndex++;
    final match = RegExp(
      r'^bytes (\d+)-(\d+)/(\d+)$',
    ).firstMatch(request.headers['content-range'] ?? '');
    final start = int.parse(match?.group(1) ?? '-1');
    final last = int.parse(match?.group(2) ?? '-1');
    final total = int.parse(match?.group(3) ?? '-1');
    if (match == null ||
        start != _pending.length ||
        last - start + 1 != request.body.length) {
      return _reply(response, 416, {
        'error': {'code': 'invalidRange'},
      });
    }
    _pending.addAll(request.body);
    if (_pending.length < total) {
      return _reply(response, 202, {
        'expirationDateTime': '2026-10-17T00:00:00Z',
        'nextExpectedRanges': ['${_pending.length}-'],
      });
    }
    final id = 'item-${++_sequence}';
    final item = <String, Object?>{
      'id': id,
      'name': _backupName,
      'size': total,
      'createdDateTime': '2026-10-16T01:30:00Z',
      'lastModifiedDateTime': '2026-10-16T01:30:00Z',
      'file': {'mimeType': 'application/zip'},
    };
    items.add(item);
    contents[id] = List<int>.of(_pending);
    _installItemRoutes(id);
    _reply(response, 201, item);
  }

  void _installItemRoutes(String id) {
    final path = '/v1.0/me/drive/items/$id';
    server.on('GET', path, (request, response) {
      if (!_authorized(request, response)) return;
      final item = items.where((item) => item['id'] == id).firstOrNull;
      if (item == null) return _reply(response, 404, _notFound());
      _reply(response, 200, {
        ...item,
        '@microsoft.graph.downloadUrl': server
            .url('download/$id')
            .replace(queryParameters: {'tempauth': 'signed-$id'})
            .toString(),
      });
    });
    server.on('GET', '/download/$id', (request, response) {
      final bytes = contents[id];
      if (request.query['tempauth'] != 'signed-$id' || bytes == null) {
        return _reply(response, 401);
      }
      response
        ..headers.contentType = ContentType.binary
        ..contentLength = bytes.length
        ..add(bytes);
    });
    server.on('DELETE', path, (request, response) {
      if (!_authorized(request, response)) return;
      final before = items.length;
      items.removeWhere((item) => item['id'] == id);
      if (items.length == before) return _reply(response, 404, _notFound());
      contents.remove(id);
      _reply(response, HttpStatus.noContent);
    });
  }
}
