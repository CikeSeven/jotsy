import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_ai_output.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_quick_add_draft.dart';

/// 待办 AI 输出的解析：一行一步的步骤、一行一个 JSON 的待办，边收边认，
/// 逐字段校验；以及整理出的待办怎样与面板上手动选的值合在一起。
void main() {
  final today = DateTime(2026, 11, 28);
  final at = DateTime(2026, 11, 1);
  TodoListRow list(String id, String name) => TodoListRow(
    id: id.hashCode,
    listId: id,
    name: name,
    colorKey: '',
    iconKey: '',
    sortOrder: 0,
    metadata: '{}',
    createdAt: at,
    updatedAt: at,
  );

  group('steps', () {
    test('bullets, numbers and checkboxes go; headings and fences skip', () {
      const text =
          '```\n以下是建议的步骤：\n1. 量尺寸\n2) 选材料\n- [x] **找师傅**\n'
          '（4）约时间\n1.5 公斤水泥\n10:00 前出门\n```\n';
      expect(parseTodoAiSteps(text, complete: true), <String>[
        '量尺寸',
        '选材料',
        '找师傅',
        '约时间',
        '1.5 公斤水泥',
        '10:00 前出门',
      ]);
    });

    test('the last line waits until the answer is complete', () {
      const text = '量尺寸\n选材';
      expect(parseTodoAiSteps(text, complete: false), <String>['量尺寸']);
      expect(parseTodoAiSteps(text, complete: true), <String>['量尺寸', '选材']);
    });

    test('existing steps and repeats are dropped; at most max', () {
      const text = 'Measure\nmeasure\nBuy paint\nBuy Paint\nCall\nClean';
      expect(
        parseTodoAiSteps(
          text,
          complete: true,
          existing: const <String>['MEASURE'],
          max: 2,
        ),
        <String>['Buy paint', 'Call'],
      );
    });
  });

  group('to-dos', () {
    final lists = <TodoListRow>[list('l1', '生活'), list('l2', 'Work')];

    test('each field is checked on its own', () {
      const text =
          '{"title": "交房租", "date": "2026-11-29", "time": "9:30", '
          '"priority": 3, "list": "生活", "tags": ["@账单", "账单"]}\n'
          '{"title": "写周报", "time": "18:00", "list": "#work", '
          '"priority": "medium"}\n'
          '{"title": "约牙医", "date": "2026-02-30", "time": "25:00", '
          '"priority": 7, "list": "不存在"}\n'
          '{"title": "", "date": "2026-11-29"}\n'
          '{"date": "2026-11-29"}\n'
          '不是 JSON\n'
          '{"title": "远在天边", "date": "2099-01-01"}\n';
      final items = parseTodoAiItems(
        text,
        complete: true,
        lists: lists,
        today: today,
      );
      expect(items.map((item) => item.title), <String>[
        '交房租',
        '写周报',
        '约牙医',
        '远在天边',
      ]);
      expect(items[0].date, DateTime(2026, 11, 29));
      expect(items[0].minute, 9 * 60 + 30);
      expect(items[0].priority, TodoPriority.high);
      expect(items[0].listId, 'l1');
      expect(items[0].tags, <String>['账单']);
      // 没有日期时不要时刻；清单名不分大小写、可带 #。
      expect(items[1].date, isNull);
      expect(items[1].minute, isNull);
      expect(items[1].listId, 'l2');
      expect(items[1].priority, TodoPriority.medium);
      // 不存在的日子、越界的时刻与优先级、认不出的清单都不带。
      expect(items[2].date, isNull);
      expect(items[2].priority, TodoPriority.none);
      expect(items[2].listId, isNull);
      expect(items[3].date, isNull, reason: '太远的日子不认');
    });

    test('a half line waits; an array answer is read at the end', () {
      const streaming = '{"title": "A"}\n{"title": "B"';
      expect(
        parseTodoAiItems(
          streaming,
          complete: false,
          lists: lists,
          today: today,
        ).map((item) => item.title),
        <String>['A'],
      );
      const array =
          '```json\n[\n  {\n    "title": "A"\n  },\n'
          '  {\n    "title": "B"\n  }\n]\n```';
      expect(
        parseTodoAiItems(
          array,
          complete: true,
          lists: lists,
          today: today,
        ).map((item) => item.title),
        <String>['A', 'B'],
      );
      // 一行一个、但包在数组里也认。
      const inline = '[{"title": "A"},\n{"title": "B"}]';
      expect(
        parseTodoAiItems(
          inline,
          complete: true,
          lists: lists,
          today: today,
        ).map((item) => item.title),
        <String>['A', 'B'],
      );
    });
  });

  group('quick add draft', () {
    test('an item keeps its own values and borrows the rest', () {
      final draft =
          TodoQuickAddDraft(
              listId: 'l1',
              tags: const <String>['家务'],
              sectionId: 's1',
            )
            ..dueDate = DateTime(2026, 12, 1)
            ..dueMinute = 8 * 60
            ..reminders = const <TodoReminder>[
              TodoReminder.onDay(days: 0, minute: 7 * 60),
            ];
      final own = draft.inputForAi(
        TodoAiItem(
          title: '交房租',
          date: DateTime(2026, 11, 29),
          listId: 'l2',
          tags: const <String>['账单'],
        ),
      );
      expect(own.dueDate, DateTime(2026, 11, 29));
      expect(own.dueMinute, isNull);
      expect(own.reminders, isEmpty, reason: '手动的提醒跟着手动的日期');
      expect(own.listId, 'l2');
      expect(own.sectionId, isNull, reason: '换了清单就不带分区');
      expect(own.tags, <String>['家务', '账单']);

      final borrowed = draft.inputForAi(const TodoAiItem(title: '拖地'));
      expect(borrowed.dueDate, DateTime(2026, 12, 1));
      expect(borrowed.dueMinute, 8 * 60);
      expect(borrowed.reminders, hasLength(1));
      expect(borrowed.listId, 'l1');
      expect(borrowed.sectionId, 's1');
    });
  });
}
