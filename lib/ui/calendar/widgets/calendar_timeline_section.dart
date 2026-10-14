import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/sections/diaries_list_section.dart'
    show DiaryOpenCallback;
import '../../diaries/widgets/energy_battery_indicator.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/qweather_icon.dart';
import 'calendar_day_content_switcher.dart';
import '../../../app/theme/app_effects.dart';
import '../../diaries/viewmodels/diary_card_view_data.dart';

/// 日历页“选中日期列表”的时间线区块。
///
/// 设计目标：
/// - 使用“左线右文”的阅读流强化一天内多条记录的故事感；
/// - 节点优先展示心情 emoji，无心情时退化为中性圆点；
/// - 每条只展示时间 + 正文摘要，保持视觉轻量。
class CalendarTimelineSection extends StatelessWidget {
  const CalendarTimelineSection({
    super.key,
    required this.selectedDay,
    required this.diaries,
    required this.onOpenDiary,
  });

  /// 当前选中日期，用于生成切换动画签名。
  final DateTime selectedDay;

  /// 当天日记集合（已按 createdAt 升序）。
  final List<DiaryWithTags> diaries;

  /// 点击时间线条目：传入整条数据（预览页直接用它渲染首帧）与从封面缩略图
  /// 抓取的共享元素画面（无封面、未解码或减少动画时为 null）。
  final DiaryOpenCallback onOpenDiary;

  static const Duration _switchDuration = ExpressiveMotion.medium;

  @override
  Widget build(BuildContext context) {
    final switchKey = ValueKey<String>(_buildSwitchSignature());

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
          key: switchKey,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < diaries.length; index++)
                _buildTimelineItem(
                  context,
                  diary: diaries[index],
                  index: index,
                  isLast: index == diaries.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 列表切换签名：
  /// - 包含选中日期，确保“切换到另一日”一定触发过渡；
  /// - 包含条目 id 与更新时间，确保同一天内容更新时动画也一致刷新。
  String _buildSwitchSignature() {
    final dayKey =
        '${selectedDay.year}-${selectedDay.month}-${selectedDay.day}';
    final itemKey = diaries
        .map(
          (item) =>
              '${item.diary.diaryId}_${item.diary.updatedAt.millisecondsSinceEpoch}',
        )
        .join('|');
    return '$dayKey::$itemKey';
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required DiaryWithTags diary,
    required int index,
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.outlineVariant.withValues(alpha: 0.6);
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
    final moodEmoji = viewData.moodEmoji;
    final summary = isLockedCapsule
        ? _countdownLabel(context, capsuleState)
        : (viewData.previewText.isNotEmpty
              ? viewData.previewText
              : context.l10n.autoT0186);
    final createdAtLabel = _formatHourMinute(diary.diary.createdAt);
    final cover = isLockedCapsule ? null : viewData.previewCover;
    final location = viewData.location;
    final weather = viewData.weather;
    final weatherIconCode = viewData.weatherIconCode;
    final rawEnergy = viewData.energyLevel;
    final energyLevel = rawEnergy == null
        ? null
        : EnergyBatteryIndicator.normalizeValue(rawEnergy);
    final hasMetaRow =
        (location != null && location.isNotEmpty) ||
        (weather != null && weather.isNotEmpty) ||
        energyLevel != null;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Column(
              children: <Widget>[
                Container(
                  width: 1.5,
                  height: 14,
                  color: index == 0 ? Colors.transparent : lineColor,
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: moodEmoji == null
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.primaryContainer,
                                width: 2,
                              ),
                            ),
                          )
                        : Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              moodEmoji,
                              style: const TextStyle(fontSize: 14, height: 1),
                            ),
                          ),
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 64,
                  color: isLast ? Colors.transparent : lineColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: ExpressiveSurfaces.cardBorderColor(colorScheme),
                  width: 0.8,
                ),
                boxShadow: AppEffects.restingCardShadow(colorScheme),
              ),
              child: Material(
                color: ExpressiveSurfaces.cardColor(colorScheme),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onOpenDiary(
                    diary,
                    coverAnchor.capture(
                      tag: diaryCoverHeroTag(diary.diary.diaryId),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                createdAtLabel,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
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
                                  weatherIconCode: weatherIconCode,
                                  energyLevel: energyLevel,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (cover != null) ...<Widget>[
                          const SizedBox(width: 12),
                          _buildCoverThumbnail(
                            context,
                            cover,
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
          ),
        ],
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

  /// 构建时间线条目右侧的小封面缩略图（圆角）。
  ///
  /// 缩略图是预览页头图的共享元素来源：点按条目时从这里抓取已绘制的画面，
  /// 飞入后在预览页展开成完整头图（与日记列表封面一致）。
  Widget _buildCoverThumbnail(
    BuildContext context,
    String source, {
    required String diaryId,
    required ImageViewerHeroAnchor anchor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // 只限制解码宽度：同时指定 cacheWidth/cacheHeight 会按默认的
    // ResizeImagePolicy.exact 把非方形原图压成正方形，BoxFit.cover 再裁切时
    // 画面已被拉伸变形。与探索页 ExploreMediaThumb 的策略保持一致。
    final cacheWidth = (52 * dpr).round();
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final image = isRemote
        ? Image.network(
            source,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.low,
            frameBuilder: expressiveImageFrameBuilder,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : Image.file(
            File(source),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.low,
            frameBuilder: expressiveImageFrameBuilder,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );

    const radius = BorderRadius.all(Radius.circular(10));
    return Builder(
      builder: (BuildContext thumbContext) {
        anchor.context = thumbContext;
        return ImageViewerHeroSource(
          tag: diaryCoverHeroTag(diaryId),
          borderRadius: radius,
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              width: 52,
              height: 52,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: image,
            ),
          ),
        );
      },
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: segments),
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
