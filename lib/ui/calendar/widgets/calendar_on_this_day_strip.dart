import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/sections/diaries_list_section.dart'
    show DiaryOpenCallback;
import '../../diaries/viewmodels/diary_card_view_data.dart';
import '../../widgets/image_viewer_hero.dart';
import 'calendar_entry_thumbnail.dart';

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
            itemBuilder: (BuildContext context, int index) => _OnThisDayCard(
              diary: diaries[index],
              selectedDay: selectedDay,
              width: _cardWidth,
              onOpenDiary: onOpenDiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard({
    required this.diary,
    required this.selectedDay,
    required this.width,
    required this.onOpenDiary,
  });

  final DiaryWithTags diary;
  final DateTime selectedDay;
  final double width;
  final DiaryOpenCallback onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewData = DiaryCardViewData.of(diary.diary);
    final createdAt = diary.diary.createdAt.toLocal();
    final yearDiff = selectedDay.year - createdAt.year;
    final relative = yearDiff > 0
        ? l10n.calendarOnThisDayYearsAgo(yearDiff)
        : l10n.calendarOnThisDayYearsLater(-yearDiff);
    final title = diary.diary.title.trim();
    final summary = viewData.previewText.isNotEmpty
        ? viewData.previewText
        : l10n.autoT0186;
    final cover = viewData.previewCover;
    final anchor = ImageViewerHeroAnchor();
    final radius = BorderRadius.circular(20);
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Material(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpenDiary(
            diary,
            anchor.capture(tag: diaryCoverHeroTag(diary.diary.diaryId)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: <Widget>[
                if (cover != null) ...<Widget>[
                  CalendarEntryThumbnail(
                    source: cover,
                    diaryId: diary.diary.diaryId,
                    anchor: anchor,
                    size: 56,
                    radius: 12,
                  ),
                  const SizedBox(width: AppSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '$relative · '
                        '${DateFormat.y(l10n.localeName).format(createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.isEmpty ? summary : title,
                        maxLines: title.isEmpty ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: title.isEmpty
                              ? FontWeight.w400
                              : FontWeight.w700,
                          color: title.isEmpty
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                          height: 1.35,
                        ),
                      ),
                      if (title.isNotEmpty)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
