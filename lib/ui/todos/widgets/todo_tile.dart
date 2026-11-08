import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../widgets/todo_check_box.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';

/// 一条待办的列表行：方框、标题与一行元信息。
///
/// 元信息依次为：截止日（逾期为 `error`）、提醒铃铛、重复、步骤进度、所在
/// 清单（只在跨清单的视图里给出 [list]）、关联日记、备注；都没有时不占行。
/// 方框按优先级着色（高 error、中 tertiary、低 primary）。已完成的标题变灰
/// 并加删除线。
///
/// 只负责展示与把点按交出去：勾选 [onToggle]、点行 [onTap]；拖动手柄
/// [trailing] 由调用方在可手动排序的视图里给出。
class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.row,
    required this.today,
    required this.onToggle,
    required this.onTap,
    this.list,
    this.trailing,
  });

  final TodoRow row;

  /// 本地零点的“今天”（截止日的相对说法与是否逾期）。
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  /// 所在清单；给出时在元信息里显示清单名。
  final TodoListRow? list;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = row.completedAt != null;
    final priority = TodoPriority.of(row.priority);
    final accent = TodoLabels.priorityColor(scheme, priority);
    final onAccent = switch (priority) {
      TodoPriority.high => scheme.onError,
      TodoPriority.medium => scheme.onTertiary,
      TodoPriority.low => scheme.onPrimary,
      TodoPriority.none => null,
    };
    final secondary = scheme.onSurfaceVariant;
    final meta = _metaItems(context, l10n, scheme, done);

    return AppCardSurface(
      shadow: false,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.input)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppSpacing.m,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Semantics(
                checked: done,
                button: true,
                label: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
                excludeSemantics: true,
                child: InkResponse(
                  onTap: onToggle,
                  radius: 22,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: TodoCheckBoxVisual(
                        checked: done,
                        size: 20,
                        accent: accent,
                        onAccent: onAccent,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        row.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: done ? secondary : null,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: secondary,
                        ),
                      ),
                      if (meta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: AppSpacing.s,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: meta,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _metaItems(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    bool done,
  ) {
    final secondary = scheme.onSurfaceVariant;
    final items = <Widget>[];
    final dueText = row.dueDate;
    final due = TodoLabels.dueOfRow(context, row, today);
    if (due != null && dueText != null) {
      final overdue =
          !done && dueText.compareTo(formatAnniversaryDate(today)) < 0;
      items.add(
        _Meta(
          icon: FontAwesomeIcons.calendar,
          text: due,
          color: overdue ? scheme.error : secondary,
        ),
      );
    }
    if (!done && decodeTodoReminders(row.reminders).isNotEmpty) {
      items.add(_Meta(icon: FontAwesomeIcons.bell, color: secondary));
    }
    if (row.repeat != null && decodeTodoRepeat(row.repeat) != null) {
      items.add(_Meta(icon: FontAwesomeIcons.repeat, color: secondary));
    }
    final steps = decodeTodoSteps(row.steps);
    if (steps.isNotEmpty) {
      items.add(
        _Meta(
          icon: FontAwesomeIcons.listCheck,
          text: l10n.todoStepsProgress(
            steps.where((s) => s.done).length,
            steps.length,
          ),
          color: secondary,
        ),
      );
    }
    final list = this.list;
    if (list != null) {
      items.add(
        _Meta(
          icon: TodoListStyle.iconOfRow(list),
          text: list.name,
          color: secondary,
        ),
      );
    }
    if (row.linkedDiaryId != null) {
      items.add(_Meta(icon: FontAwesomeIcons.bookOpen, color: secondary));
    }
    if (row.note.isNotEmpty) {
      items.add(_Meta(icon: FontAwesomeIcons.noteSticky, color: secondary));
    }
    return items;
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.color, this.text});

  final FaIconData icon;
  final Color color;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: color);
    if (text == null) return FaIcon(icon, size: 11, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FaIcon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
