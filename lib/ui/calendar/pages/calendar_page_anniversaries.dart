part of 'calendar_page.dart';

/// 选中日的纪念日区块（页面装配的一部分）。
extension _CalendarPageAnniversaries on _CalendarPageState {
  /// 选中日标题与当天日记之间的纪念日卡片。
  ///
  /// 有无纪念日的日子之间切换时高度经 AnimatedSize 展开/收起、内容交叉淡入，
  /// 下方日记不在一帧里跳动；换到另一天的另一组纪念日同样交叉淡入（键含
  /// 日期与各条 id）。没有纪念日时是零高度占位，不留空白。
  Widget _buildAnniversarySliver(AnniversaryCalendarIndex index, DateTime now) {
    final marks = index.marksOn(_selectedDay);
    final signature = marks
        .map((AnniversaryDayMark mark) => mark.row.anniversaryId)
        .join('|');
    return SliverToBoxAdapter(
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        // 卡片带外阴影，默认 hardEdge 会在高度过渡时切出硬边。
        clipBehavior: Clip.none,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: CalendarDayContentSwitcher.topAlignedSwitcherLayout,
          child: marks.isEmpty
              ? const SizedBox(
                  key: ValueKey<String>('anniversaries-none'),
                  width: double.infinity,
                )
              : Padding(
                  key: ValueKey<String>(
                    'anniversaries-$_selectedDay-$signature',
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    0,
                    AppSpacing.m,
                    AppSpacing.m,
                  ),
                  child: CalendarAnniversarySection(
                    marks: marks,
                    today: DateUtils.dateOnly(now),
                    onOpen: (AnniversaryDayMark mark) =>
                        unawaited(_controller.openAnniversary(mark)),
                  ),
                ),
        ),
      ),
    );
  }
}
