// 待办工具共用的部分：按名称找清单、待办在结果里的写法、提醒与重复规则的
// 参数 schema、解析与卡片详情里的说法。
//
// 结果与参数同一形状：`list_todos` 回传的 `reminders` / `repeat` / `steps`
// 与 `create_todo` / `update_todos` 收的参数写法一致，模型改一处再原样传回
// 即可，不用在两种写法之间换算。
//
// 提醒与重复都相对截止日：没有截止日的待办设提醒或重复时，与待办详情页同一
// 口径先把截止日定为今天（详情页的提醒 / 重复面板也是这样）。

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../l10n/app_localizations.dart';
import '../../todos/widgets/todo_labels.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';

const List<String> aiTodoPriorities = <String>['none', 'low', 'medium', 'high'];

/// 结果与参数里收集箱的名称（不在任何清单里）。
const String aiTodoInboxName = 'Inbox';

/// 按名称找待办清单（不分大小写）；空串为收集箱（null）。找不到时抛
/// [AiToolFailure] 并列出现有清单。
Future<String?> aiTodoListId(AppDatabase database, String name) async {
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  final lists = await database.getTodoLists();
  for (final list in lists) {
    if (list.name.toLowerCase() == wanted) return list.listId;
  }
  throw AiToolFailure(
    'No to-do list named "$name". Lists: '
    '${lists.isEmpty ? '(none)' : lists.map((l) => l.name).join(', ')}; '
    '"" means the inbox.',
  );
}

/// 撤销数据里的整行待办。
List<TodoRow> aiTodoRows(Object? raw) => [
  for (final row in raw as List? ?? const [])
    TodoRow.fromJson((row as Map).cast<String, dynamic>()),
];

/// 一项待办作为涉及对象（截止日期按本地日期解析，没有截止为 null）。
AiToolSubject aiTodoSubject(TodoRow row, {String? title}) => AiToolSubject.todo(
  row.todoId,
  title ?? row.title,
  due: row.dueDate == null ? null : parseAnniversaryDate(row.dueDate!),
);

/// 按 id 取一批待办；有一个不存在就整批不做。
Future<List<TodoRow>> aiTodosByIds(
  AppDatabase database,
  Iterable<String> ids,
) async {
  final rows = <TodoRow>[];
  for (final id in ids.toSet()) {
    final row = await database.getTodo(id);
    if (row == null) throw AiToolFailure('No to-do with id $id.');
    rows.add(row);
  }
  return rows;
}

String _hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

/// 一项待办在工具结果里的写法。[lists] 为清单 id → 名称（null 时不写清单）。
Map<String, Object?> aiTodoItem(TodoRow row, Map<String, String>? lists) {
  final minute = row.dueMinute;
  final note = row.note.trim();
  final steps = decodeTodoSteps(row.steps);
  final reminders = decodeTodoReminders(row.reminders);
  final repeat = decodeTodoRepeat(row.repeat);
  final completedAt = row.completedAt;
  return <String, Object?>{
    'id': row.todoId,
    'title': row.title,
    if (lists != null) 'list': lists[row.listId] ?? aiTodoInboxName,
    'due_date': ?row.dueDate,
    if (row.dueDate != null && minute != null) 'due_time': _hhmm(minute),
    if (row.priority > 0) 'priority': TodoPriority.of(row.priority).name,
    'done': completedAt != null,
    if (completedAt != null) 'completed_at': aiToolDateTime(completedAt),
    if (note.isNotEmpty)
      'note': note.length > 200 ? '${note.substring(0, 200)}…' : note,
    if (steps.isNotEmpty)
      'steps': [
        for (final step in steps)
          <String, Object?>{
            'id': step.id,
            'title': step.title,
            'done': step.done,
          },
      ],
    if (reminders.isNotEmpty)
      'reminders': [for (final reminder in reminders) _reminderJson(reminder)],
    if (repeat != null) 'repeat': _repeatJson(repeat),
  };
}

/// 步骤标题 → 步骤（依次编号）。
List<TodoStep> aiTodoNewSteps(
  List<TodoStep> existing,
  Iterable<String> titles,
) {
  final steps = [...existing];
  for (final raw in titles) {
    final title = raw.trim();
    if (title.isEmpty) continue;
    steps.add(TodoStep(id: TodoStep.nextId(steps), title: title));
  }
  if (steps.length > TodoStep.maxSteps) {
    throw const AiToolFailure(
      'A to-do has at most ${TodoStep.maxSteps} steps.',
    );
  }
  return steps;
}

// ---------------------------------------------------------------------------
// 提醒

/// 提醒参数：截止时刻之前若干分钟，或截止日当天 / 之前某天的某个时刻。
const AiArraySchema aiTodoRemindersSchema = AiArraySchema(
  description:
      'Reminders, relative to the due date. Each is either '
      '{minutes_before} (needs a due time; 0 = at the due time) or '
      '{time, days_before} (a time on the due day or N days before; works '
      'for all-day to-dos).',
  maxItems: TodoReminder.maxReminders,
  items: AiObjectSchema(
    properties: <String, AiSchema>{
      'minutes_before': AiIntegerSchema(
        minimum: 0,
        maximum: TodoReminder.maxMinutesBefore,
      ),
      'days_before': AiIntegerSchema(
        minimum: 0,
        maximum: TodoReminder.maxDaysBefore,
      ),
      'time': AiTimeSchema(),
    },
  ),
);

/// 校验过的提醒参数 → 提醒（去重，保持顺序）。[hasDueTime] 为 false 时不能
/// 有“截止前若干分钟”（全天待办到不了那个时刻）。
List<TodoReminder> aiTodoReminders(Object? raw, {required bool hasDueTime}) {
  final reminders = <TodoReminder>[];
  for (final item in raw as List? ?? const []) {
    final map = (item as Map).cast<String, Object?>();
    final minutes = map['minutes_before'] as int?;
    final time = map['time'] as int?;
    final TodoReminder reminder;
    if (minutes != null) {
      if (time != null || map['days_before'] != null) {
        throw const AiToolFailure(
          'A reminder is either {minutes_before} or {time, days_before}, '
          'not both.',
        );
      }
      if (!hasDueTime) {
        throw const AiToolFailure(
          '`minutes_before` needs a due time; for an all-day to-do use '
          '{time, days_before}.',
        );
      }
      reminder = TodoReminder.beforeDue(minutes);
    } else if (time != null) {
      reminder = TodoReminder.onDay(
        days: -(map['days_before'] as int? ?? 0),
        minute: time,
      );
    } else {
      throw const AiToolFailure(
        'Each reminder needs `minutes_before` or `time`.',
      );
    }
    if (!reminders.contains(reminder)) reminders.add(reminder);
  }
  return reminders;
}

Map<String, Object?> _reminderJson(TodoReminder reminder) =>
    switch (reminder.kind) {
      TodoReminderKind.beforeDue => <String, Object?>{
        'minutes_before': reminder.minutesBefore,
      },
      TodoReminderKind.onDay => <String, Object?>{
        'time': _hhmm(reminder.minuteOfDay),
        if (reminder.dayOffset != 0) 'days_before': -reminder.dayOffset,
      },
    };

/// 卡片详情里提醒参数的说法（落库的原始参数，格式不对的项跳过）。
String aiTodoRemindersText(AppLocalizations l10n, Object? raw) {
  if (raw is! List) return '';
  if (raw.isEmpty) return l10n.aiToolArgNone;
  final texts = <String>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final minutes = item['minutes_before'];
    final time = _minuteOf(item['time']);
    final days = item['days_before'];
    final TodoReminder reminder;
    if (minutes is int) {
      reminder = TodoReminder.beforeDue(minutes);
    } else if (time != null) {
      reminder = TodoReminder.onDay(
        days: days is int ? -days : 0,
        minute: time,
      );
    } else {
      continue;
    }
    texts.add(TodoLabels.reminderWith(l10n, reminder, _hhmm));
  }
  return texts.join(l10n.aiListSeparator);
}

int? _minuteOf(Object? raw) {
  final match = raw is String
      ? RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim())
      : null;
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

// ---------------------------------------------------------------------------
// 重复

const Map<String, TodoRepeatFrequency> _frequencies =
    <String, TodoRepeatFrequency>{
      'daily': TodoRepeatFrequency.daily,
      'weekly': TodoRepeatFrequency.weekly,
      'monthly': TodoRepeatFrequency.monthly,
      'yearly': TodoRepeatFrequency.yearly,
      'workdays': TodoRepeatFrequency.legalWorkdays,
    };

const Map<String, TodoMonthlyMode> _monthlyModes = <String, TodoMonthlyMode>{
  'day_of_month': TodoMonthlyMode.dayOfMonth,
  'weekday_ordinal': TodoMonthlyMode.weekdayOrdinal,
  'last_day': TodoMonthlyMode.lastDay,
};

/// 重复参数。枚举值与 [_frequencies] / [_monthlyModes] 的键一致（写成字面量
/// 才能 const，`ai_tools_test` 核对两边相同）。
const AiObjectSchema aiTodoRepeatSchema = AiObjectSchema(
  description:
      'Repeat rule, counted from the due date (today if the to-do has none). '
      'frequency "none" removes it; "workdays" = Chinese statutory workdays '
      '(Mon–Fri minus public holidays, plus make-up workdays).',
  properties: <String, AiSchema>{
    'frequency': AiStringSchema(
      enumValues: <String>[
        'none',
        'daily',
        'weekly',
        'monthly',
        'yearly',
        'workdays',
      ],
    ),
    'interval': AiIntegerSchema(
      minimum: 1,
      maximum: TodoRepeatRule.maxInterval,
      description: 'Every N days / weeks / months / years (default 1).',
    ),
    'weekdays': AiArraySchema(
      items: AiIntegerSchema(minimum: 1, maximum: 7),
      maxItems: 7,
      description: 'Weekly only: 1 = Monday … 7 = Sunday.',
    ),
    'monthly_on': AiStringSchema(
      enumValues: <String>['day_of_month', 'weekday_ordinal', 'last_day'],
      description:
          'Monthly only: same day number, same "Nth weekday" as the due '
          'date, or the last day of the month.',
    ),
    'from_completion': AiBooleanSchema(
      description: 'Count the next date from the day it is completed.',
    ),
    'until': AiDateSchema(description: 'Last date, YYYY-MM-DD.'),
    'count': AiIntegerSchema(
      minimum: 1,
      maximum: TodoRepeatRule.maxCount,
      description: 'Total number of times, including the first.',
    ),
  },
  required: <String>['frequency'],
);

/// 重复参数里的频率与每月落点（测试核对与 schema 的枚举一致）。
List<String> get aiTodoRepeatFrequencyKeys => _frequencies.keys.toList();
List<String> get aiTodoMonthlyModeKeys => _monthlyModes.keys.toList();

/// 校验过的重复参数 → 规则；`none` 为 null（不重复）。[anchor] 为截止日。
TodoRepeatRule? aiTodoRepeatRule(Map<String, Object?> raw, DateTime anchor) {
  final frequency = _frequencies[raw['frequency']];
  if (frequency == null) return null;
  final until = raw['until'] as DateTime?;
  if (until != null && until.isBefore(anchor)) {
    throw const AiToolFailure('`until` is before the due date.');
  }
  final weekdays = [
    for (final day in raw['weekdays'] as List? ?? const []) day as int,
  ];
  if (weekdays.isNotEmpty && frequency != TodoRepeatFrequency.weekly) {
    throw const AiToolFailure('`weekdays` only applies to weekly repeats.');
  }
  return TodoRepeatRule(
    frequency: frequency,
    // 法定工作日的间隔固定为 1（见 TodoRepeatFrequency.legalWorkdays）。
    interval: frequency == TodoRepeatFrequency.legalWorkdays
        ? 1
        : raw['interval'] as int? ?? 1,
    weekdays: frequency == TodoRepeatFrequency.weekly
        ? TodoRepeatRule.normalizeWeekdays(
            weekdays.isEmpty ? <int>[anchor.weekday] : weekdays,
          )
        : const <int>[],
    monthlyMode: _monthlyModes[raw['monthly_on']] ?? TodoMonthlyMode.dayOfMonth,
    basis: raw['from_completion'] == true
        ? TodoRepeatBasis.completion
        : TodoRepeatBasis.due,
    anchor: DateTime(anchor.year, anchor.month, anchor.day),
    until: until,
    count: raw['count'] as int?,
  );
}

Map<String, Object?> _repeatJson(TodoRepeatRule rule) {
  String keyOf<T>(Map<String, T> map, T value) =>
      map.entries.firstWhere((entry) => entry.value == value).key;
  return <String, Object?>{
    'frequency': keyOf(_frequencies, rule.frequency),
    if (rule.interval != 1) 'interval': rule.interval,
    if (rule.frequency == TodoRepeatFrequency.weekly)
      'weekdays': rule.weekdays.isEmpty
          ? <int>[rule.anchor.weekday]
          : rule.weekdays,
    if (rule.frequency == TodoRepeatFrequency.monthly)
      'monthly_on': keyOf(_monthlyModes, rule.monthlyMode),
    if (rule.basis == TodoRepeatBasis.completion) 'from_completion': true,
    if (rule.until case final until?) 'until': aiToolDate(until),
    'count': ?rule.count,
  };
}

/// 卡片详情里重复参数的说法。参数里没有截止日（几号、哪天由待办自己的截止
/// 日决定），所以每月 / 每年只写间隔，不写具体哪天。
String aiTodoRepeatText(AppLocalizations l10n, Object? raw) {
  if (raw is! Map) return '';
  final frequency = _frequencies[raw['frequency']];
  if (frequency == null) return l10n.todoRepeatNone;
  final interval = raw['interval'] is int ? raw['interval'] as int : 1;
  final String main;
  switch (frequency) {
    case TodoRepeatFrequency.daily:
      main = interval == 1
          ? l10n.todoRepeatDaily
          : l10n.todoRepeatEveryDays(interval);
    case TodoRepeatFrequency.legalWorkdays:
      main = l10n.todoRepeatLegalWorkdays;
    case TodoRepeatFrequency.weekly:
      final days = [
        for (final day
            in raw['weekdays'] is List ? raw['weekdays'] as List : [])
          if (day is int && day >= 1 && day <= 7) day,
      ];
      final every = l10n.todoRepeatEveryWeeks(interval);
      main = days.isEmpty
          ? every
          : interval == 1
          ? l10n.todoRepeatWeeklyOn(
              days
                  .map((d) => TodoLabels.weekdayName(l10n, d))
                  .join(l10n.aiListSeparator),
            )
          : l10n.todoRepeatSummaryJoin(
              every,
              days
                  .map((d) => TodoLabels.weekdayName(l10n, d))
                  .join(l10n.aiListSeparator),
            );
    case TodoRepeatFrequency.monthly:
      main = raw['monthly_on'] == 'last_day' && interval == 1
          ? l10n.todoRepeatMonthlyLastDay
          : l10n.todoRepeatEveryMonths(interval);
    case TodoRepeatFrequency.yearly:
      main = l10n.todoRepeatEveryYears(interval);
  }
  final parts = <String>[main];
  if (raw['from_completion'] == true) parts.add(l10n.todoRepeatFromCompletion);
  final until = raw['until'] is String
      ? parseAnniversaryDate(raw['until'] as String)
      : null;
  if (until != null) {
    parts.add(l10n.todoRepeatEndsOn(l10n.formatFullDate(until)));
  } else if (raw['count'] case final int count) {
    parts.add(l10n.todoRepeatEndsAfter(count));
  }
  return parts.reduce(l10n.todoRepeatSummaryJoin);
}

/// 待办工具共用的 `describeArg`：提醒与重复写成可读的说法，其余走通用格式。
String? aiDescribeTodoArg(AppLocalizations l10n, String key, Object? value) =>
    switch (key) {
      'reminders' => aiTodoRemindersText(l10n, value),
      'repeat' => aiTodoRepeatText(l10n, value),
      // 清单参数的空串是收集箱。
      'list' when value == '' => l10n.todoViewInbox,
      _ => null,
    };
