import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/sections/diaries_list_section.dart'
    show DiaryOpenCallback;
import '../viewmodels/calendar_day_agenda.dart';
import 'calendar_day_content_switcher.dart';
import 'calendar_timeline_diary_card.dart';
import 'calendar_timeline_rail.dart';
import 'calendar_timeline_todos.dart';

/// 日历页选中日的时间线：“左线右文”，日记与待办排在同一条线上。
///
/// 输入：选中日、当天日记（按发表时间升序）、待办 [todos]（待办功能开启且
/// 显示时由页面给出，否则为 null）与没有日记时的“写日记”入口 [onWrite]；
/// 输出时间线，点按、勾选、新建都经回调交给页面。无副作用。
///
/// 自上而下（排序见 [CalendarDayAgenda]）：
/// - 选中今天且有逾期待办时，时间线之上先是“已逾期”一组（不在线上）；
/// - 线上依次是全天待办、按时刻穿插的日记与定时待办；
/// - 末尾一行入口：没有日记时“写日记”（未来日期为时间胶囊），待办开启时
///   “添加待办”。
///
/// 日记节点为心情 emoji 或中性圆点；待办没有节点，线从方框左侧经过。换日、
/// 增删改与勾选后整条交叉淡入（签名含日期、各条 id 与更新时间）。
class CalendarTimelineSection extends StatelessWidget {
  const CalendarTimelineSection({
    super.key,
    required this.selectedDay,
    required this.diaries,
    required this.onOpenDiary,
    this.todos,
    this.onWrite,
    this.writeLabel,
  });

  /// 当前选中日期，用于生成切换动画签名。
  final DateTime selectedDay;

  /// 当天日记集合（已按 createdAt 升序）。
  final List<DiaryWithTags> diaries;

  /// 点击日记：传入整条数据（预览页直接用它渲染首帧）与从封面缩略图抓取的
  /// 共享元素画面（无封面、未解码或减少动画时为 null）。
  final DiaryOpenCallback onOpenDiary;

  /// 待办；null 时时间线只有日记、没有“添加待办”。
  final CalendarTimelineTodos? todos;

  /// 这一天没有日记时末尾的“写日记”入口；null 时不放。
  final VoidCallback? onWrite;

  /// [onWrite] 的文字；null 时为“写日记”。
  final String? writeLabel;

  static const Duration _switchDuration = ExpressiveMotion.medium;

  @override
  Widget build(BuildContext context) {
    final todos = this.todos;
    final agenda = CalendarDayAgenda.build(
      diaries: diaries,
      todos: todos?.entries ?? const [],
      overdue: todos?.overdue ?? const [],
    );
    final entries = _buildRailEntries(context, agenda);
    final hasOverdue = todos != null && agenda.overdue.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        0,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, _switchDuration),
        reverseDuration: ExpressiveMotion.duration(context, _switchDuration),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        // 同日内容增删时新旧列表高度不同，贴顶叠放避免默认居中造成的跳动。
        layoutBuilder: CalendarDayContentSwitcher.topAlignedSwitcherLayout,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final slideAnimation =
              Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: ExpressiveMotion.effects,
                ),
              );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(_buildSwitchSignature()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasOverdue) ...<Widget>[
                todos.overdueBlock(context),
                const SizedBox(height: AppSpacing.s),
              ],
              CalendarTimelineRail(entries: entries),
            ],
          ),
        ),
      ),
    );
  }

  List<CalendarRailEntry> _buildRailEntries(
    BuildContext context,
    CalendarDayAgenda agenda,
  ) {
    final todos = this.todos;
    final entries = <CalendarRailEntry>[
      if (todos != null)
        for (final entry in agenda.allDay) todos.railEntry(context, entry),
      for (final item in agenda.timed)
        switch (item) {
          CalendarAgendaDiary(:final diary) => CalendarRailEntry(
            id: diary.diary.diaryId,
            node: CalendarTimelineDiaryNode(diary: diary),
            child: CalendarTimelineDiaryCard(
              diary: diary,
              onOpenDiary: onOpenDiary,
            ),
          ),
          CalendarAgendaTodo(:final entry) => todos!.railEntry(context, entry),
        },
    ];
    final actions = _buildActions(context, agenda);
    if (actions.isNotEmpty) {
      entries.add(
        CalendarRailEntry(
          id: 'actions',
          // 文字按钮高 40，锚点对着它的中线。
          anchor: 20,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(spacing: AppSpacing.xs, children: actions),
          ),
        ),
      );
    }
    return entries;
  }

  /// 末尾入口：没有日记时“写日记”，待办开启时“添加待办”。只有日记、待办
  /// 关闭时不放，与改版前一致。
  List<Widget> _buildActions(BuildContext context, CalendarDayAgenda agenda) {
    final l10n = context.l10n;
    final onWrite = this.onWrite;
    final todos = this.todos;
    return <Widget>[
      if (!agenda.hasDiaries && onWrite != null)
        TextButton.icon(
          onPressed: onWrite,
          icon: const FaIcon(FontAwesomeIcons.penNib, size: 13),
          label: Text(writeLabel ?? l10n.autoT0181),
        ),
      if (todos != null)
        TextButton.icon(
          onPressed: todos.onAdd,
          icon: const FaIcon(FontAwesomeIcons.plus, size: 13),
          label: Text(l10n.calendarAddTodo),
        ),
    ];
  }

  /// 列表切换签名：
  /// - 包含选中日期，确保“切换到另一日”一定触发过渡；
  /// - 包含日记 id 与更新时间、待办 id / 完成状态与更新时间，确保同一天
  ///   内容更新时动画也一致刷新。
  String _buildSwitchSignature() {
    final dayKey =
        '${selectedDay.year}-${selectedDay.month}-${selectedDay.day}';
    final itemKey = diaries
        .map(
          (item) =>
              '${item.diary.diaryId}_${item.diary.updatedAt.millisecondsSinceEpoch}',
        )
        .join('|');
    return '$dayKey::$itemKey::${todos?.signature ?? ''}';
  }
}
