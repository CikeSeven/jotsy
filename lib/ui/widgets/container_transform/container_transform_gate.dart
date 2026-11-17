import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';

/// 容器转场（卡片 ↔ 整页的 `ContainerTransformPageRoute`、新建日记的
/// `MorphPageRoute`）共用的起步闸门、按闸门计时的模拟与 Hero 闸门。
///
/// 为什么要闸门：转场的首帧（新页面构建、排版，或下层页面重新排版并拍成
/// 快照）往往要几十毫秒，普通路由在这之前就开始计时，首帧一卡，下一帧的
/// 进度直接跳过一大截。路由先让进度停在起点，等重活的几帧画完再打开闸门，
/// 整段曲线一帧不落。

/// 转场起步的闸门：关着时进度停在起点，打开时带上这一段的时长与曲线。
class ContainerTransformGate {
  ContainerTransformGate();

  ContainerTransformGate.opened() : _open = true;

  bool _open = false;
  Duration duration = ExpressiveMotion.containerOpen;
  Curve curve = ExpressiveMotion.containerSpring;

  bool get isOpen => _open;

  void open({required Duration duration, required Curve curve}) {
    this.duration = duration;
    this.curve = curve;
    _open = true;
  }
}

/// [count] 帧画完之后执行 [callback]（转场在动，后面的帧一定会来）。
void afterContainerTransformFrames(int count, VoidCallback callback) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (count <= 1) {
      callback();
    } else {
      afterContainerTransformFrames(count - 1, callback);
    }
  });
}

/// 从 [from] 按曲线走到 [to]，但闸门打开之后才开始计时。
///
/// 计时起点是闸门打开后的第一次取值（下一帧），于是之前那一帧花多久都不会
/// 让进度跳一截。闸门迟迟不开时最多等 [maxHold]。
class GatedCurveSimulation extends Simulation {
  GatedCurveSimulation({
    required this.from,
    required this.to,
    required this.gate,
    this.instant = false,
  });

  /// 闸门最多等这么久（秒）：正常两帧就开，这只是防止哪一帧迟迟不来时
  /// 卡在起点的兜底。
  static const double maxHold = 1;

  /// 起步后的第一步隔了超过这么久（秒），就从这一帧重新起算。
  ///
  /// 为什么：起步帧之前刚把下层整屏拍成快照，GPU 可能还压着几十毫秒的活，
  /// 起步帧（进度仍在起点）被拖到很晚才上屏，下一帧按真实时间算进度，第
  /// 一眼就跳过一大截（真机返回时 34ms，一帧缩掉近两成）。从这一帧重新起
  /// 算，只是晚一两帧起步，看不出在等。正常帧间隔 120Hz 约 8ms、60Hz 约
  /// 17ms，都在阈值以内；只纠正一次，中途掉帧照常按真实时间追上，测试里
  /// `pumpAndSettle` 的 100ms 步长也不会一直卡在起点。
  static const double maxFirstStep = 0.02;

  final double from;
  final double to;
  final ContainerTransformGate gate;
  final bool instant;

  double? _start;

  /// 第一步是否已经走过（之后不再重新起算）。
  bool _stepped = false;

  double get _seconds =>
      gate.duration.inMicroseconds / Duration.microsecondsPerSecond;

  /// 已走过的时间比例（0–1）；还在等闸门时为 null。
  double? _progress(double time) {
    var start = _start;
    if (start == null) {
      if (!gate.isOpen && time < maxHold) {
        return null;
      }
      start = _start = time;
    } else if (!_stepped && time > start) {
      _stepped = true;
      if (time - start > maxFirstStep) {
        start = _start = time;
      }
    }
    final seconds = _seconds;
    return seconds <= 0 ? 1 : ((time - start) / seconds).clamp(0.0, 1.0);
  }

  bool get _still => instant || from == to;

  @override
  double x(double time) {
    if (_still) {
      return to;
    }
    final t = _progress(time);
    if (t == null) {
      return from;
    }
    return from + (to - from) * gate.curve.transform(t);
  }

  @override
  double dx(double time) {
    final start = _start;
    if (_still || start == null) {
      return 0;
    }
    final seconds = _seconds;
    if (seconds <= 0) {
      return 0;
    }
    final t = ((time - start) / seconds).clamp(0.0, 1.0);
    if (t >= 1) {
      return 0;
    }
    const h = 1e-3;
    final a = gate.curve.transform(t);
    final b = gate.curve.transform((t + h).clamp(0.0, 1.0));
    return (to - from) * (b - a) / (h * seconds);
  }

  @override
  bool isDone(double time) {
    if (_still) {
      return true;
    }
    final start = _start;
    return start != null && time - start >= _seconds;
  }
}

/// 只在路由停稳（进度为 1 且不在动）时开启本页的 Hero。
///
/// 切换开关只重建 [HeroMode] 自己，页面子树不重建。Hero 控制器在路由变化
/// 后的下一帧末尾才收集两端的 Hero，那时开关已随路由状态更新（推入时页面
/// 首次构建就是关着的）。
class RouteHeroGate extends StatefulWidget {
  const RouteHeroGate({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<RouteHeroGate> createState() => _RouteHeroGateState();
}

class _RouteHeroGateState extends State<RouteHeroGate> {
  late bool _enabled = widget.animation.isCompleted;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(RouteHeroGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
      _enabled = widget.animation.isCompleted;
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    final enabled = status.isCompleted;
    if (enabled != _enabled && mounted) {
      setState(() => _enabled = enabled);
    }
  }

  @override
  Widget build(BuildContext context) =>
      HeroMode(enabled: _enabled, child: widget.child);
}
