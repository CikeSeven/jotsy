import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../controllers/todo_field_editors.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_field_pill.dart';
import 'todo_labels.dart';

/// 详情里的属性胶囊区：日期、提醒、重复、优先级、清单、关联日记，点按打开
/// 对应的面板（[TodoFieldEditors]，选完即写库）。
///
/// 设了值的胶囊为 `secondaryContainer` 底（逾期的日期为 `errorContainer`、
/// 优先级的旗子取强调色），没设的为 `outlineVariant` 描边、只写名称的占位；
/// 关联了日记时后面多一个“打开”按钮。
///
/// 重复待办已完成的某一次（副本）的重复胶囊直接显示原循环计划真实的重复规
/// 则（如“每天”），点按直接编辑原循环计划的重复规则；原待办已被删除时回
/// 退为编辑当前这条的重复规则。
class TodoDetailPills extends ConsumerWidget {
  const TodoDetailPills({
    super.key,
    required this.row,
    required this.today,
    this.series,
  });

  final TodoRow row;
  final DateTime today;

  /// 若当前是重复待办的已完成副本且原待办仍在库里，传入原待办行；重复胶囊
  /// 以它的规则为准并直接编辑它。
  final TodoRow? series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final editors = TodoFieldEditors(
      context: context,
      ref: ref,
      row: row,
      today: today,
    );
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final dueText = row.dueDate;
    final due = dueText == null ? null : parseAnniversaryDate(dueText);
    final reminders = decodeTodoReminders(row.reminders);
    final repeatTarget = series ?? row;
    final repeat = decodeTodoRepeat(repeatTarget.repeat);
    final repeatEditors = series == null
        ? editors
        : TodoFieldEditors(
            context: context,
            ref: ref,
            row: series!,
            today: today,
          );
    final priority = TodoPriority.of(row.priority);
    final tags = TodoTags.ofMetadataText(row.metadata);
    TodoListRow? list;
    for (final item in lists) {
      if (item.listId == row.listId) list = item;
    }
    final sections = list == null
        ? const <TodoSection>[]
        : TodoSections.ofList(list.metadata);
    final overdue =
        due != null &&
        row.completedAt == null &&
        dueText!.compareTo(formatAnniversaryDate(today)) < 0;
    final linkedDiaryId = row.linkedDiaryId;
    final linkedDiary = linkedDiaryId == null
        ? null
        : ref.watch(todoLinkedDiaryProvider(linkedDiaryId));
    final diary = linkedDiary?.value;

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        TodoFieldPill(
          icon: row.dueMinute == null
              ? FontAwesomeIcons.calendar
              : FontAwesomeIcons.clock,
          label: due == null
              ? l10n.todoFieldDue
              : TodoLabels.due(context, due, row.dueMinute, today),
          set: due != null,
          background: overdue ? scheme.errorContainer : null,
          foreground: overdue ? scheme.onErrorContainer : null,
          onTap: () => unawaited(editors.pickDue()),
        ),
        TodoFieldPill(
          icon: FontAwesomeIcons.bell,
          label: reminders.isEmpty
              ? l10n.todoFieldReminders
              : reminders.length == 1
              ? TodoLabels.reminder(context, reminders.single)
              : l10n.todoRemindersCount(reminders.length),
          set: reminders.isNotEmpty,
          onTap: () => unawaited(editors.pickReminders()),
        ),
        TodoFieldPill(
          icon: FontAwesomeIcons.repeat,
          label: repeat == null
              ? l10n.todoFieldRepeat
              : TodoLabels.repeat(l10n, repeat),
          set: repeat != null,
          onTap: () => unawaited(repeatEditors.pickRepeat()),
        ),
        ExpressiveMenuAnchor(
          menuChildren: <Widget>[
            for (final value in TodoPriority.values.reversed)
              ExpressiveMenuItem(
                selected: value == priority,
                leadingIcon: FaIcon(
                  FontAwesomeIcons.solidFlag,
                  color:
                      TodoLabels.priorityColor(scheme, value) ??
                      scheme.onSurfaceVariant,
                ),
                onPressed: () => unawaited(editors.setPriority(value)),
                child: Text(TodoLabels.priority(l10n, value)),
              ),
          ],
          builder:
              (
                BuildContext context,
                ExpressiveMenuAnchorState menu,
                Widget? _,
              ) => TodoFieldPill(
                icon: priority == TodoPriority.none
                    ? FontAwesomeIcons.flag
                    : FontAwesomeIcons.solidFlag,
                iconColor: TodoLabels.priorityColor(scheme, priority),
                label: priority == TodoPriority.none
                    ? l10n.todoFieldPriority
                    : TodoLabels.priority(l10n, priority),
                set: priority != TodoPriority.none,
                onTap: menu.toggle,
              ),
        ),
        TodoFieldPill(
          icon: list == null
              ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
              : TodoListStyle.iconOfRow(list),
          iconColor: list == null
              ? null
              : TodoListStyle.accentOf(list.colorKey, scheme).onContainer,
          label: list?.name ?? l10n.todoViewInbox,
          set: true,
          onTap: () => unawaited(editors.pickList()),
        ),
        if (sections.isNotEmpty)
          TodoFieldPill(
            icon: FontAwesomeIcons.tableList,
            label:
                TodoSections.of(row.metadata, sections)?.name ??
                l10n.todoSectionNone,
            set: true,
            onTap: () => unawaited(editors.pickSection(sections)),
          ),
        TodoFieldPill(
          icon: FontAwesomeIcons.tag,
          iconColor: tags.isEmpty ? null : scheme.tertiary,
          label: tags.isEmpty
              ? l10n.todoFieldTags
              : tags.map((String tag) => '@$tag').join(' '),
          set: tags.isNotEmpty,
          onTap: () => unawaited(editors.pickTags()),
        ),
        TodoFieldPill(
          icon: FontAwesomeIcons.bookOpen,
          label: linkedDiaryId == null
              ? l10n.todoFieldDiary
              : diary == null
              ? (linkedDiary!.isLoading ? '…' : l10n.todoFieldDiaryMissing)
              : _diaryTitle(context, diary),
          set: linkedDiaryId != null,
          onTap: () => unawaited(editors.pickDiary()),
        ),
        if (diary != null)
          TodoFieldPill(
            icon: FontAwesomeIcons.arrowUpRightFromSquare,
            label: l10n.todoOpenDiary,
            set: false,
            onTap: () => unawaited(
              openDiaryPage(
                context,
                ref,
                diaryId: linkedDiaryId!,
                initialDetail: diary,
              ),
            ),
          ),
      ],
    );
  }

  /// 关联日记的显示名：标题；没有标题时用写下的日期。
  static String _diaryTitle(BuildContext context, DiaryWithTags diary) {
    final title = diary.diary.title.trim();
    if (title.isNotEmpty) return title;
    return context.l10n.formatFullDate(diary.diary.createdAt);
  }
}
