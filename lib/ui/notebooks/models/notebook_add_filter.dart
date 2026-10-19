import 'package:drift/drift.dart' show Variable;

import '../../../core/database/app_database.dart';

/// 添加日记页的时间筛选：不限 / 最近 30 天 / 今年（按发表时间）。
enum NotebookAddTimeFilter { all, recent, thisYear }

/// 添加日记页的候选范围：全部日记（私密日记不在其中），按时间筛选时再加一个
/// 发表时间下限。
///
/// 时间下限借用智能范围的谓词（与全部日记同一私密口径，只多一个
/// `d.created_at >= ?`），[notebookId] 只用于区分 provider 实例，不参与查询。
/// 下限在打开页面时算好（[now]），同一次浏览里 key 不变，分页与返回都命中
/// 同一个查询。
DiaryListScope notebookAddScope(
  NotebookAddTimeFilter filter, {
  required String notebookId,
  required DateTime now,
}) {
  final DateTime since;
  switch (filter) {
    case NotebookAddTimeFilter.all:
      return DiaryListScope.all;
    case NotebookAddTimeFilter.recent:
      final today = DateTime(now.year, now.month, now.day);
      since = today.subtract(const Duration(days: 29));
    case NotebookAddTimeFilter.thisYear:
      since = DateTime(now.year);
  }
  return DiarySmartScope(
    notebookId: notebookId,
    predicate: DiaryScopePredicate(
      sql: 'd.created_at >= ?',
      variables: <Variable<Object>>[Variable<DateTime>(since)],
    ),
  );
}
