import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/audio_recording_service.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/core/services/recording_keep_alive.dart';
import 'package:node_diary/ui/diaries/controllers/diary_recording_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:record/record.dart' show RecordState;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRecorder recorder;
  late FakeRecordingStorage storage;
  late FakeRecordingClock clock;
  late FakeKeepAlive keepAlive;
  late DiaryRecordingController controller;

  const texts = RecordingNoticeTexts(
    recording: 'Recording',
    paused: 'Paused',
    hint: 'Tap to return',
    channelName: 'Recordings',
  );

  setUp(() {
    recorder = FakeRecorder();
    storage = FakeRecordingStorage();
    clock = FakeRecordingClock();
    keepAlive = FakeKeepAlive(recorder);
    controller = DiaryRecordingController(
      recorder: recorder,
      storage: storage,
      keepAlive: keepAlive,
      clock: clock,
    );
  });

  tearDown(() async {
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    await recorder.stateController.close();
  });

  test('record pause resume finish returns one local audio file', () async {
    await controller.start();
    expect(controller.phase, DiaryRecordingPhase.recording);
    clock.elapse(const Duration(seconds: 2));

    await controller.pause();
    expect(controller.phase, DiaryRecordingPhase.paused);
    clock.elapse(const Duration(seconds: 5));
    expect(controller.elapsed, const Duration(seconds: 2));

    await controller.resume();
    clock.elapse(const Duration(seconds: 1));
    final recording = await controller.finish();

    expect(recording?.path, '/documents/diary_recordings/recording.m4a');
    expect(recording?.duration, const Duration(seconds: 3));
    expect(recorder.startCalls, 1);
    expect(recorder.pauseCalls, 1);
    expect(recorder.resumeCalls, 1);
    expect(recorder.stopCalls, 1);
    expect(storage.persistedPath, '/temporary/recording.m4a');
    expect(controller.phase, DiaryRecordingPhase.idle);
  });

  test(
    'permission can be granted and retried without restarting editor',
    () async {
      recorder.permission = false;
      await controller.start();
      expect(controller.failure, DiaryRecordingFailure.permissionDenied);
      expect(recorder.startCalls, 0);

      recorder.permission = true;
      await controller.start();
      expect(controller.phase, DiaryRecordingPhase.recording);
      expect(controller.failure, isNull);
      expect(recorder.permissionCalls, 2);
    },
  );

  test('capture failure is not misreported as denied permission', () async {
    recorder.startError = StateError('Audio device unavailable');
    await controller.start();
    expect(controller.failure, DiaryRecordingFailure.recordingFailed);
    expect(controller.phase, DiaryRecordingPhase.idle);
    expect(recorder.cancelCalls, 1);
    expect(storage.deletedPending, '/temporary/recording.m4a');
  });

  test(
    'cancel during permission request does not start microphone later',
    () async {
      final permission = Completer<bool>();
      recorder.permissionResult = permission.future;
      final starting = controller.start();
      await Future<void>.delayed(Duration.zero);
      final cancelling = controller.cancel();
      permission.complete(true);
      await starting;
      await cancelling;

      expect(recorder.startCalls, 0);
      expect(controller.phase, DiaryRecordingPhase.idle);
      expect(storage.persistedPath, isNull);
    },
  );

  test('cancel during file finalization never returns an attachment', () async {
    final persisted = Completer<String>();
    storage.persistResult = persisted.future;
    await controller.start();
    final finishing = controller.finish();
    await Future<void>.delayed(Duration.zero);
    final cancelling = controller.cancel();
    persisted.complete('/documents/diary_recordings/recording.m4a');

    expect(await finishing, isNull);
    await cancelling;
    expect(storage.deletedManaged, '/documents/diary_recordings/recording.m4a');
    expect(controller.phase, DiaryRecordingPhase.idle);
  });

  test('backgrounding pauses capture without automatically resuming', () async {
    await controller.start();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, DiaryRecordingPhase.paused);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.phase, DiaryRecordingPhase.paused);
    expect(recorder.resumeCalls, 0);
  });

  group('background capture (#251)', () {
    test(
      'keeps recording after leaving the app once the keep-alive runs',
      () async {
        await controller.start(notice: texts);
        expect(keepAlive.started, hasLength(1));
        expect(keepAlive.started.single.title, 'Recording');
        expect(keepAlive.started.single.paused, isFalse);
        // 保活在采音之前启动：Android 只允许前台应用启动麦克风前台服务。
        expect(keepAlive.startedBeforeCapture, isTrue);

        controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);

        expect(controller.phase, DiaryRecordingPhase.recording);
        expect(recorder.pauseCalls, 0);
      },
    );

    test(
      'still pauses on leaving the app when the service cannot start',
      () async {
        keepAlive.result = false;
        await controller.start(notice: texts);

        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);

        expect(controller.phase, DiaryRecordingPhase.paused);
        expect(recorder.pauseCalls, 1);
      },
    );

    test('a keep-alive that throws counts as unavailable', () async {
      keepAlive.startError = StateError('channel gone');
      await controller.start(notice: texts);
      expect(controller.phase, DiaryRecordingPhase.recording);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(controller.phase, DiaryRecordingPhase.paused);
    });

    test('the notice follows pause and resume and stops on finish', () async {
      await controller.start(notice: texts);
      clock.elapse(const Duration(seconds: 4));

      await controller.pause();
      expect(keepAlive.updates, hasLength(1));
      expect(keepAlive.updates.last.title, 'Paused');
      expect(keepAlive.updates.last.paused, isTrue);
      expect(keepAlive.updates.last.elapsed, const Duration(seconds: 4));

      await controller.resume();
      expect(keepAlive.updates, hasLength(2));
      expect(keepAlive.updates.last.title, 'Recording');
      expect(keepAlive.updates.last.paused, isFalse);
      expect(keepAlive.updates.last.elapsed, const Duration(seconds: 4));

      final recording = await controller.finish();
      expect(recording, isNotNull);
      expect(keepAlive.stopCalls, 1);
      expect(keepAlive.updates, hasLength(2));
    });

    test('a system interruption pause updates the notice too', () async {
      await controller.start(notice: texts);
      recorder.stateController.add(RecordState.pause);
      expect(controller.phase, DiaryRecordingPhase.paused);
      expect(keepAlive.updates.single.paused, isTrue);
    });

    test('cancel, a failed start and closing the page release it', () async {
      await controller.start(notice: texts);
      await controller.cancel();
      expect(keepAlive.stopCalls, 1);

      recorder.startError = StateError('Audio device unavailable');
      await controller.start(notice: texts);
      expect(controller.failure, DiaryRecordingFailure.recordingFailed);
      expect(keepAlive.stopCalls, 2);

      recorder.startError = null;
      await controller.start(notice: texts);
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(keepAlive.stopCalls, 3);
      // tearDown 再 dispose 一次。
      controller = DiaryRecordingController(
        recorder: recorder,
        storage: storage,
        keepAlive: keepAlive,
        clock: clock,
      );
    });

    test('denied permission never starts the keep-alive', () async {
      recorder.permission = false;
      await controller.start(notice: texts);
      expect(keepAlive.started, isEmpty);
      expect(keepAlive.stopCalls, 0);
    });

    test(
      'without notice texts it neither starts nor keeps recording',
      () async {
        await controller.start();
        expect(keepAlive.started, isEmpty);
        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        expect(controller.phase, DiaryRecordingPhase.paused);
      },
    );
  });

  test(
    'setting custom recording name and completing attaches name and waveform',
    () async {
      controller.setName('灵感闪现');
      expect(controller.name, '灵感闪现');

      await controller.start();
      clock.elapse(const Duration(milliseconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final recording = await controller.finish();
      expect(recording?.name, '灵感闪现');
      expect(recording?.waveform, isNotNull);
    },
  );

  test(
    'waveform is a live read-only view that grows while recording',
    () async {
      await controller.start();
      expect(controller.waveform, isEmpty);
      final view = controller.waveform;

      // 采样每 recordingAmplitudeSamplePeriod 一次；多等一个周期确保至少采到一个。
      await Future<void>.delayed(recordingAmplitudeSamplePeriod * 2);
      expect(view, isNotEmpty, reason: 'a view taken earlier must stay live');
      expect(view, everyElement(0.5));
      expect(() => controller.waveform.add(0.1), throwsUnsupportedError);

      // 暂停后不再采样，实时声纹据此静止。
      await controller.pause();
      final pausedLength = controller.waveform.length;
      await Future<void>.delayed(recordingAmplitudeSamplePeriod * 2);
      expect(controller.waveform.length, pausedLength);
    },
  );

  test(
    'starting a new session clears the previous amplitude history',
    () async {
      await controller.start();
      await Future<void>.delayed(recordingAmplitudeSamplePeriod * 2);
      expect(controller.waveform, isNotEmpty);

      await controller.cancel();
      await controller.start();
      expect(controller.waveform, isEmpty);
    },
  );
}

class FakeRecorder implements AudioRecordingService {
  final stateController = StreamController<RecordState>.broadcast(sync: true);
  bool permission = true;
  Future<bool>? permissionResult;
  Object? startError;
  int permissionCalls = 0;
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Stream<RecordState> get states => stateController.stream;
  @override
  Future<bool> hasPermission() async {
    permissionCalls++;
    return permissionResult ?? Future<bool>.value(permission);
  }

  @override
  Future<void> start(String path) async {
    startCalls++;
    if (startError != null) throw startError!;
    stateController.add(RecordState.record);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    stateController.add(RecordState.pause);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    stateController.add(RecordState.record);
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    stateController.add(RecordState.stop);
    return '/temporary/recording.m4a';
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<double> getAmplitude() async => 0.5;
}

class FakeKeepAlive implements RecordingKeepAlive {
  FakeKeepAlive(this.recorder);

  final FakeRecorder recorder;
  bool result = true;
  Object? startError;
  final List<RecordingNotice> started = [];
  final List<RecordingNotice> updates = [];
  int stopCalls = 0;
  bool _held = false;

  /// 保活启动时录音器是否还没开始采音。
  bool startedBeforeCapture = false;

  @override
  Future<bool> start(RecordingNotice notice) async {
    started.add(notice);
    startedBeforeCapture = recorder.startCalls == 0;
    if (startError != null) throw startError!;
    _held = result;
    return result;
  }

  @override
  Future<void> update(RecordingNotice notice) async {
    if (_held) updates.add(notice);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _held = false;
  }
}

class FakeRecordingStorage extends DiaryAudioStorageService {
  String? persistedPath;
  String? deletedPending;
  String? deletedManaged;
  Future<String>? persistResult;

  @override
  Future<String> createPendingPath() async => '/temporary/recording.m4a';
  @override
  Future<String> persistRecording(String path) async {
    persistedPath = path;
    return persistResult ??
        Future<String>.value('/documents/diary_recordings/recording.m4a');
  }

  @override
  Future<void> deletePendingRecording(String? path) async {
    if (path != null) deletedPending = path;
  }

  @override
  Future<void> deleteManagedRecording(String? path) async {
    deletedManaged = path;
  }
}

class FakeRecordingClock implements Stopwatch {
  Duration _elapsed = Duration.zero;
  bool _running = false;
  void elapse(Duration duration) {
    if (_running) _elapsed += duration;
  }

  @override
  Duration get elapsed => _elapsed;
  @override
  int get elapsedMicroseconds => _elapsed.inMicroseconds;
  @override
  int get elapsedMilliseconds => _elapsed.inMilliseconds;
  @override
  int get elapsedTicks => elapsedMicroseconds;
  @override
  int get frequency => 1000000;
  @override
  bool get isRunning => _running;
  @override
  void reset() => _elapsed = Duration.zero;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
}
