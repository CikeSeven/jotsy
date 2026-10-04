import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:flutter/foundation.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';

/// Owns one audio attachment's playback and pauses the previous attachment
/// before another starts. Rendering never initializes or plays audio.
class DiaryAudioPlayerController extends ChangeNotifier {
  DiaryAudioPlayerController({
    required this.recording,
    AudioPlaybackService? player,
  }) : _player = player ?? LocalAudioPlaybackService(),
       _duration = recording.duration;

  static DiaryAudioPlayerController? _active;
  final DiaryAudioAttachment recording;
  final AudioPlaybackService _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;
  bool _ready = false;
  Duration _position = Duration.zero;
  Duration _duration;

  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  bool get hasFailed => _failed;
  Duration get position => _position;
  Duration get duration => _duration;

  static Future<void> pauseActive() async {
    await _active?.pause();
  }

  Future<void> toggle() async {
    if (_disposed || _loading) return;
    if (_playing) {
      await pause();
      return;
    }
    _loading = true;
    _failed = false;
    _notify();
    try {
      if (_active != this) await _active?.pause();
      if (_disposed) return;
      _active = this;
      _bindStreams();
      if (_ready) {
        await _player.resume();
      } else {
        await _player.play(recording.path);
        _ready = true;
      }
      if (_disposed) {
        await _player.pause();
        return;
      }
      _playing = true;
    } catch (_) {
      _failed = true;
      _playing = false;
      _ready = false;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> pause() async {
    if (_disposed || (!_playing && !_loading)) return;
    try {
      await _player.pause();
      _playing = false;
    } catch (_) {
      _failed = true;
    }
    _notify();
  }

  Future<void> seek(Duration position) async {
    if (_disposed || !_ready || _loading) return;
    final milliseconds = position.inMilliseconds.clamp(
      0,
      _duration.inMilliseconds,
    );
    try {
      await _player.seek(Duration(milliseconds: milliseconds));
      _position = Duration(milliseconds: milliseconds);
    } catch (_) {
      _failed = true;
    }
    _notify();
  }

  void _bindStreams() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions.addAll([
      _player.states.listen((state) {
        _playing = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _position = Duration.zero;
          _ready = false;
        }
        _notify();
      }, onError: _handleError),
      _player.positions.listen((position) {
        _position = position;
        _notify();
      }, onError: _handleError),
      _player.durations.listen((duration) {
        if (duration > Duration.zero) _duration = duration;
        _notify();
      }, onError: _handleError),
    ]);
  }

  void _handleError(Object error) {
    _failed = true;
    _playing = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_active == this) _active = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
