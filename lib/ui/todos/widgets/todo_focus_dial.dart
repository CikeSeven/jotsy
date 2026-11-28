import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/animated_rolling_text.dart';
import '../models/todo_focus_run.dart';
import '../viewmodels/todo_focus_format.dart';
import 'todo_labels.dart';
import 'todo_focus_dial_painter.dart';

/// 专注页的核心 M3 Expressive 表盘：有机多瓣底盘 + 60 格刻度 + 动态波形进度弧 +
/// 环心三层排版（状态/进度眉标、大号逐位滚动等宽倒计时、预计结束时刻）。
///
/// - 运行中由 [Ticker] 驱动进度弧、波形流动与底盘慢转，仅重绘 [CustomPainter]，
///   不逐帧重建子树；倒计时文字只在秒数变化时更新；
/// - 暂停时波幅平滑抚平为 0、旋转停止、色调补间至 `outline`，并淡入暂停胶囊与
///   已专注时长；
/// - 路由不可见（[TickerMode] 关）或开启减少动态效果时停掉高频 Ticker，后者改为
///   每秒刷新一次平直进度弧。
class TodoFocusDial extends StatefulWidget {
  const TodoFocusDial({
    super.key,
    required this.run,
    required this.now,
    this.size = 288,
  });

  final TodoFocusRun run;
  final DateTime Function() now;
  final double size;

  @override
  State<TodoFocusDial> createState() => _TodoFocusDialState();
}

class _TodoFocusDialState extends State<TodoFocusDial>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final TodoFocusDialFrame _frame = TodoFocusDialFrame();
  Timer? _seconds;
  late int _remaining = widget.run.remaining(widget.now());
  Duration _lastElapsed = Duration.zero;
  double _wavePhase = 0;
  double _orbitAngle = 0;

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

  /// 运行且可见且未开减少动画：高频 Ticker；减少动画：每秒刷新；暂停/不可见：全停。
  void _schedule() {
    _updateClockState();
    final reduce = ExpressiveMotion.reduceMotion(context);
    final tickerOn = TickerMode.valuesOf(context).enabled;
    final running = !widget.run.paused && tickerOn;
    if (running && !reduce) {
      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        unawaited(_ticker.start());
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    _seconds?.cancel();
    _seconds = running && reduce
        ? Timer.periodic(const Duration(seconds: 1), (_) => _updateClockState())
        : null;
  }

  void _onTick(Duration elapsed) {
    final dtMs = _lastElapsed == Duration.zero
        ? 0
        : (elapsed - _lastElapsed).inMilliseconds.clamp(0, 100);
    _lastElapsed = elapsed;
    if (dtMs > 0) {
      _wavePhase =
          (_wavePhase +
              2 *
                  math.pi *
                  dtMs /
                  ExpressiveMotion.focusWaveLoop.inMilliseconds) %
          (2 * math.pi);
      _orbitAngle =
          (_orbitAngle +
              2 *
                  math.pi *
                  dtMs /
                  ExpressiveMotion.focusOrbitLoop.inMilliseconds) %
          (2 * math.pi);
    }
    _updateClockState();
  }

  void _updateClockState() {
    final run = widget.run;
    final now = widget.now();
    final planned = run.plannedSeconds;
    final elapsedMs = planned <= 0
        ? 0
        : ((run.pausedAt ?? now).difference(run.startedAt).inMilliseconds -
                  run.pausedSeconds * 1000)
              .clamp(0, planned * 1000);
    final fraction = planned <= 0 ? 0.0 : 1 - elapsedMs / (planned * 1000);
    _frame.update(
      fraction: fraction,
      wavePhase: _wavePhase,
      orbitAngle: _orbitAngle,
    );
    final remaining = run.remaining(now);
    if (remaining != _remaining && mounted) {
      setState(() => _remaining = remaining);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds?.cancel();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final reduce = ExpressiveMotion.reduceMotion(context);
    final run = widget.run;
    final isBreak = run.phase.isBreak;
    final paused = run.paused;

    final accent = paused
        ? scheme.outline
        : isBreak
        ? scheme.tertiary
        : scheme.primary;
    final backdrop = paused
        ? scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.42 : 0.62)
        : isBreak
        ? scheme.tertiaryContainer.withValues(alpha: isDark ? 0.28 : 0.44)
        : scheme.primaryContainer.withValues(alpha: isDark ? 0.26 : 0.40);
    final track = scheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.72 : 0.88,
    );
    final coreSurface = isDark
        ? scheme.surfaceContainerLow.withValues(alpha: 0.90)
        : scheme.surfaceContainerLowest.withValues(alpha: 0.92);
    final coreBorder = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.22 : 0.34,
    );
    final targetWave = paused || reduce ? 0.0 : 1.0;
    final targetScallop = paused
        ? 0.014
        : isBreak
        ? 0.056
        : 0.044;

    final clockText = TodoFocusFormat.clock(_remaining);
    final planned = run.plannedSeconds;
    final elapsed = run.elapsed(widget.now());
    final percent = planned <= 0
        ? 0
        : ((elapsed / planned) * 100).round().clamp(0, 100);
    final endsAt = run.endsAt;
    final endsText = l10n.todoFocusEndsAt(
      TodoLabels.formatTodoTime(context, endsAt.hour * 60 + endsAt.minute),
    );
    final elapsedMinutes = elapsed ~/ 60;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );

    return SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: accent),
        duration: duration,
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, Color? animatedAccent, Widget? child) {
          final currentAccent = animatedAccent ?? accent;
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: backdrop),
            duration: duration,
            curve: ExpressiveMotion.effects,
            builder:
                (BuildContext context, Color? animatedBackdrop, Widget? inner) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: targetWave),
                    duration: duration,
                    curve: ExpressiveMotion.effects,
                    builder:
                        (BuildContext context, double waveValue, Widget? c) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: targetScallop),
                            duration: duration,
                            curve: ExpressiveMotion.effects,
                            builder:
                                (
                                  BuildContext context,
                                  double scallopValue,
                                  Widget? center,
                                ) => CustomPaint(
                                  painter: TodoFocusDialPainter(
                                    frame: _frame,
                                    accentColor: currentAccent,
                                    trackColor: track,
                                    backdropColor: animatedBackdrop ?? backdrop,
                                    backdropEchoColor: currentAccent.withValues(
                                      alpha: isDark ? 0.12 : 0.10,
                                    ),
                                    backdropOutlineColor: currentAccent
                                        .withValues(
                                          alpha: isDark ? 0.16 : 0.12,
                                        ),
                                    coreSurfaceColor: coreSurface,
                                    coreBorderColor: coreBorder,
                                    tickActiveColor: currentAccent.withValues(
                                      alpha: isDark ? 0.48 : 0.40,
                                    ),
                                    tickInactiveColor: scheme.outlineVariant
                                        .withValues(
                                          alpha: isDark ? 0.24 : 0.34,
                                        ),
                                    stopDotColor: currentAccent.withValues(
                                      alpha: 0.55,
                                    ),
                                    waveIntensity: waveValue,
                                    scallopAmplitude: scallopValue,
                                    lobes: isBreak ? 10 : 12,
                                    isPreview: false,
                                  ),
                                  child: center,
                                ),
                            child: c,
                          );
                        },
                    child: inner,
                  );
                },
            child: child,
          );
        },
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(widget.size * 0.17),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: 26,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        switchInCurve: ExpressiveMotion.effects,
                        switchOutCurve: ExpressiveMotion.exit,
                        child: paused
                            ? _PausedBadge(
                                key: const ValueKey<String>('paused'),
                                label: l10n.todoFocusPaused,
                              )
                            : _PercentEyebrow(
                                key: const ValueKey<String>('running'),
                                percent: percent,
                                dotColor: accent,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ClockDigits(
                    text: clockText,
                    dialSize: widget.size,
                    color: paused
                        ? scheme.onSurface.withValues(alpha: 0.72)
                        : scheme.onSurface,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 24,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        switchInCurve: ExpressiveMotion.effects,
                        switchOutCurve: ExpressiveMotion.exit,
                        child: paused
                            ? (elapsedMinutes >= 1
                                  ? Text(
                                      l10n.todoFocusDoneBody(elapsedMinutes),
                                      key: const ValueKey<String>('elapsed'),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey<String>('empty'),
                                    ))
                            : Row(
                                key: const ValueKey<String>('ends'),
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  FaIcon(
                                    FontAwesomeIcons.bell,
                                    size: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    endsText,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures: const <FontFeature>[
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 空闲准备态的静态有机表盘预览：与 [TodoFocusDial] 共用完全一致的几何与排版，
/// 切换预设时长时数字平滑滚动、预计结束时刻实时更新，点击开始后无缝接力。
class TodoFocusPreviewDial extends StatelessWidget {
  const TodoFocusPreviewDial({
    super.key,
    required this.minutes,
    required this.now,
    this.size = 264,
  });

  final int minutes;
  final DateTime now;
  final double size;

  static final TodoFocusDialFrame _staticFrame = TodoFocusDialFrame();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final endsAt = now.add(Duration(minutes: minutes));
    final endsText = l10n.todoFocusEndsAt(
      TodoLabels.formatTodoTime(context, endsAt.hour * 60 + endsAt.minute),
    );
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: TodoFocusDialPainter(
          frame: _staticFrame,
          accentColor: scheme.primary,
          trackColor: scheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.72 : 0.90,
          ),
          backdropColor: scheme.primaryContainer.withValues(
            alpha: isDark ? 0.22 : 0.34,
          ),
          backdropEchoColor: scheme.primary.withValues(alpha: 0.08),
          backdropOutlineColor: scheme.primary.withValues(
            alpha: isDark ? 0.16 : 0.12,
          ),
          coreSurfaceColor: isDark
              ? scheme.surfaceContainerLow.withValues(alpha: 0.90)
              : scheme.surfaceContainerLowest.withValues(alpha: 0.92),
          coreBorderColor: scheme.outlineVariant.withValues(
            alpha: isDark ? 0.22 : 0.34,
          ),
          tickActiveColor: scheme.primary.withValues(
            alpha: isDark ? 0.40 : 0.32,
          ),
          tickInactiveColor: scheme.outlineVariant.withValues(alpha: 0.28),
          stopDotColor: scheme.primary,
          waveIntensity: 0,
          scallopAmplitude: 0.042,
          lobes: 12,
          isPreview: true,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.17),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.todoFocusReadyHint,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ClockDigits(
                    text: TodoFocusFormat.clock(minutes * 60),
                    dialSize: size,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FaIcon(
                        FontAwesomeIcons.bell,
                        size: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        endsText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 环心超大等宽倒计时数字：随表盘尺寸与是否含小时自适应字号，逐位弹簧滚动。
class _ClockDigits extends StatelessWidget {
  const _ClockDigits({
    required this.text,
    required this.dialSize,
    required this.color,
  });

  final String text;
  final double dialSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasHours = text.length > 5;
    final fontSize = (dialSize * (hasHours ? 0.175 : 0.22)).clamp(38.0, 64.0);
    final base = Theme.of(context).textTheme.displayMedium;
    return Semantics(
      liveRegion: false,
      label: text,
      child: AnimatedRollingText(
        text,
        style: base?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
          height: 1.06,
          color: color,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PercentEyebrow extends StatelessWidget {
  const _PercentEyebrow({
    super.key,
    required this.percent,
    required this.dotColor,
  });

  final int percent;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$percent%',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(
            FontAwesomeIcons.pause,
            size: 9,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
