import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 清单分区：定义存在清单的 `metadata.sections`、所属存在待办的
/// `metadata.sectionId`；增删改挪、批量移入与撤销、删除分区两种方式及撤销、
/// 拖动跨分区一次写完、完成副本与复制带上分区。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<TodoSection>> sectionsOf(String listId) async =>
      TodoSections.ofList((await db.getTodoList(listId))!.metadata);
  Future<String?> sectionOf(String todoId) async =>
      TodoSections.idOfTodo((await db.getTodo(todoId))!.metadata);

  test('add, rename, move and keep other list metadata', () async {
    final list = await db.createTodoList(name: '装修');
    final a = await db.addTodoSection(list, '  设计 ');
    final b = await db.addTodoSection(list, '采购');
    expect(await db.addTodoSection(list, '   '), isNull);
    expect((await sectionsOf(list)).map((s) => s.name), <String>['设计', '采购']);

    await db.renameTodoSection(list, a!, '方案');
    await db.moveTodoSection(list, b!, -1);
    expect((await sectionsOf(list)).map((s) => s.name), <String>['采购', '方案']);
    // 挪到头为止。
    await db.moveTodoSection(list, b, -1);
    expect((await sectionsOf(list)).first.id, b);
  });

  test('sections are listed in order, bad entries dropped', () {
    final sections = TodoSections.fromMetadata(<String, Object?>{
      'sections': <Object?>[
        <String, Object?>{'id': 's1', 'name': '一'},
        <String, Object?>{'id': 's1', 'name': '重复 id'},
        <String, Object?>{'id': '', 'name': '空 id'},
        <String, Object?>{'id': 's2', 'name': '  '},
        'x',
        <String, Object?>{'id': 's3', 'name': '三'},
      ],
    });
    expect(sections.map((s) => s.id), <String>['s1', 's3']);
  });

  test('batch move into a section and undo', () async {
    final list = await db.createTodoList(name: '装修');
    final s = (await db.addTodoSection(list, '设计'))!;
    final a = await db.createTodo(TodoInput(title: 'A', listId: list));
    final b = await db.createTodo(
      TodoInput(title: 'B', listId: list, sectionId: s),
    );
    final before = await db.setTodosSection(<String>[a, b], s);
    expect(before.map((row) => row.todoId), <String>[a]);
    expect(await sectionOf(a), s);
    await db.restoreTodoFields(before, TodoBatchField.section);
    expect(await sectionOf(a), isNull);
    expect(await sectionOf(b), s);
  });

  test(
    'deleting a section moves or deletes its to-dos, both undoable',
    () async {
      final list = await db.createTodoList(name: '装修');
      final s = (await db.addTodoSection(list, '设计'))!;
      final a = await db.createTodo(
        TodoInput(title: 'A', listId: list, sectionId: s),
      );
      final done = await db.createTodo(
        TodoInput(title: 'B', listId: list, sectionId: s),
      );
      await db.completeTodo(done);
      expect(await db.countTodosInSection(list, s), 2);

      final moved = await db.deleteTodoSection(list, s, withTodos: false);
      expect(await sectionsOf(list), isEmpty);
      expect(await sectionOf(a), isNull);
      await db.restoreTodoSection(moved!);
      expect((await sectionsOf(list)).single.id, s);
      expect(await sectionOf(a), s);

      final deleted = await db.deleteTodoSection(list, s, withTodos: true);
      expect(await db.getTodo(a), isNull);
      expect(await db.getTodo(done), isNull);
      await db.restoreTodoSection(deleted!);
      expect(await sectionOf(a), s);
      expect((await db.getTodo(done))!.completedAt, isNotNull);
    },
  );

  test('dragging across sections writes order and section at once', () async {
    final list = await db.createTodoList(name: '装修');
    final s = (await db.addTodoSection(list, '设计'))!;
    final a = await db.createTodo(TodoInput(title: 'A', listId: list));
    final b = await db.createTodo(
      TodoInput(title: 'B', listId: list, sectionId: s),
    );
    // 新建的排在最前：现在是 B、A。把 A 拖到 B 后面并进“设计”。
    await db.moveTodoToSection(a, s, aboveId: b);
    final rows = await db.getOpenTodos();
    expect(rows.map((row) => row.title), <String>['B', 'A']);
    expect(await sectionOf(a), s);
  });

  test('repeat copies, duplicates and step to-dos keep the section', () async {
    final list = await db.createTodoList(name: '运动');
    final s = (await db.addTodoSection(list, '晨间'))!;
    final id = await db.createTodo(
      TodoInput(
        title: '晨跑',
        listId: list,
        sectionId: s,
        dueDate: DateTime(2026, 11, 10),
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.daily,
          anchor: DateTime(2026, 11, 10),
        ),
        steps: const <TodoStep>[TodoStep(id: 's1', title: '拉伸')],
      ),
    );
    final copy = (await db.completeTodo(id, now: DateTime(2026, 11, 10)))!;
    expect(await sectionOf(copy.copyId!), s);
    final step = await db.convertTodoStepToTodo(id, 's1');
    expect(await sectionOf(step!), s);
    // 收集箱里的待办不带分区。
    final inbox = await db.createTodo(TodoInput(title: '收集箱', sectionId: s));
    expect(await sectionOf(inbox), isNull);
  });
}
