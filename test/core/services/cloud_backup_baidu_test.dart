import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_baidu.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';

import '../../support/fake_drive_server.dart';
import '../../support/webdav_test_server.dart';

const _slice = 4 * 1024 * 1024;
const _filePath = '/rest/2.0/xpan/file';

void main() {
  late FakeDriveServer server;
  late CloudBackupHttp http;
  late BaiduPanProvider provider;
  late Directory tempDir;
  late List<CloudOAuthToken> refreshed;
  final extraHttp = <CloudBackupHttp>[];

  setUp(() async {
    server = await FakeDriveServer.start();
    http = server.http();
    provider = BaiduPanProvider(
      appKey: 'ak',
      secretKey: 'sk',
      appDirectory: 'Jotsy',
      oauthBase: server.url('oauth/2.0/'),
      panBase: server.url(''),
      pcsBase: server.url('pcs/'),
    );
    tempDir = await Directory.systemTemp.createTemp('jotsy_baidu_test_');
    refreshed = <CloudOAuthToken>[];
  });

  tearDown(() async {
    http.close();
    for (final client in extraHttp) {
      client.close();
    }
    extraHttp.clear();
    await server.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CloudOAuthSession session(CloudBackupHttp client) => CloudOAuthSession(
    token: const CloudOAuthToken(accessToken: 'AT', refreshToken: 'RT'),
    refresh: (token) => provider.refresh(client, token),
    onRefreshed: (token) async => refreshed.add(token),
  );

  CloudBackupRemote remote([CloudBackupHttp? client]) {
    final used = client ?? http;
    return provider.createRemote(used, session(used));
  }

  Future<File> tempFile(List<int> bytes, [String name = 'local.zip']) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// uinfo：vip_type 决定分片大小（0 → 4 MiB）。
  void serveUserInfo({int vipType = 0}) => server.json(
    'GET',
    '/rest/2.0/xpan/nas',
    (_) => {
      'errno': 0,
      'vip_type': vipType,
      'baidu_name': 'baidu_user',
      'netdisk_name': 'netdisk_user',
    },
  );

  /// precreate / create 共用同一路径，按查询参数 method 分派；[needed] 为
  /// precreate 返回的待上传分片序号。
  void serveUploadApi({required List<int> needed, int fsId = 778899}) {
    server.json('POST', _filePath, (request) {
      final form = request.form;
      return switch (request.query['method']) {
        'precreate' => {
          'errno': 0,
          'path': form['path'],
          'uploadid': 'UP-1',
          'return_type': 1,
          'block_list': needed,
        },
        'create' => {
          'errno': 0,
          'fs_id': fsId,
          'path': form['path'],
          'size': int.parse(form['size']!),
          'mtime': 1760600000,
          'isdir': 0,
        },
        _ => {'errno': 2},
      };
    });
  }

  void serveLocateUpload(List<String> servers) => server.json(
    'GET',
    '/pcs/rest/2.0/pcs/file',
    (_) => {
      'error_code': 0,
      'host': 'c.pcs.baidu.com',
      'servers': [
        for (final host in servers) {'server': host},
      ],
    },
  );

  void serveSuperfile(String path) => server.json(
    'POST',
    path,
    (request) => {
      'md5': md5.convert(_multipartFile(request).bytes).toString(),
      'request_id': 1,
    },
  );

  List<FakeDriveRequest> apiCalls(String method, String path, String api) => [
    for (final request in server.received(method, path))
      if (request.query['method'] == api) request,
  ];

  group('device code authorization', () {
    test(
      'start requests a device code for the basic and netdisk scopes',
      () async {
        server.json(
          'GET',
          '/oauth/2.0/device/code',
          (_) => {
            'device_code': 'DC',
            'user_code': 'UC',
            'verification_url': 'https://openapi.baidu.com/device',
            'qrcode_url': 'https://openapi.baidu.com/device/qrcode/x',
            'expires_in': 300,
            'interval': 5,
          },
        );

        final authorization =
            provider.beginAuthorization(http) as CloudDeviceCodeAuthorization;
        final device = await authorization.start();

        expect(device.deviceCode, 'DC');
        expect(device.userCode, 'UC');
        expect(
          device.verificationUri,
          Uri.parse('https://openapi.baidu.com/device'),
        );
        expect(device.interval, const Duration(seconds: 5));
        expect(server.received('GET', '/oauth/2.0/device/code').single.query, {
          'response_type': 'device_code',
          'client_id': 'ak',
          'scope': 'basic,netdisk',
        });
      },
    );

    test(
      'poll maps pending, granted, declined and expired responses',
      () async {
        final replies = <(int, Map<String, Object?>)>[
          (400, {'error': 'authorization_pending'}),
          (
            200,
            {
              'access_token': 'AT',
              'refresh_token': 'RT',
              'expires_in': 2592000,
              'scope': 'basic netdisk',
            },
          ),
          (400, {'error': 'authorization_declined'}),
          (400, {'error': 'expired_token'}),
        ];
        server.on('GET', '/oauth/2.0/token', (request, response) {
          final (status, body) = replies.removeAt(0);
          response.statusCode = status;
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(body));
        });
        final authorization =
            provider.beginAuthorization(http) as CloudDeviceCodeAuthorization;
        final device = CloudDeviceAuthorization(
          deviceCode: 'DC',
          userCode: 'UC',
          verificationUri: Uri.parse('https://openapi.baidu.com/device'),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          interval: const Duration(seconds: 5),
        );

        expect(await authorization.poll(device), isA<CloudDevicePending>());
        final granted = await authorization.poll(device);
        expect(granted, isA<CloudDeviceGranted>());
        final token = (granted as CloudDeviceGranted).token;
        expect(token.accessToken, 'AT');
        expect(token.refreshToken, 'RT');
        expect(token.expiresAt, isNotNull);
        await expectLater(
          authorization.poll(device),
          _fails(CloudBackupFailure.authorizationDenied),
        );
        await expectLater(
          authorization.poll(device),
          _fails(CloudBackupFailure.authorizationExpired),
        );

        for (final request in server.received('GET', '/oauth/2.0/token')) {
          // 百度没有公开客户端模式：轮询必须带 SecretKey。
          expect(request.query, {
            'grant_type': 'device_token',
            'code': 'DC',
            'client_id': 'ak',
            'client_secret': 'sk',
          });
        }
      },
    );
  });

  group('upload', () {
    test(
      'non-VIP accounts upload 4 MiB slices then commit with create',
      () async {
        final data = _bytes(2 * _slice + 1024 * 1024 + 7, 1);
        final file = await tempFile(data);
        final sliceMd5s = _sliceMd5s(data);
        serveUserInfo();
        serveUploadApi(needed: [0, 1, 2]);
        // 假服务是 http：locateupload 返回的非 https 域名必须被忽略，退回默认
        // 上传域名 pcsBase（/pcs/ 前缀）。
        serveLocateUpload([server.base.toString()]);
        serveSuperfile('/pcs/rest/2.0/pcs/superfile2');
        final progress = <int>[];

        const name = 'jotsy_backup_20261016_083000.zip';
        final entry = await remote().upload(
          file: file,
          fileName: name,
          onProgress: (transferred, total) {
            expect(total, data.length);
            progress.add(transferred);
          },
        );

        const path = '/apps/Jotsy/$name';
        expect(entry.remoteId, '778899:$path');
        expect(entry.size, data.length);
        expect(entry.createdAt, DateTime(2026, 10, 16, 8, 30));
        expect(progress.last, data.length);

        expect(sliceMd5s, hasLength(3));
        expect(sliceMd5s.toSet(), hasLength(3));
        final precreate = apiCalls('POST', _filePath, 'precreate').single;
        expect(precreate.query['access_token'], 'AT');
        expect(precreate.headers['user-agent'], 'pan.baidu.com');
        expect(precreate.form, {
          'path': path,
          'size': '${data.length}',
          'isdir': '0',
          'autoinit': '1',
          'rtype': '3',
          'block_list': jsonEncode(sliceMd5s),
        });
        for (final hash in sliceMd5s) {
          expect(hash, matches(RegExp(r'^[0-9a-f]{32}$')));
        }

        final locate = server.received('GET', '/pcs/rest/2.0/pcs/file').single;
        expect(locate.query, {
          'method': 'locateupload',
          'appid': '250528',
          'access_token': 'AT',
          'path': path,
          'uploadid': 'UP-1',
          'upload_version': '2.0',
        });

        expect(server.received('POST', '/rest/2.0/pcs/superfile2'), isEmpty);
        final slices = server.received('POST', '/pcs/rest/2.0/pcs/superfile2');
        expect(slices, hasLength(3));
        for (var index = 0; index < slices.length; index++) {
          final request = slices[index];
          expect(request.query, {
            'method': 'upload',
            'type': 'tmpfile',
            'access_token': 'AT',
            'path': path,
            'uploadid': 'UP-1',
            'partseq': '$index',
          });
          final part = _multipartFile(request);
          expect(part.headers, contains('name="file"'));
          final expectedLength = min(_slice, data.length - index * _slice);
          expect(part.bytes, hasLength(expectedLength));
          expect(md5.convert(part.bytes).toString(), sliceMd5s[index]);
        }

        final create = apiCalls('POST', _filePath, 'create').single;
        expect(create.form, {
          'path': path,
          'size': '${data.length}',
          'isdir': '0',
          'rtype': '3',
          'uploadid': 'UP-1',
          'block_list': jsonEncode(sliceMd5s),
        });
      },
    );

    test('only the slices listed by precreate are uploaded', () async {
      final data = _bytes(_slice + 10, 2);
      final file = await tempFile(data);
      final sliceMd5s = _sliceMd5s(data);
      serveUserInfo();
      serveUploadApi(needed: [1]);
      serveLocateUpload(const []);
      serveSuperfile('/pcs/rest/2.0/pcs/superfile2');

      await remote().upload(file: file, fileName: 'resume.zip');

      final slices = server.received('POST', '/pcs/rest/2.0/pcs/superfile2');
      expect(slices.single.query['partseq'], '1');
      final part = _multipartFile(slices.single);
      expect(part.bytes, data.sublist(_slice));
      // create 仍提交完整的分片 MD5 列表，服务端按它合并。
      expect(
        apiCalls('POST', _filePath, 'create').single.form['block_list'],
        jsonEncode(sliceMd5s),
      );
    });

    test('an https host from locateupload is used for the slices', () async {
      // 全部连接（含 https 地址）接到假服务的明文端口，靠 Host 头判断选中的
      // 上传域名，不联网。
      final routed = _routedHttp(server);
      extraHttp.add(routed);
      final data = _bytes(1000, 3);
      final file = await tempFile(data);
      serveUserInfo();
      serveUploadApi(needed: [0]);
      serveLocateUpload([
        'http://plain.pcs.example.test',
        'https://c3.pcs.example.test',
        'https://c4.pcs.example.test',
      ]);
      serveSuperfile('/rest/2.0/pcs/superfile2');

      await remote(routed).upload(file: file, fileName: 'small.zip');

      final slice = server.received('POST', '/rest/2.0/pcs/superfile2').single;
      expect(slice.headers['host'], 'c3.pcs.example.test');
      expect(server.received('POST', '/pcs/rest/2.0/pcs/superfile2'), isEmpty);
      expect(_multipartFile(slice).bytes, data);
    });
  });

  group('list', () {
    test('a missing app directory (errno -9) lists no backups', () async {
      server.json('GET', _filePath, (_) => {'errno': -9, 'request_id': 1});

      expect(await remote().list(), isEmpty);
    });

    test(
      'only zip files are listed, newest first, with fs_id:path ids',
      () async {
        server.json(
          'GET',
          _filePath,
          (_) => {
            'errno': 0,
            'list': [
              {
                'fs_id': 1,
                'path': '/apps/Jotsy/folder.zip',
                'server_filename': 'folder.zip',
                'isdir': 1,
              },
              {
                'fs_id': 2,
                'path': '/apps/Jotsy/notes.txt',
                'server_filename': 'notes.txt',
                'isdir': 0,
                'size': 3,
              },
              {
                'fs_id': 333,
                'path': '/apps/Jotsy/manual.zip',
                'server_filename': 'manual.zip',
                'isdir': 0,
                'size': '42',
                'server_ctime': 1577836800,
                'server_mtime': 1577840400,
              },
              {
                'fs_id': 111,
                'path': '/apps/Jotsy/jotsy_backup_20261015_101112.zip',
                'server_filename': 'jotsy_backup_20261015_101112.zip',
                'isdir': 0,
                'size': 2048,
                'server_ctime': 1760000000,
                'server_mtime': 1760000100,
              },
            ],
          },
        );

        final entries = await remote().list();

        expect(entries.map((entry) => entry.fileName), [
          'jotsy_backup_20261015_101112.zip',
          'manual.zip',
        ]);
        expect(
          entries.first.remoteId,
          '111:/apps/Jotsy/jotsy_backup_20261015_101112.zip',
        );
        expect(entries.first.size, 2048);
        expect(entries.first.createdAt, DateTime(2026, 10, 15, 10, 11, 12));
        expect(entries.last.remoteId, '333:/apps/Jotsy/manual.zip');
        expect(entries.last.size, 42);
        expect(
          entries.last.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1577836800000, isUtc: true),
        );
        expect(
          entries.last.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(1577840400000, isUtc: true),
        );
        final request = server.received('GET', _filePath).single;
        expect(request.query, {
          'method': 'list',
          'dir': '/apps/Jotsy',
          'order': 'time',
          'desc': '1',
          'start': '0',
          'limit': '1000',
          'access_token': 'AT',
        });
        expect(request.headers['user-agent'], 'pan.baidu.com');
      },
    );

    test('a full page of 1000 items requests the next page', () async {
      server.json('GET', _filePath, (request) {
        final start = int.parse(request.query['start']!);
        final count = start == 0 ? 1000 : 1;
        return {
          'errno': 0,
          'list': [
            for (var i = 0; i < count; i++)
              {
                'fs_id': start + i + 1,
                'path': '/apps/Jotsy/b${start + i}.zip',
                'server_filename': 'b${start + i}.zip',
                'isdir': 0,
              },
          ],
        };
      });

      final entries = await remote().list();

      expect(entries, hasLength(1001));
      expect(server.received('GET', _filePath).map((r) => r.query['start']), [
        '0',
        '1000',
      ]);
    });
  });

  group('download', () {
    test(
      'fetches the dlink and downloads it with the token and pan UA',
      () async {
        final data = _bytes(5000, 4);
        server.json('GET', '/rest/2.0/xpan/multimedia', (request) {
          return {
            'errno': 0,
            'list': [
              {
                'fs_id': 111,
                'filename': 'x.zip',
                'dlink':
                    '${server.base}file/d1?fid=111&dstime=1&sign=abc%2Bdef',
              },
            ],
          };
        });
        server.on('GET', '/file/d1', (request, response) {
          response.headers.contentType = ContentType.binary;
          response.add(data);
        });
        final target = File('${tempDir.path}/out/x.zip');

        await remote().download(
          entry: const CloudBackupEntry(
            fileName: 'x.zip',
            remoteId: '111:/apps/Jotsy/x.zip',
          ),
          target: target,
        );

        expect(await target.readAsBytes(), data);
        final meta = server.received('GET', '/rest/2.0/xpan/multimedia').single;
        expect(meta.query, {
          'method': 'filemetas',
          'fsids': '[111]',
          'dlink': '1',
          'access_token': 'AT',
        });
        final fetch = server.received('GET', '/file/d1').single;
        // dlink 的签名参数原样保留（%2B 不被改写），access_token 追加在后。
        expect(
          fetch.uri.query,
          'fid=111&dstime=1&sign=abc%2Bdef&access_token=AT',
        );
        expect(fetch.headers['user-agent'], 'pan.baidu.com');
      },
    );

    test('a rejected dlink fetch fails without leaving a file', () async {
      server.json(
        'GET',
        '/rest/2.0/xpan/multimedia',
        (_) => {
          'errno': 0,
          'list': [
            {'fs_id': 111, 'dlink': '${server.base}file/d1?fid=111'},
          ],
        },
      );
      server.json(
        'GET',
        '/file/d1',
        (_) => {'error_code': 31326, 'error_msg': 'anti hotlinking'},
        status: 403,
      );
      final target = File('${tempDir.path}/x.zip');

      await expectLater(
        remote().download(
          entry: const CloudBackupEntry(
            fileName: 'x.zip',
            remoteId: '111:/apps/Jotsy/x.zip',
          ),
          target: target,
        ),
        _fails(CloudBackupFailure.unauthorized),
      );
      expect(await target.exists(), isFalse);
    });
  });

  group('delete', () {
    const entry = CloudBackupEntry(
      fileName: 'x.zip',
      remoteId: '111:/apps/Jotsy/x.zip',
    );

    test('posts a synchronous filemanager delete for the path', () async {
      server.json('POST', _filePath, (_) => {'errno': 0, 'info': []});

      await remote().delete(entry);

      final request = server.received('POST', _filePath).single;
      expect(request.query, {
        'method': 'filemanager',
        'opera': 'delete',
        'access_token': 'AT',
      });
      expect(
        request.headers['content-type'],
        startsWith('application/x-www-form-urlencoded'),
      );
      expect(request.form, {
        'async': '0',
        'filelist': jsonEncode(['/apps/Jotsy/x.zip']),
      });
    });

    test('an already missing file (errno -9) is not an error', () async {
      server.json('POST', _filePath, (_) => {'errno': -9});

      await remote().delete(entry);

      expect(server.received('POST', _filePath), hasLength(1));
    });
  });

  group('token handling', () {
    void serveRefresh() => server.json(
      'GET',
      '/oauth/2.0/token',
      (_) => {
        'access_token': 'AT2',
        'refresh_token': 'RT2',
        'expires_in': 2592000,
      },
    );

    test('errno 111 refreshes once and retries with the new token', () async {
      serveRefresh();
      server.json(
        'GET',
        _filePath,
        (request) => request.query['access_token'] == 'AT'
            ? {'errno': 111, 'errmsg': 'access token invalid'}
            : {'errno': 0, 'list': []},
      );

      expect(await remote().list(), isEmpty);

      expect(
        server.received('GET', _filePath).map((r) => r.query['access_token']),
        ['AT', 'AT2'],
      );
      final refresh = server.received('GET', '/oauth/2.0/token').single;
      expect(refresh.query, {
        'grant_type': 'refresh_token',
        'refresh_token': 'RT',
        'client_id': 'ak',
        'client_secret': 'sk',
      });
      expect(refreshed.single.accessToken, 'AT2');
      expect(refreshed.single.refreshToken, 'RT2');
    });

    test('errno -6 on a form request resends the same form', () async {
      serveRefresh();
      server.json(
        'POST',
        _filePath,
        (request) => request.query['access_token'] == 'AT'
            ? {'errno': -6}
            : {'errno': 0},
      );

      await remote().delete(
        const CloudBackupEntry(
          fileName: 'x.zip',
          remoteId: '1:/apps/Jotsy/x.zip',
        ),
      );

      final calls = server.received('POST', _filePath);
      expect(calls.map((r) => r.query['access_token']), ['AT', 'AT2']);
      expect(calls.last.form, calls.first.form);
      expect(calls.last.form['filelist'], jsonEncode(['/apps/Jotsy/x.zip']));
    });

    test(
      'a rejected refresh token (invalid_grant) expires the session',
      () async {
        server.json(
          'GET',
          '/oauth/2.0/token',
          (_) => {
            'error': 'invalid_grant',
            'error_description': 'refresh token has been used',
          },
          status: 400,
        );
        server.json('GET', _filePath, (_) => {'errno': 111});

        await expectLater(
          remote().list(),
          _fails(CloudBackupFailure.sessionExpired),
        );
        expect(server.received('GET', _filePath), hasLength(1));
        expect(refreshed, isEmpty);
      },
    );

    test(
      'a token still rejected after refreshing is not retried again',
      () async {
        serveRefresh();
        server.json('GET', _filePath, (_) => {'errno': -6});

        await expectLater(
          remote().list(),
          _fails(CloudBackupFailure.sessionExpired),
        );
        expect(server.received('GET', _filePath), hasLength(2));
        expect(server.received('GET', '/oauth/2.0/token'), hasLength(1));
      },
    );
  });

  group('errno mapping', () {
    test('errno 31034 (rate limit) maps to rateLimited', () async {
      server.json('GET', _filePath, (_) => {'errno': 31034});

      await expectLater(
        remote().list(),
        _fails(CloudBackupFailure.rateLimited),
      );
    });

    for (final (errno, failure) in [
      (-10, CloudBackupFailure.storageFull),
      (31064, CloudBackupFailure.config),
    ]) {
      test('precreate errno $errno maps to ${failure.name}', () async {
        final file = await tempFile(_bytes(100, 5));
        serveUserInfo();
        server.json('POST', _filePath, (_) => {'errno': errno});

        await expectLater(
          remote().upload(file: file, fileName: 'x.zip'),
          _fails(failure),
        );
        expect(
          server.received('POST', '/pcs/rest/2.0/pcs/superfile2'),
          isEmpty,
        );
      });
    }

    test('an unknown non-zero errno on HTTP 200 is a protocol error', () async {
      server.json('GET', _filePath, (_) => {'errno': 987654});

      await expectLater(remote().list(), _fails(CloudBackupFailure.protocol));
    });
  });
}

Matcher _fails(CloudBackupFailure failure) => throwsA(
  isA<CloudBackupException>().having((e) => e.failure, 'failure', failure),
);

/// 确定性的伪随机字节：每个分片内容不同，MD5 也就各不相同。
Uint8List _bytes(int length, int seed) {
  final data = Uint8List(length);
  var state = seed;
  for (var i = 0; i < length; i++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    data[i] = state >> 16;
  }
  return data;
}

List<String> _sliceMd5s(Uint8List data) => [
  for (var start = 0; start < data.length; start += _slice)
    md5
        .convert(data.sublist(start, min(start + _slice, data.length)))
        .toString(),
];

/// 拆出 superfile2 的单文件 multipart 请求体：分段头与文件字节。
({String headers, List<int> bytes}) _multipartFile(FakeDriveRequest request) {
  final contentType = request.headers['content-type'] ?? '';
  final boundary = RegExp(
    r'^multipart/form-data; boundary=(\S+)$',
  ).firstMatch(contentType)?.group(1);
  expect(boundary, isNotNull, reason: contentType);
  final body = request.body;
  final opening = ascii.encode('--$boundary\r\n');
  final closing = ascii.encode('\r\n--$boundary--\r\n');
  expect(body.sublist(0, opening.length), opening);
  expect(body.sublist(body.length - closing.length), closing);
  final separator = ascii.encode('\r\n\r\n');
  var headerEnd = -1;
  for (var i = opening.length; i + separator.length <= body.length; i++) {
    var hit = true;
    for (var j = 0; j < separator.length; j++) {
      if (body[i + j] != separator[j]) {
        hit = false;
        break;
      }
    }
    if (hit) {
      headerEnd = i;
      break;
    }
  }
  expect(headerEnd, greaterThan(0));
  return (
    headers: utf8.decode(body.sublist(opening.length, headerEnd)),
    bytes: body.sublist(
      headerEnd + separator.length,
      body.length - closing.length,
    ),
  );
}

/// 所有连接（含 https 地址）都接到假服务的明文端口。HttpClient 设置
/// connectionFactory 且不走代理时，https 请求直接使用返回的 socket、不做
/// TLS 握手，因此不联网也能验证客户端实际选中的主机（看 Host 头）。
CloudBackupHttp _routedHttp(FakeDriveServer server) => CloudBackupHttp(
  clientFactory: () => realFixtureHttpClient()
    ..findProxy = ((_) => 'DIRECT')
    ..connectionFactory = (uri, proxyHost, proxyPort) =>
        Socket.startConnect(InternetAddress.loopbackIPv4, server.base.port),
);
