import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';

/// Interactive playback waveform visualizer for diary audio attachments.
///
/// Displays normalized amplitude bars filled up to the current playback [progress].
/// Users can tap or drag across the waveform to seek directly in the audio track.
class DiaryWaveformBarVisualizer extends StatefulWidget {
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

  @override
  State<DiaryWaveformBarVisualizer> createState() =>
      _DiaryWaveformBarVisualizerState();
}

class _DiaryWaveformBarVisualizerState
    extends State<DiaryWaveformBarVisualizer> {
  bool _dragging = false;

  void _handleTouch(Offset localPosition, double totalWidth) {
    final onSeek = widget.onSeek;
    if (totalWidth <= 0 || onSeek == null) return;
    final clampedX = localPosition.dx.clamp(0.0, totalWidth);
    onSeek((clampedX / totalWidth).clamp(0.0, 1.0));
  }

  void _setDragging(bool value) {
    if (_dragging != value) setState(() => _dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? colors.primary;
    // 未播放的柱子要在白色卡片上清晰可辨：取 onSurfaceVariant 的弱化色，而不是
    // 与卡片描边同级的 outlineVariant（浅色下几乎看不见）。
    final inactiveColor =
        widget.inactiveColor ??
        colors.onSurfaceVariant.withValues(alpha: isDark ? 0.34 : 0.3);
    final target = widget.progress.clamp(0.0, 1.0);
    final seekable = widget.onSeek != null;

    return Semantics(
      slider: true,
      value: '${(target * 100).toInt()}%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: seekable
                ? (details) => _handleTouch(details.localPosition, width)
                : null,
            onHorizontalDragStart: seekable ? (_) => _setDragging(true) : null,
            onHorizontalDragUpdate: seekable
                ? (details) => _handleTouch(details.localPosition, width)
                : null,
            onHorizontalDragEnd: seekable ? (_) => _setDragging(false) : null,
            onHorizontalDragCancel: seekable ? () => _setDragging(false) : null,
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              // 播放位置事件约每 200ms 一次，短录音每次会跨过好几根柱子；用与事件
              // 间隔相当的补间把步进抹平成连续扫动。必须是线性曲线：缓动曲线会让
              // 每段先快后慢，匀速播放时反而出现周期性的“一顿一顿”。拖动时补间
              // 归零，播放头直接跟手。
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: target),
                duration: _dragging
                    ? Duration.zero
                    : ExpressiveMotion.duration(context, ExpressiveMotion.fast),
                curve: Curves.linear,
                builder: (context, progress, _) => CustomPaint(
                  size: Size(width, widget.height),
                  painter: _WaveformBarPainter(
                    waveform: widget.waveform,
                    progress: progress,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    dragging: _dragging,
                  ),
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
    required this.dragging,
  });

  final List<double> waveform;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty || size.width <= 0 || size.height <= 0) return;

    final count = waveform.length;
    final slotWidth = size.width / count;
    final barWidth = (slotWidth * 0.58).clamp(2.0, 5.5);
    const minBarHeight = 4.0;
    final maxBarHeight = size.height;

    final bars = <RRect>[];
    for (var i = 0; i < count; i++) {
      final barHeight =
          minBarHeight +
          waveform[i].clamp(0.0, 1.0) * (maxBarHeight - minBarHeight);
      bars.add(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * slotWidth + (slotWidth - barWidth) / 2,
            (size.height - barHeight) / 2,
            barWidth,
            barHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
      );
    }

    // 先整体画未播放色，再裁剪到播放头左侧叠画已播放色：播放头能平滑扫过柱体
    // 内部，而不是逐柱跳变颜色。
    final paint = Paint()..color = inactiveColor;
    for (final bar in bars) {
      canvas.drawRRect(bar, paint);
    }
    final playheadX = size.width * progress;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, playheadX, size.height));
    paint.color = activeColor;
    for (final bar in bars) {
      canvas.drawRRect(bar, paint);
    }
    canvas.restore();

    // 起止两端不画播放头：0 处会像贴边的竖线，播完则与最后一根柱子重叠。
    if (progress > 0.004 && progress < 0.996) {
      final lineWidth = dragging ? 3.0 : 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(playheadX - lineWidth / 2, 0, lineWidth, size.height),
          Radius.circular(lineWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.dragging != dragging;
  }
}
