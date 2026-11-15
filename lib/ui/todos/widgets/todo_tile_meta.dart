import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';

/// 待办行标题下的一排元信息胶囊（`labelSmall` w600、高 20、10 圆角）。
///
/// 依次为：截止（图标 + “今天 09:00”；未完成时逾期为 `errorContainer`、今天
/// 为 `primaryContainer`，其余与已完成的一律 `surfaceContainerHigh`）、步骤
/// 进度“1/3”、所在清单（6dp 强调色圆点 + 名称，只在跨清单的视图里给出
/// [list]），以及只画图标的提醒、重复、关联日记。都没有时返回空列表，调用方
/// 不占行。
List<Widget> buildTodoMetaPills(
  BuildContext context, {
  required TodoRow row,
  required DateTime today,
  TodoListRow? list,
}) {
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final done = row.completedAt != null;
  final pills = <Widget>[];
  final dueText = row.dueDate;
  final due = TodoLabels.dueOfRow(context, row, today);
  if (due != null && dueText != null) {
    final todayText = formatAnniversaryDate(today);
    final (Color bg, Color fg) = done
        ? (scheme.surfaceContainerHigh, scheme.onSurfaceVariant)
        : dueText.compareTo(todayText) < 0
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : dueText == todayText
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.surfaceContainerHigh, scheme.onSurfaceVariant);
    pills.add(
      TodoMetaPill(
        icon: row.dueMinute == null
            ? FontAwesomeIcons.calendar
            : FontAwesomeIcons.clock,
        text: due,
        background: bg,
        foreground: fg,
      ),
    );
  }
  final neutralBg = scheme.surfaceContainerHigh;
  final neutralFg = scheme.onSurfaceVariant;
  final steps = decodeTodoSteps(row.steps);
  if (steps.isNotEmpty) {
    pills.add(
      TodoMetaPill(
        icon: FontAwesomeIcons.listCheck,
        text: l10n.todoStepsProgress(
          steps.where((s) => s.done).length,
          steps.length,
        ),
        background: neutralBg,
        foreground: neutralFg,
      ),
    );
  }
  if (list != null) {
    pills.add(
      TodoMetaPill(
        dotColor: TodoListStyle.accentOf(list.colorKey, scheme).onContainer,
        text: list.name,
        background: neutralBg,
        foreground: neutralFg,
      ),
    );
  }
  final icons = <FaIconData>[
    if (!done && decodeTodoReminders(row.reminders).isNotEmpty)
      FontAwesomeIcons.bell,
    if (row.repeat != null && decodeTodoRepeat(row.repeat) != null)
      FontAwesomeIcons.repeat,
    if (row.linkedDiaryId != null) FontAwesomeIcons.bookOpen,
  ];
  for (final icon in icons) {
    pills.add(
      TodoMetaPill(icon: icon, background: neutralBg, foreground: neutralFg),
    );
  }
  return pills;
}

/// 一个元信息胶囊：图标或圆点 + 可选文字。
class TodoMetaPill extends StatelessWidget {
  const TodoMetaPill({
    super.key,
    required this.background,
    required this.foreground,
    this.icon,
    this.dotColor,
    this.text,
  });

  final Color background;
  final Color foreground;
  final FaIconData? icon;

  /// 清单的强调色圆点（代替图标）。
  final Color? dotColor;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final icon = this.icon;
    final dot = dotColor;
    return Container(
      height: 20,
      constraints: const BoxConstraints(maxWidth: 180),
      padding: EdgeInsets.symmetric(
        horizontal: text == null ? 6 : AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) FaIcon(icon, size: 10, color: foreground),
          if (dot != null)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          if (text != null) ...<Widget>[
            if (icon != null || dot != null) const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
