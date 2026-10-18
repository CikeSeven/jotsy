import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../models/diary_template_auto_rule.dart';
import '../viewmodels/diary_template_auto_labels.dart';
import '../viewmodels/diary_template_library.dart';
import '../widgets/diary_template_time_button.dart';
import '../widgets/diary_template_weekday_chips.dart';
import 'diary_template_choice_sheet.dart';

/// 时间段面板的结果：保存一条规则，或删除正在编辑的那条。关闭或取消时
/// 面板返回 null。
@immutable
class DiaryTemplateAutoRuleSheetResult {
  const DiaryTemplateAutoRuleSheetResult.save(DiaryTemplateAutoRule this.rule);

  const DiaryTemplateAutoRuleSheetResult.delete() : rule = null;

  /// 要保存的规则；为 null 表示删除。
  final DiaryTemplateAutoRule? rule;
}

/// 打开添加（[initial] 为 null）或编辑一条时间段规则的面板。新规则默认
/// 07:00–10:00、每天、可选模板里的第一个。面板只编辑草稿，保存与删除由
/// 调用方经控制器写入。
Future<DiaryTemplateAutoRuleSheetResult?> showDiaryTemplateAutoRuleSheet(
  BuildContext context, {
  required DiaryTemplateLibrary library,
  DiaryTemplateAutoRule? initial,
}) {
  return showModalBottomSheet<DiaryTemplateAutoRuleSheetResult>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        DiaryTemplateAutoRuleSheet(library: library, initial: initial),
  );
}

class DiaryTemplateAutoRuleSheet extends StatefulWidget {
  const DiaryTemplateAutoRuleSheet({
    super.key,
    required this.library,
    this.initial,
  });

  final DiaryTemplateLibrary library;
  final DiaryTemplateAutoRule? initial;

  @override
  State<DiaryTemplateAutoRuleSheet> createState() =>
      _DiaryTemplateAutoRuleSheetState();
}

class _DiaryTemplateAutoRuleSheetState
    extends State<DiaryTemplateAutoRuleSheet> {
  late DiaryTemplateAutoRule _rule =
      widget.initial ??
      DiaryTemplateAutoRule(
        startMinute: 7 * 60,
        endMinute: 10 * 60,
        templateId: widget.library.visible.firstOrNull?.id ?? '',
      );

  bool get _sameTime => _rule.startMinute == _rule.endMinute;

  // 规则指向的模板已被删除（或一个可选模板都没有）时不能保存，先换一个。
  bool get _canSave =>
      _rule.isValid && widget.library.byId(_rule.templateId) != null;

  Future<void> _pickTime({required bool start}) async {
    final minute = start ? _rule.startMinute : _rule.endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked == null || !mounted) return;
    final value = picked.hour * 60 + picked.minute;
    setState(() {
      _rule = start
          ? _rule.copyWith(startMinute: value)
          : _rule.copyWith(endMinute: value);
    });
  }

  Future<void> _pickTemplate() async {
    final l10n = context.l10n;
    final picked = await showDiaryTemplateChoiceSheet(
      context,
      library: widget.library,
      selectedId: _rule.templateId,
      title: l10n.diaryTemplatePickerTitle,
      allowNone: false,
    );
    final id = picked?.id;
    if (id == null || !mounted) return;
    setState(() => _rule = _rule.copyWith(templateId: id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final template = widget.library.byId(_rule.templateId);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final String? rangeHint;
    if (_sameTime) {
      rangeHint = l10n.diaryTemplatesAutoApplySameTime;
    } else if (_rule.crossesMidnight) {
      rangeHint = l10n.diaryTemplatesAutoApplyOvernightHint(
        formatDiaryTemplateAutoMinute(context, _rule.endMinute),
      );
    } else {
      rangeHint = null;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.l + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      0,
                      AppSpacing.xs,
                      AppSpacing.m,
                    ),
                    child: Text(
                      widget.initial == null
                          ? l10n.diaryTemplatesAutoApplyAddRule
                          : l10n.diaryTemplatesAutoApplyEditRule,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DiaryTemplateTimeButton(
                          label: l10n.diaryTemplatesAutoApplyStart,
                          time: formatDiaryTemplateAutoMinute(
                            context,
                            _rule.startMinute,
                          ),
                          onPressed: () => _pickTime(start: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: DiaryTemplateTimeButton(
                          label: l10n.diaryTemplatesAutoApplyEnd,
                          time: formatDiaryTemplateAutoMinute(
                            context,
                            _rule.endMinute,
                          ),
                          onPressed: () => _pickTime(start: false),
                        ),
                      ),
                    ],
                  ),
                  if (rangeHint != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xs,
                        AppSpacing.s,
                        AppSpacing.xs,
                        0,
                      ),
                      child: Text(
                        rangeHint,
                        style: _sameTime
                            ? hintStyle?.copyWith(color: colorScheme.error)
                            : hintStyle,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.l),
                  CalendarOptionsFieldLabel(
                    text: l10n.diaryTemplatesAutoApplyDays,
                  ),
                  DiaryTemplateWeekdayChips(
                    selected: _rule.weekdays,
                    onChanged: (weekdays) => setState(
                      () => _rule = _rule.copyWith(weekdays: weekdays),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      AppSpacing.s,
                      AppSpacing.xs,
                      AppSpacing.l,
                    ),
                    child: Text(
                      l10n.diaryTemplatesAutoApplyDaysHint,
                      style: hintStyle,
                    ),
                  ),
                  SettingsCardGroup(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      ListTile(
                        title: Text(l10n.diaryTemplatesAutoApplyTemplate),
                        subtitle: Text(
                          template == null
                              ? l10n.diaryTemplatesAutoApplyMissing
                              : diaryTemplateDisplayName(l10n, template),
                          style: template == null
                              ? TextStyle(color: colorScheme.error)
                              : null,
                        ),
                        trailing: const FaIcon(
                          FontAwesomeIcons.angleRight,
                          size: 14,
                        ),
                        onTap: _pickTemplate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: <Widget>[
              if (widget.initial != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const DiaryTemplateAutoRuleSheetResult.delete()),
                  child: Text(l10n.commonDelete),
                ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton(
                onPressed: _canSave
                    ? () => Navigator.of(
                        context,
                      ).pop(DiaryTemplateAutoRuleSheetResult.save(_rule))
                    : null,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
