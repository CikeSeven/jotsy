part of 'calendar_page.dart';

/// 选中日的待办区块（页面装配的一部分）。
extension _CalendarPageTodos on _CalendarPageState {
  /// 纪念日卡片之后、当天日记之前的“这天的待办”。
  ///
  /// 与纪念日区块同一套过渡：有无待办之间高度经 AnimatedSize 展开 / 收起，
  /// 换到另一天的另一组待办交叉淡入（键含日期与各条 id）；没有待办时是零
  /// 高度占位。勾选完成时同一天的这一组内容变了，也交叉淡入。
  Widget _buildTodoSliver(TodoCalendarIndex index, DateTime now) {
    final entries = index.entriesOn(_selectedDay);
    final signature = entries
        .map(
          (TodoCalendarEntry entry) =>
              '${entry.row.todoId}:${entry.done}:${entry.row.updatedAt.millisecondsSinceEpoch}',
        )
        .join('|');
    return SliverToBoxAdapter(
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: CalendarDayContentSwitcher.topAlignedSwitcherLayout,
          child: entries.isEmpty
              ? const SizedBox(
                  key: ValueKey<String>('todos-none'),
                  width: double.infinity,
                )
              : Padding(
                  key: ValueKey<String>('todos-$_selectedDay-$signature'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    0,
                    AppSpacing.m,
                    AppSpacing.s,
                  ),
                  child: TodoCalendarSection(
                    day: _selectedDay,
                    entries: entries,
                    today: DateUtils.dateOnly(now),
                  ),
                ),
        ),
      ),
    );
  }
}
