import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const galChannel = MethodChannel('gal');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const service = VideoExportService();
  late Directory root;
  late File file;
  HttpOverrides? originalHttpOverrides;
  final savedPaths = <String>[];

  setUp(() async {
    originalHttpOverrides = HttpOverrides.current;
    // 本地 HttpServer 验证真实文件流；替换 Flutter 默认返回 400 的 HTTP stub。
    HttpOverrides.global = _VideoExportHttpOverrides();
    savedPaths.clear();
    root = await Directory.systemTemp.createTemp('jotsy_video_export_test_');
    file = File(p.join(root.path, '旅行 视频.mp4'));
    await file.writeAsBytes([1, 2, 3, 4]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galChannel, (call) async {
          if (call.method == 'putVideo') {
            savedPaths.add((call.arguments as Map)['path'] as String);
            return null;
          }
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() async {
    HttpOverrides.global = originalHttpOverrides;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await root.delete(recursive: true);
  });

  test(
    'local video and encoded URI export by path without modifying the source',
    () async {
      await service.saveToGallery(file.path);
      await service.saveToGallery(file.uri.toString());
      expect(savedPaths, [file.path, file.path]);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test('empty or missing video never reaches the gallery saver', () async {
    for (final source in ['', p.join(root.path, 'missing.mp4')]) {
      await expectLater(
        service.saveToGallery(source),
        throwsA(
          isA<VideoExportException>().having(
            (error) => error.type,
            'type',
            VideoExportFailure.missingFile,
          ),
        ),
      );
    }
    expect(savedPaths, isEmpty);
  });

  test(
    'denied gallery access leaves the source intact and reports permission failure',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galChannel, (_) async => false);
      await expectLater(
        service.saveToGallery(file.path),
        throwsA(
          isA<VideoExportException>().having(
            (error) => error.type,
            'type',
            VideoExportFailure.permissionDenied,
          ),
        ),
      );
      expect(savedPaths, isEmpty);
      expect(await file.exists(), isTrue);
    },
  );

  for (final error in {
    'NOT_ENOUGH_SPACE': VideoExportFailure.notEnoughSpace,
    'NOT_SUPPORTED_FORMAT': VideoExportFailure.unsupportedFormat,
  }.entries) {
    test(
      'native ${error.key} maps to a localized export failure category',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(galChannel, (call) async {
              if (call.method == 'putVideo') {
                throw PlatformException(code: error.key);
              }
              return true;
            });
        await expectLater(
          service.saveToGallery(file.path),
          throwsA(
            isA<VideoExportException>().having(
              (e) => e.type,
              'type',
              error.value,
            ),
          ),
        );
        expect(await file.exists(), isTrue);
      },
    );
  }

  test(
    'remote video downloads as a stream then removes only its temporary copy',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      unawaited(
        server.forEach((request) async {
          request.response.headers.contentType = ContentType('video', 'mp4');
          request.response.add([5, 6]);
          request.response.add([7, 8]);
          await request.response.close();
        }),
      );
      List<int>? savedBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galChannel, (call) async {
            if (call.method == 'putVideo') {
              final path = (call.arguments as Map)['path'] as String;
              savedPaths.add(path);
              savedBytes = await File(path).readAsBytes();
              return null;
            }
            return true;
          });
      await service.saveToGallery('http://127.0.0.1:${server.port}/video.mp4');
      expect(savedBytes, [5, 6, 7, 8]);
      expect(await File(savedPaths.single).exists(), isFalse);
      expect(await file.exists(), isTrue);
    },
  );

  test('failed remote download never saves a partial video', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(
      server.forEach((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }),
    );
    await expectLater(
      service.saveToGallery('http://127.0.0.1:${server.port}/missing.mp4'),
      throwsA(
        isA<VideoExportException>().having(
          (error) => error.type,
          'type',
          VideoExportFailure.downloadFailed,
        ),
      ),
    );
    expect(savedPaths, isEmpty);
    expect((await root.list().toList()).whereType<Directory>(), isEmpty);
  });
}

class _VideoExportHttpOverrides extends HttpOverrides {}
