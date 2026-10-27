import 'package:flutter/material.dart';

import 'app_glass_scope.dart';
import 'on_glass.dart';

/// 输入框类小控件（搜索栏、筛选胶囊等）在玻璃下的填充与描边。
///
/// 两种情况都换成半透明，且都**不模糊**——这些控件都在顶栏、面板或另一块
/// 玻璃上，同一区域禁止叠两层模糊（AGENTS.md §6）：
/// - “控件”组件为玻璃：填充取玻璃底色 [AppGlassResolved.fill]（高对比度时
///   已是不透明的等效色），描边取玻璃描边（设置关闭描边时为 null）；
/// - 控件本身是经典，但画在一块玻璃表面上（[OnGlass]）：不透明的输入框底色
///   会成为一块实色补丁，换成 [OnGlass.wellColor]，不加描边。
///
/// 两者都不是时返回 null，调用方照旧用经典的颜色与结构。
@immutable
class AppGlassField {
  const AppGlassField({required this.fill, this.border});

  /// 半透明填充色。
  final Color fill;

  /// 玻璃描边；null 不画（或沿用调用方原有的描边规则）。
  final BorderSide? border;

  /// 当前位置的玻璃填充；经典时为 null。会依赖材质 scope 与 [OnGlass]。
  static AppGlassField? of(BuildContext context) {
    final glass = AppGlass.of(context);
    if (glass.isGlass(AppGlassComponent.controls)) {
      return AppGlassField(fill: glass.fill, border: glass.border);
    }
    if (OnGlass.of(context)) {
      return AppGlassField(
        fill: OnGlass.wellColor(Theme.of(context).colorScheme),
      );
    }
    return null;
  }
}
