import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';

/// 日记模块底部面板（分享、导出）共用的分组标题：主色小图标 + 粗体标题。
class DiarySheetSectionHeader extends StatelessWidget {
  const DiarySheetSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final FaIconData icon;
  final String label;

  /// 标题行右侧的补充信息（如“共 12 篇”）。
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = this.trailing;
    return Semantics(
      header: true,
      child: Row(
        children: <Widget>[
          FaIcon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s),
          // 窄屏与大字号下标题换行，不溢出（DESIGN.md §6）。
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// 面板内的开关行：与设置页 SwitchListTile 同款，左右内边距收窄以对齐
/// 分组标题。
class DiarySheetSwitch extends StatelessWidget {
  const DiarySheetSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      value: value,
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      onChanged: onChanged,
    );
  }
}
