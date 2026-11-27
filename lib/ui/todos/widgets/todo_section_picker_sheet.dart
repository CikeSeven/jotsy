import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import 'todo_sheet.dart';

/// 选分区的结果：[sectionId] 为 null 即未分区。
@immutable
class TodoSectionChoice {
  const TodoSectionChoice(this.sectionId);

  final String? sectionId;
}

/// 在清单的 [sections] 里选一个（“未分区”在最前），当前的打勾；关掉面板
/// 不选时为 null。[current] 为 null 即当前未分区；为 `''` 时一项都不标
/// （多选移到分区时）。
Future<TodoSectionChoice?> showTodoSectionPickerSheet(
  BuildContext context, {
  required List<TodoSection> sections,
  required String? current,
}) {
  return showTodoSheet<TodoSectionChoice>(
    context: context,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      return TodoSheetBody(
        title: l10n.todoFieldSection,
        children: <Widget>[
          TodoSheetOption(
            icon: FontAwesomeIcons.inbox,
            label: l10n.todoSectionNone,
            selected: current == null,
            onTap: () =>
                Navigator.of(sheetContext).pop(const TodoSectionChoice(null)),
          ),
          for (final section in sections)
            TodoSheetOption(
              icon: FontAwesomeIcons.tableList,
              label: section.name,
              selected: section.id == current,
              onTap: () =>
                  Navigator.of(sheetContext).pop(TodoSectionChoice(section.id)),
            ),
        ],
      );
    },
  );
}
