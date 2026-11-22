import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/models/ai_tool_subject.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_tool_facts.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  AiAgentCallRecord call(
    String tool,
    Map<String, Object?> args, {
    List<AiToolSubject> subjects = const <AiToolSubject>[],
  }) => AiAgentCallRecord(
    id: 'c',
    tool: tool,
    args: args,
    status: AiToolCallStatus.succeeded,
    subjects: subjects,
  );

  test('search parameters read as labelled rows, never as ids', () {
    final facts = aiToolFacts(
      zh,
      call(
        'search_diaries',
        {
          'query': '海边 日落',
          'from': '2026-10-01',
          'to': '2026-10-31',
          'notebook_id': 'nb-uuid',
          'sort': 'newest',
          'include_archived': true,
        },
        subjects: const [
          AiToolSubject.notebook('nb-uuid', '旅行手记', input: true),
        ],
      ),
    );
    final byLabel = {for (final fact in facts) fact.label: fact.value};
    expect(byLabel[zh.aiToolArgName('arg_query')], '海边 日落');
    expect(byLabel[zh.aiToolArgName('arg_date_range')], contains('–'));
    expect(byLabel[zh.aiToolArgName('arg_kind_notebook')], '旅行手记');
    expect(byLabel[zh.aiToolArgName('arg_sort')], '从新到旧');
    expect(byLabel[zh.aiToolArgName('arg_include_archived')], zh.aiToolArgYes);
    expect(facts.map((f) => f.value).join(), isNot(contains('nb-uuid')));
  });

  test('ids without a known subject are left out', () {
    final facts = aiToolFacts(
      zh,
      call('read_diaries', {
        'ids': ['a', 'b'],
      }),
    );
    expect(facts, isEmpty);
  });

  test('many targets collapse into a count', () {
    final subjects = [
      for (var i = 0; i < 5; i++)
        AiToolSubject.diary(
          'd$i',
          title: '第$i篇',
          date: DateTime(2026, 11, i + 1),
        ),
    ];
    final facts = aiToolFacts(
      zh,
      call('pin_diaries', {
        'ids': [for (final s in subjects) s.id],
        'pinned': true,
      }, subjects: subjects),
    );
    final targets = facts.firstWhere(
      (f) => f.label == zh.aiToolArgName('arg_kind_diary'),
    );
    expect(targets.value, contains('5'));
  });

  test('enum values and colors are readable in English too', () {
    final facts = aiToolFacts(
      en,
      call('set_theme', {'mode': 'dark', 'color': '#3366CC'}),
    );
    expect(facts.first.value, 'Dark');
    final color = facts.firstWhere((f) => f.color != null);
    expect(color.color, 0xff3366cc);
  });

  test('settings read as "page · setting — on / off" with readable values', () {
    final facts = aiToolFacts(
      zh,
      call('change_settings', {
        'todo_show_completed': false,
        'calendar_week_start': 'monday',
        'todo_default_list': '',
        'todo_snooze_minutes': 15,
      }),
    );
    final byLabel = {for (final fact in facts) fact.label: fact.value};
    expect(
      byLabel[zh.aiToolSettingName(zh.navTodos, zh.todoShowCompleted)],
      zh.aiToolArgOff,
    );
    expect(
      byLabel[zh.aiToolSettingName(
        zh.navCalendar,
        zh.calendarOptionsWeekStart,
      )],
      zh.calendarWeekStartMonday,
    );
    expect(
      byLabel[zh.aiToolSettingName(zh.navTodos, zh.todoSettingsDefaultList)],
      zh.todoViewInbox,
    );
    expect(
      byLabel[zh.aiToolSettingName(zh.navTodos, zh.todoSettingsSnooze)],
      zh.todoSettingsSnoozeMinutes(15),
    );
    expect(
      aiToolByName('change_settings')!.label(zh, {'todo_sort': 'due'}),
      zh.aiToolChangeSetting(
        zh.aiToolSettingName(zh.navTodos, zh.todoSortTitle),
      ),
    );
  });

  test('reminders and repeat read as sentences, never as JSON', () {
    final facts = aiToolFacts(
      en,
      call('update_todos', {
        'reminders': [
          {'minutes_before': 30},
          {'time': '20:00', 'days_before': 1},
        ],
        'repeat': {
          'frequency': 'weekly',
          'weekdays': [1, 3],
          'count': 5,
        },
      }),
    );
    final text = facts.map((f) => f.value).join('\n');
    expect(text, isNot(contains('{')));
    expect(text, contains(en.todoReminderMinutesBefore(30)));
    expect(text, contains(en.todoReminderDaysBeforeAt(1, '20:00')));
    expect(text, contains(en.todoRepeatEndsAfter(5)));
    final cleared = aiToolFacts(
      zh,
      call('update_todos', {'reminders': <Object?>[]}),
    );
    expect(cleared.single.value, zh.aiToolArgNone);
  });

  test('untitled diaries are named by their date', () {
    final name = aiSubjectName(
      zh,
      AiToolSubject.diary('x', title: '', date: DateTime(2026, 11, 3)),
    );
    expect(name, contains('11'));
    expect(name, contains('3'));
  });

  test('notebook chapter tools never leak raw chapter ids or JSON', () {
    final editFacts = aiToolFacts(
      zh,
      call(
        'edit_notebook_chapters',
        {
          'notebook_id': 'nb-uuid',
          'add': ['序言', '尾声'],
          'rename': [
            {'chapter': 'ch000001', 'title': '行前准备'},
          ],
          'order': ['ch000002', 'ch000001'],
        },
        subjects: const [AiToolSubject.notebook('nb-uuid', '旅行手记')],
      ),
    );
    final byLabel = {for (final f in editFacts) f.label: f.value};
    expect(byLabel[zh.aiToolArgName('arg_kind_notebook')], '旅行手记');
    expect(byLabel[zh.aiToolArgAddChapters], '序言、尾声');
    expect(byLabel[zh.aiToolArgRenameChapters], '行前准备');
    expect(byLabel.containsKey(zh.aiToolArgChapterOrder), isFalse);
    final joined = editFacts.map((f) => f.value).join('\n');
    expect(joined, isNot(contains('ch000001')));
    expect(joined, isNot(contains('ch000002')));
    expect(joined, isNot(contains('{')));

    final deleteFacts = aiToolFacts(
      zh,
      call(
        'delete_notebook_chapters',
        {
          'notebook_id': 'nb-uuid',
          'chapters': ['ch000001'],
        },
        subjects: const [AiToolSubject.notebook('nb-uuid', '旅行手记')],
      ),
    );
    expect(deleteFacts.map((f) => f.value).join(), isNot(contains('ch000001')));

    final unassignedFacts = aiToolFacts(
      zh,
      call(
        'move_to_notebook_chapter',
        {
          'notebook_id': 'nb-uuid',
          'ids': ['d1'],
          'chapter_id': '',
        },
        subjects: [
          const AiToolSubject.notebook('nb-uuid', '旅行手记', input: true),
          AiToolSubject.diary('d1', title: '海边', date: DateTime(2026, 11, 1)),
        ],
      ),
    );
    final moveByLabel = {for (final f in unassignedFacts) f.label: f.value};
    expect(
      moveByLabel[zh.aiToolArgName('arg_chapter_id')],
      zh.notebookChapterUnassigned,
    );

    final withChapterId = aiToolFacts(
      zh,
      call(
        'move_to_notebook_chapter',
        {
          'notebook_id': 'nb-uuid',
          'ids': ['d1'],
          'chapter_id': 'ch000001',
        },
        subjects: [
          const AiToolSubject.notebook('nb-uuid', '旅行手记', input: true),
          AiToolSubject.diary('d1', title: '海边', date: DateTime(2026, 11, 1)),
        ],
      ),
    );
    expect(
      withChapterId.map((f) => f.value).join(),
      isNot(contains('ch000001')),
    );
  });

  test('subjects survive the step record round trip', () {
    final record =
        call(
          'search_diaries',
          const {},
          subjects: [
            for (var i = 0; i < 15; i++)
              AiToolSubject.diary('d$i', title: 't$i', date: DateTime(2026)),
          ],
        ).copyWith(
          subjects: [
            for (var i = 0; i < 15; i++)
              AiToolSubject.diary('d$i', title: 't$i', date: DateTime(2026)),
          ],
        );
    expect(record.subjects, hasLength(AiToolSubject.maxStored));
    expect(record.moreSubjects, 3);
    final decoded = AiAgentCallRecord.fromJson(record.toJson())!;
    expect(decoded.subjects, record.subjects);
    expect(decoded.moreSubjects, 3);
  });
}
