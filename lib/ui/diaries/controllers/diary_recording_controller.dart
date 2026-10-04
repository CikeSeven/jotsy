import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_recording_service.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/ui/diaries/models/diary_audio_waveform.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:record/record.dart' show RecordState;

/// Owns microphone capture, pause-excluding elapsed time and pending files.
/// SDK calls are serialized so closing during a permission prompt cannot leave
/// the microphone running after the page closes. A file becomes durable only
/// after stop succeeds; committed files belong to the document, not this panel.
class DiaryRecordingController extends ChangeNotifier
    with WidgetsBindingObserver {
  DiaryRecordingController({
    AudioRecordingService? recorder,
    DiaryAudioStorageService? storage,
    Stopwatch? clock,
  }) : _recorder = recorder ?? MicrophoneRecordingService(),
       _storage = storage ?? const DiaryAudioStorageService(),
       _clock = clock ?? Stopwatch() {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioRecordingService _recorder;
  final DiaryAudioStorageService _storage;
  final Stopwatch _clock;
  Future<void> _operationTail = Future<void>.value();
  StreamSubscription<RecordState>? _stateSubscription;
  Timer? _timer;
  String? _pendingPath;
  bool _disposed = false;
  bool _hasNativeSession = false;
  int _generation = 0;

  DiaryRecordingPhase _phase = DiaryRecordingPhase.idle;
  DiaryRecordingFailure? _failure;
  double _amplitude = 0.0;
  final List<double> _waveform = [];
  String? _name;

  DiaryRecordingPhase get phase => _phase;
  DiaryRecordingFailure? get failure => _failure;
  Duration get elapsed => _clock.elapsed;
  double get amplitude => _amplitude;
  List<double> get waveform => List.unmodifiable(_waveform);
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

  Future<void> start() async {
    if (_disposed || _phase != DiaryRecordingPhase.idle) return;
    final generation = ++_generation;
    _failure = null;
    _amplitude = 0.0;
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
        _hasNativeSession = true;
        await _recorder.start(_pendingPath!);
        if (_isStale(generation)) return;
        _clock.start();
        _setPhase(DiaryRecordingPhase.recording);
        _timer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
          if (!_disposed && _phase == DiaryRecordingPhase.recording) {
            final amp = await _recorder.getAmplitude();
            if (!_disposed && _phase == DiaryRecordingPhase.recording) {
              _amplitude = amp;
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
      _amplitude = 0.0;
      _waveform.clear();
      _name = null;
      _setPhase(DiaryRecordingPhase.idle);
    });
  }

  Future<void> _discardPending() async {
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
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _phase == DiaryRecordingPhase.recording) {
      unawaited(pause());
    }
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
  void _setPhase(DiaryRecordingPhase phase) {
    _phase = phase;
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
