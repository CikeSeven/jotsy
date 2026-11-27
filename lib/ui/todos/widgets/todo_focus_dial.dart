import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/animated_rolling_text.dart';
import '../models/todo_focus_run.dart';
import '../viewmodels/todo_focus_format.dart';

/// 专注页的大圆环：剩余比例的弧 + 环心等宽的倒计时（逐位滚动）与暂停标记。
///
/// - 弧按墙钟每帧推进（[Ticker] 只驱动重绘，不重建），走得连续、不一跳一跳；
///   倒计时的数字只在秒数变化时重建；
/// - 暂停时停下 ticker；减少动画时改为每秒更新一次（弧也按秒走）；
/// - 专注用 `primary`，休息用 `tertiary`，暂停时褪成 `outline`，颜色补间
///   （`medium` + effects）。
class TodoFocusDial extends StatefulWidget {
  const TodoFocusDial({
    super.key,
    required this.run,
    required this.now,
    this.size = 280,
  });

  final TodoFocusRun run;
  final DateTime Function() now;
  final double size;

  @override
  State<TodoFocusDial> createState() => _TodoFocusDialState();
}

class _TodoFocusDialState extends State<TodoFocusDial>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _onFrame());
  final ValueNotifier<double> _fraction = ValueNotifier<double>(0);
  Timer? _seconds;
  late int _remaining = widget.run.remaining(widget.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant TodoFocusDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run != widget.run) _schedule();
  }

  /// 走着时：正常为每帧，减少动画时每秒；暂停时都停。
  void _schedule() {
    _onFrame();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final running = !widget.run.paused;
    if (running && !reduce) {
      if (!_ticker.isActive) unawaited(_ticker.start());
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    _seconds?.cancel();
    _seconds = running && reduce
        ? Timer.periodic(const Duration(seconds: 1), (_) => _onFrame())
        : null;
  }

  void _onFrame() {
    final run = widget.run;
    final now = widget.now();
    final planned = run.plannedSeconds;
    final elapsedMs = planned <= 0
        ? 0
        : ((run.pausedAt ?? now).difference(run.startedAt).inMilliseconds -
                  run.pausedSeconds * 1000)
              .clamp(0, planned * 1000);
    _fraction.value = planned <= 0 ? 0 : 1 - elapsedMs / (planned * 1000);
    final remaining = run.remaining(now);
    if (remaining != _remaining && mounted) {
      setState(() => _remaining = remaining);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds?.cancel();
    _fraction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final run = widget.run;
    final accent = run.paused
        ? scheme.outline
        : run.phase.isBreak
        ? scheme.tertiary
        : scheme.primary;
    final stroke = widget.size / 20;
    return SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: accent),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, Color? color, Widget? child) =>
            CustomPaint(
              painter: _DialPainter(
                fraction: _fraction,
                color: color ?? accent,
                track: scheme.surfaceContainerHighest,
                strokeWidth: stroke,
              ),
              child: child,
            ),
        child: Center(
          child: Semantics(
            liveRegion: false,
            label: TodoFocusFormat.clock(_remaining),
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedRollingText(
                  TodoFocusFormat.clock(_remaining),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: run.paused ? 1 : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: Text(
                    context.l10n.todoFocusPaused,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
  }) : super(repaint: fraction);

  final ValueNotifier<double> fraction;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    final value = fraction.value.clamp(0.0, 1.0);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.strokeWidth != strokeWidth;
}
