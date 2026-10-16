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
    final date =
        (meta.dateSource == DiaryCardDateSource.created ? createdAt : updatedAt)
            .toLocal();
    final localNow = now.toLocal();
    if (meta.dateFormat == DiaryCardDateFormat.relative) {
      // 相对时间本身已表达远近，不再附星期与时刻。
      return RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: date,
        now: localNow,
        l10n: l10n,
      );
    }
    var text = switch (meta.dateFormat) {
      DiaryCardDateFormat.eyebrow when meta.showWeekday =>
        l10n.formatEyebrowDate(date),
      DiaryCardDateFormat.eyebrow =>
        date.year == localNow.year
            ? l10n.formatMonthDay(date)
            : l10n.formatFullDate(date),
      DiaryCardDateFormat.full => l10n.formatFullDate(date),
      _ => DateFormat.yMd(l10n.localeName).format(date),
    };
    if (meta.showWeekday && meta.dateFormat != DiaryCardDateFormat.eyebrow) {
      text = l10n.diaryCardDateWithWeekday(
        text,
        DateFormat.E(l10n.localeName).format(date),
      );
    }
    if (meta.showTime) {
      text = l10n.diaryCardDateWithTime(
        text,
        DateFormat.Hm(l10n.localeName).format(date),
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
