import 'package:record/record.dart';

abstract interface class AudioRecordingService {
  Future<bool> hasPermission();
  Stream<RecordState> get states;
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
  Future<double> getAmplitude();
}

/// Records microphone audio locally as AAC in an M4A container. No speech
/// recognizer or network service participates in this capture path.
class MicrophoneRecordingService implements AudioRecordingService {
  AudioRecorder? _recorder;
  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _audioRecorder.hasPermission();

  @override
  Stream<RecordState> get states => _audioRecorder.onStateChanged();

  @override
  Future<void> start(String path) => _audioRecorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 96000,
      sampleRate: 44100,
      numChannels: 1,
      audioInterruption: AudioInterruptionMode.pause,
    ),
    path: path,
  );

  @override
  Future<void> pause() => _audioRecorder.pause();

  @override
  Future<void> resume() => _audioRecorder.resume();

  @override
  Future<String?> stop() => _audioRecorder.stop();

  @override
  Future<void> cancel() async {
    await _recorder?.cancel();
  }

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }

  @override
  Future<double> getAmplitude() async {
    try {
      if (_recorder == null) return 0.0;
      final amp = await _audioRecorder.getAmplitude();
      final current = amp.current;
      // Record package returns current amplitude in dBFS (-160.0 to 0.0).
      // Normalize -60.0dB to 0.0dB range into 0.0 to 1.0.
      if (current.isInfinite || current.isNaN || current < -60.0) return 0.0;
      if (current >= 0.0) return 1.0;
      return ((current + 60.0) / 60.0).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }
}
