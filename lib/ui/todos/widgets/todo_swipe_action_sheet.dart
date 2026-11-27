import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/todo_settings.dart';
import 'todo_sheet.dart';

/// 设置里“左滑操作”的说法。
String todoSwipeActionLabel(AppLocalizations l10n, TodoSwipeAction action) =>
    switch (action) {
      TodoSwipeAction.delete => l10n.commonDelete,
      TodoSwipeAction.reschedule => l10n.todoReschedule,
    };

/// 选左滑一行待办做什么（删除 / 改期）；关掉面板时为 null。
Future<TodoSwipeAction?> showTodoSwipeActionSheet(
  BuildContext context, {
  required TodoSwipeAction current,
}) {
  return showTodoSheet<TodoSwipeAction>(
    context: context,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      return TodoSheetBody(
        title: l10n.todoSettingsSwipeLeft,
        children: <Widget>[
          for (final action in TodoSwipeAction.values)
            TodoSheetOption(
              icon: switch (action) {
                TodoSwipeAction.delete => FontAwesomeIcons.trashCan,
                TodoSwipeAction.reschedule => FontAwesomeIcons.calendarDay,
              },
              label: todoSwipeActionLabel(l10n, action),
              selected: action == current,
              onTap: () => Navigator.of(sheetContext).pop(action),
            ),
        ],
      );
    },
  );
}
