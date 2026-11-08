import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_button_group.dart';
import 'todo_labels.dart';
import 'todo_sheet.dart';

/// 自定义重复：单位（天 / 周 / 月 / 年）、间隔、每周落在星期几、每月的哪
/// 一天、是否从完成那天起算、结束条件。点“保存”返回规则，关闭为 null。
///
/// 草稿只在面板内存里，保存时一次交出；起点沿用 [initial] 的起点（截止日）。
/// 法定工作日不在这里改（它没有间隔与单位），从它进来时按“每天”起步。
Future<TodoRepeatRule?> showTodoRepeatCustomSheet(
  BuildContext context, {
  required TodoRepeatRule initial,
}) {
  return showTodoSheet<TodoRepeatRule>(
    context: context,
    builder: (BuildContext sheetContext) =>
        _CustomRepeatSheet(initial: initial),
  );
}

enum _EndMode { never, until, count }

class _CustomRepeatSheet extends StatefulWidget {
  const _CustomRepeatSheet({required this.initial});

  final TodoRepeatRule initial;

  @override
  State<_CustomRepeatSheet> createState() => _CustomRepeatSheetState();
}

class _CustomRepeatSheetState extends State<_CustomRepeatSheet> {
  late TodoRepeatRule _rule =
      widget.initial.frequency == TodoRepeatFrequency.legalWorkdays
      ? widget.initial.copyWith(frequency: TodoRepeatFrequency.daily)
      : widget.initial;

  _EndMode get _endMode => _rule.until != null
      ? _EndMode.until
      : _rule.count != null
      ? _EndMode.count
      : _EndMode.never;

  void _update(TodoRepeatRule next) => setState(() => _rule = next);

  Future<void> _pickUntil() async {
    final anchor = _rule.anchor;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _rule.until ?? DateTime(anchor.year, anchor.month + 1, anchor.day),
      firstDate: anchor,
      lastDate: DateTime(anchor.year + 30, 12, 31),
    );
    if (picked != null && mounted) {
      _update(_rule.copyWith(until: picked, clearCount: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final completion = _rule.basis == TodoRepeatBasis.completion;
    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: labelStyle),
          const SizedBox(height: AppSpacing.s),
          child,
        ],
      ),
    );

    return TodoSheetBody(
      title: l10n.todoRepeatCustomTitle,
      trailing: TextButton(
        onPressed: () => Navigator.of(context).pop(_rule),
        child: Text(l10n.commonSave),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Text(
            TodoLabels.repeat(l10n, _rule),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
          ),
        ),
        section(
          l10n.todoRepeatInterval,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExpressiveButtonGroup<TodoRepeatFrequency>(
                dense: true,
                minSegmentWidth: 56,
                segments: <ButtonSegment<TodoRepeatFrequency>>[
                  ButtonSegment<TodoRepeatFrequency>(
                    value: TodoRepeatFrequency.daily,
                    label: Text(l10n.todoRepeatUnitDay),
                  ),
                  ButtonSegment<TodoRepeatFrequency>(
                    value: TodoRepeatFrequency.weekly,
                    label: Text(l10n.todoRepeatUnitWeek),
                  ),
                  ButtonSegment<TodoRepeatFrequency>(
                    value: TodoRepeatFrequency.monthly,
                    label: Text(l10n.todoRepeatUnitMonth),
                  ),
                  ButtonSegment<TodoRepeatFrequency>(
                    value: TodoRepeatFrequency.yearly,
                    label: Text(l10n.todoRepeatUnitYear),
                  ),
                ],
                selected: <TodoRepeatFrequency>{_rule.frequency},
                onSelectionChanged: (Set<TodoRepeatFrequency> value) =>
                    _update(_rule.copyWith(frequency: value.single)),
              ),
              const SizedBox(height: AppSpacing.s),
              _CountStepper(
                value: _rule.interval,
                max: TodoRepeatRule.maxInterval,
                onChanged: (int value) =>
                    _update(_rule.copyWith(interval: value)),
              ),
            ],
          ),
        ),
        if (_rule.frequency == TodoRepeatFrequency.weekly && !completion)
          section(
            l10n.todoRepeatOnDays,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  FilterChip(
                    label: Text(TodoLabels.weekdayName(l10n, day)),
                    selected:
                        (_rule.weekdays.isEmpty
                                ? <int>[_rule.anchor.weekday]
                                : _rule.weekdays)
                            .contains(day),
                    onSelected: (bool on) {
                      final current = _rule.weekdays.isEmpty
                          ? <int>{_rule.anchor.weekday}
                          : _rule.weekdays.toSet();
                      on ? current.add(day) : current.remove(day);
                      // 至少留一天：全取消时回到起点那天的星期。
                      _update(
                        _rule.copyWith(
                          weekdays: TodoRepeatRule.normalizeWeekdays(current),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        if (_rule.frequency == TodoRepeatFrequency.monthly && !completion)
          section(
            l10n.todoRepeatOnDays,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final mode in TodoMonthlyMode.values)
                  ChoiceChip(
                    label: Text(
                      TodoLabels.repeat(
                        l10n,
                        TodoRepeatRule(
                          frequency: TodoRepeatFrequency.monthly,
                          monthlyMode: mode,
                          anchor: _rule.anchor,
                        ),
                      ),
                    ),
                    selected: _rule.monthlyMode == mode,
                    onSelected: (_) =>
                        _update(_rule.copyWith(monthlyMode: mode)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s),
        SwitchListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(l10n.todoRepeatFromCompletion),
          subtitle: Text(l10n.todoRepeatFromCompletionSubtitle),
          value: completion,
          onChanged: (bool on) => _update(
            _rule.copyWith(
              basis: on ? TodoRepeatBasis.completion : TodoRepeatBasis.due,
            ),
          ),
        ),
        section(
          l10n.todoRepeatEnds,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.todoRepeatEndsNever),
                selected: _endMode == _EndMode.never,
                onSelected: (_) =>
                    _update(_rule.copyWith(clearUntil: true, clearCount: true)),
              ),
              ChoiceChip(
                label: Text(
                  _rule.until == null
                      ? l10n.todoRepeatEndsOnPick
                      : l10n.todoRepeatEndsOn(
                          l10n.formatFullDate(_rule.until!),
                        ),
                ),
                selected: _endMode == _EndMode.until,
                onSelected: (_) => _pickUntil(),
              ),
              ChoiceChip(
                label: Text(
                  _rule.count == null
                      ? l10n.todoRepeatEndsAfterPick
                      : l10n.todoRepeatEndsAfter(_rule.count!),
                ),
                selected: _endMode == _EndMode.count,
                onSelected: (_) => _update(
                  _rule.copyWith(count: _rule.count ?? 10, clearUntil: true),
                ),
              ),
            ],
          ),
        ),
        if (_endMode == _EndMode.count)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              0,
            ),
            child: _CountStepper(
              value: _rule.count!,
              max: TodoRepeatRule.maxCount,
              onChanged: (int value) => _update(_rule.copyWith(count: value)),
            ),
          ),
      ],
    );
  }
}

/// 减 / 数值 / 加 的步进器（间隔与重复次数共用），最小为 1。
class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = AppGlassField.tonalButtonStyle(context);
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          style: style,
          tooltip: '−',
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const FaIcon(FontAwesomeIcons.minus, size: 14),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          style: style,
          tooltip: '+',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
        ),
      ],
    );
  }
}
