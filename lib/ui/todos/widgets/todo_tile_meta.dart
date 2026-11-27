import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';

/// 待办行标题下的一排元信息胶囊（`labelSmall` w600、高 20、10 圆角）。
///
/// 依次为：截止（图标 + “今天 09:00”；未完成时逾期为 `errorContainer`、今天
/// 为 `primaryContainer`，其余与已完成的一律 `surfaceContainerHigh`；今天
/// 还没到的时刻在一小时内改说“还有 25 分钟”，按整分刷新）、步骤进度“1/3”
/// （给了 [onStepsTap] 时可点，带一个随 [stepsExpanded] 翻转的箭头）、所在
/// 清单（6dp 强调色圆点 + 名称，只在跨清单的视图里给出 [list]），以及只画
/// 图标的提醒、重复、关联日记。都没有时返回空列表，调用方不占行。
List<Widget> buildTodoMetaPills(
  BuildContext context, {
  required TodoRow row,
  required DateTime today,
  TodoListRow? list,
  bool stepsExpanded = false,
  VoidCallback? onStepsTap,
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
    final minute = row.dueMinute;
    pills.add(
      !done && minute != null && dueText == todayText
          ? TodoDueCountdownPill(
              today: today,
              minute: minute,
              fallback: due,
              background: bg,
              foreground: fg,
            )
          : TodoMetaPill(
              icon: minute == null
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
    final pill = TodoMetaPill(
      icon: FontAwesomeIcons.listCheck,
      text: l10n.todoStepsProgress(
        steps.where((s) => s.done).length,
        steps.length,
      ),
      background: neutralBg,
      foreground: neutralFg,
      trailing: onStepsTap == null
          ? null
          : AnimatedRotation(
              turns: stepsExpanded ? 0.5 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.spatial,
              child: FaIcon(
                FontAwesomeIcons.chevronDown,
                size: 8,
                color: neutralFg,
              ),
            ),
    );
    pills.add(
      onStepsTap == null
          ? pill
          : Semantics(
              button: true,
              expanded: stepsExpanded,
              label: stepsExpanded
                  ? l10n.todoStepsCollapse
                  : l10n.todoStepsExpand,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onStepsTap,
                child: pill,
              ),
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
    this.trailing,
  });

  final Color background;
  final Color foreground;
  final FaIconData? icon;

  /// 清单的强调色圆点（代替图标）。
  final Color? dotColor;
  final String? text;

  /// 文字后面的小图标（步骤胶囊的展开箭头）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final icon = this.icon;
    final dot = dotColor;
    final trailing = this.trailing;
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
          if (trailing != null) ...<Widget>[const SizedBox(width: 4), trailing],
        ],
      ),
    );
  }
}

/// 今天有时刻、还没完成的截止胶囊：离截止一小时以内说“还有 N 分钟”（向上
/// 取整，到点后回到 [fallback]），其余时候就是 [fallback]。只有它监听整分
/// 时钟（[todoMinuteProvider]），每分钟只重建这一颗胶囊。
class TodoDueCountdownPill extends ConsumerWidget {
  const TodoDueCountdownPill({
    super.key,
    required this.today,
    required this.minute,
    required this.fallback,
    required this.background,
    required this.foreground,
  });

  final DateTime today;

  /// 截止时刻（一天中的分钟数）。
  final int minute;
  final String fallback;
  final Color background;
  final Color foreground;

  /// 从多久以前开始倒数。
  static const Duration window = Duration(hours: 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(todoMinuteProvider);
    final due = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(minutes: minute));
    final left = due.difference(now);
    final counting = left > Duration.zero && left <= window;
    return TodoMetaPill(
      icon: FontAwesomeIcons.clock,
      text: counting
          ? context.l10n.todoDueInMinutes((left.inSeconds / 60).ceil())
          : fallback,
      background: background,
      foreground: foreground,
    );
  }
}
