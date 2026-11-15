import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/recording_keep_alive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  const texts = RecordingNoticeTexts(
    recording: '正在录音',
    paused: '录音已暂停',
    hint: '点按回到正在写的日记',
    channelName: '录音',
  );

  test('notice texts pick the title by state and carry the elapsed time', () {
    final recording = texts.notice(
      paused: false,
      elapsed: const Duration(seconds: 3),
    );
    expect(recording.toArguments(), <String, Object>{
      'title': '正在录音',
      'text': '点按回到正在写的日记',
      'channelName': '录音',
      'paused': false,
      'elapsedMs': 3000,
    });
    final paused = texts.notice(paused: true, elapsed: Duration.zero);
    expect(paused.title, '录音已暂停');
    expect(paused.paused, isTrue);
  });

  group('PlatformRecordingKeepAlive', () {
    const channel = MethodChannel('com.jotsy.diary/recording_service');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('desktop keeps capturing without any native service', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final keepAlive = PlatformRecordingKeepAlive();
      expect(
        await keepAlive.start(
          texts.notice(paused: false, elapsed: Duration.zero),
        ),
        isTrue,
      );
      await keepAlive.update(
        texts.notice(paused: true, elapsed: Duration.zero),
      );
      await keepAlive.stop();
      expect(calls, isEmpty);
    });

    test('iOS and Linux pause on leaving the app', () async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        final keepAlive = PlatformRecordingKeepAlive();
        expect(
          await keepAlive.start(
            texts.notice(paused: false, elapsed: Duration.zero),
          ),
          isFalse,
          reason: '$platform',
        );
      }
      expect(calls, isEmpty);
    });

    test(
      'Android without its native channel (tests, other hosts) answers false',
      () async {
        // 测试默认目标平台为 Android，但宿主不是 Android 真机：不得调用通道。
        final keepAlive = PlatformRecordingKeepAlive();
        expect(
          await keepAlive.start(
            texts.notice(paused: false, elapsed: Duration.zero),
          ),
          isFalse,
        );
        await keepAlive.update(
          texts.notice(paused: true, elapsed: Duration.zero),
        );
        await keepAlive.stop();
        expect(calls, isEmpty);
      },
    );
  });
}
