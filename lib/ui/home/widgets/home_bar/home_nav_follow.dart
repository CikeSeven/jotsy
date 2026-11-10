import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_block.dart';
import 'home_nav_layout.dart';

// 指示器滑动（按一个小数序号在相邻两项间移动：页面位置或导航行的弹簧）
// 的选中程度与布局上下文；从 home_nav_layout.dart 拆出，只为让那边的布局
// delegate 保持在拆分阈值以内。

/// 跟随滑动时第 [index] 项的选中程度，包装成 [Animation] 交给
/// FadeTransition 与布局 delegate 监听；只转发值监听，没有方向状态。
///
/// 按 (position, index) 判等：每次 build 新建也不会让监听方重新订阅。
class HomeNavFollowAmount extends Animation<double> {
  HomeNavFollowAmount(this.position, this.index, this.count);

  final ValueListenable<double> position;
  final int index;
  final int count;

  @override
  double get value =>
      HomeNavGeometry.followAmount(index, position.value, count);

  // 跟手没有“正向 / 反向”，状态只按当前值推算，不发状态通知。
  @override
  AnimationStatus get status => switch (value) {
    >= 1 => AnimationStatus.completed,
    <= 0 => AnimationStatus.dismissed,
    _ => AnimationStatus.forward,
  };

  @override
  void addListener(VoidCallback listener) => position.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      position.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  bool operator ==(Object other) =>
      other is HomeNavFollowAmount &&
      other.position == position &&
      other.index == index &&
      other.count == count;

  @override
  int get hashCode => Object.hash(position, index, count);
}

/// 摆放指示器需要的上下文：指示器位置（小数序号）、本项序号、总数、文字
/// 模式（推算相邻一项的图标高度用）与同一栏共享的内容尺寸（推算相邻一项
/// 的圆角块大小用）。
///
/// 位置有两种来源：页面位置（“指示器跟随滑动”，[velocity] 为 null）或
/// 导航行的弹簧（[velocity] 非空）。弹簧驱动时：
/// - 位置可以略微越过首尾两项（过冲），指示器跟着探出去一点再落回（见
///   [shift]）；页面位置越界（列表回弹）时则停在两端；
/// - 指示器按速度横向拉长，见 [stretch]。
@immutable
class HomeNavFollow {
  const HomeNavFollow({
    required this.position,
    this.velocity,
    required this.index,
    required this.count,
    required this.labelMode,
    required this.metrics,
  });

  /// 每 1 项 / 秒的速度把指示器拉长的比例，以及拉长的上限。相邻两项之间
  /// 滑动的峰值速度约 9 项 / 秒（拉长约 11%），跨三项时触到上限。
  static const double stretchPerVelocity = 0.012;
  static const double maxStretch = 0.28;

  final ValueListenable<double> position;

  /// 弹簧此刻的速度（项 / 秒）；null 表示位置来自页面，不过冲也不拉长。
  final ValueGetter<double>? velocity;
  final int index;
  final int count;
  final HomeBarLabelMode labelMode;
  final HomeNavContentMetrics metrics;

  /// 本项是否负责画指示器（位置夹到首尾后向下取整）。
  bool get isAnchor =>
      HomeNavGeometry.followAnchor(position.value, count) == index;

  /// 越过首尾两项的过冲打的折扣与上限（以项宽为单位）：两端紧挨着胶囊
  /// 内壁，跨三项时原样的过冲（约一成项宽再加上拉长）会顶到栏的边缘被
  /// 裁掉；打折后只是向外探一下，仍看得出弹性。中间各项之间不打折。
  static const double endOvershootFactor = 0.5;
  static const double maxEndOvershoot = 0.06;

  /// 指示器相对本项的偏移（以项宽为单位）；只对锚点项有意义。弹簧驱动时
  /// 越过首尾的部分按 [endOvershootFactor] 画出来，页面位置越界则不画。
  double get shift {
    final raw = position.value;
    final clamped = HomeNavGeometry.clampPosition(raw, count);
    if (velocity == null) {
      return clamped - index;
    }
    final beyond = ((raw - clamped) * endOvershootFactor).clamp(
      -maxEndOvershoot,
      maxEndOvershoot,
    );
    return clamped - index + beyond;
  }

  /// 指示器横向拉长的比例（0 ~ [maxStretch]）：运动越快拉得越长，停下即
  /// 复原，像被拖着走的水滴。
  double get stretch {
    final v = velocity?.call() ?? 0;
    return (v.abs() * stretchPerVelocity).clamp(0.0, maxStretch);
  }

  /// 第 [other] 项此刻的文字显现程度（决定它的图标在竖直方向的位置与圆角
  /// 块的大小）。“只显示选中项文字”时：
  /// - 跟随页面：文字本就按与页面位置的距离显现，直接换算；
  /// - 弹簧驱动：每项的文字按自己的选中动画显现，与指示器的位置无关（滑过
  ///   的中间项不显现文字），取它上一次布局记下的实际值。按位置换算的话，
  ///   指示器经过中间项时会先胀成带文字的大小、换锚点后又缩回去。
  double labelRevealAt(int other) => switch (labelMode) {
    HomeBarLabelMode.always => 1,
    HomeBarLabelMode.never => 0,
    HomeBarLabelMode.selected =>
      velocity == null
          ? HomeNavGeometry.followAmount(other, position.value, count)
          : metrics.of(other)?.reveal ?? 0,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeNavFollow &&
      other.position == position &&
      (other.velocity == null) == (velocity == null) &&
      other.index == index &&
      other.count == count &&
      other.labelMode == labelMode &&
      other.metrics == metrics;

  @override
  int get hashCode => Object.hash(position, index, count, labelMode, metrics);
}
