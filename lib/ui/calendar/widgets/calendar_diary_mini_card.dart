import 'package:flutter/material.dart';
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

/// 一篇日记的小卡片：可选缩略图 + 主色眉线 + 标题与摘要（无标题时摘要占两行）。
///
/// 日历“那年今日”横向列表与纪念日详情的“历年这一天”共用；点按经
/// [onOpenDiary] 打开预览，缩略图作为预览页头图的共享元素。
class CalendarDiaryMiniCard extends StatelessWidget {
  const CalendarDiaryMiniCard({
    super.key,
    required this.diary,
    required this.eyebrow,
    required this.onOpenDiary,
    this.width,
  });

  final DiaryWithTags diary;

  /// 卡片第一行的主色小字（如“3 年前 · 2023”“第 2 周年 · 2022”）。
  final String eyebrow;

  /// 横向列表里的固定宽度；为 null 时撑满父级宽度。
  final double? width;
  final DiaryOpenCallback onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewData = DiaryCardViewData.of(diary.diary);
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
                        eyebrow,
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
