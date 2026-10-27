/// “背景与材质”各数值字段的取值范围（解码夹紧、滑块与渲染共用）。
library;

import '../../diaries/models/style_library/style_json.dart';

abstract final class AppSurfaceLimits {
  /// 背景图的焦点（对应 `Alignment` 的 x / y）：图片按 cover 裁切时，焦点
  /// 决定保留哪一部分；-1 / 1 为贴边，0 为居中。
  static const align = StyleRange(-1, 1, 0.01);

  /// 背景图的模糊半径（sigma）。超过 30 图片已糊成色块，再大只是白费 GPU。
  static const blur = StyleRange(0, 30, 1);

  /// 叠在背景上的遮罩不透明度（浅色 / 深色主题各一份）。上限 0.9：再高
  /// 背景已经看不见，不如直接关掉背景。
  static const scrim = StyleRange(0, 0.9, 0.05);

  /// 玻璃的模糊半径（sigma）；0 即只有半透明底色、不模糊。
  static const glassBlurSigma = StyleRange(0, 40, 1);

  /// 玻璃底色的不透明度：低于 0.20 时玻璃上的文字在花哨的背景上难以
  /// 辨认，高于 0.95 就与实色没有区别了。
  static const glassTintOpacity = StyleRange(0.20, 0.95, 0.05);
}
