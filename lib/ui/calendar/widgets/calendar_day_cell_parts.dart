import 'dart:io';

import 'package:flutter/material.dart';

import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';

// 日期格（CalendarDayCell）的组成部件：底部指示物、角标与照片（内部排版
// 见 calendar_cell_layout.dart）。
// 只负责绘制，无副作用。

/// 日期格底部的指示物：圆点、心情 emoji 或标签色点；当天无日记时为 null。
///
/// [onFill] 为选中/今天填充格上的前景色：圆点改用它，标签色点外加一圈它的
/// 描边，避免与填充色撞色。
abstract final class CalendarCellIndicator {
  static Widget? resolve(
    ColorScheme colorScheme, {
    required CalendarDaySummary? summary,
    required CalendarDisplayOptions options,
    Color? onFill,
  }) {
    if (summary == null || !summary.hasEntries) {
      return null;
    }
    final dotColor = onFill ?? colorScheme.primary;
    switch (options.cellStyle) {
      case CalendarCellStyle.mood:
        final moods = options.moodAggregation == CalendarMoodAggregation.each
            ? summary.moods.take(CalendarDaySummary.maxMoods).toList()
            : <String>[?summary.averageMood];
        if (moods.isEmpty) {
          return CalendarCellDots(count: 1, color: dotColor);
        }
        final fontSize = moods.length > 1 ? 8.5 : 10.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final mood in moods)
              Text(
                mood,
                style: TextStyle(fontSize: fontSize, height: 1),
                textScaler: TextScaler.noScaling,
              ),
          ],
        );
      case CalendarCellStyle.tags:
        if (summary.tagColors.isEmpty) {
          return CalendarCellDots(
            count: 1,
            color: onFill ?? colorScheme.outline,
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final color in summary.tagColors)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  // 选中/今天的填充色上标签色可能撞色，加一圈前景色描边。
                  border: onFill == null
                      ? null
                      : Border.all(color: onFill, width: 1),
                ),
              ),
          ],
        );
      case CalendarCellStyle.dot:
      case CalendarCellStyle.heat:
      case CalendarCellStyle.photo:
        return CalendarCellDots(
          count: summary.entryCount.clamp(1, 3),
          color: dotColor,
        );
    }
  }
}

/// 篇数上标：紧贴日期数字右上方的小号数字（“12³”），两篇及以上时显示。
///
/// 不加底色、不与日期重叠：压住数字一角的角标胶囊会遮挡日期本身；紧贴
/// 数字的上标靠位置就能看出属于哪一天，也不挡任何笔画。颜色由所在格子
/// 决定（普通格 primary，选中/今天/热力格取该格的前景色）。
class CalendarCellCountMark extends StatelessWidget {
  const CalendarCellCountMark({
    super.key,
    required this.count,
    required this.color,
  });

  final int count;
  final Color color;

  /// 需要标出的篇数；不显示时为 null。
  ///
  /// 圆点样式、“逐篇显示”的心情样式，以及照片样式里没有照片时退回的
  /// 圆点（[dotsShown]）都是一篇一个记号，3 篇以内篇数已经一目了然，不再
  /// 重复标数字；超过记号上限（3 个）时才标。
  static int? countFor({
    required CalendarDaySummary? summary,
    required CalendarDisplayOptions options,
    bool dotsShown = false,
  }) {
    final count = summary?.entryCount ?? 0;
    if (summary == null || !options.showCountBadge || count < 2) {
      return null;
    }
    final oneMarkPerEntry = switch (options.cellStyle) {
      _ when dotsShown => true,
      CalendarCellStyle.dot => true,
      CalendarCellStyle.mood =>
        options.moodAggregation == CalendarMoodAggregation.each &&
            summary.moods.length == count,
      _ => false,
    };
    if (oneMarkPerEntry && count <= CalendarDaySummary.maxMoods) {
      return null;
    }
    return count;
  }

  /// 按选项决定是否显示上标；不显示时为 null。
  static Widget? resolve({
    required CalendarDaySummary? summary,
    required CalendarDisplayOptions options,
    required Color color,
    bool dotsShown = false,
  }) {
    final count = countFor(
      summary: summary,
      options: options,
      dotsShown: dotsShown,
    );
    return count == null
        ? null
        : CalendarCellCountMark(count: count, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      count > 9 ? '9+' : '$count',
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}

class CalendarCellDots extends StatelessWidget {
  const CalendarCellDots({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < count; index++)
          Container(
            width: 4.5,
            height: 4.5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
      ],
    );
  }
}

/// 照片上的日期数字：放在半透明小底块上，任何照片上都读得清；有篇数时
/// 以上标写在同一个底块里，农历小字（[lunar]）写在数字下方的第二行。
class CalendarCellPhotoNumber extends StatelessWidget {
  const CalendarCellPhotoNumber({
    super.key,
    required this.day,
    required this.selected,
    this.count,
    this.lunar,
  });

  final int day;
  final bool selected;
  final int? count;
  final Widget? lunar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = this.count;
    final foreground = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    // 窄屏加周数列、或大字号时格子放不下“日期 + 上标”，整体等比缩小而不是
    // 溢出。
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$day',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  if (count != null) ...<Widget>[
                    const SizedBox(width: 1.5),
                    CalendarCellCountMark(
                      count: count,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                    ),
                  ],
                ],
              ),
              ?lunar,
            ],
          ),
        ),
      ),
    );
  }
}

/// 照片上的角标垫一个小圆底，保证在任何画面上可见。
class CalendarCellBadgeBackdrop extends StatelessWidget {
  const CalendarCellBadgeBackdrop({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// 日期格照片：按格子实际像素宽度保持比例解码（与时间线缩略图的策略一致），
/// 长图顶部对齐；首次解码淡入。
class CalendarCellImage extends StatelessWidget {
  const CalendarCellImage({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 48;
        final cacheWidth = (width * dpr).round().clamp(32, 256);
        final uri = Uri.tryParse(source);
        final isRemote =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        Widget error(BuildContext _, Object __, StackTrace? ___) =>
            const SizedBox.shrink();
        return CoverCroppedImage(
          image: boundedImageProvider(
            isRemote ? NetworkImage(source) : FileImage(File(source)),
            width: cacheWidth,
          ),
          errorBuilder: error,
        );
      },
    );
  }
}
