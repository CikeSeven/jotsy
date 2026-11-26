import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/sections/diaries_list_section.dart'
    show DiaryOpenCallback, diaryCardTransitionTag;
import '../../diaries/viewmodels/diary_card_view_data.dart';
import '../../diaries/widgets/energy_battery_indicator.dart';
import '../../widgets/container_transform/container_transform_source.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/qweather_icon.dart';
import 'calendar_entry_thumbnail.dart';

/// 时间线上一篇日记的节点：有心情时为心情 emoji 小方块，没有时为中性圆点。
class CalendarTimelineDiaryNode extends StatelessWidget {
  const CalendarTimelineDiaryNode({super.key, required this.diary});

  final DiaryWithTags diary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final moodEmoji = DiaryCardViewData.of(diary.diary).moodEmoji;
    if (moodEmoji == null) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.primaryContainer, width: 2),
        ),
      );
    }
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(moodEmoji, style: const TextStyle(fontSize: 14, height: 1)),
    );
  }
}

/// 时间线上一篇日记的卡片：发表时刻、正文摘要（未解封胶囊为倒计时）、
/// 地点 / 天气 / 精力一行与封面缩略图。点按经 [onOpenDiary] 打开预览，并
/// 交出封面缩略图的共享元素画面与卡片的展开起点。
class CalendarTimelineDiaryCard extends StatelessWidget {
  const CalendarTimelineDiaryCard({
    super.key,
    required this.diary,
    required this.onOpenDiary,
  });

  final DiaryWithTags diary;
  final DiaryOpenCallback onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final coverAnchor = ImageViewerHeroAnchor();
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: diary.diary.capsuleLockedAt,
      unlockAt: diary.diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final isLockedCapsule = capsuleState.isLocked;
    // 与日记列表共用按 (diaryId, updatedAt) 缓存的派生数据：选日/翻月重建
    // 时间线不再重复 jsonDecode metadata，也不再为无封面条目解析整段正文。
    final viewData = DiaryCardViewData.of(diary.diary);
    final summary = isLockedCapsule
        ? _countdownLabel(context, capsuleState)
        : (viewData.previewText.isNotEmpty
              ? viewData.previewText
              : context.l10n.autoT0186);
    final cover = isLockedCapsule ? null : viewData.previewCover;
    final location = viewData.location;
    final weather = viewData.weather;
    final rawEnergy = viewData.energyLevel;
    final energyLevel = rawEnergy == null
        ? null
        : EnergyBatteryIndicator.normalizeValue(rawEnergy);
    final hasMetaRow =
        (location != null && location.isNotEmpty) ||
        (weather != null && weather.isNotEmpty) ||
        energyLevel != null;

    // 经典分支与原来的 Container + Material 写法逐像素一致；玻璃时为内容
    // 玻璃。预览页从这张卡片展开；点按处的 context 在来源之内才量得到它。
    return ContainerTransformSource(
      tag: diaryCardTransitionTag(diary.diary.diaryId),
      borderRadius: 22,
      shadows: AppCardSurface.shadowsOf(context),
      child: AppCardSurface(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        child: Builder(
          builder: (BuildContext tapContext) => InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onOpenDiary(
              diary,
              coverAnchor.capture(tag: diaryCoverHeroTag(diary.diary.diaryId)),
              ContainerTransformSource.capture(tapContext),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatHourMinute(diary.diary.createdAt),
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isLockedCapsule
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: isLockedCapsule
                                ? FontWeight.w700
                                : FontWeight.w400,
                            height: 1.38,
                          ),
                        ),
                        if (hasMetaRow) ...<Widget>[
                          const SizedBox(height: 6),
                          _buildMetaInlineRow(
                            context,
                            location: location,
                            weather: weather,
                            weatherIconCode: viewData.weatherIconCode,
                            energyLevel: energyLevel,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (cover != null) ...<Widget>[
                    const SizedBox(width: 12),
                    CalendarEntryThumbnail(
                      source: cover,
                      diaryId: diary.diary.diaryId,
                      anchor: coverAnchor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _countdownLabel(BuildContext context, TimeCapsuleState state) {
    final hours = state.remainingDuration.inHours;
    if (hours > 0 && hours < 24) {
      return context.l10n.timeCapsuleCountdownHours(hours.toString());
    }
    return context.l10n.timeCapsuleCountdownDays(
      state.remainingDays.toString(),
    );
  }

  Widget _buildMetaInlineRow(
    BuildContext context, {
    required String? location,
    required String? weather,
    required String? weatherIconCode,
    required double? energyLevel,
  }) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: color);

    final segments = <Widget>[];
    void appendSegment(Widget child) {
      if (segments.isNotEmpty) {
        segments.add(Text(' | ', style: textStyle));
      }
      segments.add(child);
    }

    if (location != null && location.isNotEmpty) {
      appendSegment(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(FontAwesomeIcons.locationDot, size: 11, color: color),
            const SizedBox(width: 4),
            Text(location, style: textStyle),
          ],
        ),
      );
    }

    if (weather != null && weather.isNotEmpty) {
      appendSegment(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QWeatherIcon(
              iconCode: weatherIconCode,
              weatherText: weather,
              size: 11,
              fallbackColor: color,
            ),
            const SizedBox(width: 4),
            Text(weather, style: textStyle),
          ],
        ),
      );
    }

    if (energyLevel != null) {
      appendSegment(
        EnergyBatteryIndicator(
          value: energyLevel,
          iconSize: 12,
          showLabel: false,
        ),
      );
    }

    return DesktopHorizontalScroll(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: segments),
      ),
    );
  }

  /// 时间线时间文案固定为分钟级（HH:mm）。
  String _formatHourMinute(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
