import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'expressive_icon_swap.dart';

/// 多选列表顶栏的“全选 / 取消全选”按钮（草稿箱、回收站共用）。
///
/// 外观是列表勾选框的总开关（图形见 [SelectAllIcon]）。只负责展示，选中
/// 集合由页面维护；[onPressed] 为 null 时停用（如正在提交）。
class SelectAllButton extends StatelessWidget {
  const SelectAllButton({
    super.key,
    required this.allSelected,
    required this.onPressed,
  });

  final bool allSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: allSelected ? l10n.commonDeselectAll : l10n.commonSelectAll,
      isSelected: allSelected,
      onPressed: onPressed,
      icon: SelectAllIcon(allSelected: allSelected, enabled: onPressed != null),
    );
  }
}

/// 全选开关的图形：没有全选时为描边的勾选方框，已全选时换成 `primary` 色
/// 的实心方框，两者经 [ExpressiveIconSwap] 切换。
///
/// [SelectAllButton] 与首页多选顶栏的“已选数量”全选开关共用，保证几处
/// 外观与切换动效一致。[color] 为未全选（或停用）时的颜色，null 时取所在
/// 位置的 IconTheme（如 IconButton 的默认图标色）。
class SelectAllIcon extends StatelessWidget {
  const SelectAllIcon({
    super.key,
    required this.allSelected,
    this.enabled = true,
    this.color,
  });

  final bool allSelected;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExpressiveIconSwap(
      switchKey: allSelected,
      child: FaIcon(
        allSelected
            ? FontAwesomeIcons.solidSquareCheck
            : FontAwesomeIcons.squareCheck,
        size: 18,
        color: allSelected && enabled
            ? Theme.of(context).colorScheme.primary
            : color,
      ),
    );
  }
}
