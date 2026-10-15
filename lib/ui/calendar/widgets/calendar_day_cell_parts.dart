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

/// 右上角：两篇及以上时的篇数。
///
/// 固定为 primary 小胶囊并带一圈卡片色描边，热力深色格与照片上也能分辨；
/// [inverted] 用于选中的填充格（整格已是 primary），改为 onPrimary 底。
class CalendarCellCountBadge extends StatelessWidget {
  const CalendarCellCountBadge({
    super.key,
    required this.count,
    this.inverted = false,
  });

  final int count;
  final bool inverted;

  /// 按选项与当天篇数决定是否显示；不显示时为 null。
  static Widget? resolve({
    required CalendarDaySummary? summary,
    required CalendarDisplayOptions options,
    bool inverted = false,
  }) {
    final count = summary?.entryCount ?? 0;
    if (!options.showCountBadge || count < 2) {
      return null;
    }
    return CalendarCellCountBadge(count: count, inverted: inverted);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = inverted ? colorScheme.onPrimary : colorScheme.primary;
    final foreground = inverted ? colorScheme.primary : colorScheme.onPrimary;
    return Container(
      constraints: const BoxConstraints(minWidth: 13),
      height: 13,
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6.5),
        border: Border.all(
          color: inverted
              ? colorScheme.primary
              : ExpressiveSurfaces.cardColor(colorScheme),
          width: 1,
        ),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 8,
          height: 1,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// 日期格内部排版：数字居中偏上，指示物贴底，角标在上方两角。
class CalendarCellLayout extends StatelessWidget {
  const CalendarCellLayout({
    super.key,
    required this.badgeInset,
    required this.number,
    this.indicator,
    this.leadingBadge,
    this.trailingBadge,
  });

  /// 角标相对本层边缘的偏移（负值向外）。
  final double badgeInset;
  final Widget number;
  final Widget? indicator;
  final Widget? leadingBadge;
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        Center(child: number),
        if (indicator != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: Center(child: indicator),
          ),
        if (leadingBadge != null)
          Positioned(top: badgeInset, left: badgeInset, child: leadingBadge!),
        if (trailingBadge != null)
          Positioned(top: badgeInset, right: badgeInset, child: trailingBadge!),
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
