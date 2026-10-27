import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_choice_tile.dart';

/// 日历范围“存为日记本”的小面板：智能日记本（按日期区间自动收录）或普通
/// 日记本（收进现在的 [count] 篇）。点一项即返回它的类型，关闭返回 null。
Future<NotebookKind?> showNotebookSaveRangeSheet(
  BuildContext context, {
  required int count,
}) {
  return showAppModalBottomSheet<NotebookKind>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l + MediaQuery.paddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xs,
                bottom: AppSpacing.m,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.notebookSaveRange,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ExpressiveChoiceTile(
              label: l10n.notebookSaveRangeSmart,
              description: l10n.notebookSaveRangeSmartHint,
              selected: false,
              onTap: () => Navigator.of(sheetContext).pop(NotebookKind.smart),
            ),
            ExpressiveChoiceTile(
              label: l10n.notebookSaveRangeManual,
              description: l10n.notebookSaveRangeManualHint(count),
              selected: false,
              onTap: () => Navigator.of(sheetContext).pop(NotebookKind.manual),
            ),
          ],
        ),
      );
    },
  );
}
