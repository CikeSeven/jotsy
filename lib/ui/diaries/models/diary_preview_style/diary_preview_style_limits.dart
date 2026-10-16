/// 日记预览页样式中各数值字段的取值范围（解码夹紧、滑块与渲染共用）。
library;

import '../style_library/style_json.dart';

abstract final class DiaryPreviewStyleLimits {
  /// 正文左右边距；渲染时还会按 [minTextWidth] 收窄。
  static const horizontalPadding = StyleRange(0, 48, 2);

  /// 宽屏时的正文最大宽度（开启“限制正文宽度”后生效）。
  static const contentWidth = StyleRange(480, 960, 40);

  static const coverHeight = StyleRange(160, 640, 20);
  static const coverRadius = StyleRange(0, 40, 1);
  static const titleScale = StyleRange(0.7, 1.8, 0.05);

  /// 头图最多占屏幕高度的比例：再高就看不到标题了。
  static const double coverMaxScreenFraction = 0.7;

  /// 正文区的最小宽度：窄屏上左右边距收窄到能放下它为止。
  static const double minTextWidth = 240;
}
