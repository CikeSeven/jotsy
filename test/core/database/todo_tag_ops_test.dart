import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 待办标签：规整口径、只读改 `metadata.tags`、完成副本与复制继承、批量加
/// 标签 / 改名合并 / 删除及撤销、用量统计，以及与日记标签互不相通。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<TodoRow> rowOf(String id) async => (await db.getTodo(id))!;
  Future<List<String>> tagsOf(String id) async =>
      TodoTags.fromMetadata(decodeTodoMetadata((await rowOf(id)).metadata));

  group('normalize', () {
    test('trims marks, joins spaces, dedupes ignoring case and caps', () {
      expect(TodoTags.normalize('  @家务 '), '家务');
      expect(TodoTags.normalize('＃deep work'), 'deep_work');
      expect(TodoTags.normalize('@ '), isNull);
      expect(TodoTags.normalize('a' * 40)!.length, TodoTags.maxLength);
      // 截断不切开代理对。
      final emoji = '${'a' * (TodoTags.maxLength - 1)}😀';
      expect(TodoTags.normalize(emoji), 'a' * (TodoTags.maxLength - 1));
      expect(
        TodoTags.normalizeAll(<String>['Work', 'work', ' ', '家']),
        <String>['Work', '家'],
      );
      expect(
        TodoTags.normalizeAll(<String>[for (var i = 0; i < 20; i++) 't$i']),
        hasLength(TodoTags.maxPerTodo),
      );
    });

    test('reads only string entries from metadata', () {
      expect(
        TodoTags.fromMetadata(<String, Object?>{
          'tags': <Object?>['a', 3, null, ' b '],
        }),
        <String>['a', 'b'],
      );
      expect(TodoTags.fromMetadata(<String, Object?>{'tags': 'a'}), isEmpty);
    });
  });

  test('setting tags keeps the other metadata keys', () async {
    final id = await db.createTodo(
      TodoInput(
        title: '交报告',
        dueDate: DateTime(2026, 11, 10),
        sourceDiaryId: 'diary-1',
        tags: const <String>['工作'],
      ),
    );
    await db.setTodoDue(id, date: DateTime(2026, 11, 12));
    await db.setTodoTags(id, <String>['工作', '@紧急', '工作']);
    final map = decodeTodoMetadata((await rowOf(id)).metadata);
    expect(map['tags'], <String>['工作', '紧急']);
    expect(map[TodoMetadataKeys.sourceDiaryId], 'diary-1');
    expect(map[TodoMetadataKeys.postponeCount], 1);

    // 一样的标签不写（不刷新 updated_at）；清空时去掉这个键。
    final before = (await rowOf(id)).updatedAt;
    await db.setTodoTags(id, <String>['工作', '紧急']);
    expect((await rowOf(id)).updatedAt, before);
    await db.setTodoTags(id, const <String>[]);
    expect(
      decodeTodoMetadata((await rowOf(id)).metadata),
      isNot(contains('tags')),
    );
  });

  test('completed repeat copies, duplicates and steps keep the tags', () async {
    final id = await db.createTodo(
      TodoInput(
        title: '晨跑',
        dueDate: DateTime(2026, 11, 10),
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.daily,
          anchor: DateTime(2026, 11, 10),
        ),
        steps: const <TodoStep>[TodoStep(id: 's1', title: '拉伸')],
        tags: const <String>['健康'],
      ),
    );
    final completion = await db.completeTodo(id, now: DateTime(2026, 11, 10));
    final copyId = completion!.copyId!;
    expect(await tagsOf(copyId), <String>['健康']);
    // 完成记录仍按 repeatOf 找得到。
    final occurrences = await db.watchTodoOccurrences(id).first;
    expect(occurrences.map((row) => row.todoId), <String>[copyId]);

    final stepTodo = await db.convertTodoStepToTodo(id, 's1');
    expect(await tagsOf(stepTodo!), <String>['健康']);
  });

  test('batch add, rename into an existing tag, delete and undo', () async {
    final a = await db.createTodo(
      const TodoInput(title: 'A', tags: <String>['Work']),
    );
    final b = await db.createTodo(
      const TodoInput(title: 'B', tags: <String>['工作', 'work']),
    );
    final c = await db.createTodo(const TodoInput(title: 'C'));

    final added = await db.addTodosTag(<String>[a, b, c], '工作');
    expect(added.map((row) => row.todoId).toSet(), <String>{a, c});
    expect(await tagsOf(a), <String>['Work', '工作']);

    // 合并：work → 工作，已经有“工作”的只留一个。
    final renamed = await db.renameTodoTag('WORK', '工作');
    expect(renamed.map((row) => row.todoId).toSet(), <String>{a, b});
    expect(await tagsOf(a), <String>['工作']);
    expect(await tagsOf(b), <String>['工作']);
    await db.restoreTodoFields(renamed, TodoBatchField.tags);
    expect(await tagsOf(a), <String>['Work', '工作']);
    expect(await tagsOf(b), <String>['工作', 'work']);

    final deleted = await db.deleteTodoTag('工作');
    expect(deleted, hasLength(3));
    expect(await tagsOf(c), isEmpty);
    expect(await tagsOf(a), <String>['Work']);
    await db.restoreTodoFields(deleted, TodoBatchField.tags);
    expect(await tagsOf(c), <String>['工作']);
  });

  test(
    'usage counts open and done rows and never touches diary tags',
    () async {
      final a = await db.createTodo(
        const TodoInput(title: 'A', tags: <String>['家务']),
      );
      await db.createTodo(
        const TodoInput(title: 'B', tags: <String>['家务', '采购']),
      );
      await db.completeTodo(a);
      final usages = await db.watchTodoTags().first;
      expect(usages.map((u) => u.name), <String>['家务', '采购']);
      expect(usages.first.openCount, 1);
      expect(usages.first.totalCount, 2);

      // 日记标签表里什么都没有，待办标签也不会出现在日记标签里。
      expect(await db.select(db.tags).get(), isEmpty);
      expect(jsonEncode(usages.map((u) => u.name).toList()), contains('家务'));
    },
  );
}
