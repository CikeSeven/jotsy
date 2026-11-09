import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'local_date_text.dart';

/// 待办行里的 JSON 列模型：步骤（子任务）、提醒与重复规则（纯函数，无 IO）。
///
/// 存储格式（均为 JSON 文本列，见 `Todos` 表）：
/// - `steps`：`[{"id":"s1","title":"买菜","done":false}, …]`，至多 [TodoStep.maxSteps] 条；
/// - `reminders`：`[{"kind":"beforeDue","minutes":15}, {"kind":"onDay","days":-1,"minute":1200}]`，
///   至多 [TodoReminder.maxReminders] 条；
/// - `repeat`：`{"freq":"weekly","interval":1,"weekdays":[1,3],"monthly":"dayOfMonth",
///   "basis":"due","anchor":"2026-11-08","until":null,"count":null}`，没有重复时为 NULL。
///
/// 容错：解码逐字段进行，单条坏了（缺字段、类型不符、新版本的未知种类）只跳过
/// 那一条，不让整行读不出来；重复规则的频率认不出时按“不重复”推算，但行里的
/// 原文保持不动（只有用户在这台设备上重新设定重复时才会改写这一列），旧版本
/// 读一遍不会丢掉新版本的规则。

/// 优先级。整数即持久化值（`priority` 列），越大越重要。
enum TodoPriority {
  none,
  low,
  medium,
  high;

  /// 解析持久化值；越界（损坏的导入或新版本扩展）时就近取到合法范围。
  static TodoPriority of(int raw) {
    if (raw <= 0) return none;
    if (raw >= values.length) return high;
    return values[raw];
  }
}

/// 一个步骤（子任务）：只有标题与是否完成，不单独设日期与提醒。
@immutable
class TodoStep {
  const TodoStep({required this.id, required this.title, this.done = false});

  static const int maxSteps = 100;
  static const int maxTitleLength = 200;

  /// 步骤 id：只在这条待办内唯一，用于编辑时定位与拖动排序。
  final String id;
  final String title;
  final bool done;

  TodoStep copyWith({String? title, bool? done}) =>
      TodoStep(id: id, title: title ?? this.title, done: done ?? this.done);

  /// 给 [steps] 新加一步时的 id：只需在这条待办内唯一；取现有 `s<n>` 里最大
  /// 的序号加一，删掉中间的步骤后也不会撞上。
  static String nextId(Iterable<TodoStep> steps) {
    var max = -1;
    for (final step in steps) {
      final n = int.tryParse(
        step.id.startsWith('s') ? step.id.substring(1) : '',
      );
      if (n != null && n > max) max = n;
    }
    return 's${max + 1}';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'done': done,
  };

  /// 解码一条；不是对象或没有标题时为 null。缺 id 时以 [index] 补一个稳定 id
  /// （不能随机：同一行在两台设备上解码要得到同样的结果）。
  static TodoStep? fromJson(Object? raw, int index) {
    if (raw is! Map) return null;
    final title = raw['title'];
    if (title is! String || title.trim().isEmpty) return null;
    final id = raw['id'];
    return TodoStep(
      id: id is String && id.isNotEmpty ? id : 's$index',
      title: _clip(title.trim(), maxTitleLength),
      done: raw['done'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoStep &&
      other.id == id &&
      other.title == title &&
      other.done == done;

  @override
  int get hashCode => Object.hash(id, title, done);
}

/// 提醒的种类。枚举名即持久化值。
enum TodoReminderKind {
  /// 截止时刻之前若干分钟（0 为准时）；只对有具体时间的待办有效。
  beforeDue,

  /// 截止日当天或之前某天的某个时刻（如“前一天 20:00”）；全天待办与有时间
  /// 的待办都能用。
  onDay,
}

/// 一条提醒。提醒一律相对截止日计算：没有截止日的待办不会提醒，界面上给
/// 没有日期的待办加提醒时会先把日期定下。
@immutable
class TodoReminder {
  const TodoReminder.beforeDue(int minutes)
    : kind = TodoReminderKind.beforeDue,
      minutesBefore = minutes,
      dayOffset = 0,
      minuteOfDay = 0;

  const TodoReminder.onDay({required int days, required int minute})
    : kind = TodoReminderKind.onDay,
      minutesBefore = 0,
      dayOffset = days,
      minuteOfDay = minute;

  static const int maxReminders = 5;

  /// 最早提前多久：28 天（含“提前 4 周”）。
  static const int maxMinutesBefore = 28 * 24 * 60;

  /// [TodoReminderKind.onDay] 最早提前的天数。
  static const int maxDaysBefore = 28;

  final TodoReminderKind kind;
  final int minutesBefore;

  /// [TodoReminderKind.onDay]：相对截止日的天数，0 为当天，负数为之前。
  final int dayOffset;

  /// [TodoReminderKind.onDay]：一天中的分钟数（0–1439）。
  final int minuteOfDay;

  /// 这条提醒对截止日 [dueDay]（本地零点）与截止时刻 [dueMinute] 的触发时刻；
  /// [TodoReminderKind.beforeDue] 遇到全天待办（[dueMinute] 为 null）时不触发。
  DateTime? fireAt(DateTime dueDay, int? dueMinute) {
    switch (kind) {
      case TodoReminderKind.beforeDue:
        if (dueMinute == null) return null;
        // 用日历分量构造而不是加 Duration：跨夏令时切换的那天，“9 点前 15
        // 分钟”应当仍是墙上时钟的 8:45。
        return DateTime(
          dueDay.year,
          dueDay.month,
          dueDay.day,
          0,
          dueMinute - minutesBefore,
        );
      case TodoReminderKind.onDay:
        return DateTime(
          dueDay.year,
          dueDay.month,
          dueDay.day + dayOffset,
          0,
          minuteOfDay,
        );
    }
  }

  Map<String, Object?> toJson() => switch (kind) {
    TodoReminderKind.beforeDue => <String, Object?>{
      'kind': kind.name,
      'minutes': minutesBefore,
    },
    TodoReminderKind.onDay => <String, Object?>{
      'kind': kind.name,
      'days': dayOffset,
      'minute': minuteOfDay,
    },
  };

  /// 解码一条；种类认不出或数值越界时为 null（跳过这一条）。
  static TodoReminder? fromJson(Object? raw) {
    if (raw is! Map) return null;
    switch (raw['kind']) {
      case 'beforeDue':
        final minutes = raw['minutes'];
        if (minutes is! int || minutes < 0 || minutes > maxMinutesBefore) {
          return null;
        }
        return TodoReminder.beforeDue(minutes);
      case 'onDay':
        final days = raw['days'];
        final minute = raw['minute'];
        if (days is! int || days > 0 || days < -maxDaysBefore) return null;
        if (minute is! int || minute < 0 || minute >= 24 * 60) return null;
        return TodoReminder.onDay(days: days, minute: minute);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is TodoReminder &&
      other.kind == kind &&
      other.minutesBefore == minutesBefore &&
      other.dayOffset == dayOffset &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(kind, minutesBefore, dayOffset, minuteOfDay);
}

/// 重复的频率。枚举名即持久化值。
enum TodoRepeatFrequency {
  daily,
  weekly,
  monthly,
  yearly,

  /// 法定工作日：周一到周五、去掉法定放假日、加上调休上班的周末（数据来自
  /// tyme 的 `LegalHoliday`，只收录到依赖发布时已公布的年份，之后按普通
  /// 周一到周五）。间隔固定为 1。
  legalWorkdays,
}

/// 每月重复时落在哪一天。枚举名即持久化值。
enum TodoMonthlyMode {
  /// 与起始日同一个几号；小月没有这一天时取月末（31 号在 4 月取 30 号）。
  dayOfMonth,

  /// 与起始日同一个“第几个星期几”（如每月第二个周三）；第五个不存在时取
  /// 当月最后一个。
  weekdayOrdinal,

  /// 每月最后一天。
  lastDay,
}

/// 下一次从哪天算起。枚举名即持久化值。
enum TodoRepeatBasis {
  /// 按规则排定的日子，与哪天完成无关（每周一交周报）。
  due,

  /// 从完成那天起算（浇花：浇完三天后再浇）。
  completion,
}

/// 重复规则。
///
/// [anchor] 是这一串的起点（本地日期 `YYYY-MM-DD`）：每月 31 号、每年 2 月
/// 29 日这类规则，在小月 / 平年顺延到月末后，下一次要回到 31 号 / 29 日，
/// 只记“当前截止日”会丢掉原本的几号，所以几号、第几个星期几都以起点为准。
/// 起点与当前截止日不同步时（如用户把截止日手动改到别的日子），以截止日为
/// 新起点（见 `TodoRecurrence`）。
@immutable
class TodoRepeatRule {
  const TodoRepeatRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const <int>[],
    this.monthlyMode = TodoMonthlyMode.dayOfMonth,
    this.basis = TodoRepeatBasis.due,
    required this.anchor,
    this.until,
    this.count,
  });

  static const int maxInterval = 999;
  static const int maxCount = 9999;

  final TodoRepeatFrequency frequency;

  /// 每隔几个单位（天 / 周 / 月 / 年），1–[maxInterval]。
  final int interval;

  /// 每周重复时落在星期几（`DateTime.monday`..`DateTime.sunday`，升序去重）；
  /// 为空时取起点那天的星期。
  final List<int> weekdays;

  final TodoMonthlyMode monthlyMode;
  final TodoRepeatBasis basis;

  /// 起点（本地零点）。
  final DateTime anchor;

  /// 最后一次不晚于这天（本地零点，含当天）；null 为不限。
  final DateTime? until;

  /// 一共重复几次（含第一次）；null 为不限。
  final int? count;

  TodoRepeatRule copyWith({
    TodoRepeatFrequency? frequency,
    int? interval,
    List<int>? weekdays,
    TodoMonthlyMode? monthlyMode,
    TodoRepeatBasis? basis,
    DateTime? anchor,
    DateTime? until,
    bool clearUntil = false,
    int? count,
    bool clearCount = false,
  }) {
    return TodoRepeatRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      monthlyMode: monthlyMode ?? this.monthlyMode,
      basis: basis ?? this.basis,
      anchor: anchor ?? this.anchor,
      until: clearUntil ? null : (until ?? this.until),
      count: clearCount ? null : (count ?? this.count),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'freq': frequency.name,
    'interval': interval,
    if (weekdays.isNotEmpty) 'weekdays': weekdays,
    'monthly': monthlyMode.name,
    'basis': basis.name,
    'anchor': formatAnniversaryDate(anchor),
    if (until != null) 'until': formatAnniversaryDate(until!),
    if (count != null) 'count': count,
  };

  /// 解码；频率认不出、起点缺失或不是合法日期时为 null（按不重复推算）。
  /// 其余字段坏了取默认值。
  static TodoRepeatRule? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final frequency = TodoRepeatFrequency.values.asNameMap()[raw['freq']];
    final anchorRaw = raw['anchor'];
    final anchor = anchorRaw is String ? parseAnniversaryDate(anchorRaw) : null;
    if (frequency == null || anchor == null) return null;
    final interval = raw['interval'];
    final weekdaysRaw = raw['weekdays'];
    final untilRaw = raw['until'];
    final count = raw['count'];
    return TodoRepeatRule(
      frequency: frequency,
      interval: interval is int && interval >= 1
          ? (interval > maxInterval ? maxInterval : interval)
          : 1,
      weekdays: normalizeWeekdays(<int>[
        if (weekdaysRaw is List)
          for (final day in weekdaysRaw)
            if (day is int) day,
      ]),
      monthlyMode:
          TodoMonthlyMode.values.asNameMap()[raw['monthly']] ??
          TodoMonthlyMode.dayOfMonth,
      basis:
          TodoRepeatBasis.values.asNameMap()[raw['basis']] ??
          TodoRepeatBasis.due,
      anchor: anchor,
      until: untilRaw is String ? parseAnniversaryDate(untilRaw) : null,
      count: count is int && count >= 1
          ? (count > maxCount ? maxCount : count)
          : null,
    );
  }

  /// 星期几去掉越界值、去重并升序。
  static List<int> normalizeWeekdays(Iterable<int> days) {
    final set = <int>{
      for (final day in days)
        if (day >= DateTime.monday && day <= DateTime.sunday) day,
    };
    return List<int>.unmodifiable(set.toList()..sort());
  }

  @override
  bool operator ==(Object other) =>
      other is TodoRepeatRule &&
      other.frequency == frequency &&
      other.interval == interval &&
      _sameInts(other.weekdays, weekdays) &&
      other.monthlyMode == monthlyMode &&
      other.basis == basis &&
      other.anchor == anchor &&
      other.until == until &&
      other.count == count;

  @override
  int get hashCode => Object.hash(
    frequency,
    interval,
    Object.hashAll(weekdays),
    monthlyMode,
    basis,
    anchor,
    until,
    count,
  );
}

/// 解码 `steps` 列；不是 JSON 数组时为空。
List<TodoStep> decodeTodoSteps(String? raw) {
  final list = _decodeList(raw);
  final steps = <TodoStep>[];
  final seen = <String>{};
  for (var i = 0; i < list.length && steps.length < TodoStep.maxSteps; i++) {
    final step = TodoStep.fromJson(list[i], i);
    // 重复的 id（损坏或手写的数据）只保留第一条，编辑时才能唯一定位。
    if (step != null && seen.add(step.id)) steps.add(step);
  }
  return steps;
}

String encodeTodoSteps(List<TodoStep> steps) => jsonEncode(<Object?>[
  for (final step in steps.take(TodoStep.maxSteps)) step.toJson(),
]);

/// 解码 `reminders` 列；不是 JSON 数组时为空，完全相同的提醒只保留一条。
List<TodoReminder> decodeTodoReminders(String? raw) {
  final reminders = <TodoReminder>[];
  for (final item in _decodeList(raw)) {
    final reminder = TodoReminder.fromJson(item);
    if (reminder != null && !reminders.contains(reminder)) {
      reminders.add(reminder);
      if (reminders.length >= TodoReminder.maxReminders) break;
    }
  }
  return reminders;
}

String encodeTodoReminders(List<TodoReminder> reminders) =>
    jsonEncode(<Object?>[
      for (final reminder in reminders.take(TodoReminder.maxReminders))
        reminder.toJson(),
    ]);

/// 解码 `repeat` 列；NULL、非对象或认不出的规则为 null。
TodoRepeatRule? decodeTodoRepeat(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return TodoRepeatRule.fromJson(jsonDecode(raw));
  } on FormatException {
    return null;
  }
}

String? encodeTodoRepeat(TodoRepeatRule? rule) =>
    rule == null ? null : jsonEncode(rule.toJson());

/// 解码 JSON 对象列（`metadata`）；坏了时为空对象。
Map<String, Object?> decodeTodoMetadata(String? raw) {
  if (raw == null || raw.isEmpty) return <String, Object?>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
  } on FormatException {
    // 落到下面的空对象。
  }
  return <String, Object?>{};
}

List<Object?> _decodeList(String? raw) {
  if (raw == null || raw.isEmpty) return const <Object?>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
  } on FormatException {
    // 落到下面的空列表。
  }
  return const <Object?>[];
}

/// 截到 [max] 个 UTF-16 码元，不把代理对从中间切开。
String _clip(String text, int max) {
  if (text.length <= max) return text;
  var end = max;
  final unit = text.codeUnitAt(end - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) end--;
  return text.substring(0, end);
}

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// `sort_order`（REAL）的取值：拖动只改被拖的那一行，取两邻居的中点。
abstract final class TodoSortOrder {
  /// 相邻两行之间的初始间隔。
  static const double gap = 1024;

  /// 两邻居的值小于这个差时浮点已分不开，需整串重新编号。
  static const double minGap = 1e-6;

  /// 放在 [above]（上方那一行，可空）与 [below]（下方那一行，可空）之间的值；
  /// 两者都为 null（清单里只有它）时为 0。两邻居已经分不开时为 null，调用方
  /// 先整串重新编号再取。
  static double? between(double? above, double? below) {
    if (above == null && below == null) return 0;
    if (above == null) return below! - gap;
    if (below == null) return above + gap;
    if ((below - above).abs() < minGap) return null;
    return (above + below) / 2;
  }
}

/// 重复待办某一次的“已完成副本”的业务 id：由原待办 id 与这一次的截止日
/// （`YYYY-MM-DD`）决定，形如 UUID（版本位为 5，与随机生成的 v4 区分）。
///
/// 两台设备离线各自完成同一次时生成的是同一个 id，局域网同步与备份合并后
/// 也只有一条；撤销后再完成，也写回同一行而不是多出一条。
String todoOccurrenceId(String todoId, String dueDate) {
  final bytes = sha256
      .convert(utf8.encode('jotsy.todo.occurrence|$todoId|$dueDate'))
      .bytes
      .sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
