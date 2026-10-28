import 'package:flutter/material.dart';

import 'app_glass_scope.dart';
import 'on_glass.dart';

/// 输入框类小控件（搜索栏、筛选胶囊、按钮组未选中的段落等）在玻璃下的填充
/// 与描边。
///
/// 两种情况都换成半透明，且都**不模糊**——这些控件多在顶栏、面板或另一块
/// 玻璃上，同一区域禁止叠两层模糊（AGENTS.md §6）；直接放在页面上的少数
/// 控件（如探索页的统计范围条）同样只透出半透明底色：
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

  /// 色调按钮（`FilledButton.tonal` / `IconButton.filledTonal`）在玻璃下的
  /// 底色与描边，经典时为 null。主题无法单独给 tonal 变体取色（它与实心
  /// `FilledButton` 共用 filledButtonTheme），所以由调用处传入
  /// `style:`；已有 style 的用 `tonalButtonStyle(context)?.merge(style) ??
  /// style`，玻璃的底色与描边优先。禁用态保留按钮自己的禁用色。
  static ButtonStyle? tonalButtonStyle(BuildContext context) {
    final field = of(context);
    if (field == null) return null;
    final side = field.border;
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.disabled) ? null : field.fill,
      ),
      side: side == null ? null : WidgetStatePropertyAll(side),
    );
  }
}
