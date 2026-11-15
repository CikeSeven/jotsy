import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_recording_service.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/core/services/recording_keep_alive.dart';
import 'package:node_diary/ui/diaries/models/diary_audio_waveform.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:record/record.dart' show RecordState;

/// Owns microphone capture, pause-excluding elapsed time and pending files.
/// SDK calls are serialized so closing during a permission prompt cannot leave
/// the microphone running after the page closes. A file becomes durable only
/// after stop succeeds; committed files belong to the document, not this panel.
///
/// 离开应用（熄屏、切到别的应用、最小化）时是否继续录音取决于
/// [RecordingKeepAlive]（#251）：开录时（应用在前台、权限已给）启动保活，
/// 它回答能在后台采音（Android 前台服务起来了、桌面）就继续录，否则照旧
/// 暂停——Android 后台应用没有前台服务只能录到静音。保活在录音结束、取消、
/// 失败与页面关闭时随待定文件一起释放（[_discardPending]）。
class DiaryRecordingController extends ChangeNotifier
    with WidgetsBindingObserver {
  DiaryRecordingController({
    AudioRecordingService? recorder,
    DiaryAudioStorageService? storage,
    RecordingKeepAlive? keepAlive,
    Stopwatch? clock,
  }) : _recorder = recorder ?? MicrophoneRecordingService(),
       _storage = storage ?? const DiaryAudioStorageService(),
       _keepAlive = keepAlive ?? PlatformRecordingKeepAlive(),
       _clock = clock ?? Stopwatch() {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioRecordingService _recorder;
  final DiaryAudioStorageService _storage;
  final RecordingKeepAlive _keepAlive;
  final Stopwatch _clock;
  Future<void> _operationTail = Future<void>.value();
  StreamSubscription<RecordState>? _stateSubscription;
  Timer? _timer;
  String? _pendingPath;
  bool _disposed = false;
  bool _hasNativeSession = false;
  int _generation = 0;

  // 后台保活：这次录音的通知文案、保活是否在用、离开应用后能否继续采音，
  // 以及通知上一次显示的是不是“已暂停”（只在录音 ↔ 暂停切换时刷新通知）。
  RecordingNoticeTexts? _noticeTexts;
  bool _keepAliveHeld = false;
  bool _capturesInBackground = false;
  bool? _noticePaused;

  DiaryRecordingPhase _phase = DiaryRecordingPhase.idle;
  DiaryRecordingFailure? _failure;
  final List<double> _waveform = [];
  String? _name;

  DiaryRecordingPhase get phase => _phase;
  DiaryRecordingFailure? get failure => _failure;
  Duration get elapsed => _clock.elapsed;

  /// 振幅采样的只读实时视图（旧→新），不做拷贝：实时声纹每个采样都会读取它，
  /// 全量拷贝会随录音时长线性变慢。视图随录音增长；`start()` 会清空它。
  List<double> get waveform => UnmodifiableListView<double>(_waveform);
  String? get name => _name;

  bool get hasSession =>
      _phase == DiaryRecordingPhase.recording ||
      _phase == DiaryRecordingPhase.paused;
  bool get isBusy =>
      _phase == DiaryRecordingPhase.preparing ||
      _phase == DiaryRecordingPhase.finishing;

  void setName(String? name) {
    _name = name?.trim().isEmpty ?? true ? null : name!.trim();
    notifyListeners();
  }

  /// 开始录音。[notice] 为离开应用后继续录音时通知用的文案；为空时不启用
  /// 后台保活，离开应用即暂停。
  Future<void> start({RecordingNoticeTexts? notice}) async {
    if (_disposed || _phase != DiaryRecordingPhase.idle) return;
    final generation = ++_generation;
    _noticeTexts = notice;
    _failure = null;
    _waveform.clear();
    _clock.reset();
    _setPhase(DiaryRecordingPhase.preparing);
    await _enqueue(() async {
      try {
        if (!await _recorder.hasPermission()) {
          if (!_isStale(generation)) {
            _failure = DiaryRecordingFailure.permissionDenied;
            _setPhase(DiaryRecordingPhase.idle);
          }
          return;
        }
        if (_isStale(generation)) return;
        _stateSubscription ??= _recorder.states.listen(
          _onNativeState,
          onError: (Object error) => unawaited(_failAndDiscard()),
        );
        _pendingPath = await _storage.createPendingPath();
        if (_isStale(generation)) return;
        // 保活必须在采音前、应用还在前台时启动（Android 不允许后台启动麦克风
        // 前台服务）。这之后变旧（取消、关闭页面）由随后排队的 _discardPending
        // 释放。
        await _acquireKeepAlive();
        if (_isStale(generation)) return;
        _hasNativeSession = true;
        await _recorder.start(_pendingPath!);
        if (_isStale(generation)) return;
        _clock.start();
        _setPhase(DiaryRecordingPhase.recording);
        _timer = Timer.periodic(recordingAmplitudeSamplePeriod, (_) async {
          if (!_disposed && _phase == DiaryRecordingPhase.recording) {
            final amp = await _recorder.getAmplitude();
            if (!_disposed && _phase == DiaryRecordingPhase.recording) {
              _waveform.add(amp);
              notifyListeners();
            }
          }
        });
      } catch (_) {
        await _discardPending();
        if (!_isStale(generation)) {
          _failure = DiaryRecordingFailure.recordingFailed;
          _setPhase(DiaryRecordingPhase.idle);
        }
      }
    });
  }

  Future<void> pause() async {
    if (_disposed || _phase != DiaryRecordingPhase.recording) return;
    final generation = _generation;
    _clock.stop();
    _setPhase(DiaryRecordingPhase.preparing);
    await _enqueue(() async {
      try {
        await _recorder.pause();
        if (!_isStale(generation)) _setPhase(DiaryRecordingPhase.paused);
      } catch (_) {
        if (!_isStale(generation)) {
          _failure = DiaryRecordingFailure.recordingFailed;
          _clock.start();
          _setPhase(DiaryRecordingPhase.recording);
        }
      }
    });
  }

  Future<void> resume() async {
    if (_disposed || _phase != DiaryRecordingPhase.paused) return;
    final generation = _generation;
    _failure = null;
    _setPhase(DiaryRecordingPhase.preparing);
    await _enqueue(() async {
      try {
        await _recorder.resume();
        if (!_isStale(generation)) {
          _clock.start();
          _setPhase(DiaryRecordingPhase.recording);
        }
      } catch (_) {
        if (!_isStale(generation)) {
          _failure = DiaryRecordingFailure.recordingFailed;
          _setPhase(DiaryRecordingPhase.paused);
        }
      }
    });
  }

  Future<DiaryAudioAttachment?> finish() async {
    if (_disposed || !hasSession) return null;
    final generation = _generation;
    _clock.stop();
    _timer?.cancel();
    _setPhase(DiaryRecordingPhase.finishing);
    return _enqueue(() async {
      try {
        final path = await _recorder.stop();
        _hasNativeSession = false;
        await _releaseKeepAlive();
        if (path == null || _isStale(generation)) return null;
        final durablePath = await _storage.persistRecording(path);
        _pendingPath = null;
        if (_isStale(generation)) {
          await _storage.deleteManagedRecording(durablePath);
          return null;
        }
        final compressedWaveform = compressRecordingWaveform(_waveform);
        final recording = DiaryAudioAttachment(
          path: durablePath,
          duration: elapsed,
          name: _name,
          waveform: compressedWaveform,
        );
        _setPhase(DiaryRecordingPhase.idle);
        return recording;
      } catch (_) {
        if (!_isStale(generation)) {
          _failure = DiaryRecordingFailure.saveFailed;
        }
        return null;
      } finally {
        if (!_isStale(generation) && _phase == DiaryRecordingPhase.finishing) {
          _failure ??= DiaryRecordingFailure.saveFailed;
          await _discardPending();
          _setPhase(DiaryRecordingPhase.idle);
        }
      }
    });
  }

  Future<void> cancel() async {
    ++_generation;
    _clock.stop();
    _timer?.cancel();
    _setPhase(DiaryRecordingPhase.finishing);
    await _enqueue(() async {
      await _discardPending();
      _clock.reset();
      _failure = null;
      _waveform.clear();
      _name = null;
      _setPhase(DiaryRecordingPhase.idle);
    });
  }

  Future<void> _acquireKeepAlive() async {
    final texts = _noticeTexts;
    if (texts == null) return;
    try {
      _capturesInBackground = await _keepAlive.start(
        texts.notice(paused: false, elapsed: Duration.zero),
      );
    } catch (_) {
      _capturesInBackground = false;
    }
    _keepAliveHeld = true;
    _noticePaused = false;
  }

  Future<void> _releaseKeepAlive() async {
    if (!_keepAliveHeld) return;
    _keepAliveHeld = false;
    _capturesInBackground = false;
    _noticePaused = null;
    try {
      await _keepAlive.stop();
    } catch (_) {
      // The service may already be gone with the activity.
    }
  }

  /// 通知跟着录音 ↔ 暂停切换（含来电等系统打断造成的暂停）。不等待：通道
  /// 调用按发出顺序执行，之后的 stop 不会被它越过。
  void _syncNotice() {
    final texts = _noticeTexts;
    if (!_keepAliveHeld || texts == null) return;
    final bool paused;
    switch (_phase) {
      case DiaryRecordingPhase.recording:
        paused = false;
      case DiaryRecordingPhase.paused:
        paused = true;
      default:
        return;
    }
    if (paused == _noticePaused) return;
    _noticePaused = paused;
    unawaited(
      _keepAlive
          .update(texts.notice(paused: paused, elapsed: _clock.elapsed))
          .catchError((Object _) {}),
    );
  }

  Future<void> _discardPending() async {
    await _releaseKeepAlive();
    if (_hasNativeSession) {
      try {
        await _recorder.cancel();
      } catch (_) {
        // The recorder may already have been stopped by the operating system.
      }
      _hasNativeSession = false;
    }
    final path = _pendingPath;
    _pendingPath = null;
    try {
      await _storage.deletePendingRecording(path);
    } catch (_) {
      // Cleanup failures must not keep the microphone/session active.
    }
  }

  void _onNativeState(RecordState state) {
    if (_disposed || !_hasNativeSession || isBusy) return;
    switch (state) {
      case RecordState.record:
        _clock.start();
        _setPhase(DiaryRecordingPhase.recording);
      case RecordState.pause:
        _clock.stop();
        _setPhase(DiaryRecordingPhase.paused);
      case RecordState.stop:
        unawaited(_failAndDiscard());
    }
  }

  Future<void> _failAndDiscard() async {
    if (_disposed || isBusy) return;
    await cancel();
    if (!_disposed) {
      _failure = DiaryRecordingFailure.recordingFailed;
      notifyListeners();
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _operationTail.then((_) => action());
    _operationTail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs only make the app inactive. Pause on actual background
    // transitions; never restart capture automatically when the user returns.
    // 保活确认能在后台采音时（#251）照常录下去。
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _phase == DiaryRecordingPhase.recording &&
        !_capturesInBackground) {
      unawaited(pause());
    }
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
  void _setPhase(DiaryRecordingPhase phase) {
    _phase = phase;
    _syncNotice();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_stateSubscription?.cancel());
    unawaited(
      _enqueue(() async {
        await _discardPending();
        await _recorder.dispose();
      }).catchError((Object _) {}),
    );
    super.dispose();
  }
}
