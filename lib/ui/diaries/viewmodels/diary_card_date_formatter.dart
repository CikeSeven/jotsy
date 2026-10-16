import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';
import '../models/diary_card_style/diary_card_style.dart';

/// 卡片眉线日期与底栏时间的格式化。
///
/// 默认组合（眉线“月日 · 星期”、底栏相对更新时间）原样调用改版前的
/// `formatEyebrowDate` 与 [RelativeTimeFormatter]，保证默认样式文字不变；
/// 其余组合用 intl 的本地化模式与 ARB 拼接模板，不按语言写分支。
abstract final class DiaryCardDateFormatter {
  static String eyebrow({
    required AppLocalizations l10n,
    required DiaryCardMetaStyle meta,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime now,
  }) {
    return format(
      l10n: l10n,
      format: meta.dateFormat,
      showWeekday: meta.showWeekday,
      showTime: meta.showTime,
      date: meta.dateSource == DiaryCardDateSource.created
          ? createdAt
          : updatedAt,
      now: now,
    );
  }

  /// 按格式、星期与时刻开关格式化一个日期（卡片眉线与预览页信息栏共用）。
  static String format({
    required AppLocalizations l10n,
    required DiaryCardDateFormat format,
    required bool showWeekday,
    required bool showTime,
    required DateTime date,
    required DateTime now,
  }) {
    final local = date.toLocal();
    final localNow = now.toLocal();
    if (format == DiaryCardDateFormat.relative) {
      // 相对时间本身已表达远近，不再附星期与时刻。
      return RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: local,
        now: localNow,
        l10n: l10n,
      );
    }
    var text = switch (format) {
      DiaryCardDateFormat.eyebrow when showWeekday => l10n.formatEyebrowDate(
        local,
      ),
      DiaryCardDateFormat.eyebrow =>
        local.year == localNow.year
            ? l10n.formatMonthDay(local)
            : l10n.formatFullDate(local),
      DiaryCardDateFormat.full => l10n.formatFullDate(local),
      _ => DateFormat.yMd(l10n.localeName).format(local),
    };
    if (showWeekday && format != DiaryCardDateFormat.eyebrow) {
      text = l10n.diaryCardDateWithWeekday(
        text,
        DateFormat.E(l10n.localeName).format(local),
      );
    }
    if (showTime) {
      text = l10n.diaryCardDateWithTime(
        text,
        DateFormat.Hm(l10n.localeName).format(local),
      );
    }
    return text;
  }

  /// 底栏时间；隐藏时返回 null。
  static String? footer({
    required AppLocalizations l10n,
    required DiaryCardFooterTime mode,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime now,
  }) {
    return switch (mode) {
      DiaryCardFooterTime.relativeUpdated =>
        RelativeTimeFormatter.formatUpdatedAt(
          updatedAt: updatedAt,
          now: now,
          l10n: l10n,
        ),
      DiaryCardFooterTime.absoluteUpdated => l10n.diaryCardFooterUpdated(
        l10n.formatPreciseDateTime(updatedAt, now),
      ),
      DiaryCardFooterTime.created => l10n.diaryCardFooterCreated(
        l10n.formatPreciseDateTime(createdAt, now),
      ),
      DiaryCardFooterTime.hidden => null,
    };
  }
}
