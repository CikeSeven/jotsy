import 'dart:math' as math;

/// Utilities for audio waveform processing, compression, and deterministic synthesis.
///
/// Ensures both newly recorded audio (with captured amplitude samples) and
/// legacy or imported audio have high-fidelity, expressive voiceprint visualizers.

/// Compresses raw amplitude samples into a compact list of normalized bar values.
List<double> compressRecordingWaveform(
  List<double> samples, {
  int targetCount = 36,
}) {
  if (samples.isEmpty) return const <double>[];
  if (samples.length <= targetCount) {
    return samples
        .map((s) => double.parse(s.clamp(0.05, 1.0).toStringAsFixed(2)))
        .toList();
  }

  final bucketSize = samples.length / targetCount;
  final result = <double>[];

  for (var i = 0; i < targetCount; i++) {
    final start = (i * bucketSize).floor();
    final end = math.min(((i + 1) * bucketSize).ceil(), samples.length);
    var peak = 0.05;
    for (var j = start; j < end; j++) {
      if (samples[j] > peak) {
        peak = samples[j];
      }
    }
    result.add(double.parse(peak.clamp(0.05, 1.0).toStringAsFixed(2)));
  }

  return result;
}

/// Returns a high-fidelity waveform for display.
///
/// If real amplitude [samples] exist, they are resampled to [barCount].
/// Otherwise, a realistic, deterministic voiceprint is synthesized based on
/// [seedKey] and [duration], ensuring visual consistency across app launches.
List<double> generateEffectiveWaveform({
  required List<double> samples,
  required String seedKey,
  required Duration duration,
  int barCount = 36,
}) {
  if (samples.isNotEmpty) {
    return _resampleSamples(samples, barCount);
  }
  return _synthesizeWaveform(seedKey, duration, barCount);
}

List<double> _resampleSamples(List<double> source, int targetCount) {
  if (source.length == targetCount) return source;
  final bucketSize = source.length / targetCount;
  final resampled = <double>[];

  for (var i = 0; i < targetCount; i++) {
    final start = (i * bucketSize).floor();
    final end = math.min(((i + 1) * bucketSize).ceil(), source.length);
    var maxVal = 0.05;
    for (var j = start; j < end; j++) {
      if (source[j] > maxVal) maxVal = source[j];
    }
    resampled.add(double.parse(maxVal.clamp(0.08, 1.0).toStringAsFixed(2)));
  }
  return resampled;
}

List<double> _synthesizeWaveform(
  String seedKey,
  Duration duration,
  int barCount,
) {
  final hash = seedKey.hashCode ^ duration.inMilliseconds;
  final rng = math.Random(hash);

  // Generate a natural-sounding speech rhythm envelope
  final basePhase = rng.nextDouble() * 2 * math.pi;
  final secondPhase = rng.nextDouble() * 2 * math.pi;
  final result = <double>[];

  for (var i = 0; i < barCount; i++) {
    final t = i / (barCount - 1);
    // Envelope: smooth fade-in and fade-out at sentence boundaries
    final envelope = math.sin(t * math.pi).clamp(0.3, 1.0);

    // Harmonic speech cadence: combines base rhythm, words, and minor pauses
    final wave1 = 0.5 + 0.5 * math.sin(basePhase + t * 4 * math.pi);
    final wave2 = 0.5 + 0.5 * math.cos(secondPhase + t * 9 * math.pi);
    final jitter = (rng.nextDouble() - 0.5) * 0.25;

    final raw = (wave1 * 0.55 + wave2 * 0.35 + jitter) * envelope;
    final normalized = raw.clamp(0.12, 0.95);
    result.add(double.parse(normalized.toStringAsFixed(2)));
  }

  return result;
}
