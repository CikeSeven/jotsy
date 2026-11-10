/// 首页栏样式中数值字段的取值范围（解码夹紧、滑块与渲染共用）。
library;

import '../../../diaries/models/style_library/style_json.dart';

abstract final class HomeBarStyleLimits {
  /// 玻璃底色的不透明度：低于 0.15 时栏上的文字在花哨的内容上难以辨认，
  /// 高于 0.85 加上重模糊就与实色没有区别了。
  static const tintOpacity = StyleRange(0.15, 0.85, 0.05);
}
