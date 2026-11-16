import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../models/gallery_level.dart';

/// 媒体画廊一组的日期标题：固定高度、吸顶（`PinnedHeaderSliver`）。
///
/// 底色与页面一致（有背景时取实色栏底色），滚到它下面的缩略图被盖住，
/// 文字始终画在实色上，明暗主题与背景图下都可读。
class GalleryGroupHeader extends StatelessWidget {
  const GalleryGroupHeader({super.key, required this.title});

  /// 标题条高度；换档时找回锚点的几何计算（`GalleryLayout`）用同一个值。
  static const double extent = 48;

  final String title;

  /// 分组标题：按天时今天 / 昨天写成“今天 / 昨天”，其余只写日期（今年的
  /// 不写年份，不带星期）；按月、按年时为本地化的年月 / 年份。
  static String titleFor(
    BuildContext context,
    DateTime key,
    GalleryLevel level,
  ) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    switch (level) {
      case GalleryLevel.day:
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (key == today) return l10n.calendarRelativeToday;
        if (key == DateTime(now.year, now.month, now.day - 1)) {
          return l10n.calendarRelativeYesterday;
        }
        return key.year == now.year
            ? DateFormat.MMMd(locale).format(key)
            : DateFormat.yMMMd(locale).format(key);
      case GalleryLevel.month:
        return DateFormat.yMMM(locale).format(key);
      case GalleryLevel.year:
        return DateFormat.y(locale).format(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backdrop = AppPageBackdrop.of(context);
    return ColoredBox(
      color: backdrop.hasBackground
          ? backdrop.solidBarColor
          : backdrop.pageColor,
      child: SizedBox(
        height: extent,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.m + 4,
            end: AppSpacing.m,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
