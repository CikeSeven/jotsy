import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 半透明 / 玻璃日记卡片的表面装饰：投影只画在卡片外侧，其余（底色或渐变、
/// 圆角）交给 [base] 照常绘制。
///
/// 为什么不直接用 `BoxShadow(blurStyle: BlurStyle.outer)`：引擎对圆角矩形的
/// outer 模糊有快速路径缺陷——只在形状边缘附近一圈（约模糊范围）挖空，离边缘
/// 更远的内部仍按阴影颜色整块填充。实色卡片的不透明底色把它盖住了，半透明
/// 与玻璃卡片上就露成正文后面一块颜色更深的矩形。这里改用与
/// `OuterShadowPainter`（菜单、玻璃表面）相同的做法：偶奇裁切掉卡片形状本身，
/// 再按普通（normal）模糊画投影，内部一个像素都不画。
///
/// 输入：不含投影的 [base] 与要画在外侧的 [shadows]（blurStyle 一律按 normal
/// 处理）；输出：先外侧投影、后 [base]。命中测试、内边距与裁切路径都委托给
/// [base]，与原来的 BoxDecoration 行为一致。只由 `DiarySelectionSurface` 在
/// 卡片带外侧投影时使用；不透明卡片仍用普通 BoxDecoration。
@immutable
class DiaryCardOuterShadowDecoration extends Decoration {
  const DiaryCardOuterShadowDecoration({
    required this.base,
    required this.shadows,
  });

  /// 底色 / 渐变与圆角（不含投影）。
  final BoxDecoration base;

  /// 只画在卡片外侧的投影。
  final List<BoxShadow> shadows;

  @override
  EdgeInsetsGeometry get padding => base.padding;

  @override
  bool get isComplex => base.isComplex;

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      base.getClipPath(rect, textDirection);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      base.hitTest(size, position, textDirection: textDirection);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _OuterShadowBoxPainter(this, base.createBoxPainter(onChanged), onChanged);

  @override
  bool operator ==(Object other) {
    return other is DiaryCardOuterShadowDecoration &&
        other.base == base &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(base, Object.hashAll(shadows));
}

class _OuterShadowBoxPainter extends BoxPainter {
  _OuterShadowBoxPainter(this._decoration, this._base, super.onChanged);

  final DiaryCardOuterShadowDecoration _decoration;
  final BoxPainter _base;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size != null && _decoration.shadows.isNotEmpty) {
      final rect = offset & size;
      final radius =
          _decoration.base.borderRadius?.resolve(configuration.textDirection) ??
          BorderRadius.zero;
      final shape = radius.toRRect(rect);
      // 裁切外框要盖住最远的投影：模糊约延伸 2 倍半径，再加偏移与扩散。
      var extent = 0.0;
      for (final shadow in _decoration.shadows) {
        extent = math.max(
          extent,
          shadow.blurRadius * 2 +
              shadow.spreadRadius.abs() +
              shadow.offset.distance,
        );
      }
      // 偶奇填充：外框减去卡片形状，只留外侧。
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(extent + 1))
        ..addRRect(shape);
      canvas
        ..save()
        ..clipPath(outside);
      for (final shadow in _decoration.shadows) {
        final normal = BoxShadow(
          color: shadow.color,
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
        );
        canvas.drawRRect(
          shape.shift(shadow.offset).inflate(shadow.spreadRadius),
          normal.toPaint(),
        );
      }
      canvas.restore();
    }
    _base.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    _base.dispose();
    super.dispose();
  }
}
