import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/todo_check_box.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/diary_todo_items.dart';
import 'todo_list_picker_sheet.dart';
import 'todo_sheet.dart';

/// “转为独立待办”：列出日记正文里的待办列表项（未勾的默认选中），选好
/// 清单后批量建成独立待办，关联这篇日记并在 `metadata` 记下来源。日记正文
/// 不改动——两者从此各自独立。
///
/// 建好后在打开方给出“已添加 N 条待办”的提示。
Future<void> showTodoConvertSheet(
  BuildContext context, {
  required String diaryId,
  required List<DiaryTodoItem> items,
}) async {
  final created = await showTodoSheet<int>(
    context: context,
    builder: (BuildContext sheetContext) =>
        _ConvertSheet(diaryId: diaryId, items: items),
  );
  if (created == null || created == 0 || !context.mounted) return;
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(context.l10n.todoConvertDone(created))),
    ),
  );
}

class _ConvertSheet extends ConsumerStatefulWidget {
  const _ConvertSheet({required this.diaryId, required this.items});

  final String diaryId;
  final List<DiaryTodoItem> items;

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends ConsumerState<_ConvertSheet> {
  late final Set<int> _selected = <int>{
    for (var i = 0; i < widget.items.length; i++)
      if (!widget.items[i].checked) i,
  };
  late String? _listId = ref.read(todoSettingsProvider).defaultListId;
  bool _saving = false;

  Future<void> _submit() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    final inputs = <TodoInput>[
      for (var i = 0; i < widget.items.length; i++)
        if (_selected.contains(i))
          TodoInput(
            title: widget.items[i].text,
            listId: _listId,
            linkedDiaryId: widget.diaryId,
            sourceDiaryId: widget.diaryId,
          ),
    ];
    try {
      await ref.read(appDatabaseProvider).createTodos(inputs);
      if (mounted) Navigator.of(context).pop(inputs.length);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    String listName = l10n.todoViewInbox;
    for (final list in lists) {
      if (list.listId == _listId) listName = list.name;
    }
    return TodoSheetBody(
      title: l10n.todoConvertTitle,
      trailing: TextButton(
        onPressed: _selected.isEmpty || _saving ? null : _submit,
        child: Text(l10n.todoConvertSubmit(_selected.length)),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Text(
            l10n.todoConvertHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: FaIcon(
            FontAwesomeIcons.listCheck,
            size: 16,
            color: scheme.primary,
          ),
          title: Text(l10n.todoFieldList),
          trailing: Text(
            listName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          onTap: () async {
            final choice = await showTodoListPickerSheet(
              context,
              current: _listId,
            );
            if (choice != null && mounted) {
              setState(() => _listId = choice.listId);
            }
          },
        ),
        const Divider(indent: 16, endIndent: 16),
        for (var i = 0; i < widget.items.length; i++)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titleAlignment: ListTileTitleAlignment.center,
            leading: TodoCheckBoxVisual(checked: _selected.contains(i)),
            title: Text(
              widget.items[i].text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: widget.items[i].checked
                  ? TextStyle(
                      color: scheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    )
                  : null,
            ),
            selected: _selected.contains(i),
            onTap: () => setState(
              () => _selected.contains(i)
                  ? _selected.remove(i)
                  : _selected.add(i),
            ),
          ),
      ],
    );
  }
}
