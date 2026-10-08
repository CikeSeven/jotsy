import 'dart:io';

import 'package:path/path.dart' as p;

// Flutter 的组件绑定默认拦截 HTTP；仅让 loopback 测试使用真实传输。
HttpClient realFixtureHttpClient() =>
    HttpOverrides.runWithHttpOverrides(HttpClient.new, _FixtureHttpOverrides());

class _FixtureHttpOverrides extends HttpOverrides {}

/// 本地 WebDAV 模拟服务保留 ZIP 字节；调用方负责关闭 server 和删除 root。
Future<HttpServer> startWebDavFixture(Directory root) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final path = p.join(root.path, request.uri.path.substring(1));
    switch (request.method) {
      case 'MKCOL':
        await request.drain<void>();
        final directory = Directory(path);
        if (await directory.exists()) {
          request.response.statusCode = 405;
        } else {
          await directory.create();
          request.response.statusCode = 201;
        }
      case 'PUT':
        final file = File(path);
        await file.parent.create(recursive: true);
        final sink = file.openWrite();
        try {
          await sink.addStream(request);
        } finally {
          await sink.close();
        }
        request.response.statusCode = 201;
      case 'GET':
        await request.drain<void>();
        final file = File(path);
        if (await file.exists()) {
          await request.response.addStream(file.openRead());
        } else {
          request.response.statusCode = 404;
        }
      case 'PROPFIND':
        await request.drain<void>();
        request.response.statusCode = 207;
        final xml = StringBuffer('<D:multistatus xmlns:D="DAV:">');
        await for (final file in Directory(path).list()) {
          if (file is! File) continue;
          final href = '/${p.relative(file.path, from: root.path)}';
          xml.write(
            '<D:response><D:href>$href</D:href><D:propstat><D:prop>'
            '<D:resourcetype/><D:getcontentlength>${await file.length()}</D:getcontentlength>'
            '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>',
          );
        }
        request.response.write('$xml</D:multistatus>');
      default:
        await request.drain<void>();
        request.response.statusCode = 405;
    }
    await request.response.close();
  });
  return server;
}
