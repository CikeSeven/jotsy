import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_aliyun.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';

import '../../support/fake_drive_server.dart';

void main() {
  late FakeDriveServer server;
  late CloudBackupHttp http;
  late _FakeAliyun aliyun;
  late Directory tempDir;
  late List<CloudOAuthToken> refreshed;
  late DateTime now;

  setUp(() async {
    server = await FakeDriveServer.start();
    http = server.http();
    aliyun = _FakeAliyun(server);
    tempDir = await Directory.systemTemp.createTemp('jotsy_aliyun_test_');
    refreshed = <CloudOAuthToken>[];
    now = DateTime(2026, 1, 1, 8);
  });

  tearDown(() async {
    http.close();
    await server.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// [secret] 为空时是 PKCE 公开客户端（没有刷新令牌）。
  AliyunDriveProvider provider({String secret = 'sec'}) => AliyunDriveProvider(
    clientId: 'cid',
    clientSecret: secret,
    apiBase: server.url(''),
  );

  CloudOAuthSession session({
    String? refreshToken = 'r1',
    String secret = 'sec',
  }) {
    final drive = provider(secret: secret);
    return CloudOAuthSession(
      token: CloudOAuthToken(accessToken: 'a1', refreshToken: refreshToken),
      refresh: (token) => drive.refresh(http, token),
      onRefreshed: (token) async => refreshed.add(token),
    );
  }

  AliyunDriveRemote remote({CloudOAuthSession? oauth}) => AliyunDriveRemote(
    http: http,
    session: oauth ?? session(),
    apiBase: server.url(''),
    partSize: 4,
    clock: () => now,
  );

  Future<File> tempFile(List<int> bytes) async {
    final file = File('${tempDir.path}/local.zip');
    await file.writeAsBytes(bytes);
    return file;
  }

  List<FakeDriveRequest> api(String name) =>
      server.received('POST', '/adrive/v1.0/$name');

  group('authorization', () {
    test(
      'authorize URI uses the oob redirect and PKCE without a client secret',
      () {
        final authorization = provider(secret: '').beginAuthorization(http);

        expect(authorization, isA<CloudCodePasteAuthorization>());
        final uri = (authorization as CloudCodePasteAuthorization).authorizeUri;
        expect(uri.path, '/oauth/authorize');
        expect(uri.queryParameters, {
          'client_id': 'cid',
          'redirect_uri': 'oob',
          'scope': AliyunDriveProvider.scope,
          'response_type': 'code',
          'state': isNotEmpty,
          'code_challenge': isNotEmpty,
          'code_challenge_method': 'S256',
        });
      },
    );

    test(
      'exchange without a secret posts a verifier matching the challenge',
      () async {
        final authorization =
            provider(secret: '').beginAuthorization(http)
                as CloudCodePasteAuthorization;
        final challenge =
            authorization.authorizeUri.queryParameters['code_challenge']!;

        final token = await authorization.exchange(' code-123\n');

        final body = server.received('POST', '/oauth/access_token').single;
        expect(body.headers['content-type'], startsWith('application/json'));
        expect(body.json, {
          'client_id': 'cid',
          'grant_type': 'authorization_code',
          'code': 'code-123',
          'code_verifier': isNotEmpty,
        });
        final verifier = (body.json! as Map)['code_verifier'] as String;
        expect(verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43,128}$')));
        expect(_s256(verifier), challenge);
        expect(challenge, isNot(contains('=')));
        // PKCE 公开客户端只拿到访问令牌。
        expect(token.accessToken, 'a1');
        expect(token.refreshToken, isNull);
        expect(token.expiresAt, isNotNull);
      },
    );

    test(
      'a client secret replaces PKCE in the URI and in the exchange',
      () async {
        final authorization =
            provider().beginAuthorization(http) as CloudCodePasteAuthorization;

        final query = authorization.authorizeUri.queryParameters;
        expect(query['redirect_uri'], 'oob');
        expect(query['scope'], AliyunDriveProvider.scope);
        expect(query.containsKey('code_challenge'), isFalse);
        expect(query.containsKey('code_challenge_method'), isFalse);

        final token = await authorization.exchange('code-123');

        expect(server.received('POST', '/oauth/access_token').single.json, {
          'client_id': 'cid',
          'client_secret': 'sec',
          'grant_type': 'authorization_code',
          'code': 'code-123',
        });
        expect(token.accessToken, 'a1');
        expect(token.refreshToken, 'r1');
      },
    );

    test('exchange maps an invalid code to authorizationExpired', () async {
      final authorization =
          provider(secret: '').beginAuthorization(http)
              as CloudCodePasteAuthorization;

      await expectLater(
        authorization.exchange('stale-code'),
        _throwsFailure(CloudBackupFailure.authorizationExpired),
      );
    });
  });

  group('backup folder', () {
    test(
      'prepare uses the folder granted at authorization and caches it',
      () async {
        aliyun.grantedFolderId = 'granted-folder';
        final client = remote();

        await client.prepare();
        await client.prepare();
        await client.list();

        expect(api('user/getDriveInfo'), hasLength(1));
        expect(api('openFile/get_by_path'), isEmpty);
        expect(api('openFile/create'), isEmpty);
        expect(
          (api('openFile/list').single.json! as Map)['parent_file_id'],
          'granted-folder',
        );
      },
    );

    test(
      'prepare creates the Jotsy folder when get_by_path reports NotFound',
      () async {
        await remote().prepare();

        expect(api('openFile/get_by_path').single.json, {
          'drive_id': 'd1',
          'file_path': '/Jotsy',
        });
        expect(api('openFile/create').single.json, {
          'drive_id': 'd1',
          'parent_file_id': 'root',
          'name': 'Jotsy',
          'type': 'folder',
          'check_name_mode': 'refuse',
        });
        expect(aliyun.folderId, 'jotsy-folder');
      },
    );

    test('prepare reuses an existing Jotsy folder', () async {
      aliyun.folderId = 'existing-folder';
      final client = remote();

      await client.prepare();
      await client.list();

      expect(api('openFile/create'), isEmpty);
      expect(
        (api('openFile/list').single.json! as Map)['parent_file_id'],
        'existing-folder',
      );
    });
  });

  group('remote round trip', () {
    test(
      'upload PUTs every part without Content-Type or Authorization, then completes',
      () async {
        final bytes = List<int>.generate(10, (index) => index + 1);
        final file = await tempFile(bytes);
        aliyun.renameTo = 'jotsy_backup_20260101_080000(1).zip';
        final progress = <int>[];

        final entry = await remote().upload(
          file: file,
          fileName: 'jotsy_backup_20260101_080000.zip',
          onProgress: (sent, total) {
            progress.add(sent);
            expect(total, bytes.length);
          },
        );

        final create = api('openFile/create').last;
        expect(create.json, {
          'drive_id': 'd1',
          'parent_file_id': 'jotsy-folder',
          'name': 'jotsy_backup_20260101_080000.zip',
          'type': 'file',
          'check_name_mode': 'auto_rename',
          'size': 10,
          'part_info_list': [
            {'part_number': 1},
            {'part_number': 2},
            {'part_number': 3},
          ],
        });
        final puts = aliyun.partRequests;
        expect(puts.map((r) => r.uri.path), [
          '/oss/file-1/1',
          '/oss/file-1/2',
          '/oss/file-1/3',
        ]);
        expect(puts.every((r) => r.query['sig'] == 'first'), isTrue);
        // 预签名地址带 Content-Type 或 Authorization 会让签名校验失败。
        for (final request in puts) {
          expect(request.headers.containsKey('content-type'), isFalse);
          expect(request.headers.containsKey('authorization'), isFalse);
        }
        expect(puts.map((r) => r.body.length), [4, 4, 2]);
        expect([for (final request in puts) ...request.body], bytes);
        expect(api('openFile/complete').single.json, {
          'drive_id': 'd1',
          'file_id': 'file-1',
          'upload_id': 'upload-file-1',
        });
        // complete 必须在全部分片之后。
        expect(
          server.requests.indexOf(api('openFile/complete').single),
          greaterThan(server.requests.indexOf(puts.last)),
        );
        expect(api('openFile/getUploadUrl'), isEmpty);
        expect(aliyun.files['file-1'], bytes);
        expect(progress.last, bytes.length);
        expect(entry.remoteId, 'file-1');
        expect(entry.fileName, 'jotsy_backup_20260101_080000(1).zip');
        expect(entry.size, bytes.length);
        expect(entry.createdAt, DateTime(2026, 1, 1, 8));
      },
    );

    test('rapid upload skips the part uploads and complete', () async {
      aliyun.rapidUpload = true;
      final file = await tempFile(List<int>.filled(10, 7));

      final entry = await remote().upload(
        file: file,
        fileName: 'jotsy_backup_20260101_080000.zip',
      );

      expect(entry.remoteId, 'file-1');
      expect(aliyun.partRequests, isEmpty);
      expect(api('openFile/complete'), isEmpty);
    });

    test(
      'presigned URLs older than 50 minutes are renewed for the remaining parts',
      () async {
        final bytes = List<int>.generate(10, (index) => 50 + index);
        final file = await tempFile(bytes);
        // 第一片传完时时钟走过 51 分钟，剩余分片必须换用新地址。
        aliyun.onPart = (part) {
          if (part == 1) now = now.add(const Duration(minutes: 51));
        };

        await remote().upload(
          file: file,
          fileName: 'jotsy_backup_20260101_080000.zip',
        );

        expect(api('openFile/getUploadUrl').single.json, {
          'drive_id': 'd1',
          'file_id': 'file-1',
          'upload_id': 'upload-file-1',
          'part_info_list': [
            {'part_number': 2},
            {'part_number': 3},
          ],
        });
        expect(aliyun.partRequests.map((r) => '${r.uri.path}?${r.uri.query}'), [
          '/oss/file-1/1?sig=first',
          '/oss/file-1/2?sig=renewed',
          '/oss/file-1/3?sig=renewed',
        ]);
        expect(aliyun.files['file-1'], bytes);
      },
    );

    test(
      'list pages through next_marker, keeps zip files and sorts newest first',
      () async {
        aliyun.folderId = 'folder';
        server.json('POST', '/adrive/v1.0/openFile/list', (request) {
          final marker = (request.json! as Map)['marker'];
          if (marker == null) {
            return {
              'items': [
                {'type': 'folder', 'file_id': 'dir', 'name': 'nested.zip'},
                {'type': 'file', 'file_id': 'txt', 'name': 'notes.txt'},
                {
                  'type': 'file',
                  'file_id': 'older',
                  'name': 'jotsy_backup_20260101_080000.zip',
                  'size': 10,
                  'updated_at': '2026-03-01T00:00:00.000Z',
                },
              ],
              'next_marker': 'page-2',
            };
          }
          return {
            'items': [
              {
                'type': 'file',
                'file_id': 'newer',
                'name': 'jotsy_backup_20260201_080000.zip',
                'size': '20',
              },
              {
                'type': 'file',
                'file_id': 'manual',
                'name': 'manual.zip',
                'created_at': '2025-12-01T00:00:00.000Z',
                'updated_at': '2026-04-01T00:00:00.000Z',
              },
            ],
            'next_marker': '',
          };
        });

        final entries = await remote().list();

        expect(api('openFile/list').map((r) => r.json), [
          {'drive_id': 'd1', 'parent_file_id': 'folder', 'limit': 100},
          {
            'drive_id': 'd1',
            'parent_file_id': 'folder',
            'limit': 100,
            'marker': 'page-2',
          },
        ]);
        expect(entries.map((entry) => entry.remoteId), [
          'newer',
          'older',
          'manual',
        ]);
        expect(entries.first.size, 20);
        expect(entries[1].updatedAt, DateTime.utc(2026, 3));
        // 非本应用命名的 ZIP 用网盘的创建时间排序。
        expect(entries.last.createdAt, DateTime.utc(2025, 12));
      },
    );

    test(
      'download fetches a signed URL and GETs it without Authorization',
      () async {
        final bytes = List<int>.generate(300, (index) => index % 256);
        aliyun.folderId = 'folder';
        aliyun.files['file-9'] = bytes;
        final target = File('${tempDir.path}/restore/download.zip');

        await remote().download(
          entry: const CloudBackupEntry(fileName: 'a.zip', remoteId: 'file-9'),
          target: target,
        );

        expect(api('openFile/getDownloadUrl').single.json, {
          'drive_id': 'd1',
          'file_id': 'file-9',
          'expire_sec': 900,
        });
        final get = server.received('GET', '/download/file-9').single;
        expect(get.query['sig'], 'download');
        expect(get.headers.containsKey('authorization'), isFalse);
        expect(await target.readAsBytes(), bytes);
      },
    );

    test('a rejected download URL fails without leaving a file', () async {
      aliyun.folderId = 'folder';
      aliyun.files['file-9'] = [1, 2, 3];
      aliyun.downloadStatus = HttpStatus.forbidden;
      final target = File('${tempDir.path}/download.zip');

      await expectLater(
        remote().download(
          entry: const CloudBackupEntry(fileName: 'a.zip', remoteId: 'file-9'),
          target: target,
        ),
        _throwsFailure(CloudBackupFailure.unauthorized),
      );
      expect(await target.exists(), isFalse);
    });

    test(
      'delete moves the file to the recycle bin and ignores NotFound',
      () async {
        aliyun.folderId = 'folder';
        aliyun.files['file-9'] = [1, 2, 3];
        const entry = CloudBackupEntry(fileName: 'a.zip', remoteId: 'file-9');
        final client = remote();

        await client.delete(entry);
        await client.delete(entry);

        expect(api('openFile/recyclebin/trash').map((r) => r.json), [
          {'drive_id': 'd1', 'file_id': 'file-9'},
          {'drive_id': 'd1', 'file_id': 'file-9'},
        ]);
        expect(aliyun.trashed, ['file-9']);
        expect(aliyun.files, isEmpty);
      },
    );

    test(
      'upload, list, download and delete round trip through the fake API',
      () async {
        final bytes = List<int>.generate(13, (index) => 200 + index);
        final file = await tempFile(bytes);
        final client = remote();

        await client.prepare();
        final uploaded = await client.upload(
          file: file,
          fileName: 'jotsy_backup_20260301_120000.zip',
        );
        final listed = await client.list();
        final target = File('${tempDir.path}/restored.zip');
        await client.download(entry: listed.single, target: target);
        await client.delete(listed.single);

        expect(aliyun.partRequests, hasLength(4));
        expect(listed.single.remoteId, uploaded.remoteId);
        expect(listed.single.size, bytes.length);
        expect(await target.readAsBytes(), bytes);
        expect(await client.list(), isEmpty);
        expect(api('user/getDriveInfo'), hasLength(1));
      },
    );
  });

  group('token refresh', () {
    test(
      'a 401 refreshes with the secret once, retries and keeps the rotated token',
      () async {
        aliyun.validToken = 'a2';
        aliyun.folderId = 'folder';

        await remote().prepare();

        expect(server.received('POST', '/oauth/access_token').single.json, {
          'client_id': 'cid',
          'client_secret': 'sec',
          'grant_type': 'refresh_token',
          'refresh_token': 'r1',
        });
        expect(
          api('user/getDriveInfo').map((r) => r.headers['authorization']),
          ['Bearer a1', 'Bearer a2'],
        );
        expect(
          api('openFile/get_by_path').single.headers['authorization'],
          'Bearer a2',
        );
        expect(refreshed, hasLength(1));
        expect(refreshed.single.accessToken, 'a2');
        // 带 Secret 时刷新令牌每次轮换，必须保存新的。
        expect(refreshed.single.refreshToken, 'r2');
      },
    );

    test(
      'without a refresh token (PKCE) a 401 surfaces sessionExpired',
      () async {
        aliyun.validToken = 'a2';

        await expectLater(
          remote(oauth: session(refreshToken: null, secret: '')).prepare(),
          _throwsFailure(CloudBackupFailure.sessionExpired),
        );
        expect(server.received('POST', '/oauth/access_token'), isEmpty);
        expect(api('user/getDriveInfo'), hasLength(1));
      },
    );

    test('an invalid refresh token surfaces sessionExpired', () async {
      aliyun.validToken = 'a2';

      await expectLater(
        remote(oauth: session(refreshToken: 'revoked')).prepare(),
        _throwsFailure(CloudBackupFailure.sessionExpired),
      );
      expect(refreshed, isEmpty);
    });
  });

  group('error mapping', () {
    test('QuotaExhausted.Drive maps to storageFull', () async {
      aliyun.folderId = 'folder';
      aliyun.createError = (400, 'QuotaExhausted.Drive');
      final file = await tempFile([1, 2, 3]);

      await expectLater(
        remote().upload(file: file, fileName: 'a.zip'),
        _throwsFailure(CloudBackupFailure.storageFull),
      );
      expect(aliyun.partRequests, isEmpty);
    });

    test('TooManyRequests maps to rateLimited', () async {
      aliyun.folderId = 'folder';
      server.json(
        'POST',
        '/adrive/v1.0/openFile/list',
        (_) => {'code': 'TooManyRequests', 'message': 'Too Many Requests'},
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

/// 一次进行中的分片上传。
class _Upload {
  _Upload(this.name, this.parentId, this.partCount);

  final String name;
  final String parentId;
  final int partCount;
  final Map<int, List<int>> parts = <int, List<int>>{};
}

/// 只模拟客户端用到的阿里云盘开放平台接口：令牌端点（JSON）、单个 drive
/// 下的平铺文件、分片预签名地址（`/oss/<file_id>/<part>`）与下载地址。
class _FakeAliyun {
  _FakeAliyun(this.server) {
    server.on('POST', '/oauth/access_token', _token);
    _api(
      'user/getDriveInfo',
      (_) => {
        'user_id': 'u1',
        'default_drive_id': 'd1',
        'resource_drive_id': 'd2',
        'folder_id': ?grantedFolderId,
      },
    );
    _api('openFile/get_by_path', (body) {
      if (folderId == null || body['file_path'] != '/Jotsy') {
        return _error(404, 'NotFound.File');
      }
      return {'file_id': folderId, 'name': 'Jotsy', 'type': 'folder'};
    });
    _api('openFile/create', _create);
    _api('openFile/getUploadUrl', (body) {
      final fileId = body['file_id'] as String;
      if (body['upload_id'] != 'upload-$fileId') {
        return _error(404, 'NotFound.UploadId');
      }
      return {
        'file_id': fileId,
        'upload_id': body['upload_id'],
        'part_info_list': _partUrls(
          fileId,
          body['part_info_list'] as List,
          'renewed',
        ),
      };
    });
    _api('openFile/complete', (body) {
      final fileId = body['file_id'] as String;
      final upload = uploads.remove(fileId);
      if (upload == null || upload.parts.length != upload.partCount) {
        return _error(400, 'PartNotSequential');
      }
      files[fileId] = [
        for (var part = 1; part <= upload.partCount; part++)
          ...upload.parts[part]!,
      ];
      names[fileId] = upload.name;
      parents[fileId] = upload.parentId;
      return {'file_id': fileId, 'name': upload.name, 'type': 'file'};
    });
    _api(
      'openFile/list',
      (body) => {
        'items': [
          for (final id in files.keys)
            if (parents[id] == body['parent_file_id'])
              {
                'type': 'file',
                'file_id': id,
                'name': names[id],
                'size': files[id]!.length,
                'updated_at': '2026-03-01T00:00:00.000Z',
              },
        ],
        'next_marker': '',
      },
    );
    _api('openFile/getDownloadUrl', (body) {
      final fileId = body['file_id'] as String;
      if (!files.containsKey(fileId)) return _error(404, 'NotFound.File');
      server.on('GET', '/download/$fileId', (request, response) {
        // 预签名地址再带 Authorization 头会被 OSS 拒绝。
        if (request.headers.containsKey('authorization') ||
            downloadStatus != HttpStatus.ok) {
          response.statusCode = request.headers.containsKey('authorization')
              ? HttpStatus.badRequest
              : downloadStatus;
          response.write('<Error><Code>AccessDenied</Code></Error>');
          return;
        }
        response.contentLength = files[fileId]!.length;
        response.add(files[fileId]!);
      });
      return {
        'url': server.url('download/$fileId?sig=download').toString(),
        'expiration': '2026-01-01T08:15:00.000Z',
        'method': 'GET',
      };
    });
    _api('openFile/recyclebin/trash', (body) {
      final fileId = body['file_id'] as String;
      if (files.remove(fileId) == null) return _error(404, 'NotFound.File');
      trashed.add(fileId);
      return {'drive_id': body['drive_id'], 'file_id': fileId};
    });
  }

  final FakeDriveServer server;

  String validToken = 'a1';

  /// 文件夹级授权时 getDriveInfo 返回的 folder_id。
  String? grantedFolderId;

  /// 根目录下已有的 `Jotsy` 文件夹。
  String? folderId;

  /// openFile/create 同名自动重命名后返回的文件名。
  String? renameTo;
  bool rapidUpload = false;
  (int, String)? createError;
  int downloadStatus = HttpStatus.ok;

  /// 每个分片 PUT 收到后的回调（用于推进假时钟）。
  void Function(int part)? onPart;

  final Map<String, List<int>> files = <String, List<int>>{};
  final Map<String, String> names = <String, String>{};
  final Map<String, String> parents = <String, String>{};
  final Map<String, _Upload> uploads = <String, _Upload>{};
  final List<FakeDriveRequest> partRequests = <FakeDriveRequest>[];
  final List<String> trashed = <String>[];
  int _fileCount = 0;

  void _token(FakeDriveRequest request, HttpResponse response) {
    final body = (request.json! as Map).cast<String, Object?>();
    final hasSecret = body['client_secret'] == 'sec';
    if (body['client_id'] != 'cid') {
      _write(response, _error(400, 'InvalidClientId'));
      return;
    }
    if (body['grant_type'] == 'authorization_code') {
      if (body['code'] != 'code-123') {
        _write(response, _error(400, 'InvalidCode'));
        return;
      }
      _write(response, {
        'token_type': 'Bearer',
        'access_token': 'a1',
        'refresh_token': ?(hasSecret ? 'r1' : null),
        'expires_in': hasSecret ? 7200 : 2592000,
      });
      return;
    }
    if (!hasSecret || body['refresh_token'] != 'r1') {
      _write(response, _error(400, 'InvalidParameter.RefreshToken'));
      return;
    }
    validToken = 'a2';
    _write(response, {
      'token_type': 'Bearer',
      'access_token': 'a2',
      'refresh_token': 'r2',
      'expires_in': 7200,
    });
  }

  Object? _create(Map<String, Object?> body) {
    if (createError case (final status, final code)?) {
      return _error(status, code);
    }
    if (body['type'] == 'folder') {
      folderId = 'jotsy-folder';
      return {'file_id': folderId, 'file_name': 'Jotsy', 'type': 'folder'};
    }
    final fileId = 'file-${++_fileCount}';
    final partList = body['part_info_list'] as List;
    uploads[fileId] = _Upload(
      renameTo ?? body['name'] as String,
      body['parent_file_id'] as String,
      partList.length,
    );
    if (rapidUpload) {
      files[fileId] = const [];
      return {
        'file_id': fileId,
        'file_name': body['name'],
        'rapid_upload': true,
      };
    }
    return {
      'file_id': fileId,
      'upload_id': 'upload-$fileId',
      'file_name': renameTo ?? body['name'],
      'rapid_upload': false,
      'part_info_list': _partUrls(fileId, partList, 'first'),
    };
  }

  /// 为每个分片登记 PUT 路由并返回带签名参数的地址；同一分片再次签发时
  /// 签名不同，测试据此区分新旧地址。
  List<Map<String, Object?>> _partUrls(String fileId, List parts, String sig) {
    return [
      for (final part in parts)
        {
          'part_number': (part as Map)['part_number'],
          'upload_url': _registerPart(fileId, part['part_number'] as int, sig),
        },
    ];
  }

  String _registerPart(String fileId, int part, String sig) {
    server.on('PUT', '/oss/$fileId/$part', (request, response) {
      partRequests.add(request);
      final upload = uploads[fileId];
      if (upload == null || request.query['sig'] != sig) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      upload.parts[part] = request.body;
      onPart?.call(part);
    });
    return server.url('oss/$fileId/$part?sig=$sig').toString();
  }

  void _api(String name, Object? Function(Map<String, Object?> body) handler) {
    server.on('POST', '/adrive/v1.0/$name', (request, response) {
      if (request.headers['authorization'] != 'Bearer $validToken') {
        _write(response, _error(401, 'AccessTokenInvalid'));
        return;
      }
      _write(response, handler((request.json! as Map).cast<String, Object?>()));
    });
  }

  static (int, Object?) _error(int status, String code) =>
      (status, {'code': code, 'message': code, 'requestId': 'req-1'});

  static void _write(HttpResponse response, Object? result) {
    final (status, body) = result is (int, Object?) ? result : (200, result);
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
  }
}
