import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_page_background.dart';
import '../models/gallery_level.dart';

/// 媒体画廊一组的日期标题：随网格一起滚动（不吸顶），画在页面背景上。
///
/// 固定高度（[extentFor]，行布局按它排），文字压在下方、紧挨着这组的
/// 第一行格子，上方留出与上一组之间的间隔。精度随档位：
/// - 按天：大字为“今天 / 昨天”或几月几日（不是今年时带年份），小字为
///   星期（今天 / 昨天时为完整日期与星期）；
/// - 按月：年月；按年：年份，字号逐级加大，分组越粗标题越醒目。
/// 行尾为这组的张数。文字经 [AppPageBackdrop.onBackgroundTextStyle]，
/// 背景图上同样可读。
class GalleryGroupHeader extends StatelessWidget {
  const GalleryGroupHeader({
    super.key,
    required this.date,
    required this.level,
    required this.count,
    required this.inset,
  });

  /// 这组的时间桶键（这一天 / 这个月 / 这一年的零点）。
  final DateTime date;
  final GalleryLevel level;
  final int count;

  /// 左右与网格对齐的内边距。
  final double inset;

  /// 标题行的高度；行布局（`GalleryGrid`）用同一个值。
  static double extentFor(GalleryLevel level) => switch (level) {
    GalleryLevel.day => 40,
    GalleryLevel.month => 44,
    GalleryLevel.year => 52,
  };

  /// 标题的大字与小字（小字可为 null），见类注释。
  static ({String title, String? subtitle}) labelsFor(
    AppLocalizations l10n,
    DateTime date,
    GalleryLevel level, {
    DateTime? now,
  }) {
    final locale = l10n.localeName;
    final today = now ?? DateTime.now();
    switch (level) {
      case GalleryLevel.day:
        final day = DateTime(date.year, date.month, date.day);
        final todayKey = DateTime(today.year, today.month, today.day);
        final relative = day == todayKey
            ? l10n.calendarRelativeToday
            : day == DateTime(today.year, today.month, today.day - 1)
            ? l10n.calendarRelativeYesterday
            : null;
        if (relative != null) {
          return (
            title: relative,
            subtitle: DateFormat.MMMEd(locale).format(day),
          );
        }
        return (
          title: day.year == today.year
              ? DateFormat.MMMd(locale).format(day)
              : DateFormat.yMMMd(locale).format(day),
          subtitle: DateFormat.E(locale).format(day),
        );
      case GalleryLevel.month:
        return (title: DateFormat.yMMMM(locale).format(date), subtitle: null);
      case GalleryLevel.year:
        return (title: DateFormat.y(locale).format(date), subtitle: null);
    }
  }

  /// 标题行左侧（大字 + 小字）与行尾张数的文字，[build] 与换档过渡里画在
  /// 画布上的 [GalleryHeaderLabel] 共用。
  static ({InlineSpan title, InlineSpan count}) spansFor(
    BuildContext context, {
    required DateTime date,
    required GalleryLevel level,
    required int count,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final labels = labelsFor(l10n, date, level);
    final titleStyle = switch (level) {
      GalleryLevel.day => textTheme.titleSmall,
      GalleryLevel.month => textTheme.titleMedium,
      GalleryLevel.year => textTheme.titleLarge,
    }?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.onSurface);
    final mutedStyle = textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final subtitle = labels.subtitle;
    return (
      title: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: labels.title,
            style: AppPageBackdrop.onBackgroundTextStyle(context, titleStyle),
          ),
          if (subtitle != null)
            TextSpan(
              text: '  $subtitle',
              style: AppPageBackdrop.onBackgroundTextStyle(context, mutedStyle),
            ),
        ],
      ),
      count: TextSpan(
        text: l10n.exploreGalleryGroupCount(count),
        style: AppPageBackdrop.onBackgroundTextStyle(
          context,
          textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spans = spansFor(context, date: date, level: level, count: count);
    return SizedBox(
      height: extentFor(level),
      child: Padding(
        // 文字贴近下面的格子、与上一组拉开：标题属于它下面这组。
        padding: EdgeInsetsDirectional.fromSTEB(inset, 0, inset, _bottomGap),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  spans.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: _countGap),
              Text.rich(spans.count, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  /// 文字离下面格子的距离与张数前的最小间隔。
  static const double _bottomGap = 6;
  static const double _countGap = 12;
}

/// 换档过渡里画在画布上的日期标题：与 [GalleryGroupHeader] 同样的文字、
/// 同样的摆放（基线对齐、压在行底、张数靠行尾），只是不建组件，每帧按
/// 位置与不透明度直接画。用完须 [dispose]。
class GalleryHeaderLabel {
  GalleryHeaderLabel._({
    required this._title,
    required this._count,
    required this.extent,
    required this.inset,
    required this.width,
    required TextDirection textDirection,
  }) : _rtl = textDirection == TextDirection.rtl;

  factory GalleryHeaderLabel.of(
    BuildContext context, {
    required DateTime date,
    required GalleryLevel level,
    required int count,
    required double inset,
    required double width,
  }) {
    final spans = GalleryGroupHeader.spansFor(
      context,
      date: date,
      level: level,
      count: count,
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final countPainter = TextPainter(
      text: spans.count,
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final titlePainter =
        TextPainter(
          text: spans.title,
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
          ellipsis: '…',
        )..layout(
          maxWidth: math.max(
            0,
            width -
                inset * 2 -
                GalleryGroupHeader._countGap -
                countPainter.width,
          ),
        );
    return GalleryHeaderLabel._(
      title: titlePainter,
      count: countPainter,
      extent: GalleryGroupHeader.extentFor(level),
      inset: inset,
      width: width,
      textDirection: textDirection,
    );
  }

  final TextPainter _title;
  final TextPainter _count;
  final double extent;
  final double inset;
  final double width;
  final bool _rtl;

  /// 在标题行左上角 [origin] 处以不透明度 [opacity] 画出。
  void paint(Canvas canvas, Offset origin, double opacity) {
    if (opacity <= 0) return;
    double baseline(TextPainter painter) =>
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    // 基线对齐后整行压在行底（同 Row 的基线对齐：行高 = 最大基线以上 +
    // 最大基线以下）。
    final below = math.max(
      _title.height - baseline(_title),
      _count.height - baseline(_count),
    );
    final line = origin.dy + extent - GalleryGroupHeader._bottomGap - below;
    final start = origin.dx + inset;
    final end = origin.dx + width - inset;
    final titleX = _rtl ? end - _title.width : start;
    final countX = _rtl ? start : end - _count.width;
    final translucent = opacity < 1;
    if (translucent) {
      canvas.saveLayer(
        Rect.fromLTWH(origin.dx, origin.dy, width, extent),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    _title.paint(canvas, Offset(titleX, line - baseline(_title)));
    _count.paint(canvas, Offset(countX, line - baseline(_count)));
    if (translucent) canvas.restore();
  }

  void dispose() {
    _title.dispose();
    _count.dispose();
  }
}
