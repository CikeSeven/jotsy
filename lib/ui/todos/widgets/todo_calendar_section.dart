import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_navigation.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_calendar_index.dart';
import 'todo_quick_add_sheet.dart';
import 'todo_tile.dart';

/// 日历选中日下方的“这天的待办”：标题行（右侧“+”以这一天为截止日新建）
/// 与各条待办（同待办页的行，可直接勾选；重复待办以后的某一次只显示、
/// 不能勾选）。点行打开详情。
class TodoCalendarSection extends ConsumerWidget {
  const TodoCalendarSection({
    super.key,
    required this.day,
    required this.entries,
    required this.today,
  });

  final DateTime day;
  final List<TodoCalendarEntry> entries;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final database = ref.read(appDatabaseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.calendarTodoSectionTitle,
                  style: AppPageBackdrop.onBackgroundTextStyle(
                    context,
                    theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.calendarAddTodo,
              onPressed: () => unawaited(
                showTodoQuickAddSheet(
                  context,
                  preset: TodoQuickAddPreset(
                    dueDate: DateUtils.dateOnly(day),
                    listId: ref.read(todoSettingsProvider).defaultListId,
                  ),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
            ),
          ],
        ),
        for (final entry in entries)
          Padding(
            key: ValueKey<String>(
              'calendar_todo_${entry.row.todoId}_${entry.occurrence}',
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: TodoTile(
              row: entry.row,
              today: today,
              onToggle: entry.projected
                  ? null
                  : () =>
                        unawaited(toggleTodoDone(context, database, entry.row)),
              disabledHint: l10n.calendarTodoRepeatHint,
              onTap: () => unawaited(openTodoDetail(context, entry.row.todoId)),
            ),
          ),
      ],
    );
  }
}
