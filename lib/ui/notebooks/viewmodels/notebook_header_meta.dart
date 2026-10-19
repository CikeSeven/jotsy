import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations_gen.dart';
import '../../../utils/text_stats.dart';

/// 日记本头部卡片的统计：篇数、总字数与时间跨度（最早 / 最晚一篇的发表
/// 时间）。篇数与首页列表同一口径（未删除、未归档）；字数与跨度来自同一
/// 集合的轻量概览（未解封的胶囊不计入，它们的正文本来就不可见）。
@immutable
class NotebookHeaderStats {
  const NotebookHeaderStats({
    required this.count,
    required this.words,
    this.first,
    this.last,
  });

  /// 由篇数与概览列表算出统计；字数经 [DiaryWordCounts]（按版本缓存）。
  factory NotebookHeaderStats.from(
    int count,
    List<ExploreDiaryOverview> overviews,
  ) {
    var words = 0;
    DateTime? first;
    DateTime? last;
    for (final overview in overviews) {
      words += DiaryWordCounts.of(
        diaryId: overview.diaryId,
        updatedAt: overview.updatedAt,
        text: overview.contentText,
      );
      final created = overview.createdAt.toLocal();
      if (first == null || created.isBefore(first)) first = created;
      if (last == null || created.isAfter(last)) last = created;
    }
    return NotebookHeaderStats(
      count: count,
      words: words,
      first: first,
      last: last,
    );
  }

  final int count;
  final int words;
  final DateTime? first;
  final DateTime? last;
}

/// 字数的展示：按语言的千分位写全数，与日历概览的“共 N 字”同一写法
/// （紧凑写法的“2.1万”后面再接“ 字”读起来别扭）。
String formatNotebookWords(int words, String localeName) {
  return NumberFormat.decimalPattern(localeName).format(words);
}

/// 时间跨度：同一个月只写这个月；最晚一篇在本月时写“至今”；没有可统计
/// 的日记时为 null。
String? notebookSpanLabel(
  AppLocalizations l10n,
  NotebookHeaderStats stats, {
  required DateTime now,
}) {
  final first = stats.first;
  final last = stats.last;
  if (first == null || last == null) {
    return null;
  }
  final format = DateFormat.yMMM(l10n.localeName);
  final sameMonth = first.year == last.year && first.month == last.month;
  if (sameMonth) {
    return format.format(first);
  }
  final lastIsCurrentMonth = last.year == now.year && last.month == now.month;
  if (lastIsCurrentMonth) {
    return l10n.notebookMetaSpanOngoing(format.format(first));
  }
  return l10n.notebookMetaSpan(format.format(first), format.format(last));
}

/// 统计行：“23 篇 · 21,345 字 · 2023年5月 – 至今”。
String notebookHeaderMetaLine(
  AppLocalizations l10n,
  NotebookHeaderStats stats, {
  required DateTime now,
}) {
  final span = notebookSpanLabel(l10n, stats, now: now);
  return <String>[
    l10n.notebookEntryCount(stats.count),
    l10n.notebookMetaWords(formatNotebookWords(stats.words, l10n.localeName)),
    ?span,
  ].join(' · ');
}
