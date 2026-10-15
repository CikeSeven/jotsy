import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// 启动编排的共享进度：由启动层（`AppBootstrapHome`）在首页挂载时提供，
/// 0 → 1 线性走完一整段编排（[LaunchReveal.duration]）。
///
/// 为什么共用一个进度而不是各区块各起一个 AnimationController：错峰关系
/// 集中在 [LaunchRevealSlot] 里，一处就能看清整段节奏；编排结束后进度停在 1、
/// 不再出帧，之后滚动新建的列表项直接是落定态。
class LaunchRevealScope extends InheritedWidget {
  const LaunchRevealScope({
    super.key,
    required this.progress,
    required super.child,
  });

  final Animation<double> progress;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LaunchRevealScope>()?.progress;

  @override
  bool updateShouldNotify(LaunchRevealScope oldWidget) =>
      progress != oldWidget.progress;
}

/// 编排中的时间槽：何时开始（占整段编排的比例），以及从哪里进场。
///
/// 节奏（整段 long = 500ms，每个区块各自走 medium = 250ms）：
/// - 0ms 顶栏先到，给出“已就绪”的第一反馈；
/// - 30ms 标签栏、50ms 底部导航紧随其后，搭起页面骨架；
/// - 100ms 起列表卡片每张错开 30ms 浮起：屏幕中部的卡片与正在淡出的品牌
///   图形重叠，等图形基本淡出（此时约剩一成）再进场，不叠出重影；第 5 张
///   之后与第 5 张同步（已在首屏之外，再错峰只会拖长编排）；
/// - 250ms FAB 最后弹出，收在整段结尾。
@immutable
class LaunchRevealSlot {
  const LaunchRevealSlot._(this.start, {this.rise = 0, this.scaleFrom = 1});

  /// 顶栏：品牌字标、搜索框与操作按钮。
  static const masthead = LaunchRevealSlot._(0, rise: 12);

  /// 标签筛选栏。
  static const filters = LaunchRevealSlot._(0.06, rise: 12);

  /// 底部导航。
  static const navigation = LaunchRevealSlot._(0.1, rise: 16);

  /// 首屏主操作（新建 FAB）：原位放大弹出，不位移。
  static const action = LaunchRevealSlot._(0.5, scaleFrom: 0.6);

  /// 列表中第 [index] 项。
  factory LaunchRevealSlot.content(int index) =>
      LaunchRevealSlot._(0.2 + 0.06 * math.min(index, 4), rise: 20);

  /// 起始时刻，占整段编排时长的比例。
  final double start;

  /// 进场前位于落点下方的距离（dp）。
  final double rise;

  /// 进场前的缩放。
  final double scaleFrom;

  /// 单个区块的入场时长占整段编排的比例。
  static double get span =>
      ExpressiveMotion.medium.inMicroseconds /
      LaunchReveal.duration.inMicroseconds;
}

/// 让区块按 [slot] 加入启动编排：透明度走 effects 淡入，位移与缩放走
/// spatial 微弹簧落位。
///
/// 没有 [LaunchRevealScope]（其他路由、单独挂载的测试）时原样返回子树。
/// 有 scope 时包装结构恒定为 Opacity → Transform，编排结束后三者都是恒等值，
/// 不会因为编排结束而改变子树结构、触发卡片重新挂载。
class LaunchReveal extends StatelessWidget {
  const LaunchReveal({super.key, required this.slot, required this.child});

  /// 整段编排时长。
  static const Duration duration = ExpressiveMotion.long;

  final LaunchRevealSlot slot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = LaunchRevealScope.maybeOf(context);
    if (progress == null) {
      return child;
    }
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final t = ((progress.value - slot.start) / LaunchRevealSlot.span).clamp(
          0.0,
          1.0,
        );
        // Curve.transform 在 0 与 1 处精确返回端点，落定后位移为 0、缩放为 1。
        final settle = ExpressiveMotion.spatial.transform(t);
        return Opacity(
          opacity: ExpressiveMotion.effects.transform(t),
          child: Transform.translate(
            offset: Offset(0, slot.rise * (1 - settle)),
            child: Transform.scale(
              scale: slot.scaleFrom + (1 - slot.scaleFrom) * settle,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
