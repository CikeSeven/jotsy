import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_s3.dart';
import 'package:node_diary/core/services/cloud_backup_s3_signer.dart';
import 'package:xml/xml.dart';

import '../../support/fake_drive_server.dart';
import '../../support/webdav_test_server.dart';

const _objectPath = '/backup/jotsy/x.zip';
const _entry = CloudBackupEntry(fileName: 'x.zip', remoteId: 'jotsy/x.zip');

void main() {
  group('S3Signer', () {
    // AWS 文档 “Signature Calculations for the Authorization Header” 的示例。
    const signer = S3Signer(
      accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      region: 'us-east-1',
    );

    S3SignedRequest signExample(Map<String, String> query) => signer.sign(
      method: 'GET',
      scheme: 'https',
      host: 'examplebucket.s3.amazonaws.com',
      port: null,
      pathSegments: const [],
      query: query,
      payloadHash: S3Signer.emptyPayloadHash,
      now: DateTime.utc(2013, 5, 24),
    );

    String expectedAuthorization(String signature) =>
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=$signature';

    test('empty payload hash is the SHA-256 of an empty body', () {
      expect(
        S3Signer.emptyPayloadHash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('GET ?lifecycle matches the AWS documentation signature', () {
      final signed = signExample(const {'lifecycle': ''});

      expect(
        signed.headers[HttpHeaders.authorizationHeader],
        expectedAuthorization(
          'fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543',
        ),
      );
      expect(signed.headers['x-amz-date'], '20130524T000000Z');
      expect(signed.headers['x-amz-content-sha256'], S3Signer.emptyPayloadHash);
      expect(
        signed.uri.toString(),
        'https://examplebucket.s3.amazonaws.com/?lifecycle=',
      );
    });

    test(
      'GET ?max-keys=2&prefix=J matches the AWS documentation signature',
      () {
        // 查询参数按键名排序后签名，与传入顺序无关。
        final signed = signExample(const {'prefix': 'J', 'max-keys': '2'});

        expect(
          signed.headers[HttpHeaders.authorizationHeader],
          expectedAuthorization(
            '34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
          ),
        );
        expect(
          signed.uri.toString(),
          'https://examplebucket.s3.amazonaws.com/?max-keys=2&prefix=J',
        );
      },
    );

    test('awsUriEncode keeps only unreserved characters', () {
      expect(S3Signer.awsUriEncode('a b+c/中'), 'a%20b%2Bc%2F%E4%B8%AD');
      expect(S3Signer.awsUriEncode('AZaz09-._~'), 'AZaz09-._~');
      expect(S3Signer.awsUriEncode('=&@:!*'), '%3D%26%40%3A%21%2A');
    });

    test('the signed URI keeps the exact percent-encoding that was signed', () {
      final signed = signer.sign(
        method: 'PUT',
        scheme: 'http',
        host: '127.0.0.1',
        port: 9000,
        pathSegments: const ['backup', 'jotsy', 'a b+c=中.zip'],
        query: const {'uploadId': 'u+1/2=', 'partNumber': '1'},
        payloadHash: S3Signer.emptyPayloadHash,
        now: DateTime.utc(2026, 10, 16),
      );

      // Dart 的 Uri 不会主动编码 + = 等字符；这里必须保留签名时的 %2B/%3D。
      expect(signed.uri.path, '/backup/jotsy/a%20b%2Bc%3D%E4%B8%AD.zip');
      expect(signed.uri.query, 'partNumber=1&uploadId=u%2B1%2F2%3D');
      expect(signed.uri.queryParameters['uploadId'], 'u+1/2=');
      expect(signed.uri.authority, '127.0.0.1:9000');
    });
  });

  group('S3BackupConfig', () {
    S3BackupConfig config({
      String endpoint = 'https://s3.example.com',
      String region = 'us-east-1',
      String bucket = 'backup',
      String accessKeyId = 'AK',
      String secretAccessKey = 'SK',
      String prefix = 'jotsy/',
    }) => S3BackupConfig(
      endpoint: endpoint,
      region: region,
      bucket: bucket,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      prefix: prefix,
    );

    test('an endpoint without a scheme defaults to https', () {
      expect(
        config(endpoint: ' oss-cn-hangzhou.aliyuncs.com ').endpointUri,
        Uri.parse('https://oss-cn-hangzhou.aliyuncs.com'),
      );
      expect(
        config(endpoint: 'http://127.0.0.1:9000').endpointUri,
        Uri.parse('http://127.0.0.1:9000'),
      );
    });

    test('empty, hostless or non-http endpoints are config errors', () {
      for (final endpoint in ['', '   ', 'https://', 'ftp://s3.example.com']) {
        expect(
          () => config(endpoint: endpoint).validate(),
          _failsWith(CloudBackupFailure.config),
          reason: endpoint,
        );
      }
    });

    test('prefix is normalized to slash-separated segments ending in /', () {
      expect(config(prefix: 'jotsy').normalizedPrefix, 'jotsy/');
      expect(config(prefix: '/a//b/./../c/').normalizedPrefix, 'a/b/c/');
      expect(
        config(prefix: r'\backups\jotsy').normalizedPrefix,
        'backups/jotsy/',
      );
      expect(config(prefix: ' / ').normalizedPrefix, '');
      expect(config(prefix: '').normalizedPrefix, '');
    });

    test('bucket names and keys are validated', () {
      expect(config(bucket: 'my-bucket-1250000000').validate(), isNotNull);
      expect(config(bucket: 'my_bucket.v2').validate(), isNotNull);
      for (final bucket in ['', 'a', 'Backup', '-backup', 'back up']) {
        expect(
          () => config(bucket: bucket).validate(),
          _failsWith(CloudBackupFailure.config),
          reason: bucket,
        );
      }
      expect(
        () => config(accessKeyId: ' ').validate(),
        _failsWith(CloudBackupFailure.config),
      );
      expect(
        () => config(secretAccessKey: '').validate(),
        _failsWith(CloudBackupFailure.config),
      );
    });

    test('a blank region signs as us-east-1', () {
      expect(config(region: '  ').signingRegion, 'us-east-1');
      expect(config(region: ' auto ').signingRegion, 'auto');
    });

    test('the remote refuses an invalid config before any request', () {
      expect(
        () => S3BackupRemote(config: config(bucket: 'Invalid Bucket')),
        _failsWith(CloudBackupFailure.config),
      );
    });

    test('toJson trims fields and stores the normalized prefix', () {
      final json = config(
        endpoint: ' https://s3.example.com ',
        bucket: ' backup ',
        accessKeyId: ' AK ',
        prefix: '/team/jotsy',
      ).toJson();

      expect(json, {
        'endpoint': 'https://s3.example.com',
        'region': 'us-east-1',
        'bucket': 'backup',
        'accessKeyId': 'AK',
        'secretAccessKey': 'SK',
        'prefix': 'team/jotsy/',
        'pathStyle': false,
      });
      final restored = S3BackupConfig.fromJson(json);
      expect(restored.normalizedPrefix, 'team/jotsy/');
      expect(restored.pathStyle, isFalse);
    });
  });

  group('S3BackupRemote', () {
    late FakeDriveServer server;
    late CloudBackupHttp http;
    late Directory tempDir;
    final extraHttp = <CloudBackupHttp>[];
    final now = DateTime.utc(2026, 10, 16, 8, 30);

    setUp(() async {
      server = await FakeDriveServer.start();
      http = server.http();
      tempDir = await Directory.systemTemp.createTemp('jotsy_s3_test_');
    });

    tearDown(() async {
      // 每个用例收到的每个请求都按 SigV4 独立重算签名并核对载荷摘要。
      for (final request in server.requests) {
        _expectValidSignature(request);
      }
      http.close();
      for (final client in extraHttp) {
        client.close();
      }
      extraHttp.clear();
      await server.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    S3BackupConfig config({
      String? endpoint,
      bool pathStyle = true,
      String prefix = 'jotsy/',
    }) => S3BackupConfig(
      endpoint: endpoint ?? server.base.toString(),
      region: 'us-east-1',
      bucket: 'backup',
      accessKeyId: 'AK',
      secretAccessKey: 'SK',
      prefix: prefix,
      pathStyle: pathStyle,
    );

    S3BackupRemote remote({
      S3BackupConfig? using,
      CloudBackupHttp? client,
      int multipartThreshold = 1024,
      int partSize = 1000,
    }) => S3BackupRemote(
      config: using ?? config(),
      http: client ?? http,
      clock: () => now,
      multipartThreshold: multipartThreshold,
      partSize: partSize,
    );

    Future<File> tempFile(List<int> bytes) async {
      final file = File('${tempDir.path}/local.zip');
      await file.writeAsBytes(bytes);
      return file;
    }

    void xml(
      String method,
      String path,
      String Function(FakeDriveRequest request) body, {
      int status = 200,
    }) {
      server.on(method, path, (request, response) {
        response.statusCode = status;
        response.headers.contentType = ContentType('application', 'xml');
        response.write(body(request));
      });
    }

    String error(String code) =>
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Error><Code>$code</Code><Message>m</Message>'
        '<RequestId>r</RequestId></Error>';

    group('upload', () {
      test('a file under the threshold is sent with a single PUT', () async {
        final data = _bytes(600, 1);
        final file = await tempFile(data);
        const name = 'jotsy_backup_20261016_083000.zip';
        server.on('PUT', '/backup/jotsy/$name', (request, response) {
          response.headers.set('ETag', '"abc"');
        });
        final progress = <int>[];

        final entry = await remote().upload(
          file: file,
          fileName: name,
          onProgress: (transferred, _) => progress.add(transferred),
        );

        expect(entry.remoteId, 'jotsy/$name');
        expect(entry.size, 600);
        expect(progress.last, 600);
        final put = server.requests.single;
        expect(put.method, 'PUT');
        expect(put.uri.path, '/backup/jotsy/$name');
        expect(put.uri.query, isEmpty);
        expect(put.body, data);
        expect(put.headers['content-length'], '600');
        expect(put.headers['x-amz-date'], '20261016T083000Z');
        expect(
          put.headers['authorization'],
          startsWith(
            'AWS4-HMAC-SHA256 Credential=AK/20261016/us-east-1/s3/aws4_request',
          ),
        );
      });

      test('a large file uses multipart upload with parts in order', () async {
        final data = _bytes(2500, 2);
        final file = await tempFile(data);
        // UploadId 含 + / =：查询串编码与签名必须往返一致。
        const uploadId = 'UPL+1/x=';
        xml('POST', _objectPath, (request) {
          if (request.query.containsKey('uploads')) {
            return '<InitiateMultipartUploadResult '
                'xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
                '<Bucket>backup</Bucket><Key>jotsy/x.zip</Key>'
                '<UploadId>$uploadId</UploadId>'
                '</InitiateMultipartUploadResult>';
          }
          return '<CompleteMultipartUploadResult>'
              '<Key>jotsy/x.zip</Key><ETag>"final"</ETag>'
              '</CompleteMultipartUploadResult>';
        });
        server.on('PUT', _objectPath, (request, response) {
          response.headers.set('ETag', '"etag-${request.query['partNumber']}"');
        });
        final progress = <int>[];

        await remote().upload(
          file: file,
          fileName: 'x.zip',
          onProgress: (transferred, total) {
            expect(total, 2500);
            progress.add(transferred);
          },
        );

        final requests = server.requests;
        expect(requests.map((r) => r.method), [
          'POST',
          'PUT',
          'PUT',
          'PUT',
          'POST',
        ]);
        expect(requests.first.uri.query, 'uploads=');
        expect(requests.first.body, isEmpty);
        final parts = requests.sublist(1, 4);
        for (var index = 0; index < parts.length; index++) {
          final part = parts[index];
          expect(part.query, {
            'partNumber': '${index + 1}',
            'uploadId': uploadId,
          });
          final start = index * 1000;
          final end = start + 1000 < 2500 ? start + 1000 : 2500;
          expect(part.body, data.sublist(start, end));
        }
        final complete = requests.last;
        expect(complete.query, {'uploadId': uploadId});
        final document = XmlDocument.parse(complete.text);
        expect(document.rootElement.name.local, 'CompleteMultipartUpload');
        expect(
          [
            for (final part in document.findAllElements('Part'))
              (
                part.getElement('PartNumber')!.innerText,
                part.getElement('ETag')!.innerText,
              ),
          ],
          [('1', '"etag-1"'), ('2', '"etag-2"'), ('3', '"etag-3"')],
        );
        expect(progress.last, 2500);
        expect(server.received('DELETE', _objectPath), isEmpty);
      });

      test('a failed part aborts the multipart upload', () async {
        final file = await tempFile(_bytes(2500, 3));
        xml(
          'POST',
          _objectPath,
          (_) =>
              '<InitiateMultipartUploadResult><UploadId>U1</UploadId>'
              '</InitiateMultipartUploadResult>',
        );
        server.on('PUT', _objectPath, (request, response) {
          if (request.query['partNumber'] == '2') {
            response.statusCode = 500;
            response.write(error('InternalError'));
            return;
          }
          response.headers.set('ETag', '"p"');
        });
        server.on('DELETE', _objectPath, (request, response) {
          response.statusCode = 204;
        });

        await expectLater(
          remote().upload(file: file, fileName: 'x.zip'),
          _failsWith(CloudBackupFailure.network),
        );

        expect(server.received('PUT', _objectPath), hasLength(2));
        expect(server.received('DELETE', _objectPath).single.query, {
          'uploadId': 'U1',
        });
        // 只有 CreateMultipartUpload，没有 Complete。
        expect(server.received('POST', _objectPath), hasLength(1));
      });

      test(
        'an <Error> in a 200 CompleteMultipartUpload response throws',
        () async {
          final file = await tempFile(_bytes(1500, 4));
          xml('POST', _objectPath, (request) {
            if (request.query.containsKey('uploads')) {
              return '<InitiateMultipartUploadResult><UploadId>U2</UploadId>'
                  '</InitiateMultipartUploadResult>';
            }
            return error('InternalError');
          });
          server.on('PUT', _objectPath, (request, response) {
            response.headers.set('ETag', '"p${request.query['partNumber']}"');
          });
          server.on('DELETE', _objectPath, (request, response) {
            response.statusCode = 204;
          });

          await expectLater(
            remote().upload(file: file, fileName: 'x.zip'),
            throwsA(isA<CloudBackupException>()),
          );
          expect(server.received('DELETE', _objectPath).single.query, {
            'uploadId': 'U2',
          });
        },
      );
    });

    group('list', () {
      test('ListObjectsV2 pages through continuation tokens', () async {
        // 续页令牌是 base64，含 + / =。
        const token = 'tok+1/AB==';
        xml('GET', '/backup', (request) {
          if (request.query['continuation-token'] == null) {
            return '<?xml version="1.0" encoding="UTF-8"?>'
                '<ListBucketResult '
                'xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
                '<Name>backup</Name><Prefix>jotsy/</Prefix>'
                '<KeyCount>3</KeyCount><IsTruncated>true</IsTruncated>'
                '<NextContinuationToken>$token</NextContinuationToken>'
                '<Contents><Key>jotsy/</Key><Size>0</Size></Contents>'
                '<Contents><Key>jotsy/jotsy_backup_20261015_101112.zip</Key>'
                '<LastModified>2026-10-15T02:11:20.000Z</LastModified>'
                '<Size>2048</Size></Contents>'
                '<Contents><Key>jotsy/readme.txt</Key><Size>3</Size></Contents>'
                '<CommonPrefixes><Prefix>jotsy/old/</Prefix></CommonPrefixes>'
                '</ListBucketResult>';
          }
          return '<ListBucketResult '
              'xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
              '<IsTruncated>false</IsTruncated>'
              '<Contents><Key>jotsy/manual.zip</Key>'
              '<LastModified>2020-01-01T00:00:00.000Z</LastModified>'
              '<Size>42</Size></Contents>'
              '</ListBucketResult>';
        });

        final entries = await remote().list();

        expect(entries.map((entry) => entry.remoteId), [
          'jotsy/jotsy_backup_20261015_101112.zip',
          'jotsy/manual.zip',
        ]);
        expect(entries.first.fileName, 'jotsy_backup_20261015_101112.zip');
        expect(entries.first.size, 2048);
        expect(entries.first.createdAt, DateTime(2026, 10, 15, 10, 11, 12));
        expect(entries.first.updatedAt, DateTime.utc(2026, 10, 15, 2, 11, 20));
        expect(entries.last.size, 42);
        expect(entries.last.createdAt, DateTime.utc(2020));

        final requests = server.received('GET', '/backup');
        expect(requests, hasLength(2));
        expect(requests.first.query, {
          'list-type': '2',
          'delimiter': '/',
          'prefix': 'jotsy/',
        });
        expect(
          requests.first.uri.query,
          'delimiter=%2F&list-type=2&prefix=jotsy%2F',
        );
        expect(requests.last.query, {
          'list-type': '2',
          'delimiter': '/',
          'prefix': 'jotsy/',
          'continuation-token': token,
        });
      });

      test('prepare lists a single key to check access', () async {
        xml('GET', '/backup', (_) => '<ListBucketResult/>');

        await remote().prepare();

        expect(server.received('GET', '/backup').single.query['max-keys'], '1');
      });
    });

    group('download and delete', () {
      test('download writes the object bytes to the target', () async {
        final data = _bytes(3000, 5);
        server.on('GET', _objectPath, (request, response) {
          response.headers.contentType = ContentType.binary;
          response.add(data);
        });
        final target = File('${tempDir.path}/restore/x.zip');
        final progress = <int>[];

        await remote().download(
          entry: _entry,
          target: target,
          onProgress: (transferred, _) => progress.add(transferred),
        );

        expect(await target.readAsBytes(), data);
        expect(progress.last, 3000);
      });

      test('a missing object fails as notFound without a file', () async {
        xml('GET', _objectPath, (_) => error('NoSuchKey'), status: 404);
        final target = File('${tempDir.path}/x.zip');

        await expectLater(
          remote().download(entry: _entry, target: target),
          _failsWith(CloudBackupFailure.notFound),
        );
        expect(await target.exists(), isFalse);
      });

      test('delete sends DELETE for the object key', () async {
        server.on('DELETE', _objectPath, (request, response) {
          response.statusCode = 204;
        });

        await remote().delete(_entry);

        expect(
          server.received('DELETE', _objectPath).single.uri.query,
          isEmpty,
        );
      });

      test('delete tolerates 404 from compatible services', () async {
        xml('DELETE', _objectPath, (_) => error('NoSuchKey'), status: 404);

        await remote().delete(_entry);

        expect(server.received('DELETE', _objectPath), hasLength(1));
      });

      test('keys with reserved characters are sent as signed', () async {
        // 假服务按原始（已编码）路径路由。
        const encoded = '/backup/jotsy/a%20b%2Bc%3D%E4%B8%AD.zip';
        server.on('DELETE', encoded, (request, response) {
          response.statusCode = 204;
        });

        await remote().delete(
          const CloudBackupEntry(fileName: 'a', remoteId: 'jotsy/a b+c=中.zip'),
        );

        // 签名与原始请求行的一致性由 tearDown 的验签覆盖。
        expect(server.received('DELETE', encoded), hasLength(1));
      });
    });

    group('error mapping', () {
      for (final (status, code, failure) in [
        (403, 'InvalidAccessKeyId', CloudBackupFailure.unauthorized),
        (403, 'SignatureDoesNotMatch', CloudBackupFailure.unauthorized),
        (404, 'NoSuchBucket', CloudBackupFailure.config),
        (301, 'PermanentRedirect', CloudBackupFailure.config),
        (503, 'SlowDown', CloudBackupFailure.rateLimited),
      ]) {
        test('$code maps to ${failure.name}', () async {
          xml('GET', '/backup', (_) => error(code), status: status);

          await expectLater(remote().prepare(), _failsWith(failure));
        });
      }

      test('a bodiless 301 without Location is a config error', () async {
        // 区域不对时 S3 的 301 不带 Location；不能被当成网络错误。
        server.on('GET', '/backup', (request, response) {
          response.statusCode = 301;
        });

        await expectLater(
          remote().prepare(),
          _failsWith(CloudBackupFailure.config),
        );
      });

      test('a bodiless 500 falls back to the status code', () async {
        server.on('GET', '/backup', (request, response) {
          response.statusCode = 500;
        });

        await expectLater(
          remote().list(),
          _failsWith(CloudBackupFailure.network),
        );
      });
    });

    group('addressing', () {
      test(
        'path style keeps the endpoint base path before the bucket',
        () async {
          xml('GET', '/minio/backup', (_) => '<ListBucketResult/>');

          await remote(
            using: config(endpoint: server.url('minio/').toString()),
          ).list();

          expect(server.received('GET', '/minio/backup'), hasLength(1));
        },
      );

      test('virtual-hosted style puts the bucket in the host name', () async {
        // 所有连接（含 https 地址）都接到假服务的明文端口：HttpClient 设置
        // connectionFactory 且不走代理时 https 直接使用返回的 socket、不做
        // TLS 握手，所以不联网也能核对真实请求的 Host 头与路径。
        final routed = CloudBackupHttp(
          clientFactory: () => realFixtureHttpClient()
            ..findProxy = ((_) => 'DIRECT')
            ..connectionFactory = (uri, proxyHost, proxyPort) =>
                Socket.startConnect(
                  InternetAddress.loopbackIPv4,
                  server.base.port,
                ),
        );
        extraHttp.add(routed);
        xml('GET', '/', (_) => '<ListBucketResult/>');
        server.on('DELETE', '/jotsy/x.zip', (request, response) {
          response.statusCode = 204;
        });
        final virtual = remote(
          using: config(
            endpoint: 'https://s3.us-east-1.amazonaws.com',
            pathStyle: false,
          ),
          client: routed,
        );

        await virtual.list();
        await virtual.delete(_entry);

        final list = server.received('GET', '/').single;
        expect(list.headers['host'], 'backup.s3.us-east-1.amazonaws.com');
        expect(list.query['prefix'], 'jotsy/');
        final delete = server.received('DELETE', '/jotsy/x.zip').single;
        expect(delete.headers['host'], 'backup.s3.us-east-1.amazonaws.com');
      });
    });
  });
}

Matcher _failsWith(CloudBackupFailure failure) => throwsA(
  isA<CloudBackupException>().having((e) => e.failure, 'failure', failure),
);

Uint8List _bytes(int length, int seed) {
  final data = Uint8List(length);
  var state = seed;
  for (var i = 0; i < length; i++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    data[i] = state >> 16;
  }
  return data;
}

/// 独立按 SigV4 重算签名：规范路径与查询串取自服务端实际收到的原始请求行，
/// 所以既校验签名算法，也能发现“签名用的编码”与“真正发出的 URL”不一致。
/// 同时核对 `x-amz-content-sha256` 等于请求体的真实摘要。
void _expectValidSignature(FakeDriveRequest request) {
  final authorization = request.headers['authorization'] ?? '';
  expect(authorization, startsWith('AWS4-HMAC-SHA256 Credential=AK/'));
  final match = RegExp(
    r'^AWS4-HMAC-SHA256 Credential=AK/(\d{8})/([^/]+)/s3/aws4_request, '
    r'SignedHeaders=([a-z0-9;-]+), Signature=([0-9a-f]{64})$',
  ).firstMatch(authorization);
  expect(match, isNotNull, reason: authorization);
  final date = match!.group(1)!;
  final region = match.group(2)!;
  final signedHeaders = match.group(3)!;
  final payloadHash = request.headers['x-amz-content-sha256'];
  expect(payloadHash, sha256.convert(request.body).toString());

  final pairs = [
    for (final pair in request.uri.query.split('&'))
      if (pair.isNotEmpty)
        pair.contains('=')
            ? (
                pair.substring(0, pair.indexOf('=')),
                pair.substring(pair.indexOf('=') + 1),
              )
            : (pair, ''),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  final canonicalRequest = [
    request.method,
    request.uri.path.isEmpty ? '/' : request.uri.path,
    pairs.map((pair) => '${pair.$1}=${pair.$2}').join('&'),
    for (final name in signedHeaders.split(';'))
      '$name:${request.headers[name]!.trim()}',
    '',
    signedHeaders,
    payloadHash!,
  ].join('\n');
  final stringToSign = [
    'AWS4-HMAC-SHA256',
    request.headers['x-amz-date']!,
    '$date/$region/s3/aws4_request',
    sha256.convert(utf8.encode(canonicalRequest)).toString(),
  ].join('\n');
  List<int> hmac(List<int> key, String value) =>
      Hmac(sha256, key).convert(utf8.encode(value)).bytes;
  final key = hmac(
    hmac(hmac(hmac(utf8.encode('AWS4SK'), date), region), 's3'),
    'aws4_request',
  );
  expect(
    Hmac(sha256, key).convert(utf8.encode(stringToSign)).toString(),
    match.group(4),
    reason: canonicalRequest,
  );
}
