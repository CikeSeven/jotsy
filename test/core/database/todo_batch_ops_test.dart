import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<TodoRow> rowOf(String id) async => (await db.getTodo(id))!;

  group('batch complete', () {
    test(
      'completes plain and repeating todos and undo restores both',
      () async {
        final plain = await db.createTodo(const TodoInput(title: '寄快递'));
        final weekly = await db.createTodo(
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
        final done = await db.createTodo(const TodoInput(title: '早就做完了'));
        await db.completeTodo(done);
        final plainBefore = await rowOf(plain);
        final weeklyBefore = await rowOf(weekly);

        final results = await db.completeTodos(<String>[
          plain,
          weekly,
          weekly,
          done,
          'missing',
        ], now: DateTime(2026, 11, 2, 20));

        expect(results.map((r) => r.before.todoId), <String>[
          plain,
          weekly,
        ], reason: '重复的 id 只算一次，已完成与不存在的跳过');
        expect((await rowOf(plain)).completedAt, isNotNull);
        final advanced = results.last;
        expect(advanced.nextDue, DateTime(2026, 11, 9));
        expect(advanced.copyId, todoOccurrenceId(weekly, '2026-11-02'));
        final original = await rowOf(weekly);
        expect(original.completedAt, isNull);
        expect(original.dueDate, '2026-11-09');
        expect(decodeTodoSteps(original.steps).single.done, isFalse);
        expect((await rowOf(advanced.copyId!)).completedAt, isNotNull);

        for (final completion in results.reversed) {
          await db.undoTodoCompletion(completion);
        }
        final plainAfter = await rowOf(plain);
        expect(plainAfter.completedAt, isNull);
        expect(
          plainAfter.copyWith(updatedAt: plainBefore.updatedAt),
          plainBefore,
        );
        final weeklyAfter = await rowOf(weekly);
        expect(
          weeklyAfter.copyWith(updatedAt: weeklyBefore.updatedAt),
          weeklyBefore,
        );
        expect(await db.getTodo(advanced.copyId!), isNull);
      },
    );
  });

  group('batch due', () {
    test(
      'switching to all-day drops timed reminders and keeps on-day ones',
      () async {
        const onDay = TodoReminder.onDay(days: -1, minute: 20 * 60);
        final timed = await db.createTodo(
          TodoInput(
            title: '开会',
            dueDate: DateTime(2026, 11, 10),
            dueMinute: 9 * 60,
            reminders: const <TodoReminder>[
              TodoReminder.beforeDue(0),
              TodoReminder.beforeDue(15),
              onDay,
            ],
          ),
        );
        final noDate = await db.createTodo(
          const TodoInput(title: '没有日期', priority: TodoPriority.high),
        );
        final timedBefore = await rowOf(timed);
        final noDateBefore = await rowOf(noDate);

        final before = await db.setTodosDue(<String>[
          timed,
          noDate,
        ], date: DateTime(2026, 11, 12));

        expect(before.map((r) => r.todoId).toSet(), <String>{timed, noDate});
        final row = await rowOf(timed);
        expect(row.dueDate, '2026-11-12');
        expect(row.dueMinute, isNull);
        expect(decodeTodoReminders(row.reminders), <TodoReminder>[onDay]);
        final other = await rowOf(noDate);
        expect(other.dueDate, '2026-11-12');
        expect(other.priority, TodoPriority.high.index, reason: '只写日期那几列');

        await db.restoreTodoFields(before, TodoBatchField.due);
        final restored = await rowOf(timed);
        expect(
          restored.copyWith(updatedAt: timedBefore.updatedAt),
          timedBefore,
        );
        expect(restored.updatedAt.isBefore(timedBefore.updatedAt), isFalse);
        expect(
          (await rowOf(noDate)).copyWith(updatedAt: noDateBefore.updatedAt),
          noDateBefore,
        );
      },
    );

    test('a timed due keeps every reminder', () async {
      final id = await db.createTodo(
        TodoInput(
          title: '交周报',
          dueDate: DateTime(2026, 11, 10),
          reminders: const <TodoReminder>[TodoReminder.beforeDue(30)],
        ),
      );
      await db.setTodosDue(
        <String>[id],
        date: DateTime(2026, 11, 13),
        minute: 18 * 60,
      );
      final row = await rowOf(id);
      expect(row.dueMinute, 18 * 60);
      expect(decodeTodoReminders(row.reminders), const <TodoReminder>[
        TodoReminder.beforeDue(30),
      ]);
    });

    test(
      'clearing the date drops the repeat and undo brings it back',
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
        final repeatBefore = (await rowOf(id)).repeat;
        final before = await db.setTodosDue(<String>[id]);
        final row = await rowOf(id);
        expect(row.dueDate, isNull);
        expect(row.repeat, isNull);

        await db.restoreTodoFields(before, TodoBatchField.due);
        final restored = await rowOf(id);
        expect(restored.dueDate, '2026-01-31');
        expect(restored.repeat, repeatBefore);
      },
    );

    test('rows already on that date are left untouched', () async {
      final id = await db.createTodo(
        TodoInput(title: '已经是这天', dueDate: DateTime(2026, 11, 12)),
      );
      final untouched = await rowOf(id);
      final before = await db.setTodosDue(<String>[
        id,
      ], date: DateTime(2026, 11, 12));
      expect(before, isEmpty);
      expect(await rowOf(id), untouched);
    });
  });

  group('batch list and priority', () {
    test('moving to a list puts them first and undo writes back', () async {
      final work = await db.createTodoList(name: '工作');
      final existing = await db.createTodo(
        TodoInput(title: '本来就在', listId: work),
      );
      final a = await db.createTodo(const TodoInput(title: 'A'));
      final b = await db.createTodo(const TodoInput(title: 'B'));
      // 收集箱里现在是 B A。
      final aBefore = await rowOf(a);
      final existingBefore = await rowOf(existing);

      final before = await db.setTodosListId(<String>[a, b, existing], work);

      expect(before.map((r) => r.todoId), <String>[
        b,
        a,
      ], reason: '已经在目标清单里的不动');
      expect(await rowOf(existing), existingBefore);
      final inWork = (await db.watchOpenTodos().first)
          .where((r) => r.listId == work)
          .map((r) => r.title);
      expect(inWork, <String>['B', 'A', '本来就在']);

      await db.restoreTodoFields(before, TodoBatchField.list);
      final restored = await rowOf(a);
      expect(restored.listId, isNull);
      expect(restored.sortOrder, aBefore.sortOrder);
      expect(restored.title, aBefore.title);
    });

    test('undoing a move skips rows whose list was deleted', () async {
      final from = await db.createTodoList(name: '旧清单');
      final to = await db.createTodoList(name: '新清单');
      final id = await db.createTodo(TodoInput(title: '搬走的', listId: from));
      final before = await db.setTodosListId(<String>[id], to);
      await db.deleteTodoList(from);

      await db.restoreTodoFields(before, TodoBatchField.list);
      expect((await rowOf(id)).listId, to);
    });

    test('priority changes only touch rows that differ', () async {
      final a = await db.createTodo(const TodoInput(title: 'A'));
      final b = await db.createTodo(
        const TodoInput(title: 'B', priority: TodoPriority.high),
      );
      final bBefore = await rowOf(b);

      final before = await db.setTodosPriority(<String>[
        a,
        b,
      ], TodoPriority.high);

      expect(before.single.todoId, a);
      expect((await rowOf(a)).priority, TodoPriority.high.index);
      expect(await rowOf(b), bBefore);

      await db.restoreTodoFields(before, TodoBatchField.priority);
      expect((await rowOf(a)).priority, TodoPriority.none.index);
    });

    test('restoring skips rows deleted in the meantime', () async {
      final id = await db.createTodo(const TodoInput(title: '删掉了'));
      final before = await db.setTodosPriority(<String>[id], TodoPriority.low);
      await db.deleteTodo(id);
      await db.restoreTodoFields(before, TodoBatchField.priority);
      expect(await db.getTodo(id), isNull);
    });
  });

  group('batch delete', () {
    test('deleted rows come back exactly through restoreTodos', () async {
      final list = await db.createTodoList(name: '工作');
      final a = await db.createTodo(
        TodoInput(
          title: 'A',
          listId: list,
          dueDate: DateTime(2026, 11, 10),
          steps: const <TodoStep>[TodoStep(id: 's', title: '步骤')],
        ),
      );
      final b = await db.createTodo(const TodoInput(title: 'B'));
      final keep = await db.createTodo(const TodoInput(title: '留着'));
      final originals = <TodoRow>[await rowOf(a), await rowOf(b)];

      final removed = await db.deleteTodos(<String>[a, b, 'missing']);

      expect(removed.map((r) => r.todoId).toSet(), <String>{a, b});
      expect(await db.getTodo(a), isNull);
      expect(await db.getTodo(keep), isNotNull);
      await db.restoreTodos(removed);
      expect(await rowOf(a), originals.first);
      expect(await rowOf(b), originals.last);
    });
  });

  group('list progress', () {
    test('counts open and done per list including the inbox', () async {
      final work = await db.createTodoList(name: '工作');
      final empty = await db.createTodoList(name: '空清单');
      final w1 = await db.createTodo(TodoInput(title: 'W1', listId: work));
      await db.createTodo(TodoInput(title: 'W2', listId: work));
      await db.createTodo(TodoInput(title: 'W3', listId: work));
      final i1 = await db.createTodo(const TodoInput(title: 'I1'));
      await db.completeTodos(<String>[w1, i1]);

      final progress = await db.watchTodoListProgress().first;

      expect(progress, <String?, TodoListProgress>{
        work: const TodoListProgress(open: 2, done: 1),
        null: const TodoListProgress(open: 0, done: 1),
      });
      expect(progress.containsKey(empty), isFalse);
      expect(progress[work]!.total, 3);
      expect(progress[work]!.fraction, closeTo(1 / 3, 1e-9));
      expect(progress[null]!.fraction, 1);
      expect(TodoListProgress.empty.fraction, 0);
    });

    test('the stream follows writes', () async {
      final id = await db.createTodo(const TodoInput(title: 'A'));
      final updates = db.watchTodoListProgress();
      expect(await updates.first, <String?, TodoListProgress>{
        null: const TodoListProgress(open: 1, done: 0),
      });
      await db.completeTodo(id);
      expect(await updates.first, <String?, TodoListProgress>{
        null: const TodoListProgress(open: 0, done: 1),
      });
    });
  });

  test('empty batches return without writing', () async {
    final id = await db.createTodo(const TodoInput(title: 'A'));
    final untouched = await rowOf(id);
    expect(await db.completeTodos(const <String>[]), isEmpty);
    expect(
      await db.setTodosDue(const <String>[], date: DateTime(2026)),
      isEmpty,
    );
    expect(await db.setTodosListId(const <String>[], 'x'), isEmpty);
    expect(
      await db.setTodosPriority(const <String>[], TodoPriority.high),
      isEmpty,
    );
    expect(await db.deleteTodos(const <String>[]), isEmpty);
    await db.restoreTodoFields(const <TodoRow>[], TodoBatchField.due);
    expect(await rowOf(id), untouched);
    expect(await db.watchTodoListProgress().first, <String?, TodoListProgress>{
      null: const TodoListProgress(open: 1, done: 0),
    });
  });
}
