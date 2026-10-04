import 'package:audioplayers/audioplayers.dart';

abstract interface class AudioPlaybackService {
  Stream<PlayerState> get states;
  Stream<Duration> get positions;
  Stream<Duration> get durations;
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// Plays a recorded local file. The player is created only on first use so
/// rendering a document neither starts playback nor opens a platform session.
class LocalAudioPlaybackService implements AudioPlaybackService {
  AudioPlayer? _player;
  AudioPlayer get _audioPlayer => _player ??= AudioPlayer();

  @override
  Stream<PlayerState> get states => _audioPlayer.onPlayerStateChanged;
  @override
  Stream<Duration> get positions => _audioPlayer.onPositionChanged;
  @override
  Stream<Duration> get durations => _audioPlayer.onDurationChanged;

  @override
  Future<void> play(String path) => _audioPlayer.play(DeviceFileSource(path));
  @override
  Future<void> pause() async => _player?.pause();
  @override
  Future<void> resume() => _audioPlayer.resume();
  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);
  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
