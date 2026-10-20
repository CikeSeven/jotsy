import 'package:flutter/material.dart';

import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../settings_option_tiles.dart';
import 'style_color_dialog.dart';

/// 一个自定义颜色（浅色 / 深色两态）的设置行：右侧色块显示当前明暗下的实际
/// 颜色，点按打开取色对话框，取消时不改动。深色为 null 时按 [role] 自动推导。
class StyleCustomColorTile extends StatelessWidget {
  const StyleCustomColorTile({
    super.key,
    required this.title,
    required this.light,
    required this.dark,
    required this.role,
    required this.onChanged,
    this.subtitle,
    this.nested = false,
  });

  final String title;
  final String? subtitle;

  /// 是否为上一行的从属项：与 `SettingsSwitchTile.nested` 相同的缩进与标题
  /// 字阶。
  final bool nested;
  final int light;
  final int? dark;
  final DiaryCardColorRole role;
  final ValueChanged<StyleCustomColor> onChanged;

  Color _shown(Brightness brightness) {
    if (brightness == Brightness.light) {
      return Color(light);
    }
    final dark = this.dark;
    return dark != null
        ? Color(dark)
        : DiaryCardColors.deriveDark(Color(light), role);
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showStyleColorDialog(
      context,
      title: title,
      light: light,
      dark: dark,
      role: role,
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        nested ? SettingsSwitchTile.nestedIndent : 16,
        4,
        16,
        4,
      ),
      title: Text(
        title,
        style: nested ? SettingsSwitchTile.nestedTitleStyle : null,
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _shown(scheme.brightness),
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      onTap: () => _edit(context),
    );
  }
}
