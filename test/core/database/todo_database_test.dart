import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('todo writes', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('create puts new todos first and fields round-trip', () async {
      final first = await db.createTodo(const TodoInput(title: ' 第一条 '));
      final second = await db.createTodo(
        TodoInput(
          title: '交周报',
          note: ' 周五前 ',
          priority: TodoPriority.high,
          dueDate: DateTime(2026, 11, 13, 18),
          dueMinute: 15 * 60,
          reminders: const <TodoReminder>[TodoReminder.beforeDue(30)],
          steps: const <TodoStep>[TodoStep(id: 'a', title: '整理数据')],
        ),
      );
      final rows = await db.watchOpenTodos().first;
      expect(rows.map((r) => r.todoId), <String>[second, first]);
      final row = rows.first;
      expect(row.title, '交周报');
      expect(row.note, '周五前');
      expect(row.priority, TodoPriority.high.index);
      expect(row.dueDate, '2026-11-13');
      expect(row.dueMinute, 15 * 60);
      expect(decodeTodoReminders(row.reminders).single.minutesBefore, 30);
      expect(decodeTodoSteps(row.steps).single.title, '整理数据');
      expect(rows.last.title, '第一条');
      expect(
        () => db.createTodo(const TodoInput(title: '  ')),
        throwsFormatException,
      );
    });

    test('batch create keeps the given order at the top', () async {
      await db.createTodo(const TodoInput(title: '旧的'));
      await db.createTodos(const <TodoInput>[
        TodoInput(title: 'A'),
        TodoInput(title: 'B'),
      ]);
      final rows = await db.watchOpenTodos().first;
      expect(rows.map((r) => r.title), <String>['A', 'B', '旧的']);
    });

    test('moving between neighbours only rewrites the moved row', () async {
      final a = await db.createTodo(const TodoInput(title: 'A'));
      final b = await db.createTodo(const TodoInput(title: 'B'));
      final c = await db.createTodo(const TodoInput(title: 'C'));
      // 现在顺序是 C B A；把 A 拖到 C 与 B 之间。
      final before = await db.getTodo(b);
      await db.moveTodo(a, aboveId: c, belowId: b);
      final rows = await db.watchOpenTodos().first;
      expect(rows.map((r) => r.title), <String>['C', 'A', 'B']);
      expect((await db.getTodo(b))!.updatedAt, before!.updatedAt);
    });

    test(
      'setting a due date re-anchors the repeat; clearing drops it',
      () async {
        final id = await db.createTodo(
          TodoInput(
            title: '还信用卡',
            dueDate: DateTime(2026, 1, 31),
            repeat: TodoRepeatRule(
              frequency: TodoRepeatFrequency.monthly,
              anchor: DateTime(2026, 1, 31),
            ),
          ),
        );
        await db.setTodoDue(id, date: DateTime(2026, 2, 15));
        var row = (await db.getTodo(id))!;
        expect(decodeTodoRepeat(row.repeat)!.anchor, DateTime(2026, 2, 15));
        await db.setTodoDue(id, date: null);
        row = (await db.getTodo(id))!;
        expect(row.dueDate, isNull);
        expect(row.repeat, isNull);
      },
    );

    test('search matches title, note and step titles only', () async {
      await db.createTodo(
        const TodoInput(
          title: '准备旅行',
          steps: <TodoStep>[TodoStep(id: 'a', title: '订酒店')],
        ),
      );
      await db.createTodo(const TodoInput(title: '买书', note: '旅行时看'));
      await db.createTodo(
        const TodoInput(
          title: '别的',
          steps: <TodoStep>[TodoStep(id: 'b', title: '无关', done: true)],
        ),
      );
      expect(
        (await db.watchTodoSearch('酒店').first).map((r) => r.title),
        <String>['准备旅行'],
      );
      expect((await db.watchTodoSearch('旅行').first), hasLength(2));
      expect(
        await db.watchTodoSearch('done').first,
        isEmpty,
        reason: '步骤 JSON 的键名不算命中',
      );
    });

    test('completing a plain todo and undoing it', () async {
      final id = await db.createTodo(const TodoInput(title: '寄快递'));
      final done = (await db.completeTodo(id))!;
      expect(done.advanced, isFalse);
      expect((await db.getTodo(id))!.completedAt, isNotNull);
      expect(await db.completeTodo(id), isNull, reason: '已完成的不再完成');
      await db.undoTodoCompletion(done);
      expect((await db.getTodo(id))!.completedAt, isNull);
    });

    test(
      'completing a repeating todo advances it and records the occurrence',
      () async {
        final id = await db.createTodo(
          TodoInput(
            title: '浇花',
            dueDate: DateTime(2026, 11, 2),
            repeat: TodoRepeatRule(
              frequency: TodoRepeatFrequency.weekly,
              anchor: DateTime(2026, 11, 2),
            ),
            steps: const <TodoStep>[TodoStep(id: 'a', title: '阳台', done: true)],
          ),
        );
        final result = (await db.completeTodo(
          id,
          now: DateTime(2026, 11, 2, 20),
        ))!;
        expect(result.nextDue, DateTime(2026, 11, 9));
        final original = (await db.getTodo(id))!;
        expect(original.completedAt, isNull);
        expect(original.dueDate, '2026-11-09');
        expect(decodeTodoSteps(original.steps).single.done, isFalse);
        expect(
          decodeTodoMetadata(original.metadata)[TodoMetadataKeys.repeatDone],
          1,
        );
        final copy = (await db.getTodo(result.copyId!))!;
        expect(copy.completedAt, isNotNull);
        expect(copy.dueDate, '2026-11-02');
        expect(copy.repeat, isNull);
        expect(result.copyId, todoOccurrenceId(id, '2026-11-02'));

        await db.undoTodoCompletion(result);
        expect((await db.getTodo(id))!.dueDate, '2026-11-02');
        expect(await db.getTodo(result.copyId!), isNull);
      },
    );

    test(
      'the last occurrence of a counted series completes the todo',
      () async {
        final id = await db.createTodo(
          TodoInput(
            title: '吃药',
            dueDate: DateTime(2026, 11, 2),
            repeat: TodoRepeatRule(
              frequency: TodoRepeatFrequency.daily,
              anchor: DateTime(2026, 11, 2),
              count: 1,
            ),
          ),
        );
        final result = (await db.completeTodo(id, now: DateTime(2026, 11, 2)))!;
        expect(result.advanced, isFalse);
        expect((await db.getTodo(id))!.completedAt, isNotNull);
        expect(await db.watchCompletedTodos().first, hasLength(1));
      },
    );

    test('step toggles and snooze', () async {
      final id = await db.createTodo(
        const TodoInput(
          title: '搬家',
          steps: <TodoStep>[TodoStep(id: 'a', title: '打包')],
        ),
      );
      await db.setTodoStepDone(id, 'a', true);
      expect(
        decodeTodoSteps((await db.getTodo(id))!.steps).single.done,
        isTrue,
      );
      final until = DateTime(2026, 11, 8, 10, 30);
      await db.snoozeTodo(id, until);
      expect((await db.getTodo(id))!.snoozedUntil, until);
    });

    test('deleting a list removes its todos and undo restores both', () async {
      final listId = await db.createTodoList(name: '工作');
      final inList = await db.createTodo(
        TodoInput(title: '开会', listId: listId),
      );
      final inbox = await db.createTodo(const TodoInput(title: '收集箱里的'));
      expect(
        await db.watchTodoListProgress().first,
        <String?, TodoListProgress>{
          listId: const TodoListProgress(open: 1, done: 0),
          null: const TodoListProgress(open: 1, done: 0),
        },
      );
      final deletion = (await db.deleteTodoList(listId))!;
      expect(deletion.todos.single.todoId, inList);
      expect(await db.getTodo(inList), isNull);
      expect(await db.getTodo(inbox), isNotNull);
      await db.restoreTodoList(deletion);
      expect((await db.getTodo(inList))!.listId, listId);
      expect(await db.watchTodoLists().first, hasLength(1));
    });

    test('lists keep drag order', () async {
      final a = await db.createTodoList(name: 'A');
      final b = await db.createTodoList(name: 'B');
      final c = await db.createTodoList(name: 'C');
      await db.moveTodoList(c, belowId: a);
      expect((await db.watchTodoLists().first).map((l) => l.listId), <String>[
        c,
        a,
        b,
      ]);
    });

    test('clearing completed todos returns them for undo', () async {
      final a = await db.createTodo(const TodoInput(title: 'A'));
      await db.createTodo(const TodoInput(title: 'B'));
      await db.completeTodo(a);
      final removed = await db.deleteCompletedTodos();
      expect(removed.single.todoId, a);
      expect(await db.watchCompletedTodos().first, isEmpty);
      await db.restoreTodos(removed);
      expect(await db.watchCompletedTodos().first, hasLength(1));
    });

    test('hard-deleting a diary clears todo links', () async {
      final diaryId = await db.createDiary(
        title: '日记',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
      );
      final todo = await db.createTodo(
        TodoInput(title: '跟进', linkedDiaryId: diaryId),
      );
      expect(await db.watchTodosLinkedToDiary(diaryId).first, hasLength(1));
      await db.hardDeleteDiary(diaryId);
      expect((await db.getTodo(todo))!.linkedDiaryId, isNull);
    });
  });

  group('schema v19 migration', () {
    Future<File> v18DatabaseFile({required bool keepTodoTables}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v19_todos');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v18.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        if (keepTodoTables) {
          await original.createTodo(const TodoInput(title: '降级前写的'));
        }
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (!keepTodoTables) {
        legacy.execute('DROP TABLE todos');
        legacy.execute('DROP TABLE todo_lists');
      }
      legacy.execute('PRAGMA user_version = 18');
      legacy.close();
      return file;
    }

    test('v18 upgrade creates the tables and keeps the diaries', () async {
      final file = await v18DatabaseFile(keepTodoTables: false);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final diary = await migrated.select(migrated.diaries).getSingle();
        expect(diary.title, '升级前的日记');
        await migrated.createTodo(const TodoInput(title: '新的'));
        expect(await migrated.watchOpenTodos().first, hasLength(1));
      } finally {
        await migrated.close();
      }
    });

    test('upgrading over tables a downgrade left keeps their rows', () async {
      final file = await v18DatabaseFile(keepTodoTables: true);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final rows = await migrated.select(migrated.todos).get();
        expect(rows.single.title, '降级前写的');
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), migrated.schemaVersion);
      } finally {
        await migrated.close();
      }
    });
  });
}
