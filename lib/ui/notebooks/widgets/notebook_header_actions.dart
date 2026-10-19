import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';

/// 首页日记本头部卡片的操作行：一排小号的浅色按钮，窄屏时折行。
///
/// “添加日记”（从已有日记挑选，见 `NotebookAddDiariesPage`）、“目录”
/// （`NotebookContentsPage`）与“统计”（`NotebookInsightsPage`，智能日记本也
/// 有）。回调为 null 的按钮不显示。
class NotebookHeaderActions extends StatelessWidget {
  const NotebookHeaderActions({
    super.key,
    required this.onAddDiaries,
    this.onOpenContents,
    this.onOpenInsights,
  });

  final VoidCallback? onAddDiaries;
  final VoidCallback? onOpenContents;
  final VoidCallback? onOpenInsights;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onAddDiaries = this.onAddDiaries;
    final onOpenContents = this.onOpenContents;
    final onOpenInsights = this.onOpenInsights;
    // 小号按钮：紧凑密度、缩小内边距，仍保留 40dp 的可点高度。
    final style = FilledButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: <Widget>[
          if (onAddDiaries != null)
            FilledButton.tonalIcon(
              style: style,
              onPressed: onAddDiaries,
              icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
              label: Text(l10n.notebookAddDiaries),
            ),
          if (onOpenContents != null)
            FilledButton.tonalIcon(
              style: style,
              onPressed: onOpenContents,
              icon: const FaIcon(FontAwesomeIcons.listUl, size: 12),
              label: Text(l10n.notebookContents),
            ),
          if (onOpenInsights != null)
            FilledButton.tonalIcon(
              style: style,
              onPressed: onOpenInsights,
              icon: const FaIcon(FontAwesomeIcons.chartSimple, size: 12),
              label: Text(l10n.notebookInsights),
            ),
        ],
      ),
    );
  }
}
