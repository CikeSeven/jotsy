import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Interactive playback waveform visualizer for diary audio attachments.
///
/// Displays normalized amplitude bars filled up to the current playback [progress].
/// Users can tap or drag across the waveform to seek directly in the audio track.
class DiaryWaveformBarVisualizer extends StatelessWidget {
  const DiaryWaveformBarVisualizer({
    super.key,
    required this.waveform,
    required this.progress,
    this.onSeek,
    this.activeColor,
    this.inactiveColor,
    this.height = 34.0,
  });

  /// Normalized bar heights in range [0.0, 1.0].
  final List<double> waveform;

  /// Playback progress in range [0.0, 1.0].
  final double progress;

  /// Callback when the user taps or scrubs to seek.
  final ValueChanged<double>? onSeek;

  /// Color for bars before and at the current playhead.
  final Color? activeColor;

  /// Color for unplayed bars.
  final Color? inactiveColor;

  /// Height of the waveform visualizer container.
  final double height;

  void _handleTouch(Offset localPosition, double totalWidth) {
    if (totalWidth <= 0 || onSeek == null) return;
    final clampedX = localPosition.dx.clamp(0.0, totalWidth);
    final targetProgress = (clampedX / totalWidth).clamp(0.0, 1.0);
    onSeek!(targetProgress);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveActiveColor = activeColor ?? colors.primary;
    final effectiveInactiveColor =
        inactiveColor ?? colors.outlineVariant.withValues(alpha: 0.35);

    return Semantics(
      slider: true,
      value: '${(progress * 100).toInt()}%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onSeek == null
                ? null
                : (details) => _handleTouch(details.localPosition, width),
            onHorizontalDragUpdate: onSeek == null
                ? null
                : (details) => _handleTouch(details.localPosition, width),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                size: Size(width, height),
                painter: _WaveformBarPainter(
                  waveform: waveform,
                  progress: progress.clamp(0.0, 1.0),
                  activeColor: effectiveActiveColor,
                  inactiveColor: effectiveInactiveColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveformBarPainter extends CustomPainter {
  const _WaveformBarPainter({
    required this.waveform,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> waveform;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty || size.width <= 0 || size.height <= 0) return;

    final count = waveform.length;
    final slotWidth = size.width / count;
    final barWidth = (slotWidth * 0.58).clamp(2.0, 5.5);
    const minBarHeight = 4.0;
    final maxBarHeight = size.height;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final x = i * slotWidth + (slotWidth - barWidth) / 2;
      final sample = waveform[i].clamp(0.0, 1.0);
      final barHeight = minBarHeight + sample * (maxBarHeight - minBarHeight);
      final y = (size.height - barHeight) / 2;

      final isPlayed = (i / count) <= progress;
      final paint = isPlayed ? activePaint : inactivePaint;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

/// Dynamic live voiceprint visualizer during recording.
///
/// Reacts dynamically to input [amplitude] (normalized 0.0 to 1.0).
/// When paused or quiet, gracefully settles into a gentle baseline.
class LiveVoiceprintVisualizer extends StatefulWidget {
  const LiveVoiceprintVisualizer({
    super.key,
    required this.amplitude,
    required this.isRecording,
    required this.isPaused,
    this.barCount = 23,
    this.height = 42.0,
  });

  final double amplitude;
  final bool isRecording;
  final bool isPaused;
  final int barCount;
  final double height;

  @override
  State<LiveVoiceprintVisualizer> createState() =>
      _LiveVoiceprintVisualizerState();
}

class _LiveVoiceprintVisualizerState extends State<LiveVoiceprintVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void didUpdateWidget(LiveVoiceprintVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && _motionController.isAnimating) {
      _motionController.stop();
    } else if (widget.isRecording && !_motionController.isAnimating) {
      _motionController.repeat();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final activeBarColor = colors.primary;
    final pausedBarColor = colors.onSurfaceVariant.withValues(
      alpha: isDark ? 0.35 : 0.25,
    );

    return AnimatedBuilder(
      animation: _motionController,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LiveVoiceprintPainter(
              amplitude: widget.amplitude,
              phase: _motionController.value * 2 * math.pi,
              isRecording: widget.isRecording,
              isPaused: widget.isPaused,
              barCount: widget.barCount,
              activeColor: activeBarColor,
              pausedColor: pausedBarColor,
              reduceMotion: MediaQuery.disableAnimationsOf(context),
            ),
          ),
        );
      },
    );
  }
}

class _LiveVoiceprintPainter extends CustomPainter {
  const _LiveVoiceprintPainter({
    required this.amplitude,
    required this.phase,
    required this.isRecording,
    required this.isPaused,
    required this.barCount,
    required this.activeColor,
    required this.pausedColor,
    required this.reduceMotion,
  });

  final double amplitude;
  final double phase;
  final bool isRecording;
  final bool isPaused;
  final int barCount;
  final Color activeColor;
  final Color pausedColor;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0 || size.height <= 0) return;

    final slotWidth = size.width / barCount;
    final barWidth = (slotWidth * 0.52).clamp(2.5, 5.0);
    const minHeight = 4.0;
    final maxHeight = size.height;

    final paint = Paint()
      ..color = isPaused ? pausedColor : activeColor
      ..style = PaintingStyle.fill;

    final half = (barCount - 1) / 2.0;

    for (var i = 0; i < barCount; i++) {
      final x = i * slotWidth + (slotWidth - barWidth) / 2;

      double barHeight;
      if (isPaused) {
        barHeight = minHeight;
      } else if (reduceMotion) {
        // Subtle non-animated baseline when user prefers reduced motion
        final bell = 1.0 - math.pow((i - half) / half, 2).clamp(0.0, 1.0);
        barHeight = minHeight + (amplitude * (maxHeight - minHeight) * bell);
      } else {
        // Bell-curve envelope centered in the middle of voiceprint
        final normalizedDist = ((i - half).abs() / half).clamp(0.0, 1.0);
        final bell = math.cos(normalizedDist * math.pi * 0.5);

        // Gentle breathing wave when quiet + high reaction when speaking
        final wave = math.sin(phase + i * 0.45) * 0.15;
        final dynamicAmp = (amplitude * 0.85 + wave.abs() * 0.15).clamp(
          0.05,
          1.0,
        );

        final target = minHeight + (maxHeight - minHeight) * bell * dynamicAmp;
        barHeight = target.clamp(minHeight, maxHeight);
      }

      final y = (size.height - barHeight) / 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveVoiceprintPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.phase != phase ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.pausedColor != pausedColor;
  }
}
