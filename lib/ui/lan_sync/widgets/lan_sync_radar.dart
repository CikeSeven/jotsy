// 英雄卡上方的雷达区：九瓣饼干形本机图标 + 定位虚线圈 + 三圈扩散波纹。
//
// 状态机（只有两态）：
// - 播放：[LanSyncRadar.animate]（可被发现且页面可见）为真、所在路由的
//   TickerMode 开着、系统没有开减少动画——三圈波纹以
//   `ExpressiveMotion.pulseLoop`（3.6s）为周期循环，相位各差三分之一周期；
// - 静止：任一条件不满足——停表，三圈静态环以 20% 不透明度停在均分的位置。
// 条件在 didChangeDependencies（TickerMode、减少动画）与 didUpdateWidget
// （animate）里重新判断，路由被盖住或 Tab 切走时 TickerMode 关闭即停表，
// 不空转出帧。整块是装饰，读屏不读。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../models/lan_sync_platform.dart';
import 'lan_sync_device_glyph.dart';

/// 见文件头注释。
class LanSyncRadar extends StatefulWidget {
  const LanSyncRadar({
    super.key,
    required this.platform,
    required this.animate,
  });

  /// 雷达区的高度（横排时也是宽度）。
  static const double extent = 184;

  final LanSyncPlatform platform;

  /// 是否允许播放波纹（可被发现且页面可见）；减少动画与 TickerMode 另行判断。
  final bool animate;

  @override
  State<LanSyncRadar> createState() => _LanSyncRadarState();
}

class _LanSyncRadarState extends State<LanSyncRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.pulseLoop,
  );
  bool _tickerEnabled = true;
  bool _reduceMotion = false;

  bool get _shouldRun => widget.animate && _tickerEnabled && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = ExpressiveMotion.reduceMotion(context);
    _sync();
  }

  @override
  void didUpdateWidget(LanSyncRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    if (_shouldRun) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: LanSyncRadar.extent,
        child: CustomPaint(
          painter: _RadarPainter(
            progress: _controller,
            running: _shouldRun,
            ringColor: colors.outlineVariant,
            waveColor: colors.primary,
          ),
          child: Center(child: LanSyncDeviceGlyph(platform: widget.platform)),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.running,
    required this.ringColor,
    required this.waveColor,
  }) : super(repaint: progress);

  /// 定位虚线圈的直径。
  static const double _guideDiameter = 132;

  /// 波纹从定位圈的 0.55 倍放大到 1.25 倍。
  static const double _startScale = 0.55;
  static const double _endScale = 1.25;
  static const double _peakOpacity = 0.42;
  static const double _restingOpacity = 0.2;
  static const int _waves = 3;

  final Animation<double> progress;
  final bool running;
  final Color ringColor;
  final Color waveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    _paintGuide(canvas, center);
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < _waves; i++) {
      // 每圈相位差三分之一周期；静止时取均分的位置，三圈错开排布。
      final phase = running
          ? (progress.value + i / _waves) % 1.0
          : (i + 0.5) / _waves;
      final eased = ExpressiveMotion.effects.transform(phase);
      final scale = _startScale + (_endScale - _startScale) * eased;
      final opacity = running ? _peakOpacity * (1 - eased) : _restingOpacity;
      wave.color = waveColor.withValues(alpha: opacity);
      canvas.drawCircle(center, _guideDiameter / 2 * scale, wave);
    }
  }

  /// 132dp 虚线定位圈：沿圆周画等长短弧。
  void _paintGuide(Canvas canvas, Offset center) {
    const radius = _guideDiameter / 2;
    const dashes = 48;
    const sweep = 2 * math.pi / dashes;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ringColor;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.5, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.running != running ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.waveColor != waveColor ||
      oldDelegate.progress != progress;
}
