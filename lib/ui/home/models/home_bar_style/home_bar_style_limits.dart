/// 首页栏样式中各数值字段的取值范围（解码夹紧、滑块与渲染共用）。
library;

import '../../../diaries/models/style_library/style_json.dart';

abstract final class HomeBarStyleLimits {
  /// 毛玻璃的模糊半径（sigma）；0 即只有半透明底色、不模糊。
  static const blurSigma = StyleRange(0, 40, 1);

  /// 玻璃底色的不透明度：低于 0.30 时栏上的文字在花哨的内容上难以辨认，
  /// 高于 0.95 就与实色没有区别了。
  static const tintOpacity = StyleRange(0.30, 0.95, 0.05);

  /// 悬浮底栏的高度。默认 60：块高（内容 + 内边距）之上还要留出与左右
  /// 相称的上下留白，更矮时块会顶到栏边。
  static const barHeight = StyleRange(48, 80, 2);

  /// 悬浮底栏的圆角；渲染时还会夹到高度的一半（再大也只是胶囊）。
  static const cornerRadius = StyleRange(0, 40, 1);

  /// 悬浮底栏与屏幕左右边缘的距离。默认 40：栏不铺满，两侧留白让胶囊
  /// 像浮在页面上的一块玻璃，而不是一条贴边的条。上限放到 56，窄屏上的
  /// 最窄宽度仍够放四项。
  static const sideMargin = StyleRange(0, 56, 2);

  /// 悬浮底栏与屏幕底部（系统手势区之上）的距离。
  static const bottomGap = StyleRange(0, 32, 2);

  /// 底栏图标大小。默认 18：与 60 高的栏、13 号左右的标签搭配最协调。
  static const iconSize = StyleRange(14, 28, 1);

  /// 图标与文字的间距：0 时文字紧贴图标框，12 已足够疏朗，再大就像两行。
  static const labelGap = StyleRange(0, 12, 1);

  /// 圆角块的内边距：再大块就撑满导航项，渲染时还会按栏高收窄。
  static const blockPadding = StyleRange(0, 12, 1);

  /// 描边 / 分隔线的不透明度：低于 0.10 已几乎看不见，开关关掉即可。
  static const lineOpacity = StyleRange(0.10, 1.00, 0.05);

  /// 描边 / 分隔线的粗细：0.5 是能稳定画出的最细线，超过 3 就不再是“细线”，
  /// 而是压在胶囊边缘、挤占内容的边框了。
  static const lineWidth = StyleRange(0.5, 3.0, 0.1);
}
