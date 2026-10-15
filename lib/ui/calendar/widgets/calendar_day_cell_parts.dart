import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/expressive_image_frame.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';

// 日期格（CalendarDayCell）的组成部件：内部排版、底部指示物、角标与照片。
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

/// 篇数角标：压住日期数字右上角的小胶囊，两篇及以上时显示。
///
/// 用 primaryContainer 色调而不是实心 primary：满月都有多篇时一排实心小
/// 胶囊过于抢眼。外圈一道卡片色描边，压在选中/今天的填充色、热力深色格
/// 与照片上也分得开。
class CalendarCellCountBadge extends StatelessWidget {
  const CalendarCellCountBadge({super.key, required this.count});

  final int count;

  /// 按选项与当天篇数决定是否显示；不显示时为 null。
  ///
  /// 圆点样式与“逐篇显示”的心情样式里一篇就有一个记号，3 篇以内篇数已经
  /// 一目了然，不再重复标数字；超过记号上限（3 个）时才显示。
  static Widget? resolve({
    required CalendarDaySummary? summary,
    required CalendarDisplayOptions options,
  }) {
    final count = summary?.entryCount ?? 0;
    if (summary == null || !options.showCountBadge || count < 2) {
      return null;
    }
    final oneMarkPerEntry = switch (options.cellStyle) {
      CalendarCellStyle.dot => true,
      CalendarCellStyle.mood =>
        options.moodAggregation == CalendarMoodAggregation.each &&
            summary.moods.length == count,
      _ => false,
    };
    if (oneMarkPerEntry && count <= CalendarDaySummary.maxMoods) {
      return null;
    }
    return CalendarCellCountBadge(count: count);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 12),
      height: 12,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ExpressiveSurfaces.cardColor(colorScheme),
          width: 1,
        ),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 7.5,
          height: 1,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 日期格内部排版：数字居中，指示物贴底；角标挂在数字上而不是格子角上。
///
/// 圆点/心情/标签色样式的格子没有可见边框，角标若放在格子四角，会落在
/// 两个日期数字之间，看不出属于哪一天；压住数字一角（像应用图标上的
/// 消息角标）归属才明确。角标溢出数字的范围用负偏移表示，不改变数字的
/// 居中位置。
class CalendarCellLayout extends StatelessWidget {
  const CalendarCellLayout({
    super.key,
    required this.number,
    this.indicator,
    this.leadingBadge,
    this.trailingBadge,
  });

  final Widget number;
  final Widget? indicator;

  /// 数字左上角：未解封胶囊的锁或天气。
  final Widget? leadingBadge;

  /// 数字右上角：篇数。
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final leadingBadge = this.leadingBadge;
    final trailingBadge = this.trailingBadge;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              number,
              if (leadingBadge != null)
                Positioned(top: -6, left: -8, child: leadingBadge),
              if (trailingBadge != null)
                Positioned(top: -6, right: -9, child: trailingBadge),
            ],
          ),
        ),
        if (indicator != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Center(child: indicator),
          ),
      ],
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

/// 日期格照片：按格子实际像素解码，只限制宽度以免非方形原图被压扁
/// （与时间线缩略图的策略一致）；首次解码淡入。
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
        return isRemote
            ? Image.network(
                source,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.low,
                frameBuilder: expressiveImageFrameBuilder,
                errorBuilder: error,
              )
            : Image.file(
                File(source),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.low,
                frameBuilder: expressiveImageFrameBuilder,
                errorBuilder: error,
              );
      },
    );
  }
}
