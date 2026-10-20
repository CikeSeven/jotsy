import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'home_nav_layout.dart';

/// 圆角块指示器的形状：圆角按块自己的高度现算，与栏的圆角同心。
///
/// 块高由布局时量到的内容（图标框 + 间距 + 文字）加内边距决定，构建时还
/// 不知道，所以不能像胶囊那样在 build 里给一个固定半径的
/// RoundedRectangleBorder；改由形状在拿到矩形时按
/// [HomeNavGeometry.blockRadius] 推算。指示器（Ink）与水波纹的裁切共用它，
/// 两者的圆角才始终一致。
@immutable
class HomeNavBlockBorder extends ShapeBorder {
  const HomeNavBlockBorder({
    required this.cornerRadius,
    required this.barHeight,
  });

  /// 栏的圆角（已夹到栏高一半以内）与栏高：同心半径 = 栏圆角 − 块到栏
  /// 上下边缘的距离。
  final double cornerRadius;
  final double barHeight;

  /// 高为 [height] 的块的圆角。
  double radiusFor(double height) =>
      HomeNavGeometry.blockRadius(cornerRadius, barHeight, height);

  RRect _rrect(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radiusFor(rect.height)));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect));

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) => canvas.drawRRect(_rrect(rect), paint);

  /// 没有描边，只有填充（由 [paintInterior] 画）。
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => HomeNavBlockBorder(
    cornerRadius: cornerRadius * t,
    barHeight: barHeight * t,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeNavBlockBorder &&
      other.cornerRadius == cornerRadius &&
      other.barHeight == barHeight;

  @override
  int get hashCode => Object.hash(cornerRadius, barHeight);
}

/// 同一栏各导航项最近一次布局量到的内容尺寸，供跟随滑动时的锚点项推算
/// 相邻一项的圆角块大小。
///
/// 为什么需要共享：块宽可能由文字宽度决定（长名称、大内边距），而锚点项
/// 的布局里量不到下一项的文字。各项在自己的布局里写入本项的值，锚点项读
/// 下一项的值；Row 按序号依次布局，读到的可能是上一帧的值，但跟随滑动时
/// 每一帧都会重新布局所有项，下一帧即更新，块大小仍连续变化，不会在锚点
/// 换项时跳变。只是缓存，不触发重新布局；没量到时回退本项自己的值。
class HomeNavContentMetrics {
  final Map<int, HomeNavContentSize> _sizes = <int, HomeNavContentSize>{};

  void record(int index, HomeNavContentSize size) => _sizes[index] = size;

  HomeNavContentSize? of(int index) => _sizes[index];
}

/// 一项内容在文字完全显现时的尺寸：[width] 为图标框与文字中较宽的一个，
/// [labelHeight] 为间距 + 文字高度（文字收起时这部分高度随之收起）。
@immutable
class HomeNavContentSize {
  const HomeNavContentSize({required this.width, required this.labelHeight});

  final double width;
  final double labelHeight;
}
