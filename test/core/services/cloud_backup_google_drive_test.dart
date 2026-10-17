import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_google_drive.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';

import '../../support/fake_drive_server.dart';

const _folderMime = 'application/vnd.google-apps.folder';
const _deviceGrant = 'urn:ietf:params:oauth:grant-type:device_code';
const _folderQuery =
    "name = 'Jotsy' and mimeType = '$_folderMime' "
    "and 'root' in parents and trashed = false";

void main() {
  late FakeDriveServer server;
  late CloudBackupHttp http;
  late Directory tempDir;
  late GoogleDriveProvider provider;
  late _GoogleDriveFake fake;
  late CloudOAuthSession session;
  late List<CloudOAuthToken> refreshed;

  setUp(() async {
    server = await FakeDriveServer.start();
    http = server.http();
    tempDir = await Directory.systemTemp.createTemp('jotsy_gdrive_test_');
    provider = GoogleDriveProvider(
      clientId: 'cid',
      clientSecret: 'sec',
      oauthBase: server.url('oauth/'),
      apiBase: server.url('drive/v3/'),
      uploadBase: server.url('upload/drive/v3/'),
    );
    fake = _GoogleDriveFake(server);
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

  CloudDeviceCodeAuthorization deviceFlow() {
    final authorization = provider.beginAuthorization(http);
    expect(authorization, isA<CloudDeviceCodeAuthorization>());
    return authorization as CloudDeviceCodeAuthorization;
  }

  Future<File> writeBackup(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  List<FakeDriveRequest> folderLookups() => [
    for (final request in server.received('GET', '/drive/v3/files'))
      if (request.query['q'] == _folderQuery) request,
  ];

  group('设备码授权', () {
    test(
      'start posts client id and drive.file scope and parses verification_url',
      () async {
        server.json(
          'POST',
          '/oauth/device/code',
          (_) => {
            'device_code': 'dev-123',
            'user_code': 'GQVQ-JKEC',
            'verification_url': 'https://www.google.com/device',
            'expires_in': 1800,
            'interval': 5,
          },
        );

        final before = DateTime.now();
        final authorization = await deviceFlow().start();

        expect(authorization.deviceCode, 'dev-123');
        expect(authorization.userCode, 'GQVQ-JKEC');
        expect(
          authorization.verificationUri,
          Uri.parse('https://www.google.com/device'),
        );
        expect(authorization.verificationUriComplete, isNull);
        expect(authorization.interval, const Duration(seconds: 5));
        expect(
          authorization.expiresAt.isAfter(
            before.add(const Duration(minutes: 29)),
          ),
          isTrue,
        );
        // 申请设备码只带 client_id 与 scope，client_secret 只在换令牌时发送。
        expect(server.received('POST', '/oauth/device/code').single.form, {
          'client_id': 'cid',
          'scope': GoogleDriveProvider.scope,
        });
      },
    );

    test('start maps a rejected OAuth client to appKeyMissing', () async {
      server.json(
        'POST',
        '/oauth/device/code',
        (_) => {
          'error': 'invalid_client',
          'error_description': 'The OAuth client was not found.',
        },
        status: 401,
      );

      await expectLater(
        deviceFlow().start(),
        _throwsFailure(CloudBackupFailure.appKeyMissing),
      );
    });

    test(
      'poll maps 428 pending, slow_down and success with the device grant form',
      () async {
        fake.tokenReplies.addAll([
          (428, {'error': 'authorization_pending'}),
          (403, {'error': 'slow_down'}),
          (
            200,
            {
              'access_token': 'ya29.new',
              'expires_in': 3599,
              'refresh_token': '1//refresh',
              'scope': GoogleDriveProvider.scope,
              'token_type': 'Bearer',
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
        expect(token.accessToken, 'ya29.new');
        expect(token.refreshToken, '1//refresh');
        expect(token.expiresAt, isNotNull);
        final polls = server.received('POST', '/oauth/token');
        expect(polls, hasLength(3));
        for (final request in polls) {
          expect(request.form, {
            'client_id': 'cid',
            'client_secret': 'sec',
            'device_code': 'dev-123',
            'grant_type': _deviceGrant,
          });
        }
      },
    );

    test(
      'poll throws for denied, expired and invalid_grant codes and 5xx',
      () async {
        final cases = <(int, String?, CloudBackupFailure)>[
          (403, 'access_denied', CloudBackupFailure.authorizationDenied),
          (400, 'expired_token', CloudBackupFailure.authorizationExpired),
          // Google 文档里设备码过期返回 invalid_grant。
          (400, 'invalid_grant', CloudBackupFailure.authorizationExpired),
          // 5xx 归为网络错误，waitForDeviceToken 才会容忍并继续轮询。
          (503, null, CloudBackupFailure.network),
        ];
        final flow = deviceFlow();
        for (final (status, error, failure) in cases) {
          fake.tokenReplies.add((status, {'error': ?error}));
          await expectLater(
            flow.poll(_deviceAuthorization()),
            _throwsFailure(failure),
            reason: '$status $error',
          );
        }
      },
    );

    test(
      'waitForDeviceToken backs off on slow_down and returns the granted token',
      () async {
        fake.tokenReplies.addAll([
          (428, {'error': 'authorization_pending'}),
          (403, {'error': 'slow_down'}),
          (200, {'access_token': 'ya29.done', 'refresh_token': '1//r'}),
        ]);
        final waits = <Duration>[];

        final token = await waitForDeviceToken(
          _deviceAuthorization(),
          deviceFlow().poll,
          cancellation: CloudBackupCancellation(),
          delay: (duration) async => waits.add(duration),
        );

        expect(token.accessToken, 'ya29.done');
        expect(waits, const [
          Duration(seconds: 5),
          Duration(seconds: 5),
          Duration(seconds: 10),
        ]);
      },
    );
  });

  group('Drive 往返', () {
    test('prepare reuses the Jotsy folder found in the drive root', () async {
      final drive = remote();

      await drive.prepare();
      await drive.list();

      // 文件夹 id 被缓存：后续 list 不再查找，也从不创建。
      final lookup = folderLookups().single;
      expect(lookup.query['orderBy'], 'createdTime');
      expect(lookup.query['pageSize'], '1');
      expect(lookup.query['fields'], 'files(id)');
      expect(lookup.headers['authorization'], 'Bearer a1');
      expect(server.received('POST', '/drive/v3/files'), isEmpty);
    });

    test('prepare creates the Jotsy folder when none exists', () async {
      fake.folderId = null;
      final drive = remote();

      await drive.prepare();
      await drive.prepare();

      final create = server.received('POST', '/drive/v3/files').single;
      expect(create.query, {'fields': 'id'});
      expect(create.headers['authorization'], 'Bearer a1');
      expect(create.json, {
        'name': 'Jotsy',
        'mimeType': _folderMime,
        'parents': ['root'],
      });
      expect(fake.folderId, isNotNull);
      expect(folderLookups(), hasLength(1));
    });

    test(
      'upload opens a resumable session and PUTs the whole file to Location',
      () async {
        final bytes = List<int>.generate(5000, (i) => (i * 31 + 7) % 256);
        const name = 'jotsy_backup_20261016_093000.zip';
        final file = await writeBackup(name, bytes);
        final progress = <(int, int?)>[];

        final entry = await remote().upload(
          file: file,
          fileName: name,
          onProgress: (sent, total) => progress.add((sent, total)),
        );

        final init = server.received('POST', '/upload/drive/v3/files').single;
        expect(init.query['uploadType'], 'resumable');
        expect(
          init.query['fields'],
          'id,name,mimeType,size,createdTime,modifiedTime',
        );
        expect(init.headers['authorization'], 'Bearer a1');
        expect(init.headers['x-upload-content-length'], '5000');
        expect(init.headers['x-upload-content-type'], 'application/zip');
        expect(init.json, {
          'name': name,
          'parents': [fake.folderId],
        });
        final put = server.received('PUT', '/upload/drive/v3/files').single;
        expect(put.query['upload_id'], isNotEmpty);
        expect(put.headers['content-length'], '5000');
        expect(put.headers['content-type'], 'application/zip');
        expect(put.body, bytes);

        expect(entry.fileName, name);
        expect(entry.remoteId, fake.files.single['id']);
        expect(entry.size, 5000);
        expect(entry.createdAt, DateTime(2026, 10, 16, 9, 30));
        expect(fake.contents[entry.remoteId], bytes);
        expect(progress.last, (5000, 5000));
      },
    );

    test(
      'list follows nextPageToken, drops folders and non-zip files, newest first',
      () async {
        fake
          ..seed('jotsy_backup_20261001_080000.zip', size: 10)
          ..seed('notes.txt', mimeType: 'text/plain')
          ..seed('Archive', mimeType: _folderMime)
          // 名字像备份的文件夹也必须按 mimeType 排除。
          ..seed('old-backups.zip', mimeType: _folderMime)
          ..seed(
            'manual.zip',
            size: 30,
            createdTime: '2026-09-01T12:00:00.000Z',
            modifiedTime: '2026-09-02T12:00:00.000Z',
          )
          ..seed('jotsy_backup_20261015_210000.zip', size: 20)
          ..seed('elsewhere.zip', parent: 'other-folder');

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
        final pages = [
          for (final request in server.received('GET', '/drive/v3/files'))
            if (request.query['q'] != _folderQuery) request,
        ];
        expect(pages.map((request) => request.query['pageToken']), [
          null,
          '2',
          '4',
        ]);
        for (final page in pages) {
          expect(
            page.query['q'],
            "'${fake.folderId}' in parents "
            'and trashed = false',
          );
          expect(
            page.query['fields'],
            'nextPageToken,files(id,name,mimeType,size,createdTime,modifiedTime)',
          );
          expect(page.headers['authorization'], 'Bearer a1');
        }
      },
    );

    test('download writes the alt=media content into the target', () async {
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
      final request = server.received('GET', '/drive/v3/files/$id').single;
      expect(request.query, {'alt': 'media'});
      expect(request.headers['authorization'], 'Bearer a1');
      expect(progress.last, 3000);
    });

    test(
      'download of a missing file throws notFound and leaves no file',
      () async {
        final target = File('${tempDir.path}/restore/missing.zip');

        await expectLater(
          remote().download(
            entry: const CloudBackupEntry(fileName: 'x.zip', remoteId: 'gone'),
            target: target,
          ),
          _throwsFailure(CloudBackupFailure.notFound),
        );
        expect(await target.exists(), isFalse);
      },
    );

    test('delete removes the file and treats 404 as already deleted', () async {
      final id = fake.seed('jotsy_backup_20261010_101010.zip');
      final entry = CloudBackupEntry(fileName: 'x.zip', remoteId: id);
      final drive = remote();

      await drive.delete(entry);
      expect(fake.files, isEmpty);
      await drive.delete(entry);

      final deletes = server.received('DELETE', '/drive/v3/files/$id');
      expect(deletes, hasLength(2));
      expect(deletes.first.headers['authorization'], 'Bearer a1');
    });
  });

  group('令牌刷新', () {
    test(
      'a 401 refreshes once, retries with the new token and keeps the old refresh token',
      () async {
        fake.validToken = 'a2';
        // Google 的刷新响应不带 refresh_token。
        fake.tokenReplies.add((
          200,
          {'access_token': 'a2', 'expires_in': 3599, 'token_type': 'Bearer'},
        ));
        final drive = remote();

        await drive.prepare();
        await drive.list();

        final refresh = server.received('POST', '/oauth/token').single;
        expect(refresh.form, {
          'grant_type': 'refresh_token',
          'refresh_token': 'r1',
          'client_id': 'cid',
          'client_secret': 'sec',
        });
        expect(
          folderLookups().map((request) => request.headers['authorization']),
          ['Bearer a1', 'Bearer a2'],
        );
        expect(refreshed.single.accessToken, 'a2');
        expect(refreshed.single.refreshToken, 'r1');
        expect(refreshed.single.expiresAt, isNotNull);
        expect(session.token.refreshToken, 'r1');
        expect(
          server
              .received('GET', '/drive/v3/files')
              .last
              .headers['authorization'],
          'Bearer a2',
        );
      },
    );

    test(
      'a token still rejected after refresh fails as unauthorized without refreshing again',
      () async {
        fake.validToken = 'never';
        fake.tokenReplies.add((200, {'access_token': 'a2'}));

        await expectLater(
          remote().prepare(),
          _throwsFailure(CloudBackupFailure.unauthorized),
        );
        expect(server.received('POST', '/oauth/token'), hasLength(1));
        expect(folderLookups(), hasLength(2));
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
            'error_description': 'Token has been expired or revoked.',
          },
        ));

        await expectLater(
          remote().prepare(),
          _throwsFailure(CloudBackupFailure.sessionExpired),
        );
        expect(refreshed, isEmpty);
        expect(session.token.accessToken, 'a1');
      },
    );
  });

  group('错误归类', () {
    test(
      'storageQuotaExceeded on the resumable session maps to storageFull',
      () async {
        fake.uploadError = (403, _googleError('storageQuotaExceeded'));
        const name = 'jotsy_backup_20261016_093000.zip';
        final file = await writeBackup(name, const [1, 2, 3]);

        await expectLater(
          remote().upload(file: file, fileName: name),
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
        expect(server.received('PUT', '/upload/drive/v3/files'), isEmpty);
      },
    );

    test(
      'rate limit reasons map to rateLimited and other 403s to unauthorized',
      () async {
        const name = 'jotsy_backup_20261016_093000.zip';
        final file = await writeBackup(name, const [1, 2, 3]);
        final cases = <(String, CloudBackupFailure)>[
          ('userRateLimitExceeded', CloudBackupFailure.rateLimited),
          ('rateLimitExceeded', CloudBackupFailure.rateLimited),
          ('insufficientFilePermissions', CloudBackupFailure.unauthorized),
        ];
        final drive = remote();
        for (final (reason, failure) in cases) {
          fake.uploadError = (403, _googleError(reason));
          await expectLater(
            drive.upload(file: file, fileName: name),
            _throwsFailure(failure),
            reason: reason,
          );
        }
      },
    );
  });
}

Matcher _throwsFailure(CloudBackupFailure failure) => throwsA(
  isA<CloudBackupException>().having((e) => e.failure, 'failure', failure),
);

CloudDeviceAuthorization _deviceAuthorization() => CloudDeviceAuthorization(
  deviceCode: 'dev-123',
  userCode: 'GQVQ-JKEC',
  verificationUri: Uri.parse('https://www.google.com/device'),
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  interval: const Duration(seconds: 5),
);

Map<String, Object?> _googleError(String reason) => {
  'error': {
    'code': 403,
    'message': reason,
    'errors': [
      {'domain': 'usageLimits', 'reason': reason, 'message': reason},
    ],
  },
};

void _reply(HttpResponse response, int status, [Object? body]) {
  response.statusCode = status;
  if (body == null) return;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
}

/// 只模拟客户端用到的 Google OAuth 与 Drive v3 接口：按 Bearer 令牌鉴权、
/// 文件夹查找/创建、可续传上传、分页列表、alt=media 下载与删除。
/// 处理器里不做断言（异常会脱离测试上下文），测试结束后检查记录的请求。
class _GoogleDriveFake {
  _GoogleDriveFake(this.server) {
    server.on('POST', '/oauth/token', (request, response) {
      if (tokenReplies.isEmpty) {
        return _reply(response, 400, {'error': 'unexpected_token_request'});
      }
      final (status, body) = tokenReplies.removeAt(0);
      _reply(response, status, body);
    });
    server.on('GET', '/drive/v3/files', _search);
    server.on('POST', '/drive/v3/files', _createFolder);
    server.on('POST', '/upload/drive/v3/files', _startUpload);
    server.on('PUT', '/upload/drive/v3/files', _finishUpload);
  }

  final FakeDriveServer server;

  /// 已存在的 Jotsy 文件夹；置 null 模拟首次使用。
  String? folderId = 'jotsy-folder';
  String validToken = 'a1';

  /// 列表每页条数，故意很小以覆盖分页。
  int pageSize = 2;

  /// 令牌端点（设备码轮询与刷新）依次返回的响应。
  final List<(int, Object?)> tokenReplies = [];

  /// 非空时可续传会话的创建按此失败。
  (int, Object?)? uploadError;

  final List<Map<String, Object?>> files = [];
  final Map<String, List<int>> contents = {};
  final Map<String, Map<String, Object?>> _sessions = {};
  int _sequence = 0;

  /// 直接放入一个文件，返回其 id；[parent] 默认是 Jotsy 文件夹。
  String seed(
    String name, {
    String? parent,
    String mimeType = 'application/zip',
    int? size,
    List<int>? bytes,
    String createdTime = '2026-10-01T00:00:00.000Z',
    String? modifiedTime,
  }) {
    final id = 'file-${++_sequence}';
    files.add({
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'parents': [parent ?? folderId],
      if (mimeType != _folderMime) 'size': '${size ?? bytes?.length ?? 0}',
      'createdTime': createdTime,
      'modifiedTime': modifiedTime ?? createdTime,
    });
    if (bytes != null) contents[id] = bytes;
    _installFileRoutes(id);
    return id;
  }

  bool _authorized(FakeDriveRequest request, HttpResponse response) {
    if (request.headers['authorization'] == 'Bearer $validToken') return true;
    _reply(response, 401, {
      'error': {
        'code': 401,
        'message': 'Invalid Credentials',
        'errors': [
          {'reason': 'authError', 'location': 'Authorization'},
        ],
        'status': 'UNAUTHENTICATED',
      },
    });
    return false;
  }

  /// Drive 只返回请求 fields 里列出的字段（列表为 `files(...)` 内的部分），
  /// 未请求的 mimeType、parents 不会出现在响应里。
  static Map<String, Object?> _public(
    Map<String, Object?> file, [
    String fields = 'id,name,mimeType,size,createdTime,modifiedTime',
  ]) {
    final inner = RegExp(r'files\(([^)]*)\)').firstMatch(fields)?.group(1);
    final keys = (inner ?? fields).split(',').map((key) => key.trim());
    return {
      for (final key in keys)
        if (file.containsKey(key)) key: file[key],
    };
  }

  void _search(FakeDriveRequest request, HttpResponse response) {
    if (!_authorized(request, response)) return;
    final q = request.query['q'];
    if (q == _folderQuery) {
      return _reply(response, 200, {
        'files': [
          if (folderId != null) {'id': folderId},
        ],
      });
    }
    if (folderId == null || q != "'$folderId' in parents and trashed = false") {
      return _reply(response, 400, _googleError('invalidQuery'));
    }
    final children = [
      for (final file in files)
        if ((file['parents'] as List).contains(folderId)) file,
    ];
    final offset = int.parse(request.query['pageToken'] ?? '0');
    final end = offset + pageSize;
    _reply(response, 200, {
      'files': [
        for (final file in children.skip(offset).take(pageSize))
          _public(file, request.query['fields'] ?? ''),
      ],
      if (end < children.length) 'nextPageToken': '$end',
    });
  }

  void _createFolder(FakeDriveRequest request, HttpResponse response) {
    if (!_authorized(request, response)) return;
    final body = request.json as Map;
    final id = 'folder-${++_sequence}';
    if (body['name'] == 'Jotsy' && body['mimeType'] == _folderMime) {
      folderId = id;
    }
    _reply(response, 200, {'id': id});
  }

  void _startUpload(FakeDriveRequest request, HttpResponse response) {
    if (!_authorized(request, response)) return;
    final error = uploadError;
    if (error != null) return _reply(response, error.$1, error.$2);
    if (request.query['uploadType'] != 'resumable') {
      return _reply(response, 400, _googleError('badRequest'));
    }
    final uploadId = 'upload-${++_sequence}';
    _sessions[uploadId] = (request.json as Map).cast<String, Object?>();
    response.headers.set(
      HttpHeaders.locationHeader,
      server
          .url('upload/drive/v3/files')
          .replace(
            queryParameters: {'uploadType': 'resumable', 'upload_id': uploadId},
          ),
    );
    _reply(response, 200);
  }

  void _finishUpload(FakeDriveRequest request, HttpResponse response) {
    final metadata = _sessions.remove(request.query['upload_id']);
    if (metadata == null) {
      return _reply(response, 404, _googleError('notFound'));
    }
    final id = 'file-${++_sequence}';
    final now = DateTime.now().toUtc().toIso8601String();
    final file = <String, Object?>{
      'id': id,
      'name': metadata['name'],
      'mimeType': 'application/zip',
      'parents': metadata['parents'],
      'size': '${request.body.length}',
      'createdTime': now,
      'modifiedTime': now,
    };
    files.add(file);
    contents[id] = request.body;
    _installFileRoutes(id);
    _reply(response, 200, _public(file));
  }

  void _installFileRoutes(String id) {
    server.on('GET', '/drive/v3/files/$id', (request, response) {
      if (!_authorized(request, response)) return;
      final bytes = contents[id];
      if (request.query['alt'] != 'media' || bytes == null) {
        return _reply(response, 400, _googleError('badRequest'));
      }
      response
        ..headers.contentType = ContentType.binary
        ..contentLength = bytes.length
        ..add(bytes);
    });
    server.on('DELETE', '/drive/v3/files/$id', (request, response) {
      if (!_authorized(request, response)) return;
      final before = files.length;
      files.removeWhere((file) => file['id'] == id);
      if (files.length == before) {
        return _reply(response, 404, _googleError('notFound'));
      }
      contents.remove(id);
      _reply(response, HttpStatus.noContent);
    });
  }
}
