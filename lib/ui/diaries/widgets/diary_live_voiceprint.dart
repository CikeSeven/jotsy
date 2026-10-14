import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';

// 声纹几何：柱宽 + 柱间距 = 一个槽位。柱子取整数槽位铺满宽度，滚动以槽位为单位。
const double _barWidth = 3.5;
const double _barGap = 3.0;
const double _minBarHeight = 5.0;

/// 振幅 → 柱高的非线性映射。归一化振幅是 dBFS 线性映射，人声多落在 0.4~0.8，
/// 略大于 1 的指数把安静底噪压低、让说话起伏更分明。
const double _levelGamma = 1.35;

/// 单根声纹柱的几何；[hasSample] 为 false 表示该槽位还没有采样，画成基线圆点。
@immutable
class VoiceprintBar {
  const VoiceprintBar({required this.rect, required this.hasSample});

  final Rect rect;
  final bool hasSample;
}

/// 计算当前帧所有声纹柱的几何，自左向右排列，最新采样贴右缘。
///
/// [samples] 旧→新，只使用前 [count] 个（调用方构造画笔时的长度快照，避免实时
/// 列表在构建与绘制之间增长造成错位）。[scrollOffset] 是尚未滚完的槽位数：
/// 新采样到达的瞬间列表已整体左移一格，这里把所有柱子向右“退回”该偏移，再由
/// 调用方逐帧减小它，视觉上就是平滑地向左滑入。
@visibleForTesting
List<VoiceprintBar> layoutVoiceprintBars({
  required List<double> samples,
  required int count,
  required Size size,
  double scrollOffset = 0,
}) {
  const slot = _barWidth + _barGap;
  final slots = math.max(1, (size.width / slot).floor());
  final inset = (size.width - slots * slot) / 2 + _barGap / 2;
  final available = math.min(count, samples.length);
  // 最新一根随滑入逐渐长高，避免新柱以完整高度突然出现在右缘。
  final grow = (1 - scrollOffset).clamp(0.0, 1.0);

  final bars = <VoiceprintBar>[];
  // r 为距最新采样的槽位数。r == slots 是正在滑出左缘的最旧一根：滚动期间
  // 所有柱子右移 scrollOffset，不多画这一根左缘就会露出空槽。
  for (var r = slots; r >= 0; r--) {
    final x = inset + (slots - 1 - r + scrollOffset) * slot;
    final index = available - 1 - r;
    final hasSample = index >= 0;
    final double height;
    if (hasSample) {
      var shaped = math.pow(samples[index].clamp(0.0, 1.0), _levelGamma);
      if (r == 0) shaped *= grow;
      height = _minBarHeight + (size.height - _minBarHeight) * shaped;
    } else {
      height = _barWidth;
    }
    bars.add(
      VoiceprintBar(
        rect: Rect.fromLTWH(x, (size.height - height) / 2, _barWidth, height),
        hasSample: hasSample,
      ),
    );
  }
  return bars;
}

/// 录音过程中的实时声纹：每个振幅采样一根柱，自右向左匀速滚动。
///
/// 左侧尚无采样的槽位显示基线圆点（待机/刚开始时整条都是圆点），暂停时已录下
/// 的柱子保留并变为弱化色。[samples] 是控制器的实时只读视图，组件只靠长度增长
/// 判断新采样到达，因此不会在安静（无新采样）时持续刷新帧。
class LiveVoiceprintVisualizer extends StatefulWidget {
  const LiveVoiceprintVisualizer({
    super.key,
    required this.samples,
    required this.active,
    this.height = 48,
  });

  /// 振幅采样（0~1），旧→新。
  final List<double> samples;

  /// 是否正在录制：true 使用主色，false（暂停/待机）使用弱化色。
  final bool active;

  final double height;

  @override
  State<LiveVoiceprintVisualizer> createState() =>
      _LiveVoiceprintVisualizerState();
}

class _LiveVoiceprintVisualizerState extends State<LiveVoiceprintVisualizer>
    with SingleTickerProviderStateMixin {
  static final double _slotsPerSecond =
      Duration.microsecondsPerSecond /
      recordingAmplitudeSamplePeriod.inMicroseconds;

  /// 滚动积压上限：界面卡顿后一次到达多个采样时，最多补滚这么多格，防止声纹
  /// 长时间“追帧”滑动。
  static const double _maxPendingSlots = 3;

  late final Ticker _ticker;

  /// 尚未滚完的槽位数，由 ticker 逐帧递减；只驱动重绘，不触发组件重建。
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);
  Duration _lastTick = Duration.zero;
  int _seen = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _seen = widget.samples.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _settle();
  }

  @override
  void didUpdateWidget(LiveVoiceprintVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final length = widget.samples.length;
    if (length < _seen) {
      // 新一轮录音：控制器清空了历史，不应带着旧的滚动偏移。
      _seen = length;
      _settle();
      return;
    }
    final arrived = length - _seen;
    _seen = length;
    if (arrived == 0 || _reduceMotion) return;
    _scroll.value = math.min(_scroll.value + arrived, _maxPendingSlots);
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _settle() {
    _scroll.value = 0;
    if (_ticker.isActive) _ticker.stop();
  }

  void _onTick(Duration elapsed) {
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    // 匀速滚动，速度与采样节拍一致；积压超过一格时按比例加速追赶。
    final catchUp = 1 + math.max(0.0, _scroll.value - 1);
    final next = _scroll.value - dt * _slotsPerSecond * catchUp;
    if (next <= 0) {
      _settle();
    } else {
      _scroll.value = next;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final barColor = widget.active
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: 0.4);
    final dotColor = colors.onSurfaceVariant.withValues(
      alpha: isDark ? 0.32 : 0.26,
    );

    // 声纹逐帧重绘，隔离到独立图层，避免波及外层面板（含阴影）。
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: barColor),
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          curve: ExpressiveMotion.effects,
          builder: (context, color, _) => CustomPaint(
            painter: _VoiceprintPainter(
              samples: widget.samples,
              count: widget.samples.length,
              scroll: _scroll,
              barColor: color ?? barColor,
              dotColor: dotColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceprintPainter extends CustomPainter {
  _VoiceprintPainter({
    required this.samples,
    required this.count,
    required this.scroll,
    required this.barColor,
    required this.dotColor,
  }) : super(repaint: scroll);

  final List<double> samples;

  /// 构造时的采样数量快照：[samples] 是实时视图，只有数量变化才需要重绘。
  final int count;
  final ValueListenable<double> scroll;
  final Color barColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // 左缘约四个槽位内逐渐淡出：旧的柱子滑出时不被裁剪边硬切。用逐柱透明度
    // 而不是渐变着色，保持纯色柱体。右缘不淡出，最新采样必须清晰。
    const fadeWidth = (_barWidth + _barGap) * 4;
    final paint = Paint();
    for (final bar in layoutVoiceprintBars(
      samples: samples,
      count: count,
      size: size,
      scrollOffset: scroll.value,
    )) {
      final fade = (bar.rect.center.dx / fadeWidth).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      final color = bar.hasSample ? barColor : dotColor;
      paint.color = color.withValues(alpha: color.a * fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar.rect, Radius.circular(_barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceprintPainter oldDelegate) =>
      oldDelegate.count != count ||
      !identical(oldDelegate.samples, samples) ||
      oldDelegate.barColor != barColor ||
      oldDelegate.dotColor != dotColor;
}
