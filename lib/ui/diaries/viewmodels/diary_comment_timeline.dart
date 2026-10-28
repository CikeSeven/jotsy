import 'package:flutter/material.dart' show DateUtils;
import 'package:node_diary/l10n/app_localizations.dart';

/// 留言时间线的纯计算：留言距日记写下过了多久，以及条数多时怎么折叠。
/// 预览页留言区、写留言面板的标题、探索页留言卡片与导出共用，说法一致。

/// 从日记写下那天到留言那天隔了几个日历日（按本地日期算，不足一天的时刻差
/// 不计）。日期相减后按 24 小时四舍五入：跨夏令时的那天只有 23 或 25 小时，
/// 直接取 `inDays` 会少算一天。留言早于日记（日记的时间被改到了以后）时为 0。
int diaryCommentDayGap(DateTime diaryCreatedAt, DateTime commentCreatedAt) {
  final from = DateUtils.dateOnly(diaryCreatedAt.toLocal());
  final to = DateUtils.dateOnly(commentCreatedAt.toLocal());
  final days = (to.difference(from).inHours / 24).round();
  return days < 0 ? 0 : days;
}

/// 两个日期之间过了几个整月（按日历月：1 月 31 日到 2 月 28 日还不满一个月）。
int _wholeMonthsBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  var months = (b.year - a.year) * 12 + (b.month - a.month);
  if (b.day < a.day) months -= 1;
  return months < 0 ? 0 : months;
}

/// “写下后 N 天 / N 个月 / N 年 M 个月”，同一天写的为“当天写下”。
///
/// 不满一个月按天、不满一年按月、再往后按年（零头的月数为 0 时只写年）：
/// 回看的意义在于“隔了多久”，越久越不需要精确到天。
String diaryCommentRelativeLabel(
  AppLocalizations l10n,
  DateTime diaryCreatedAt,
  DateTime commentCreatedAt,
) {
  final days = diaryCommentDayGap(diaryCreatedAt, commentCreatedAt);
  if (days == 0) return l10n.diaryCommentSameDay;
  final months = _wholeMonthsBetween(diaryCreatedAt, commentCreatedAt);
  if (months < 1) return l10n.diaryCommentDaysLater(days);
  if (months < 12) return l10n.diaryCommentMonthsLater(months);
  final years = months ~/ 12;
  final rest = months % 12;
  return rest == 0
      ? l10n.diaryCommentYearsLater(years)
      : l10n.diaryCommentYearsMonthsLater(years, rest);
}

/// 留言区的折叠：超过 [threshold] 条时只显示最早的 [head] 条与最近的 [tail]
/// 条，中间收成一行“展开其余 N 条”。
///
/// 最早那条是第一次回看时的心境，最近几条是现在的，中间的按需展开；条数
/// 不多时全部显示，折叠只会让人多点一下。
class DiaryCommentFold<T> {
  const DiaryCommentFold._(this.head, this.hiddenCount, this.tail);

  /// 按 [expanded] 计算 [items]（已按旧 → 新排好）的显示方式。
  factory DiaryCommentFold.of(
    List<T> items, {
    required bool expanded,
    int threshold = 5,
    int head = 1,
    int tail = 3,
  }) {
    assert(head + tail < threshold);
    if (expanded || items.length <= threshold) {
      return DiaryCommentFold<T>._(items, 0, <T>[]);
    }
    return DiaryCommentFold<T>._(
      items.sublist(0, head),
      items.length - head - tail,
      items.sublist(items.length - tail),
    );
  }

  /// 折叠行之前的留言；不折叠时就是全部。
  final List<T> head;

  /// 收起的条数；为 0 时不折叠，没有折叠行。
  final int hiddenCount;

  /// 折叠行之后的留言；不折叠时为空。
  final List<T> tail;

  bool get folded => hiddenCount > 0;
}
