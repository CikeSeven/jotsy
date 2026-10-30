// 连线面板中间的两条点线跑道（DESIGN.md §5.28“同步中”）。
//
// - 上道 `primary`：圆点自左（本机）向右（对方）流动，表示发送；
// - 下道 `tertiary`：圆点自右向左流动，表示接收。
// 每道 3 颗 8dp 圆点，相位各差三分之一程（1.8s 一程 → 错开 0.6s），在两端
// 淡入淡出。没有该方向的数据时那条跑道静止并变淡；减少动画时圆点静止。
//
// 循环只在“有跑道在流动、没开减少动画、所在路由可见（TickerMode）”时运行：
// 被别的页面盖住时 TickerMode 关掉，这里随之停表，不在后台空转出帧。
// 纯装饰，读屏不读（进度由会话面板的读屏文字给出）。

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

class LanSyncFlowLanes extends StatefulWidget {
  const LanSyncFlowLanes({
    super.key,
    required this.sending,
    required this.receiving,
  });

  /// 上道（发送）是否在流动。
  final bool sending;

  /// 下道（接收）是否在流动。
  final bool receiving;

  /// 两条跑道合计的高度。
  static const double height = 40;

  @override
  State<LanSyncFlowLanes> createState() => _LanSyncFlowLanesState();
}

class _LanSyncFlowLanesState extends State<LanSyncFlowLanes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.flowLoop,
  );
  bool _reduceMotion = false;
  bool _tickerEnabled = true;

  bool get _shouldRun =>
      (widget.sending || widget.receiving) && !_reduceMotion && _tickerEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = ExpressiveMotion.reduceMotion(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncLoop();
  }

  @override
  void didUpdateWidget(LanSyncFlowLanes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  void _syncLoop() {
    if (_shouldRun) {
      if (!_loop.isAnimating) _loop.repeat();
    } else if (_loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 不播放时把进度传成 null：画家把圆点画在固定位置，不订阅动画。
    final animating = _shouldRun;
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size.fromHeight(LanSyncFlowLanes.height),
        painter: _LanesPainter(
          animation: animating ? _loop : null,
          sendColor: colors.primary,
          receiveColor: colors.tertiary,
          sending: widget.sending,
          receiving: widget.receiving,
        ),
      ),
    );
  }
}

class _LanesPainter extends CustomPainter {
  _LanesPainter({
    required this.animation,
    required this.sendColor,
    required this.receiveColor,
    required this.sending,
    required this.receiving,
  }) : super(repaint: animation);

  final Animation<double>? animation;
  final Color sendColor;
  final Color receiveColor;
  final bool sending;
  final bool receiving;

  static const double _dotRadius = 4;
  static const double _trackDot = 2;
  static const double _trackStep = 6;
  static const int _dots = 3;

  /// 端点淡入淡出所占的一程比例。
  static const double _fade = 0.15;

  /// 静止时圆点的位置（一程的六分之一、二分之一、六分之五）。
  static const List<double> _restPositions = <double>[1 / 6, 1 / 2, 5 / 6];

  @override
  void paint(Canvas canvas, Size size) {
    final laneHeight = size.height / 2;
    _paintLane(
      canvas,
      size.width,
      laneHeight / 2,
      sendColor,
      active: sending,
      leftToRight: true,
    );
    _paintLane(
      canvas,
      size.width,
      laneHeight * 1.5,
      receiveColor,
      active: receiving,
      leftToRight: false,
    );
  }

  void _paintLane(
    Canvas canvas,
    double width,
    double y,
    Color color, {
    required bool active,
    required bool leftToRight,
  }) {
    final paint = Paint();
    // 2dp 点线轨道：没有该方向的数据时整条更淡。
    paint.color = color.withValues(alpha: active ? 0.32 : 0.14);
    for (var x = _trackDot / 2; x <= width; x += _trackStep) {
      canvas.drawCircle(Offset(x, y), _trackDot / 2, paint);
    }
    final travel = width - _dotRadius * 2;
    if (travel <= 0) return;
    double xOf(double t) => _dotRadius + travel * (leftToRight ? t : 1 - t);

    final progress = animation?.value;
    if (!active || progress == null) {
      // 静止：不流动的跑道（变淡）与减少动画时（原色）都停在固定位置。
      paint.color = color.withValues(alpha: active ? 1 : 0.3);
      for (final t in _restPositions) {
        canvas.drawCircle(Offset(xOf(t), y), _dotRadius, paint);
      }
      return;
    }
    for (var i = 0; i < _dots; i++) {
      final t = (progress + i / _dots) % 1;
      final edge = t < 1 - t ? t : 1 - t;
      final alpha = (edge / _fade).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(xOf(t), y), _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_LanesPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.sendColor != sendColor ||
      oldDelegate.receiveColor != receiveColor ||
      oldDelegate.sending != sending ||
      oldDelegate.receiving != receiving;
}
