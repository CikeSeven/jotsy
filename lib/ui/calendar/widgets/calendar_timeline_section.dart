import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/widgets/energy_battery_indicator.dart';
import '../../widgets/qweather_icon.dart';

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

  /// 点击条目后的导航回调（打开预览页）。
  final ValueChanged<String> onOpenDiary;

  static const Duration _switchDuration = Duration(milliseconds: 280);

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
        duration: _switchDuration,
        reverseDuration: _switchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
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
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: diary.diary.capsuleLockedAt,
      unlockAt: diary.diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final isLockedCapsule = capsuleState.isLocked;
    final moodEmoji = _extractMoodEmoji(diary.diary);
    final summary =
        isLockedCapsule
            ? _countdownLabel(context, capsuleState)
            : _buildSummaryText(context, diary.diary);
    final createdAtLabel = _formatHourMinute(diary.diary.createdAt);
    final cover = isLockedCapsule ? null : _resolveCover(diary.diary);
    final contextMeta = _extractContextMetadata(diary.diary);
    final location = _extractLocation(contextMeta);
    final weather = _extractWeather(contextMeta);
    final weatherIconCode = _extractWeatherIconCode(contextMeta);
    final energyLevel = _extractEnergyLevel(contextMeta);
    final hasMetaRow =
        (location != null && location.isNotEmpty) ||
        (weather != null && weather.isNotEmpty) ||
        energyLevel != null;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Column(
              children: <Widget>[
                Container(
                  width: 1,
                  height: 12,
                  color: index == 0 ? Colors.transparent : lineColor,
                ),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child:
                        moodEmoji == null
                            ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withValues(
                                  alpha: 0.92,
                                ),
                                shape: BoxShape.circle,
                              ),
                            )
                            : Text(
                              moodEmoji,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(height: 1),
                            ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: isLast ? Colors.transparent : lineColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onOpenDiary(diary.diary.diaryId),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 0, 12),
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
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color:
                                    isLockedCapsule
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                fontWeight:
                                    isLockedCapsule
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                height: 1.35,
                              ),
                            ),
                            if (hasMetaRow) ...<Widget>[
                              const SizedBox(height: 5),
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
                        const SizedBox(width: 10),
                        _buildCoverThumbnail(context, cover),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 条目摘要优先使用正文纯文本镜像。
  /// 若正文文本为空（例如仅图片日记），返回统一占位文案，避免视觉空行。
  String _buildSummaryText(BuildContext context, Diary diary) {
    final normalized = diary.contentText.replaceAll('\n', ' ').trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return context.l10n.autoT0186;
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

  /// 时间线右侧封面缩略图来源：
  /// 1) diary.cover；
  /// 2) 正文 Delta 中第一张图片；
  /// 3) 都不存在时不展示缩略图。
  String? _resolveCover(Diary diary) {
    final normalizedCover = diary.cover?.trim();
    if (normalizedCover != null && normalizedCover.isNotEmpty) {
      return normalizedCover;
    }
    return _extractFirstImageFromContent(diary.content);
  }

  /// 构建时间线条目右侧的小封面缩略图（圆角）。
  Widget _buildCoverThumbnail(BuildContext context, String source) {
    final colorScheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (52 * dpr).round();
    final cacheHeight = (52 * dpr).round();
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final image =
        isRemote
            ? Image.network(
              source,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
            : Image.file(
              File(source),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: image,
      ),
    );
  }

  /// 从 Quill Delta JSON 中提取第一张图片地址。
  String? _extractFirstImageFromContent(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(normalized);
      return _extractImageFromNode(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 递归扫描 Delta 节点，兼容 list/map 嵌套和 image embed 写法。
  String? _extractImageFromNode(Object? node) {
    if (node is List) {
      for (final item in node) {
        final image = _extractImageFromNode(item);
        if (image != null) {
          return image;
        }
      }
      return null;
    }

    if (node is! Map) {
      return null;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        return image.trim();
      }
    }

    final type = node['type'];
    if (type == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }

    final root = node['root'];
    if (root != null) {
      final image = _extractImageFromNode(root);
      if (image != null) {
        return image;
      }
    }

    final children = node['children'];
    if (children != null) {
      final image = _extractImageFromNode(children);
      if (image != null) {
        return image;
      }
    }

    return null;
  }

  /// 从 metadata.context 中提取 moodEmoji 作为时间线节点。
  String? _extractMoodEmoji(Diary diary) {
    final context = _extractContextMetadata(diary);
    final mood = context?['moodEmoji']?.toString().trim();
    if (mood == null || mood.isEmpty) {
      return null;
    }
    return mood;
  }

  /// 解析 metadata.context，用于展示地点、天气、精力等行内信息。
  Map<String, dynamic>? _extractContextMetadata(Diary diary) {
    try {
      final decoded = jsonDecode(diary.metadata);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final context = decoded['context'];
      if (context is! Map<String, dynamic>) {
        return null;
      }
      return context;
    } catch (_) {
      return null;
    }
  }

  String? _extractLocation(Map<String, dynamic>? context) {
    final location = context?['location']?.toString().trim();
    if (location == null || location.isEmpty) {
      return null;
    }
    return location;
  }

  String? _extractWeather(Map<String, dynamic>? context) {
    final weather = context?['weather']?.toString().trim();
    if (weather == null || weather.isEmpty) {
      return null;
    }
    return weather;
  }

  String? _extractWeatherIconCode(Map<String, dynamic>? context) {
    final iconCode = context?['weatherIconCode']?.toString().trim();
    if (iconCode == null || iconCode.isEmpty) {
      return null;
    }
    return iconCode;
  }

  double? _extractEnergyLevel(Map<String, dynamic>? context) {
    final raw = context?['energyLevel'];
    final parsed = switch (raw) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    if (parsed == null) {
      return null;
    }
    return EnergyBatteryIndicator.normalizeValue(parsed);
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
