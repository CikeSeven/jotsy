import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_block.dart';
import 'home_nav_layout.dart';

// 跟随滑动（指示器随页面的小数位置在相邻两项间移动）的选中程度与布局
// 上下文；从 home_nav_layout.dart 拆出，只为让那边的布局 delegate 保持在
// 拆分阈值以内。

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

/// 跟随滑动时布局需要的上下文：页面位置、本项序号、总数、文字模式
/// （推算相邻一项的图标高度用）与同一栏共享的内容尺寸（推算相邻一项的
/// 圆角块大小用）。
@immutable
class HomeNavFollow {
  const HomeNavFollow({
    required this.position,
    required this.index,
    required this.count,
    required this.labelMode,
    required this.metrics,
  });

  final ValueListenable<double> position;
  final int index;
  final int count;
  final HomeBarLabelMode labelMode;
  final HomeNavContentMetrics metrics;

  /// 第 [other] 项此刻的文字显现程度（决定它的图标在竖直方向的位置）。
  double labelRevealAt(int other) => switch (labelMode) {
    HomeBarLabelMode.always => 1,
    HomeBarLabelMode.never => 0,
    HomeBarLabelMode.selected => HomeNavGeometry.followAmount(
      other,
      position.value,
      count,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is HomeNavFollow &&
      other.position == position &&
      other.index == index &&
      other.count == count &&
      other.labelMode == labelMode &&
      other.metrics == metrics;

  @override
  int get hashCode => Object.hash(position, index, count, labelMode, metrics);
}
