import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/diary_template_variables.dart';
import '../viewmodels/diary_template_labels.dart';
import '../viewmodels/diary_template_variable_values.dart';
import '../../widgets/desktop_horizontal_scroll.dart';

/// 模板编辑页的“插入变量”条：常用的几个变量直接点，其余在“全部变量”面板
/// 里（附按今天算出的示例）。点按回调 [onInsert] 当前界面语言的占位写法，
/// 插到哪个输入框由编辑页决定。
class DiaryTemplateVariableBar extends StatelessWidget {
  const DiaryTemplateVariableBar({super.key, required this.onInsert});

  final ValueChanged<String> onInsert;

  static const List<DiaryTemplateVariable> _common = <DiaryTemplateVariable>[
    DiaryTemplateVariable.date,
    DiaryTemplateVariable.weekday,
    DiaryTemplateVariable.time,
    DiaryTemplateVariable.lunar,
    DiaryTemplateVariable.solarTerm,
    DiaryTemplateVariable.question,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DesktopHorizontalScroll(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Row(
          children: <Widget>[
            for (final variable in _common) ...<Widget>[
              ActionChip(
                avatar: const FaIcon(FontAwesomeIcons.plus, size: 10),
                label: Text(diaryTemplateVariableLabel(l10n, variable)),
                onPressed: () =>
                    onInsert(diaryTemplateVariableToken(l10n, variable)),
              ),
              const SizedBox(width: AppSpacing.s),
            ],
            ActionChip(
              avatar: const FaIcon(FontAwesomeIcons.ellipsis, size: 12),
              label: Text(l10n.diaryTemplateEditorAllVariables),
              onPressed: () async {
                final token = await _showAllVariables(context);
                if (token != null) onInsert(token);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showAllVariables(BuildContext context) {
  return showAppModalBottomSheet<String>(
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
      final now = DateTime.now();
      final values = DiaryTemplateVariableValues.compute(
        l10n: l10n,
        diaryDate: now,
        now: now,
      );
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  l10n.diaryTemplateEditorVariablesTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.s,
                ),
                child: Text(
                  l10n.diaryTemplateEditorVariablesHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final variable in DiaryTemplateVariable.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  title: Text(diaryTemplateVariableLabel(l10n, variable)),
                  subtitle: Text(
                    l10n.diaryTemplateEditorVariableExample(
                      values[variable] ?? '',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    diaryTemplateVariableToken(l10n, variable),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(diaryTemplateVariableToken(l10n, variable)),
                ),
            ],
          );
        },
      );
    },
  );
}
