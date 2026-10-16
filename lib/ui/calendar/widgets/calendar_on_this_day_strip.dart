import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/sections/diaries_list_section.dart'
    show DiaryOpenCallback;
import 'calendar_diary_mini_card.dart';

/// 选中日下方的“那年今日”：其他年份同月同日写下的日记，横向小卡片。
///
/// 输入：选中日期与已过滤掉未解封胶囊的日记（按年份倒序）；点卡片经
/// [onOpenDiary] 打开预览（缩略图作为预览页头图的共享元素）。无副作用。
///
/// 与探索页“那年今日”的区别：探索页只看今天；这里跟随日历上任意选中的
/// 一天，往前往后的年份都列出（“3 年前”“1 年后”）。
class CalendarOnThisDayStrip extends StatelessWidget {
  const CalendarOnThisDayStrip({
    super.key,
    required this.selectedDay,
    required this.diaries,
    required this.onOpenDiary,
  });

  static const double _cardWidth = 236;
  static const double _cardHeight = 96;

  final DateTime selectedDay;
  final List<DiaryWithTags> diaries;
  final DiaryOpenCallback onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Semantics(
            header: true,
            child: Row(
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.clockRotateLeft,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  l10n.calendarOnThisDayTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          // 卡片带静止阴影，列表上下各留 4dp，阴影不会被横向列表裁成硬边。
          height: _cardHeight + 8,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 4,
            ),
            itemCount: diaries.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
            itemBuilder: (BuildContext context, int index) {
              final diary = diaries[index];
              final createdAt = diary.diary.createdAt.toLocal();
              final yearDiff = selectedDay.year - createdAt.year;
              final relative = yearDiff > 0
                  ? l10n.calendarOnThisDayYearsAgo(yearDiff)
                  : l10n.calendarOnThisDayYearsLater(-yearDiff);
              return CalendarDiaryMiniCard(
                diary: diary,
                eyebrow:
                    '$relative · '
                    '${DateFormat.y(l10n.localeName).format(createdAt)}',
                width: _cardWidth,
                onOpenDiary: onOpenDiary,
              );
            },
          ),
        ),
      ],
    );
  }
}
