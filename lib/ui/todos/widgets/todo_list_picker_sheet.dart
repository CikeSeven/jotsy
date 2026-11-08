import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../controllers/todo_list_actions.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';
import 'todo_sheet.dart';

/// 选清单面板的结果：[listId] 为 null 即收集箱。
@immutable
class TodoListChoice {
  const TodoListChoice(this.listId);

  final String? listId;
}

/// 选一个清单（收集箱在最前，最后是“新建清单”——新建成功即选中它）。
/// 关闭面板不改动时为 null。
Future<TodoListChoice?> showTodoListPickerSheet(
  BuildContext context, {
  required String? current,
}) {
  return showTodoSheet<TodoListChoice>(
    context: context,
    builder: (BuildContext sheetContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        final l10n = context.l10n;
        final scheme = Theme.of(context).colorScheme;
        final lists = ref.watch(todoListsProvider).value ?? const [];
        return TodoSheetBody(
          title: l10n.todoFieldList,
          children: <Widget>[
            TodoSheetOption(
              icon: TodoLabels.smartViewIcon(TodoSmartView.inbox),
              label: l10n.todoViewInbox,
              selected: current == null,
              onTap: () =>
                  Navigator.of(context).pop(const TodoListChoice(null)),
            ),
            for (final list in lists)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: FaIcon(
                  TodoListStyle.iconOfRow(list),
                  size: 18,
                  color: TodoListStyle.accentOf(
                    list.colorKey,
                    scheme,
                  ).onContainer,
                ),
                title: Text(list.name),
                selected: list.listId == current,
                trailing: list.listId == current
                    ? FaIcon(
                        FontAwesomeIcons.check,
                        size: 16,
                        color: scheme.primary,
                      )
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(TodoListChoice(list.listId)),
              ),
            TodoSheetOption(
              icon: FontAwesomeIcons.plus,
              label: l10n.todoListNew,
              onTap: () async {
                final id = await createTodoListFlow(context, ref);
                if (id != null && context.mounted) {
                  Navigator.of(context).pop(TodoListChoice(id));
                }
              },
            ),
          ],
        );
      },
    ),
  );
}
