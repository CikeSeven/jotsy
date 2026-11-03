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
/// 里（附按今天算出的示例；时间下方另有一行 12 小时制的带格式写法与格式
/// 说明）。点按回调 [onInsert] 当前界面语言的占位写法，插到哪个输入框由
/// 编辑页决定。
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

/// 格式说明里举的例子（`{{时间:HH:mm:ss}}`）：与 12 小时制那一行不同，
/// 顺带示范秒。图案是语法而不是文案，两种界面语言相同，所以不进 ARB。
const String _timeFormatExample = 'HH:mm:ss';

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
      final time12hFormat = l10n.diaryTemplateVarTime12hFormat;
      void pick(String token) => Navigator.of(sheetContext).pop(token);
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
              for (final variable in DiaryTemplateVariable.values) ...<Widget>[
                _VariableTile(
                  label: diaryTemplateVariableLabel(l10n, variable),
                  example: values[variable] ?? '',
                  token: diaryTemplateVariableToken(l10n, variable),
                  onPick: pick,
                ),
                // 时间可以带格式：紧跟一行常用的 12 小时制（图案按界面语言的
                // 习惯，取自 ARB），再用一句说明告诉用户可以自己写。
                if (variable == DiaryTemplateVariable.time) ...<Widget>[
                  _VariableTile(
                    label: l10n.diaryTemplateVarTime12hLabel,
                    example: values.valueOf(variable, time12hFormat) ?? '',
                    token: diaryTemplateVariableToken(
                      l10n,
                      variable,
                      format: time12hFormat,
                    ),
                    onPick: pick,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      0,
                      AppSpacing.xs,
                      AppSpacing.s,
                    ),
                    child: Text(
                      l10n.diaryTemplateEditorTimeFormatHint(
                        diaryTemplateVariableToken(
                          l10n,
                          variable,
                          format: _timeFormatExample,
                        ),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      );
    },
  );
}

/// 面板里的一个变量：名称、按今天算出的示例与占位写法，点按挑选这个写法。
class _VariableTile extends StatelessWidget {
  const _VariableTile({
    required this.label,
    required this.example,
    required this.token,
    required this.onPick,
  });

  final String label;
  final String example;
  final String token;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      title: Text(label),
      subtitle: Text(
        context.l10n.diaryTemplateEditorVariableExample(example),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        token,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: () => onPick(token),
    );
  }
}
