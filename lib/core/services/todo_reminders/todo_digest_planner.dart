import 'package:meta/meta.dart';

import '../../database/app_database.dart';
import 'todo_reminder_planner.dart';

/// 每日摘要（默认关）：每天在设置的时刻弹一条“今天有 N 件待办，其中 M 件
/// 已逾期”。纯函数，无 IO、不读时钟；与提醒一起经调度器对账、经
/// `TodoNotificationGateway` 发出。

/// 每次往后排几天的摘要。应用每次运行、待办变化时都会重排，所以只在应用
/// 一周没打开时才断档；排得更远会挤占 iOS 64 条的待发上限。
const int kTodoDigestDays = 7;

/// 摘要正文里最多写几条待办的标题。
const int kTodoDigestTitleLimit = 3;

/// 算摘要通知 id 的键（见 [todoReminderNotificationId]）：待办的业务 id 是
/// UUID，不会是这个字符串，所以不会与某条提醒同 id。
const String kTodoDigestIdKey = '#digest';

/// 排好的一天的摘要。
@immutable
class PlannedTodoDigest {
  const PlannedTodoDigest({
    required this.id,
    required this.day,
    required this.fireAt,
    required this.count,
    required this.overdue,
    required this.titles,
  });

  final int id;

  /// 摘要说的是哪一天（本地零点）。
  final DateTime day;
  final DateTime fireAt;

  /// 这一天“今天”视图里的件数：截止日在这一天及以前的未完成待办（与
  /// 今天视图的计数同一口径）。
  final int count;

  /// 其中截止日在这一天以前的（已逾期）。
  final int overdue;

  /// 最该先做的几条的标题：逾期的在前（越早越前），再按截止时刻、优先级。
  final List<String> titles;

  /// 交给网关的那一条：没有对应的待办（`todoId` 为空），点开时切到待办 Tab
  /// 的“今天”。标题由调用方按界面语言写好。
  PlannedReminder toReminder(String title) => PlannedReminder(
    id: id,
    todoId: '',
    title: title,
    occurrence: day,
    dueMinute: null,
    fireAt: fireAt,
    digest: true,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedTodoDigest &&
      other.id == id &&
      other.day == day &&
      other.fireAt == fireAt &&
      other.count == count &&
      other.overdue == overdue &&
      _sameTitles(other.titles, titles);

  static bool _sameTitles(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, day, fireAt, count, overdue, Object.hashAll(titles));
}

/// 排出从今天起 [days] 天、每天 [minute]（一天中的分钟数）的摘要。
///
/// - 件数按现在的待办推算：不打开应用时待办不会变，推算的就是到时的实情；
///   本机、同步或备份改了待办时调度器会重排，件数随之更新；
/// - 这一天没有要做的（件数为 0）不排，免得每天弹一条“没有待办”；
/// - 只排 [now] 之后的；今天的已过点、但仍在系统队列里（[pendingIds]，系统
///   因省电推迟）的保留，与提醒的对账口径一致。
List<PlannedTodoDigest> planTodoDigests({
  required List<TodoRow> todos,
  required DateTime now,
  required int minute,
  int days = kTodoDigestDays,
  Set<int> pendingIds = const <int>{},
}) {
  final dated = <({TodoRow row, String due})>[
    for (final row in todos)
      if (row.completedAt == null && row.dueDate != null)
        (row: row, due: row.dueDate!),
  ];
  if (dated.isEmpty) return const <PlannedTodoDigest>[];
  // 逾期的在前（越早越前），同一天按截止时刻（全天的在后）、再按优先级。
  dated.sort((a, b) {
    final byDay = a.due.compareTo(b.due);
    if (byDay != 0) return byDay;
    final am = a.row.dueMinute ?? 24 * 60;
    final bm = b.row.dueMinute ?? 24 * 60;
    if (am != bm) return am.compareTo(bm);
    return b.row.priority.compareTo(a.row.priority);
  });

  final planned = <PlannedTodoDigest>[];
  for (var offset = 0; offset < days; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final fireAt = DateTime(
      day.year,
      day.month,
      day.day,
      minute ~/ 60,
      minute % 60,
    );
    final id = todoReminderNotificationId(kTodoDigestIdKey, fireAt);
    if (!fireAt.isAfter(now) && !pendingIds.contains(id)) continue;
    final dayText = formatAnniversaryDate(day);
    var count = 0;
    var overdue = 0;
    final titles = <String>[];
    for (final entry in dated) {
      final order = entry.due.compareTo(dayText);
      if (order > 0) break;
      count++;
      if (order < 0) overdue++;
      final title = entry.row.title.trim();
      if (titles.length < kTodoDigestTitleLimit && title.isNotEmpty) {
        titles.add(title);
      }
    }
    if (count == 0) continue;
    planned.add(
      PlannedTodoDigest(
        id: id,
        day: day,
        fireAt: fireAt,
        count: count,
        overdue: overdue,
        titles: List<String>.unmodifiable(titles),
      ),
    );
  }
  return planned;
}
