import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_video_gallery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.jotsy.diary/video_gallery');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Android gallery returns all selected videos in selection order',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return [
              {'name': '旅行 视频.mp4', 'path': '/cache/first.mp4', 'size': 1024},
              {'name': 'second.mov', 'path': '/cache/second.mov', 'size': 4096},
            ];
          });
      final files = await DiaryVideoGalleryService.pickAndroidVideos();
      expect(calls.single.method, 'pickVideos');
      expect(calls.single.arguments, isNull);
      expect(files!.map((file) => file.name), ['旅行 视频.mp4', 'second.mov']);
      expect(files.map((file) => file.path), [
        '/cache/first.mp4',
        '/cache/second.mov',
      ]);
      expect(files.map((file) => file.size), [1024, 4096]);
      expect(files.every((file) => file.bytes == null), isTrue);
    },
  );

  test('cancelling Android gallery returns no selected files', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await DiaryVideoGalleryService.pickAndroidVideos(), isNull);
  });

  test(
    'gallery or cache errors propagate to the import failure handler',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'video_copy_failed');
          });
      await expectLater(
        DiaryVideoGalleryService.pickAndroidVideos(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
