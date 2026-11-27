import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/controllers/todo_reorder.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/models/todo_view.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_groups.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_list_entries.dart';
import 'package:node_diary/ui/todos/widgets/todo_group_header.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';

import 'todos_page_harness.dart';

/// 清单分区的界面：清单视图按分区分组（未分区在最上）、点标题折叠、末尾
/// “添加分区”、标题菜单删除（待办回到未分区，可撤销）、智能视图行上写
/// “清单 · 分区”，以及拖过分区时本地先按新分区排、库里跟上才撤掉。
void main() {
  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  late String listId;
  late String design;

  Future<void> seed(AppDatabase db) async {
    listId = await db.createTodoList(name: '装修');
    design = (await db.addTodoSection(listId, '设计'))!;
    await db.addTodoSection(listId, '采购');
    await db.createTodo(TodoInput(title: '量尺寸', listId: listId));
    await db.createTodo(
      TodoInput(title: '画平面图', listId: listId, sectionId: design),
    );
  }

  List<String> headers(WidgetTester tester) => tester
      .widgetList<TodoGroupHeader>(find.byType(TodoGroupHeader))
      .map((header) => header.group.section?.name ?? header.group.kind.name)
      .toList();

  testWidgets('a list view groups rows by section and folds a section', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      height: 1200,
      seed: (db) async {
        await seed(db);
      },
      todoSettings: const TodoSettings(defaultViewKey: 'today'),
    );
    // 换到这个清单（默认视图键里还不知道 id）。
    await tester.tap(find.byIcon(FontAwesomeIcons.angleDown.data).first);
    await settle(tester);
    await tester.tap(find.text('装修').last);
    await settle(tester);

    expect(headers(tester), containsAllInOrder(<String>['设计', '采购']));
    expect(openTodoTitles(tester), <String>['量尺寸', '画平面图']);
    final l10n = todoL10n(tester);
    expect(find.text(l10n.todoSectionAdd), findsOneWidget);

    // 点“设计”折起来：行收起、标题留着。
    await tester.tap(find.widgetWithText(TodoGroupHeader, '设计'));
    await settle(tester);
    expect(find.widgetWithText(TodoTile, '画平面图'), findsNothing);
    expect(find.widgetWithText(TodoGroupHeader, '设计'), findsOneWidget);
    await tester.tap(find.widgetWithText(TodoGroupHeader, '设计'));
    await settle(tester);
    expect(find.widgetWithText(TodoTile, '画平面图'), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('deleting a section moves its to-dos out and can be undone', (
    tester,
  ) async {
    final db = await pumpTodosPage(tester, height: 1200, seed: seed);
    await tester.tap(find.byIcon(FontAwesomeIcons.angleDown.data).first);
    await settle(tester);
    await tester.tap(find.text('装修').last);
    await settle(tester);
    final l10n = todoL10n(tester);

    await tester.tap(find.byTooltip(l10n.todoSectionActions).first);
    await settle(tester);
    await tester.tap(find.text(l10n.todoSectionDelete));
    await settle(tester);
    expect(find.text(l10n.todoSectionDeleteTitle('设计')), findsOneWidget);
    await tester.tap(find.text(l10n.commonDelete).last);
    await settle(tester);
    expect(headers(tester), isNot(contains('设计')));
    final row = await todoRowTitled(tester, db, '画平面图');
    expect(TodoSections.idOfTodo(row.metadata), isNull);

    await tester.tap(find.text(l10n.commonUndo));
    await settle(tester);
    expect(headers(tester), contains('设计'));
    final back = await todoRowTitled(tester, db, '画平面图');
    expect(TodoSections.idOfTodo(back.metadata), design);
    await unmountTodos(tester);
  });

  testWidgets('smart views write the list and section on the row', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: seed,
    );
    expect(find.text('装修 · 设计'), findsOneWidget);
    await unmountTodos(tester);
  });

  test('a drag across sections holds the new section until it lands', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db);
    var open = await db.getOpenTodos();
    final reorder = TodoReorder(onChanged: () {});
    // 量尺寸（未分区）拖进“设计”，先后不变：只看顺序会过早撤掉。
    final at = open.indexWhere((row) => row.title == '量尺寸');
    final moved = open[at].todoId;
    reorder.drop(db, open, at, at, readOpen: () => open, section: (id: design));
    expect(reorder.sections, <String, String?>{moved: design});
    reorder.settle(open);
    expect(reorder.sections, isNotEmpty, reason: '库里的分区还没跟上');
    // 写完（同一事务里写了顺序与分区）后库里跟上，撤掉本地的。
    await Future<void>.delayed(const Duration(milliseconds: 50));
    open = await db.getOpenTodos();
    final row = open.firstWhere((row) => row.todoId == moved);
    expect(TodoSections.idOfTodo(row.metadata), design);
    reorder.settle(open);
    expect(reorder.sections, isEmpty);
    reorder.dispose();
  });

  test('unknown sections count as no section; empty ones keep a header', () {
    final at = DateTime(2026, 11, 28);
    TodoRow row(String id, String metadata) => TodoRow(
      id: id.hashCode,
      todoId: id,
      listId: 'l',
      title: id,
      note: '',
      priority: 0,
      reminders: '[]',
      steps: '[]',
      sortOrder: 0,
      metadata: metadata,
      createdAt: at,
      updatedAt: at,
    );
    const sections = <TodoSection>[
      TodoSection(id: 's1', name: '设计'),
      TodoSection(id: 's2', name: '采购'),
    ];
    final groups = buildTodoGroups(
      view: const TodoView.list('l'),
      open: <TodoRow>[
        row('a', '{"sectionId":"s1"}'),
        row('b', '{"sectionId":"gone"}'),
        row('c', '{}'),
      ],
      completed: const <TodoRow>[],
      listOrder: const <String>['l'],
      sort: TodoSortMode.manual,
      today: at,
      showCompleted: false,
      sections: sections,
    );
    expect(groups.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.plain,
      TodoGroupKind.section,
      TodoGroupKind.section,
    ]);
    expect(groups.first.rows.map((r) => r.todoId), <String>['b', 'c']);
    expect(groups[1].rows.single.todoId, 'a');
    expect(groups[2].rows, isEmpty);
    // 折起来的分区只出标题。
    final entries = buildTodoListEntries(
      groups,
      collapsed: <String>{groups[1].key},
    );
    expect(entries.whereType<TodoRowEntry>().map((e) => e.row.todoId), <String>[
      'b',
      'c',
    ]);
  });
}
