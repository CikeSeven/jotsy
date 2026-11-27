part of 'todo_quick_parse_rules.dart';

// ───────────────────────────── 重复与提醒 ─────────────────────────────
//
// 与日期、时刻一样，中 / 英 / 日 / 俄写法同时生效。重复先于日期识别（“每周一”
// 整体是重复，不再把“周一”当成下周一的日期），提醒先于时刻（“前一天晚上
// 8点”是提醒，不是截止时刻）。

/// 识别出的重复：频率、间隔、每周的星期几与每月的几号（都可空）。由调用方
/// 按截止日转成 `TodoRepeatRule`（[TodoQuickRepeat.firstDue] 给出没写日期时
/// 的第一个截止日）。
@immutable
class TodoQuickRepeat {
  const TodoQuickRepeat(
    this.frequency, {
    this.interval = 1,
    this.weekdays = const <int>[],
    this.monthDay,
  });

  final TodoRepeatFrequency frequency;
  final int interval;

  /// 每周落在星期几（升序去重）；空为“与截止日同一天”。
  final List<int> weekdays;

  /// 每月的几号（“每月15号”）。
  final int? monthDay;

  /// 没写日期时的第一个截止日：今天起第一个符合的日子（今天符合就是今天）。
  DateTime firstDue(DateTime today) {
    if (frequency == TodoRepeatFrequency.weekly && weekdays.isNotEmpty) {
      for (var i = 0; i < 7; i++) {
        final day = _addDays(today, i);
        if (weekdays.contains(day.weekday)) return day;
      }
    }
    if (frequency == TodoRepeatFrequency.legalWorkdays) {
      for (var i = 0; i < 7; i++) {
        final day = _addDays(today, i);
        if (day.weekday <= DateTime.friday) return day;
      }
    }
    final monthDay = this.monthDay;
    if (monthDay != null) return _dayOfMonth(today, monthDay) ?? today;
    return today;
  }

  /// 以 [anchor]（截止日）为起点的规则。
  TodoRepeatRule ruleFrom(DateTime anchor) => TodoRepeatRule(
    frequency: frequency,
    interval: interval,
    weekdays: weekdays,
    anchor: anchor,
  );

  @override
  bool operator ==(Object other) =>
      other is TodoQuickRepeat &&
      other.frequency == frequency &&
      other.interval == interval &&
      listEquals(other.weekdays, weekdays) &&
      other.monthDay == monthDay;

  @override
  int get hashCode =>
      Object.hash(frequency, interval, Object.hashAll(weekdays), monthDay);
}

/// 识别出的提醒：提前多久（分钟，“提前 10 分钟”“2 hours before”）或提前
/// 几天的某个时刻（“前一天晚上8点”，[minuteOfDay] 为 null 时由调用方取截止
/// 时刻或全天待办的默认提醒时刻）。
@immutable
class TodoQuickReminder {
  const TodoQuickReminder.before(int minutes)
    : minutesBefore = minutes,
      daysBefore = 0,
      minuteOfDay = null;

  const TodoQuickReminder.daysBefore(int days, {this.minuteOfDay})
    : minutesBefore = null,
      daysBefore = days;

  final int? minutesBefore;
  final int daysBefore;
  final int? minuteOfDay;

  /// 落成一条提醒。[dueMinute] 为截止时刻（全天为 null），[allDayMinute]
  /// 为全天待办的默认提醒时刻。按分钟提前的提醒只对有时刻的待办有效，全天
  /// 时为 null（调用方不加）。
  TodoReminder? resolve({required int? dueMinute, required int allDayMinute}) {
    final minutes = minutesBefore;
    if (minutes != null) {
      return dueMinute == null ? null : TodoReminder.beforeDue(minutes);
    }
    return TodoReminder.onDay(
      days: -daysBefore,
      minute: minuteOfDay ?? dueMinute ?? allDayMinute,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoQuickReminder &&
      other.minutesBefore == minutesBefore &&
      other.daysBefore == daysBefore &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(minutesBefore, daysBefore, minuteOfDay);
}

/// 原文里所有可能的重复片段。
List<TodoQuickCandidate<TodoQuickRepeat>> findQuickRepeatCandidates(
  String text,
  DateTime today,
) => _collect(_repeatRules, text, today);

/// 原文里所有可能的提醒片段。
List<TodoQuickCandidate<TodoQuickReminder>> findQuickReminderCandidates(
  String text,
  DateTime today,
) => _collect(_reminderRules, text, today);

const _weekdaysOnly = <int>[1, 2, 3, 4, 5];

const _enWeekdayWords =
    'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
    'tues|thurs|thur|mon|tue|wed|thu|fri|sat|sun';

/// 俄文星期（单数宾格与“по …ам”复数与格）的前两个字母见 [_ruWeekdays]。
const _ruWeekdayWords =
    'понедельник|вторник|среду|четверг|пятницу|субботу|воскресенье|'
    'понедельникам|вторникам|средам|четвергам|пятницам|субботам|воскресеньям';

final List<_Rule<TodoQuickRepeat>> _repeatRules = [
  // 中文：每天 / 每日 / 每 N 天。
  _Rule(r'每\s*(\d{1,3}|[一二两三四五六七八九十]{1,3})\s*天|每一?天|每日', (m, text, today) {
    final raw = m[1];
    if (raw == null) return const TodoQuickRepeat(TodoRepeatFrequency.daily);
    final n = int.tryParse(raw) ?? _cnNumber(raw);
    if (n == null || n < 1 || n > TodoRepeatRule.maxInterval) return null;
    return TodoQuickRepeat(TodoRepeatFrequency.daily, interval: n);
  }),
  // 中文：（每个）工作日（法定工作日，含调休）；单写“工作日”后面紧跟汉字
  // 时多半是别的词（“工作日报”），不算。
  _Rule(
    '每[个個]?工作日|工作日(?![\u4e00-\u9fff])',
    (m, text, today) =>
        const TodoQuickRepeat(TodoRepeatFrequency.legalWorkdays),
  ),
  // 中文：每周末（周六、周日）。
  _Rule(
    '每[个個]?(?:周|週)末',
    (m, text, today) => const TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: <int>[6, 7],
    ),
  ),
  // 中文：每周一三五 / 每星期二、四 / 每周（不带星期）。
  _Rule(
    '每[个個]?(?:周|週|星期|礼拜|禮拜)'
    '((?:[一二三四五六日天][、，,和及]?)*[一二三四五六日天])?',
    (m, text, today) => TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: _sortedDays(
        (m[1] ?? '').split('').map((String c) => _cnWeekdays[c]),
      ),
    ),
  ),
  // 中文：每月 15 号 / 每个月 / 每年。
  _Rule(r'每[个個]?月(?:\s*(\d{1,2})\s*[号號日])?', (m, text, today) {
    final day = m[1] == null ? null : int.parse(m[1]!);
    if (day != null && (day < 1 || day > 31)) return null;
    return TodoQuickRepeat(TodoRepeatFrequency.monthly, monthDay: day);
  }),
  _Rule(
    '每年',
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.yearly),
  ),
  // 日文：毎日 / N 日ごと / 平日 / 毎週月水金 / 毎週 / 毎月 15 日 / 毎年。
  _Rule(r'(\d{1,3})\s*日ごと|毎日', (m, text, today) {
    final raw = m[1];
    if (raw == null) return const TodoQuickRepeat(TodoRepeatFrequency.daily);
    final n = int.parse(raw);
    if (n < 1 || n > TodoRepeatRule.maxInterval) return null;
    return TodoQuickRepeat(TodoRepeatFrequency.daily, interval: n);
  }),
  _Rule(
    '毎週((?:[月火水木金土日](?:曜日?)?[・、,と]?)*[月火水木金土日](?:曜日?)?)?',
    (m, text, today) => TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: _sortedDays(
        (m[1] ?? '').split('').map((String c) => _jaWeekdays[c]),
      ),
    ),
  ),
  _Rule(
    '平日(?![\u4e00-\u9fff])',
    (m, text, today) => const TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: _weekdaysOnly,
    ),
  ),
  _Rule(r'毎月(?:\s*(\d{1,2})\s*日)?', (m, text, today) {
    final day = m[1] == null ? null : int.parse(m[1]!);
    if (day != null && (day < 1 || day > 31)) return null;
    return TodoQuickRepeat(TodoRepeatFrequency.monthly, monthDay: day);
  }),
  _Rule(
    '毎年',
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.yearly),
  ),
  // 英文：every day / daily / every N days / every weekday / weekdays /
  // every monday and thursday / every week / weekly / monthly / yearly。
  _Rule(_words([r'every\s+(\d{1,3})\s+days|every\s*day|daily']), (
    m,
    text,
    today,
  ) {
    final raw = m[1];
    if (raw == null) return const TodoQuickRepeat(TodoRepeatFrequency.daily);
    final n = int.parse(raw);
    if (n < 1 || n > TodoRepeatRule.maxInterval) return null;
    return TodoQuickRepeat(TodoRepeatFrequency.daily, interval: n);
  }),
  _Rule(
    _words([r'(?:every|on)\s+weekdays?|weekdays']),
    (m, text, today) => const TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: _weekdaysOnly,
    ),
  ),
  _Rule(
    _words([
      '(?:every|each)\\s+((?:(?:$_enWeekdayWords)s?\\s*(?:,|and|&)?\\s*)*'
          '(?:$_enWeekdayWords))s?',
    ]),
    (m, text, today) => TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: _sortedDays(
        RegExp(
          _enWeekdayWords,
          caseSensitive: false,
        ).allMatches(m[1]!).map((Match d) => _enWeekday(d[0]!)),
      ),
    ),
  ),
  _Rule(
    _words([r'every\s+week|weekly']),
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.weekly),
  ),
  _Rule(
    _words([r'every\s+month|monthly']),
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.monthly),
  ),
  _Rule(
    _words([r'every\s+year|yearly|annually']),
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.yearly),
  ),
  // 俄文：каждый день / ежедневно / каждые N дней / по будням / каждый
  // понедельник / по средам / каждую неделю / ежемесячно / ежегодно。
  _Rule(_words([r'каждые\s+(\d{1,3})\s+дн(?:я|ей)|каждый\s+день|ежедневно']), (
    m,
    text,
    today,
  ) {
    final raw = m[1];
    if (raw == null) return const TodoQuickRepeat(TodoRepeatFrequency.daily);
    final n = int.parse(raw);
    if (n < 1 || n > TodoRepeatRule.maxInterval) return null;
    return TodoQuickRepeat(TodoRepeatFrequency.daily, interval: n);
  }),
  _Rule(
    _words([r'по\s+будням']),
    (m, text, today) => const TodoQuickRepeat(
      TodoRepeatFrequency.weekly,
      weekdays: _weekdaysOnly,
    ),
  ),
  _Rule(_words(['(?:кажд(?:ый|ую|ое)|по)\\s+($_ruWeekdayWords)']), (
    m,
    text,
    today,
  ) {
    final day = _ruWeekdays[m[1]!.toLowerCase().substring(0, 2)];
    return day == null
        ? null
        : TodoQuickRepeat(TodoRepeatFrequency.weekly, weekdays: <int>[day]);
  }),
  _Rule(
    _words([r'каждую\s+неделю|еженедельно']),
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.weekly),
  ),
  _Rule(
    _words([r'каждый\s+месяц|ежемесячно']),
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.monthly),
  ),
  _Rule(
    _words([r'каждый\s+год|ежегодно']),
    (m, text, today) => const TodoQuickRepeat(TodoRepeatFrequency.yearly),
  ),
];

final List<_Rule<TodoQuickReminder>> _reminderRules = [
  // 中文：提前 10 分钟 / 提前半小时 / 提前 2 小时 / 提前一天（提醒）。
  _Rule(r'提前\s*(\d{1,3}|[一二两三四五六七八九十]{1,3}|半)\s*(?:个|個)?\s*'
      r'(分钟|分鐘|小时|小時|钟头|天|日)(?:提醒)?', (m, text, today) {
    final raw = m[1]!;
    final unit = m[2]!;
    if (raw == '半') {
      return unit.startsWith('小') || unit == '钟头'
          ? const TodoQuickReminder.before(30)
          : null;
    }
    final n = int.tryParse(raw) ?? _cnNumber(raw);
    if (n == null || n < 1) return null;
    return _reminderOf(n, switch (unit) {
      '分钟' || '分鐘' => _ReminderUnit.minute,
      '天' || '日' => _ReminderUnit.day,
      _ => _ReminderUnit.hour,
    });
  }),
  // 中文：前一天（晚上）8 点（半）/ 前两天早上 9 点提醒。
  _Rule('前(一|两|二|三|[1-3])天\\s*($_cjkPeriods)?\\s*'
      r'(\d{1,2}|[一二两三四五六七八九十]{1,3})\s*[点點時时]\s*(?:(半)|(\d{1,2})\s*分?)?'
      r'(?:提醒)?', (m, text, today) {
    final days = int.tryParse(m[1]!) ?? _cnNumber(m[1]!);
    final hour = int.tryParse(m[3]!) ?? _cnNumber(m[3]!);
    if (days == null || hour == null) return null;
    final minute = m[4] != null ? 30 : int.parse(m[5] ?? '0');
    final clock = _clock(hour, minute, _periodWords[m[2]]);
    return clock == null
        ? null
        : TodoQuickReminder.daysBefore(days, minuteOfDay: clock);
  }),
  // 日文：10 分前（に通知）/ 1 時間前 / 1 日前。
  _Rule(r'(\d{1,3})\s*(分|時間|日)前(?:に(?:通知|リマインド))?', (m, text, today) {
    final n = int.parse(m[1]!);
    if (n < 1) return null;
    return _reminderOf(n, switch (m[2]!) {
      '分' => _ReminderUnit.minute,
      '日' => _ReminderUnit.day,
      _ => _ReminderUnit.hour,
    });
  }),
  // 英文：remind me 10 min before / 2 hours before / 1 day before。
  _Rule(
    _words([
      r'(?:remind\s+(?:me\s+)?)?(\d{1,3})\s*'
          r'(m|min|mins|minutes?|h|hrs?|hours?|d|days?)\s+(?:before|early)',
    ]),
    (m, text, today) {
      final n = int.parse(m[1]!);
      if (n < 1) return null;
      final unit = m[2]!.toLowerCase();
      return _reminderOf(
        n,
        unit.startsWith('m')
            ? _ReminderUnit.minute
            : unit.startsWith('d')
            ? _ReminderUnit.day
            : _ReminderUnit.hour,
      );
    },
  ),
  // 俄文：за 10 минут / за 2 часа / за 1 день。
  _Rule(
    _words([r'за\s+(\d{1,3})\s+(минут[уы]?|час(?:а|ов)?|д(?:ень|ня|ней))']),
    (m, text, today) {
      final n = int.parse(m[1]!);
      if (n < 1) return null;
      final unit = m[2]!.toLowerCase();
      return _reminderOf(
        n,
        unit.startsWith('мин')
            ? _ReminderUnit.minute
            : unit.startsWith('д')
            ? _ReminderUnit.day
            : _ReminderUnit.hour,
      );
    },
  ),
];

enum _ReminderUnit { minute, hour, day }

/// 提前 [n] 个 [unit]；超过上限（28 天）时不识别。
TodoQuickReminder? _reminderOf(int n, _ReminderUnit unit) {
  switch (unit) {
    case _ReminderUnit.day:
      return n > TodoReminder.maxDaysBefore
          ? null
          : TodoQuickReminder.daysBefore(n);
    case _ReminderUnit.hour:
    case _ReminderUnit.minute:
      final minutes = unit == _ReminderUnit.hour ? n * 60 : n;
      return minutes > TodoReminder.maxMinutesBefore
          ? null
          : TodoQuickReminder.before(minutes);
  }
}

/// 星期几去空、去重、升序。
List<int> _sortedDays(Iterable<int?> days) =>
    (days.whereType<int>().toSet().toList()..sort());
