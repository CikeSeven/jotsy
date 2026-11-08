import 'dart:convert';

import 'package:meta/meta.dart';

import '../../database/app_database.dart';

/// 一条排好的提醒：在 [fireAt]（本地时刻）为待办 [todoId] 的 [occurrence]
/// 那一次弹出通知。
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.todoId,
    required this.title,
    required this.occurrence,
    required this.dueMinute,
    required this.fireAt,
    this.snooze = false,
  });

  /// 通知 id：由 [todoId] 与 [fireAt] 决定（见 [todoReminderNotificationId]），
  /// 同一条提醒每次重排都是同一个 id，对账时只增删变化的部分。
  final int id;
  final String todoId;
  final String title;

  /// 这一次的截止日（本地零点）。重复待办的每一次各自排提醒。
  final DateTime occurrence;

  /// 截止时刻（一天中的分钟数）；全天为 null。通知正文据此写“今天 15:00”。
  final int? dueMinute;
  final DateTime fireAt;

  /// 是不是“稍后提醒”排出的那一条。
  final bool snooze;

  /// 通知的 payload：点开或按通知上的按钮时据此找到待办与这一次。
  String get payload => encodeTodoReminderPayload(
    todoId: todoId,
    occurrence: formatAnniversaryDate(occurrence),
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.todoId == todoId &&
      other.title == title &&
      other.occurrence == occurrence &&
      other.dueMinute == dueMinute &&
      other.fireAt == fireAt &&
      other.snooze == snooze;

  @override
  int get hashCode =>
      Object.hash(id, todoId, title, occurrence, dueMinute, fireAt, snooze);
}

/// 通知 payload 的前缀：对账时只认带这个前缀的待办通知，不碰别的通知。
const String kTodoReminderPayloadPrefix = 'todo:';

String encodeTodoReminderPayload({
  required String todoId,
  required String occurrence,
}) =>
    '$kTodoReminderPayloadPrefix${jsonEncode(<String, Object?>{'t': todoId, 'o': occurrence})}';

/// 解析 payload；不是待办通知或格式不对时为 null。
({String todoId, String occurrence})? decodeTodoReminderPayload(
  String? payload,
) {
  if (payload == null || !payload.startsWith(kTodoReminderPayloadPrefix)) {
    return null;
  }
  // payload 之后可能追加了以 `|` 分隔的外观信息（见 TodoNotificationRequest）。
  final body = payload.substring(kTodoReminderPayloadPrefix.length);
  final bar = body.indexOf('|');
  try {
    final node = jsonDecode(bar < 0 ? body : body.substring(0, bar));
    if (node is! Map) return null;
    final todoId = node['t'];
    final occurrence = node['o'];
    if (todoId is! String || occurrence is! String) return null;
    return (todoId: todoId, occurrence: occurrence);
  } on FormatException {
    return null;
  }
}

/// 通知 id：`todoId|fireAt（到分钟）` 的 FNV-1a 哈希，取 31 位正整数（Android
/// 与 iOS 的通知 id 都是 32 位有符号整数）。几百条提醒里撞上的概率可以忽略；
/// 真撞上时后排的覆盖先排的，最多少响一次。
int todoReminderNotificationId(String todoId, DateTime fireAt) {
  final key =
      '$todoId|${fireAt.year}-${fireAt.month}-${fireAt.day}'
      ' ${fireAt.hour}:${fireAt.minute}';
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(key)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// 按未完成的待办排出接下来要弹的提醒（纯函数，无 IO、不读时钟）。
///
/// 规则：
/// - 只排 [now] 之后、[horizon] 之内的；已经过去的不补弹；
/// - 每条提醒相对这一次的截止日计算（[TodoReminder.fireAt]）；全天待办的
///   “准时 / 提前若干分钟”提醒没有意义，跳过；
/// - 重复待办把窗口内的每一次都展开（最多 [maxOccurrencesPerTodo] 次），
///   “一共重复 N 次”的按剩余次数截断——应用没打开、没机会重排时，后面几次
///   也照样会响；
/// - “稍后提醒”（`snoozed_until`）单独排一条；
/// - 按时刻排序，取最早的 [limit] 条（系统对单个应用的待发通知数有上限：
///   Android 约 500 个闹钟，iOS 64 条）。同一时刻的同一条待办只排一次。
List<PlannedReminder> planTodoReminders({
  required List<TodoRow> todos,
  required DateTime now,
  Duration horizon = const Duration(days: 30),
  int limit = 200,
  int maxOccurrencesPerTodo = 31,
}) {
  final end = now.add(horizon);
  final planned = <int, PlannedReminder>{};

  void add(TodoRow row, DateTime occurrence, DateTime fireAt, bool snooze) {
    if (!fireAt.isAfter(now) || fireAt.isAfter(end)) return;
    final id = todoReminderNotificationId(row.todoId, fireAt);
    planned.putIfAbsent(
      id,
      () => PlannedReminder(
        id: id,
        todoId: row.todoId,
        title: row.title,
        occurrence: occurrence,
        dueMinute: row.dueMinute,
        fireAt: fireAt,
        snooze: snooze,
      ),
    );
  }

  for (final row in todos) {
    if (row.completedAt != null) continue;
    final dueText = row.dueDate;
    final due = dueText == null ? null : parseAnniversaryDate(dueText);
    final snoozed = row.snoozedUntil;
    if (snoozed != null) {
      add(
        row,
        due ?? DateTime(snoozed.year, snoozed.month, snoozed.day),
        snoozed,
        true,
      );
    }
    if (due == null) continue;
    final reminders = decodeTodoReminders(row.reminders);
    if (reminders.isEmpty) continue;
    final occurrences = <DateTime>[due];
    final rule = decodeTodoRepeat(row.repeat);
    if (rule != null) {
      final done = decodeTodoMetadata(
        row.metadata,
      )[TodoMetadataKeys.repeatDone];
      final count = rule.count;
      final remaining = count == null
          ? maxOccurrencesPerTodo
          : count - (done is int ? done : 0);
      // 提醒最早提前 28 天：窗口末尾再往后看 28 天的截止日，它们的提醒可能
      // 落在窗口里。
      final lookahead = end.add(
        const Duration(days: TodoReminder.maxDaysBefore + 1),
      );
      var cursor = due;
      while (occurrences.length < remaining &&
          occurrences.length < maxOccurrencesPerTodo) {
        final next = TodoRecurrence.nextAfter(rule, cursor);
        if (next == null || next.isAfter(lookahead)) break;
        occurrences.add(next);
        cursor = next;
      }
    }
    for (final occurrence in occurrences) {
      for (final reminder in reminders) {
        final fireAt = reminder.fireAt(occurrence, row.dueMinute);
        if (fireAt != null) add(row, occurrence, fireAt, false);
      }
    }
  }

  final sorted = planned.values.toList()
    ..sort((a, b) {
      final byTime = a.fireAt.compareTo(b.fireAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return sorted.length <= limit ? sorted : sorted.sublist(0, limit);
}
