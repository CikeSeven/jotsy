import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';

/// 树形列表里一行的展开 / 收起（下面有列出来的子本时才有）。
@immutable
class NotebookRowToggle {
  const NotebookRowToggle({required this.expanded, required this.onToggle});

  /// 子本是否展开着。
  final bool expanded;
  final VoidCallback onToggle;
}

/// 展开 / 收起的箭头：`angleDown`，展开时转成朝上（`medium` + `spatial`），
/// 与书架“已合上”、目录页章节同一组方向。颜色与尺寸默认取所在的
/// `IconTheme`（[color] / [size] 可覆盖）。
class NotebookTreeChevron extends StatelessWidget {
  const NotebookTreeChevron({
    super.key,
    required this.expanded,
    this.size,
    this.color,
  });

  final bool expanded;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.spatial,
      child: FaIcon(FontAwesomeIcons.angleDown, size: size, color: color),
    );
  }
}

/// 行尾的展开 / 收起按钮（管理页、选本面板、上级选择面板、小组件与 AI 的
/// 选本面板共用）：16px `onSurfaceVariant` 箭头，提示“收起子本 / 展开子本”。
///
/// [compact] 时触控区收成 40 × 40（放进最小高 56、上下留 8 的选本行里不把
/// 行撑高），否则为默认的 48。
class NotebookTreeToggleButton extends StatelessWidget {
  const NotebookTreeToggleButton({
    super.key,
    required this.toggle,
    this.compact = false,
  });

  final NotebookRowToggle toggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: toggle.expanded
          ? l10n.notebookSubCollapse
          : l10n.notebookSubExpand,
      onPressed: toggle.onToggle,
      style: compact
          ? IconButton.styleFrom(
              minimumSize: const Size.square(40),
              fixedSize: const Size.square(40),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      icon: NotebookTreeChevron(
        expanded: toggle.expanded,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
