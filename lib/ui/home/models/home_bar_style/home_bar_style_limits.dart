/// 首页栏样式中数值字段的取值范围（解码夹紧、滑块与渲染共用）。
///
/// 导航项各项的上下限一起保证栏不失衡：最大的图标 + 文字 + 间距加上内容
/// 留白也放得进由它们推导出的格高（见 `HomeBarMetrics.itemHeight`），最小
/// 的组合点按区域仍不低于 38。
library;

import '../../../diaries/models/style_library/style_json.dart';

abstract final class HomeBarStyleLimits {
  /// 玻璃底色的不透明度：低于 0.15 时栏上的文字在花哨的内容上难以辨认，
  /// 高于 0.85 加上重模糊就与实色没有区别了。
  static const tintOpacity = StyleRange(0.15, 0.85, 0.05);

  /// 圆角程度：胶囊圆角占栏高一半的比例。1 即完整的胶囊（两端半圆），0 为
  /// 直角；按比例而不是 dp 存，图标与文字变大、栏随之变高时形状不走样，
  /// 默认值也始终是胶囊。
  static const roundness = StyleRange(0, 1, 0.05);

  /// 导航项（也是选中指示器）的宽度：56 以下“文字”在四个字的名称上要缩得
  /// 很小，96 已是侧边栏的整宽。
  static const itemWidth = StyleRange(56, 96, 2);

  /// 导航项与胶囊内壁的缝（指示器四周离胶囊边的距离）：2 时指示器几乎贴
  /// 边，10 以上胶囊里就空出一圈厚边。
  static const itemInset = StyleRange(2, 10, 1);

  /// 图标大小。
  static const itemIconSize = StyleRange(18, 26, 1);

  /// 文字字号：10 是能稳定读清的下限，14 已与正文同级，再大就喧宾夺主。
  static const itemLabelSize = StyleRange(10, 14, 0.5);

  /// 图标与文字的距离。
  static const itemLabelGap = StyleRange(0, 8, 1);
}
