/// 日记卡片样式中各数值字段的取值范围。
///
/// 同一份范围被三处共用：解码时夹紧（旧版本或手改的样式码越界只回退到
/// 边界）、设置页滑块的 min/max/divisions、渲染层的二次夹紧。
library;

import '../style_library/style_json.dart';

/// 一个数值字段的闭区间与步进（与预览页样式共用 [StyleRange]）。
typedef DiaryCardRange = StyleRange;

abstract final class DiaryCardStyleLimits {
  // 表面。
  static const cornerRadius = DiaryCardRange(0, 40, 1);
  static const opacity = DiaryCardRange(0.5, 1, 0.05);
  static const borderWidth = DiaryCardRange(0, 4, 0.2);
  static const accentWidth = DiaryCardRange(2, 12, 1);
  static const shadowElevation = DiaryCardRange(0, 24, 1);

  /// 颜色强度（着色叠加的不透明度，或描边/强调条/阴影颜色本身的不透明度）。
  static const strength = DiaryCardRange(0.04, 1, 0.02);

  // 字体。
  static const titleScale = DiaryCardRange(0.8, 1.4, 0.05);
  static const previewScale = DiaryCardRange(0.85, 1.3, 0.05);
  static const metaScale = DiaryCardRange(0.85, 1.3, 0.05);

  // 封面。
  static const coverSide = DiaryCardRange(64, 168, 2);
  static const coverHeight = DiaryCardRange(72, 280, 4);
  static const coverRadius = DiaryCardRange(0, 40, 1);
  static const coverGap = DiaryCardRange(6, 24, 1);

  /// 背景封面模式下文字底板的不透明度；过低时文字压在照片上难以辨认。
  static const scrim = DiaryCardRange(0.3, 0.95, 0.05);

  // 布局。
  static const paddingH = DiaryCardRange(6, 32, 1);
  static const paddingV = DiaryCardRange(4, 28, 1);
  static const cardGap = DiaryCardRange(0, 24, 1);
  static const sideMargin = DiaryCardRange(0, 32, 1);
  static const elementGap = DiaryCardRange(0, 16, 1);
  static const titleMaxLines = DiaryCardRange(1, 4, 1);
  static const previewMaxLines = DiaryCardRange(1, 8, 1);
  static const columns = DiaryCardRange(2, 3, 1);
}
