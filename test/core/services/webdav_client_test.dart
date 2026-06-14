import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/webdav_client.dart';
import 'package:node_diary/core/services/webdav_models.dart';

void main() {
  late Directory tempDir;
  late HttpServer server;
  late List<_RecordedRequest> requests;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jotsy_webdav_test_');
    await Directory('${tempDir.path}/dav').create();
    requests = <_RecordedRequest>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _serveWebDav(server, tempDir, requests);
  });

  tearDown(() async {
    await server.close(force: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  WebDavConfig config({String remoteDirectory = '/jotsy/nested/'}) {
    return WebDavConfig(
      serverUrl: 'http://${server.address.host}:${server.port}/dav/',
      username: 'alice',
      password: 'secret',
      remoteDirectory: remoteDirectory,
    );
  }

  test('sends Basic auth and recursively creates NAS directories', () async {
    final client = WebDavClient(config: config());

    await client.ensureDirectory(config().normalizedRemoteDirectory);

    final mkcolPaths =
        requests
            .where((request) => request.method == 'MKCOL')
            .map((request) => request.path)
            .toList();
    expect(mkcolPaths, contains('/dav/jotsy/'));
    expect(mkcolPaths, contains('/dav/jotsy/nested/'));
    expect(
      requests.every(
        (request) =>
            request.authorization ==
            'Basic ${base64Encode(utf8.encode('alice:secret'))}',
      ),
      isTrue,
    );
  });

  test(
    'uploads and downloads files without loading whole backup in client API',
    () async {
      final client = WebDavClient(config: config());
      final local = File('${tempDir.path}/local.zip');
      await local.writeAsString('backup-body');

      await client.ensureDirectory(config().normalizedRemoteDirectory);
      await client.putFile(
        remotePath: '/jotsy/nested/jotsy_backup_20260615_100000.zip',
        file: local,
      );
      final downloaded = File('${tempDir.path}/download.zip');
      await client.downloadFile(
        remotePath: '/jotsy/nested/jotsy_backup_20260615_100000.zip',
        targetFile: downloaded,
      );

      expect(await downloaded.readAsString(), 'backup-body');
      expect(
        requests.where((request) => request.method == 'PUT').single.body,
        'backup-body',
      );
    },
  );

  test('parses PROPFIND multistatus and skips directories', () async {
    final client = WebDavClient(config: config());
    await client.ensureDirectory(config().normalizedRemoteDirectory);
    await File(
      '${tempDir.path}/dav/jotsy/nested/jotsy_backup_20260615_100000.zip',
    ).writeAsString('zip-a');
    await File(
      '${tempDir.path}/dav/jotsy/nested/manifest.json',
    ).writeAsString('{}');

    final files = await client.listFiles('/jotsy/nested/');

    expect(files.map((file) => file.fileName), contains('manifest.json'));
    expect(
      files.where((file) => file.fileName.endsWith('.zip')).single.path,
      '/jotsy/nested/jotsy_backup_20260615_100000.zip',
    );
  });

  test('maps WebDAV error status to readable exception', () async {
    final client = WebDavClient(config: config(remoteDirectory: '/forbidden/'));

    await expectLater(
      client.listFiles('/forbidden/'),
      throwsA(
        isA<WebDavException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.isUnauthorized, 'isUnauthorized', isTrue),
      ),
    );
  });
}

void _serveWebDav(
  HttpServer server,
  Directory root,
  List<_RecordedRequest> requests,
) {
  server.listen((HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    requests.add(
      _RecordedRequest(
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        body: body,
      ),
    );

    final expectedAuth = 'Basic ${base64Encode(utf8.encode('alice:secret'))}';
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        expectedAuth) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    if (request.uri.path.startsWith('/dav/forbidden')) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final target = _targetEntity(root, request.uri.path);
    switch (request.method) {
      case 'MKCOL':
        final dir = Directory(target.path);
        if (await dir.exists()) {
          request.response.statusCode = HttpStatus.methodNotAllowed;
        } else {
          await dir.create(recursive: false);
          request.response.statusCode = HttpStatus.created;
        }
        break;
      case 'PROPFIND':
        final dir = Directory(target.path);
        if (!await dir.exists()) {
          request.response.statusCode = HttpStatus.notFound;
          break;
        }
        request.response.statusCode = 207;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        request.response.write(await _multistatusXml(root, dir));
        break;
      case 'PUT':
        final file = File(target.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(body, flush: true);
        request.response.statusCode = HttpStatus.created;
        break;
      case 'GET':
        final file = File(target.path);
        if (!await file.exists()) {
          request.response.statusCode = HttpStatus.notFound;
          break;
        }
        request.response.statusCode = HttpStatus.ok;
        await request.response.addStream(file.openRead());
        break;
      case 'DELETE':
        final file = File(target.path);
        if (await file.exists()) {
          await file.delete();
          request.response.statusCode = HttpStatus.noContent;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        break;
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
    }
    await request.response.close();
  });
}

FileSystemEntity _targetEntity(Directory root, String uriPath) {
  final decoded = Uri.decodeComponent(uriPath);
  final relative = decoded.replaceFirst(RegExp(r'^/'), '');
  return File('${root.path}/$relative');
}

Future<String> _multistatusXml(Directory root, Directory dir) async {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<D:multistatus xmlns:D="DAV:">',
  );
  final dirHref =
      '/${dir.path.substring(root.path.length + 1).replaceAll('\\', '/')}/';
  buffer.write(
    '<D:response><D:href>$dirHref</D:href><D:propstat><D:prop>'
    '<D:resourcetype><D:collection /></D:resourcetype>'
    '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>',
  );
  await for (final entity in dir.list(followLinks: false)) {
    final href =
        '/${entity.path.substring(root.path.length + 1).replaceAll('\\', '/')}';
    final stat = await entity.stat();
    final isDirectory = entity is Directory;
    buffer.write(
      '<D:response><D:href>${isDirectory ? '$href/' : href}</D:href>',
    );
    buffer.write('<D:propstat><D:prop>');
    if (isDirectory) {
      buffer.write('<D:resourcetype><D:collection /></D:resourcetype>');
    } else {
      buffer.write('<D:resourcetype />');
      buffer.write('<D:getcontentlength>${stat.size}</D:getcontentlength>');
      buffer.write(
        '<D:getlastmodified>${HttpDate.format(stat.modified.toUtc())}</D:getlastmodified>',
      );
      buffer.write('<D:getetag>"${stat.size}"</D:getetag>');
    }
    buffer.write(
      '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>',
    );
  }
  buffer.write('</D:multistatus>');
  return buffer.toString();
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.path,
    required this.authorization,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final String body;
}
