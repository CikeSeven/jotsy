import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 一张卡片表面的具体绘制参数（已按主题、置顶与样式解析完毕）。
///
/// 由 `DiaryCardResolvedStyle.appearanceFor` 产出，交给 `DiarySelectionSurface`
/// 绘制；选中高亮、选中描边加粗与按压脉冲在绘制时叠加，不在这里体现。
@immutable
class DiaryCardSurfaceSpec {
  const DiaryCardSurfaceSpec({
    required this.color,
    required this.radius,
    required this.borderColor,
    required this.borderWidth,
    required this.shadows,
    this.gradientColors,
    this.gradientBegin = AlignmentDirectional.topStart,
    this.gradientEnd = AlignmentDirectional.bottomEnd,
  });

  /// 表面底色（已含置顶着色与不透明度）；有渐变时作为渐变起点。
  final Color color;
  final double radius;

  /// 静止态描边；宽度为 0 时不画描边（选中时仍会加粗显示）。
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;

  /// 两色渐变的色标；null 表示纯色表面。
  final List<Color>? gradientColors;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;

  @override
  bool operator ==(Object other) {
    return other is DiaryCardSurfaceSpec &&
        other.color == color &&
        other.radius == radius &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        listEquals(other.shadows, shadows) &&
        listEquals(other.gradientColors, gradientColors) &&
        other.gradientBegin == gradientBegin &&
        other.gradientEnd == gradientEnd;
  }

  @override
  int get hashCode => Object.hash(
    color,
    radius,
    borderColor,
    borderWidth,
    Object.hashAll(shadows),
    gradientColors == null ? null : Object.hashAll(gradientColors!),
    gradientBegin,
    gradientEnd,
  );
}
