import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../viewmodels/todo_ai_output.dart';
import 'todo_ai_preview.dart';
import 'todo_bare_input.dart';
import 'todo_labels.dart';
import 'todo_quick_input.dart';

/// “AI 整理”预览里的一条待办：勾选框 + 可直接改的标题 + 认出的值
/// （日期 / 时刻、清单、标签、优先级）胶囊，点 × 去掉那一项。改动经
/// [onEdit] 交出整条新值；标题逐字交出（只改预览，不写库）。
class TodoAiOrganizeItem extends StatefulWidget {
  const TodoAiOrganizeItem({
    super.key,
    required this.item,
    required this.on,
    required this.today,
    required this.lists,
    required this.onToggle,
    required this.onEdit,
  });

  final TodoAiItem item;
  final bool on;
  final DateTime today;
  final List<TodoListRow> lists;
  final VoidCallback onToggle;
  final ValueChanged<TodoAiItem> onEdit;

  @override
  State<TodoAiOrganizeItem> createState() => _TodoAiOrganizeItemState();
}

class _TodoAiOrganizeItemState extends State<TodoAiOrganizeItem> {
  late final TextEditingController _title = TextEditingController(
    text: widget.item.title,
  );

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final dismiss = l10n.todoQuickParseDismiss;
    String? listName;
    for (final list in widget.lists) {
      if (list.listId == item.listId) listName = list.name;
    }
    final date = item.date;
    final chips = <Widget>[
      if (date != null)
        TodoParsedChip(
          icon: item.minute == null
              ? FontAwesomeIcons.calendar
              : FontAwesomeIcons.clock,
          label: TodoLabels.due(context, date, item.minute, widget.today),
          tooltip: dismiss,
          onDismiss: () => widget.onEdit(item.copyWith(clearDate: true)),
        ),
      if (listName != null)
        TodoParsedChip(
          icon: FontAwesomeIcons.hashtag,
          label: listName,
          tooltip: dismiss,
          onDismiss: () => widget.onEdit(item.copyWith(clearList: true)),
        ),
      for (final tag in item.tags)
        TodoParsedChip(
          icon: FontAwesomeIcons.at,
          label: tag,
          tooltip: dismiss,
          onDismiss: () => widget.onEdit(
            item.copyWith(
              tags: <String>[
                for (final other in item.tags)
                  if (!TodoTags.same(other, tag)) other,
              ],
            ),
          ),
        ),
      if (item.priority != TodoPriority.none)
        TodoParsedChip(
          icon: FontAwesomeIcons.solidFlag,
          iconColor: TodoLabels.priorityColor(scheme, item.priority),
          label: TodoLabels.priority(l10n, item.priority),
          tooltip: dismiss,
          onDismiss: () =>
              widget.onEdit(item.copyWith(priority: TodoPriority.none)),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TodoAiKeepBox(
          title: item.title,
          value: widget.on,
          onChanged: widget.onToggle,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _title,
                  maxLength: TodoAiItem.maxTitleLength,
                  minLines: 1,
                  maxLines: 3,
                  contextMenuBuilder: appTextContextMenuBuilder,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: widget.on
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                  decoration: todoBareInputDecoration(),
                  onChanged: (String text) =>
                      widget.onEdit(widget.item.copyWith(title: text)),
                ),
                if (chips.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
