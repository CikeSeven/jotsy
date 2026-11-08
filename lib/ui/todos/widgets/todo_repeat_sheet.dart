import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import 'todo_labels.dart';
import 'todo_repeat_custom_sheet.dart';
import 'todo_sheet.dart';

/// 重复面板的结果：新的规则，[rule] 为 null 即不重复。
@immutable
class TodoRepeatChoice {
  const TodoRepeatChoice(this.rule);

  final TodoRepeatRule? rule;
}

/// 选重复：不重复 / 每天 / 法定工作日 / 每周（起点那天的星期）/ 每月（起点
/// 那天的几号）/ 每年（起点那天的月日）/ 自定义…。预设都以 [anchor]（截止日；
/// 没有日期时为今天）为起点。关闭面板不改动时为 null。
Future<TodoRepeatChoice?> showTodoRepeatSheet(
  BuildContext context, {
  required TodoRepeatRule? current,
  required DateTime anchor,
}) {
  return showTodoSheet<TodoRepeatChoice>(
    context: context,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final presets = <TodoRepeatRule>[
        TodoRepeatRule(frequency: TodoRepeatFrequency.daily, anchor: anchor),
        TodoRepeatRule(
          frequency: TodoRepeatFrequency.legalWorkdays,
          anchor: anchor,
        ),
        TodoRepeatRule(
          frequency: TodoRepeatFrequency.weekly,
          weekdays: <int>[anchor.weekday],
          anchor: anchor,
        ),
        TodoRepeatRule(frequency: TodoRepeatFrequency.monthly, anchor: anchor),
        TodoRepeatRule(frequency: TodoRepeatFrequency.yearly, anchor: anchor),
      ];
      final matched = current != null && presets.contains(current);
      void choose(TodoRepeatRule? rule) =>
          Navigator.of(sheetContext).pop(TodoRepeatChoice(rule));

      Future<void> custom() async {
        final rule = await showTodoRepeatCustomSheet(
          sheetContext,
          initial:
              current ??
              TodoRepeatRule(
                frequency: TodoRepeatFrequency.weekly,
                weekdays: <int>[anchor.weekday],
                anchor: anchor,
              ),
        );
        if (rule != null && sheetContext.mounted) choose(rule);
      }

      return TodoSheetBody(
        title: l10n.todoFieldRepeat,
        children: <Widget>[
          TodoSheetOption(
            icon: FontAwesomeIcons.ban,
            label: l10n.todoRepeatNone,
            selected: current == null,
            onTap: () => choose(null),
          ),
          for (final preset in presets)
            TodoSheetOption(
              icon: FontAwesomeIcons.repeat,
              label: TodoLabels.repeat(l10n, preset),
              selected: preset == current,
              onTap: () => choose(preset),
            ),
          TodoSheetOption(
            icon: FontAwesomeIcons.sliders,
            label: l10n.todoRepeatCustom,
            detail: current != null && !matched
                ? TodoLabels.repeat(l10n, current)
                : null,
            selected: false,
            onTap: custom,
          ),
        ],
      );
    },
  );
}
