import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 首页底栏导航行的几何换算（纯函数）：选中指示器的矩形、导航项随页面
/// 位置的选中程度。
///
/// 导航行是一排等宽的格子，指示器是一颗与格子同样大小的胶囊，位置用一个
/// 小数序号表示（1.5 即第 1、2 项正中间）。位置有两种来源：
/// - 导航行自己的弹簧（点按切换）：位置可以略微越过首尾两项，途中带着
///   速度——指示器按速度拉长、压扁，撞到胶囊内壁时被挤扁而不是穿出去；
/// - 页面位置（“指示器跟随滑动”）：逐帧跟手，不拉伸，越界时停在两端。
abstract final class HomeNavGeometry {
  /// 选中图标的放大倍数（停稳后的值，弹出途中会越过它）。
  static const double selectedIconScale = 1.1;

  /// 按到底时内容缩小的比例。
  static const double pressDepth = 0.08;

  /// 图标选中时叠加的初速度（选中程度 / 秒）：弹簧多越过终点一截再落回，
  /// 图标“弹一下”，峰值约 1.14 倍。
  static const double popKick = 45;

  /// 每 1 项 / 秒的速度把指示器拉长的比例与上限。相邻两项之间滑动的峰值
  /// 速度约 8 项 / 秒（拉长约 14%），跨三项时触到上限。
  static const double stretchPerVelocity = 0.018;
  static const double maxStretch = 0.30;

  /// 拉长时高度按拉长比例的这个倍数收窄（最多约 9%）：变长的同时略微
  /// 变扁，像一滴被拖着走的水，而不是一块只会变宽的板。
  static const double squashRatio = 0.3;

  /// 指示器越过首尾两项时最多探出导航行的距离：缝为 [inset] 时到胶囊
  /// 内壁还留 1，再往外就被挤扁（见 [indicatorRect]）。
  static double edgeRoom(double inset) => math.max(0, inset - 1);

  /// 页面位置夹到有效范围内。
  static double clampPosition(double position, int count) =>
      position.clamp(0.0, math.max(0, count - 1).toDouble());

  /// 跟随滑动时第 [index] 项的选中程度：离页面位置一页以上为 0，正对为 1。
  static double followAmount(int index, double position, int count) =>
      (1 - (index - clampPosition(position, count)).abs()).clamp(0.0, 1.0);

  /// 指示器在导航行（大小 [size]，共 [count] 项）里的矩形。
  ///
  /// [position] 是小数序号；[velocity] 是它此刻的速度（项 / 秒），只在
  /// [elastic]（弹簧驱动）时使用。[rtl] 时序号从右往左数。[edgeRoom] 是
  /// 首尾两端最多探出导航行的距离（取 [HomeNavGeometry.edgeRoom]）。
  ///
  /// - 非弹性：位置夹到首尾，矩形就是所在的那一格（两格之间线性平移）；
  /// - 弹性：位置原样使用（可以越界），宽度按速度拉长、高度相应收窄，
  ///   拉伸以中心为准；左右边缘不超出导航行两端 [edgeRoom]——越过首尾的
  ///   过冲与拉伸顶到胶囊内壁时，指示器在那一侧被挤扁，过后弹回原宽。
  static Rect indicatorRect({
    required Size size,
    required int count,
    required double position,
    required double edgeRoom,
    double velocity = 0,
    bool elastic = false,
    bool rtl = false,
  }) {
    if (count <= 0) {
      return Rect.zero;
    }
    final itemWidth = size.width / count;
    final at = elastic ? position : clampPosition(position, count);
    final stretch = elastic
        ? math.min(velocity.abs() * stretchPerVelocity, maxStretch)
        : 0.0;
    final width = itemWidth * (1 + stretch);
    final height = size.height * (1 - stretch * squashRatio);
    final center = (at + 0.5) * itemWidth;
    var left = math.max(center - width / 2, -edgeRoom);
    var right = math.min(center + width / 2, size.width + edgeRoom);
    if (right < left) {
      // 位置远在范围之外（Tab 集合变化的那一帧）：收成贴着那一端的零宽。
      left = right = right.clamp(-edgeRoom, size.width + edgeRoom);
    }
    if (rtl) {
      final mirroredLeft = size.width - right;
      right = size.width - left;
      left = mirroredLeft;
    }
    final top = (size.height - height) / 2;
    return Rect.fromLTRB(left, top, right, top + height);
  }
}
