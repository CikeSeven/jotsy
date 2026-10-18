import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../viewmodels/diary_template_auto_labels.dart';
import '../viewmodels/diary_template_library.dart';

/// 从可选用的模板里单选一个的底部面板：自动套用的默认模板与时间段规则的
/// 模板共用。
///
/// 关闭面板返回 null；选了一项返回 `(id: …)`，其中 `(id: null)` 为“不自动
/// 套用”——只有 [allowNone] 为 true 时才有这一项（时间段必须指向一个模板）。
/// [selectedId] 为当前选中的模板；它已被隐藏或删除时没有选中项。
Future<({String? id})?> showDiaryTemplateChoiceSheet(
  BuildContext context, {
  required DiaryTemplateLibrary library,
  required String? selectedId,
  required String title,
  String? hint,
  bool allowNone = true,
}) {
  return showModalBottomSheet<({String? id})>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      void pick(String? id) => Navigator.of(sheetContext).pop((id: id));
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        builder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  0,
                  AppSpacing.xs,
                  hint == null ? AppSpacing.m : 0,
                ),
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.m,
                  ),
                  child: Text(
                    hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (allowNone)
                ExpressiveChoiceTile(
                  label: l10n.diaryTemplatesAutoApplyNone,
                  selected: selectedId == null,
                  onTap: () => pick(null),
                ),
              for (final (index, template)
                  in library.visible.indexed) ...<Widget>[
                if (allowNone || index > 0)
                  const SizedBox(height: AppSpacing.s),
                ExpressiveChoiceTile(
                  label: diaryTemplateDisplayName(l10n, template),
                  description: template.description.isEmpty
                      ? null
                      : template.description,
                  selected: selectedId == template.id,
                  onTap: () => pick(template.id),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}
