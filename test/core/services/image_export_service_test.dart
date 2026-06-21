import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isRemoteSource', () {
    test('识别 http/https 为网络源', () {
      expect(ImageExportService.isRemoteSource('http://a.com/x.jpg'), isTrue);
      expect(ImageExportService.isRemoteSource('https://a.com/x.png'), isTrue);
    });

    test('本地文件路径不是网络源', () {
      expect(
        ImageExportService.isRemoteSource('/data/app/diary_images/x.jpg'),
        isFalse,
      );
      expect(ImageExportService.isRemoteSource('file:///tmp/x.png'), isFalse);
    });

    test('前后空白不影响判定', () {
      expect(
        ImageExportService.isRemoteSource('  https://a.com/x.jpg  '),
        isTrue,
      );
    });
  });

  group('入参校验', () {
    const service = ImageExportService();

    test('空源保存时抛 invalidSource', () async {
      await expectLater(
        service.saveToGallery('   '),
        throwsA(
          isA<ImageExportException>().having(
            (ImageExportException e) => e.type,
            'type',
            ImageExportErrorType.invalidSource,
          ),
        ),
      );
    });

    test('空源分享时抛 invalidSource', () async {
      await expectLater(
        service.shareImage(''),
        throwsA(
          isA<ImageExportException>().having(
            (ImageExportException e) => e.type,
            'type',
            ImageExportErrorType.invalidSource,
          ),
        ),
      );
    });
  });

  group('远程图片下载缓存', () {
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const service = ImageExportService();
    const imageHost = 'image.test';

    late Directory tempDir;
    late HttpServer server;
    var requestCount = 0;
    final sharedPaths = <String>[];

    setUp(() async {
      ImageExportService.debugClearRemoteImageCache();
      requestCount = 0;
      sharedPaths.clear();
      tempDir = await Directory.systemTemp.createTemp('jotsy_image_export_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            if (call.method == 'getTemporaryDirectory') {
              return tempDir.path;
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            final arguments = call.arguments as Map<Object?, Object?>;
            final paths = arguments['paths'] as List<Object?>;
            sharedPaths.add(paths.single! as String);
            return 'success';
          });
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      HttpOverrides.global = _RedirectingHttpOverrides(
        host: imageHost,
        serverPort: server.port,
      );
    });

    tearDown(() async {
      HttpOverrides.global = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
      ImageExportService.debugClearRemoteImageCache();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('短时间分享同一远程图片复用临时文件且只下载一次', () async {
      unawaited(
        server.forEach((request) async {
          requestCount += 1;
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(<int>[1, 2]);
          request.response.add(<int>[3, 4]);
          await request.response.close();
        }),
      );

      await service.shareImage('https://$imageHost/a.png');
      await service.shareImage('https://$imageHost/a.png');

      expect(requestCount, 1);
      expect(sharedPaths, hasLength(2));
      expect(sharedPaths[0], sharedPaths[1]);
      expect(await File(sharedPaths.first).readAsBytes(), <int>[1, 2, 3, 4]);
    });

    test('并发分享同一远程图片复用同一次下载', () async {
      unawaited(
        server.forEach((request) async {
          requestCount += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          request.response.headers.contentType = ContentType('image', 'webp');
          request.response.add(<int>[9, 8, 7]);
          await request.response.close();
        }),
      );

      await Future.wait(<Future<void>>[
        service.shareImage('https://$imageHost/concurrent.webp'),
        service.shareImage('https://$imageHost/concurrent.webp'),
      ]);

      expect(requestCount, 1);
      expect(sharedPaths, hasLength(2));
      expect(sharedPaths[0], sharedPaths[1]);
      expect(await File(sharedPaths.first).readAsBytes(), <int>[9, 8, 7]);
    });

    test('超过大小上限的响应不落地分享', () async {
      unawaited(
        server.forEach((request) async {
          requestCount += 1;
          request.response.headers
            ..contentType = ContentType('image', 'jpeg')
            ..contentLength = 25 * 1024 * 1024;
          try {
            await request.response.close();
          } on HttpException {
            // 客户端会在读取正文前因 Content-Length 超限主动关闭连接。
          }
        }),
      );

      await expectLater(
        service.shareImage('https://$imageHost/huge.jpg'),
        throwsA(
          isA<ImageExportException>().having(
            (ImageExportException e) => e.type,
            'type',
            ImageExportErrorType.downloadFailed,
          ),
        ),
      );
      expect(requestCount, 1);
      expect(sharedPaths, isEmpty);
    });

    test('非图片响应不落地分享', () async {
      unawaited(
        server.forEach((request) async {
          requestCount += 1;
          request.response.headers.contentType = ContentType.text;
          request.response.write('not an image');
          await request.response.close();
        }),
      );

      await expectLater(
        service.shareImage('https://$imageHost/not-image.txt'),
        throwsA(
          isA<ImageExportException>().having(
            (ImageExportException e) => e.type,
            'type',
            ImageExportErrorType.downloadFailed,
          ),
        ),
      );
      expect(requestCount, 1);
      expect(sharedPaths, isEmpty);
    });
  });
}

class _RedirectingHttpOverrides extends HttpOverrides {
  _RedirectingHttpOverrides({required this.host, required this.serverPort});

  final String host;
  final int serverPort;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _RedirectingHttpClient(
      delegate: super.createHttpClient(context),
      host: host,
      serverPort: serverPort,
    );
  }
}

class _RedirectingHttpClient implements HttpClient {
  _RedirectingHttpClient({
    required this.delegate,
    required this.host,
    required this.serverPort,
  });

  final HttpClient delegate;
  final String host;
  final int serverPort;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (url.host == host) {
      return delegate.getUrl(
        url.replace(
          scheme: 'http',
          host: '127.0.0.1',
          port: serverPort,
        ),
      );
    }
    return delegate.getUrl(url);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
