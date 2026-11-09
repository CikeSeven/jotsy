// 日历类的只读工具：某一天的概览、纪念日（待办见 `ai_tools_todos.dart`）。

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/viewmodels/anniversary_calendar.dart';
import '../../anniversaries/viewmodels/anniversary_countdown.dart';
import '../../anniversaries/viewmodels/anniversary_rule.dart';
import '../../calendar/viewmodels/calendar_holiday_day.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_todo_parts.dart';
import 'ai_tools_diaries.dart';

/// 某一天：农历、节假日、这天的心情、这天写的日记、到期的待办、纪念日。
class GetCalendarDayTool extends AiTool {
  const GetCalendarDayTool();

  @override
  String get name => 'get_calendar_day';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Everything on one day: lunar date, public holiday, the day mood, '
      'entries written that day (titles only), to-dos due and anniversaries '
      'falling on it.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'date': AiDateSchema(description: 'YYYY-MM-DD; today if omitted.'),
    },
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final date = args['date'];
    return date is String
        ? l10n.aiToolCalendarDayOf(date)
        : l10n.aiToolCalendarDay;
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final day = args['date'] as DateTime? ?? context.today;
    final next = DateTime(day.year, day.month, day.day + 1);
    final database = context.database;
    final features = context.env.features;
    final privacy = context.prefs.privacy;
    final lunar = CalendarLunarDay.of(day);
    final holiday = CalendarHolidayDay.of(day);
    final diaries = await database.getAiContextDiaries(
      start: day,
      end: next,
      excludedNotebookIds: privacy.excludedNotebookIds,
      excludedTagNames: privacy.excludedTagNames,
      now: context.now,
    );
    final key = formatAnniversaryDate(day);
    final moods = await database.watchDayMoods().first;
    final mood = moods.where((row) => row.day == key).firstOrNull;
    final todos = features.todos
        ? await database.watchTodosDueBetween(day, day).first
        : const <TodoRow>[];
    final anniversaries = <Map<String, Object?>>[];
    if (features.anniversariesEnabled) {
      for (final row in await database.watchAnniversaries().first) {
        final rule = AnniversaryRule.fromRow(row);
        if (rule == null) continue;
        final occurrence = AnniversaryCalendar.next(rule, day);
        if (occurrence != null && occurrence.date == day) {
          anniversaries.add(<String, Object?>{
            'id': row.anniversaryId,
            'title': row.title,
            if (rule.repeats) 'times': occurrence.ordinal,
          });
        }
      }
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'date': aiToolDate(day),
        'lunar_date': lunar.date,
        'solar_term_today': ?lunar.term,
        if (lunar.festivals.isNotEmpty) 'festivals': lunar.festivals,
        if (holiday != null)
          'public_holiday': <String, Object?>{
            'name': holiday.name,
            'is_make_up_workday': holiday.isWork,
          },
        if (privacy.sendMood && mood != null) 'day_mood': mood.mood,
        'diaries': [
          for (final diary in diaries) aiDiaryToolHeader(context, diary),
        ],
        if (features.todos)
          'todos_due': [for (final todo in todos) aiTodoItem(todo, null)],
        if (features.anniversariesEnabled) 'anniversaries': anniversaries,
      },
      subjects: [
        AiToolSubject.day(day),
        for (final diary in diaries) aiContextDiarySubject(diary),
        for (final todo in todos) aiTodoSubject(todo),
      ],
    );
  }
}

class ListAnniversariesTool extends AiTool {
  const ListAnniversariesTool();

  @override
  String get name => 'list_anniversaries';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'List anniversaries and countdown days with their next date and how '
      'many days until it (or since a one-off date has passed).';

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  bool isAvailable(AiToolEnv env) => env.features.anniversariesEnabled;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolListAnniversaries;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final rows = await context.database.watchAnniversaries().first;
    final items = <Map<String, Object?>>[];
    for (final row in rows) {
      final rule = AnniversaryRule.fromRow(row);
      if (rule == null) continue;
      final countdown = AnniversaryCountdown.of(rule, context.today);
      items.add(<String, Object?>{
        'id': row.anniversaryId,
        'title': row.title,
        'date': row.baseDate,
        'repeats': row.recurrence,
        if (countdown.next case final next?) 'next_date': aiToolDate(next.date),
        'days_until_next': ?countdown.daysUntilNext,
        'days_since_date': countdown.daysSinceBase,
        if (row.note.trim().isNotEmpty) 'note': row.note.trim(),
      });
    }
    return AiToolOutcome(
      data: <String, Object?>{'anniversaries': items},
      summary: context.l10n.aiToolAnniversaryCount(items.length),
      subjects: [
        for (final row in rows)
          AiToolSubject.anniversary(
            row.anniversaryId,
            row.title,
            date: parseAnniversaryDate(row.baseDate),
          ),
      ],
    );
  }
}
