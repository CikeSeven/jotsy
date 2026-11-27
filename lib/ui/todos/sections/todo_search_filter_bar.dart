import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_search_filter.dart';
import '../widgets/todo_list_picker_sheet.dart';
import '../widgets/todo_tag_picker_sheet.dart';

/// 待办搜索页顶部的一排筛选（横向可滚，桌面可拖动 / 滚轮横滚）：状态单选
/// （全部 / 未完成 / 已完成）、清单、标签（有待办标签或已选时才出现）、只看
/// 高优先级、只看有日期的。
///
/// 清单胶囊没选时点开选清单面板；选了之后显示清单名，点它换一个、点 ×
/// 去掉。筛选只是页面临时状态，经 [onChanged] 交回新的 [TodoSearchFilter]。
class TodoSearchFilterBar extends ConsumerWidget {
  const TodoSearchFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.padding,
  });

  final TodoSearchFilter filter;
  final ValueChanged<TodoSearchFilter> onChanged;

  /// 左右留白（与结果列表对齐）。
  final EdgeInsets padding;

  Future<void> _pickList(BuildContext context) async {
    final choice = await showTodoListPickerSheet(
      context,
      // 还没按清单筛时一项都不标（null 会标出收集箱）。
      current: filter.listChosen ? filter.listId : '',
    );
    if (choice == null) return;
    onChanged(filter.withList(choice.listId));
  }

  Future<void> _pickTag(BuildContext context) async {
    final tag = await showTodoTagPickOneSheet(context);
    if (tag != null) onChanged(filter.withTag(tag));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = ref.watch(todoListsProvider).value ?? const [];
    final hasTags = ref.watch(
      todoTagsProvider.select((value) => value.value?.isNotEmpty ?? false),
    );
    final tag = filter.tag;
    String? listName;
    if (filter.listChosen) {
      final id = filter.listId;
      listName = id == null
          ? l10n.todoViewInbox
          : lists.where((list) => list.listId == id).firstOrNull?.name;
    }

    Widget gap() => const SizedBox(width: AppSpacing.s);
    Widget status(String label, TodoSearchStatus value) => ChoiceChip(
      label: Text(label),
      selected: filter.status == value,
      onSelected: (_) => onChanged(filter.copyWith(status: value)),
    );

    return DesktopHorizontalScroll(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: Row(
          children: <Widget>[
            Semantics(
              container: true,
              label: l10n.todoSearchFilterStatus,
              child: Row(
                children: <Widget>[
                  status(l10n.todoViewAll, TodoSearchStatus.all),
                  gap(),
                  status(l10n.todoSearchFilterOpen, TodoSearchStatus.open),
                  gap(),
                  status(l10n.todoViewCompleted, TodoSearchStatus.done),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.l),
            FilterChip(
              label: Text(listName ?? l10n.todoFieldList),
              selected: filter.listChosen,
              onSelected: (_) => unawaited(_pickList(context)),
              onDeleted: filter.listChosen
                  ? () => onChanged(filter.withoutList())
                  : null,
            ),
            if (hasTags || tag != null) ...<Widget>[
              gap(),
              FilterChip(
                label: Text(tag == null ? l10n.todoFieldTags : '@$tag'),
                selected: tag != null,
                onSelected: (_) => unawaited(_pickTag(context)),
                onDeleted: tag == null
                    ? null
                    : () => onChanged(filter.withTag(null)),
              ),
            ],
            gap(),
            FilterChip(
              label: Text(l10n.todoSearchFilterHigh),
              selected: filter.highOnly,
              onSelected: (bool value) =>
                  onChanged(filter.copyWith(highOnly: value)),
            ),
            gap(),
            FilterChip(
              label: Text(l10n.todoSearchFilterDated),
              selected: filter.datedOnly,
              onSelected: (bool value) =>
                  onChanged(filter.copyWith(datedOnly: value)),
            ),
          ],
        ),
      ),
    );
  }
}
