import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_quick_add_sheet.dart';
import 'package:node_diary/ui/todos/widgets/todo_tag_nav.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';

import 'todos_page_harness.dart';

/// 待办标签的界面：行上的 `@标签`、视图面板里的标签组与标签视图、在标签视图
/// 里新建自动带上、详情的标签面板（新建 / 取消）、快速新建识别 `@标签`、
/// 多选“加标签”与撤销。
void main() {
  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<List<String>> tagsOf(
    WidgetTester tester,
    AppDatabase db,
    String title,
  ) async => TodoTags.ofMetadataText(
    (await todoRowTitled(tester, db, title)).metadata,
  );

  Future<void> seed(AppDatabase db) async {
    await db.createTodo(const TodoInput(title: '拖地', tags: <String>['家务']));
    await db.createTodo(
      const TodoInput(title: '买菜', tags: <String>['家务', '采购']),
    );
    await db.createTodo(const TodoInput(title: '写周报'));
  }

  testWidgets('the view sheet lists tags and opens a tag view', (tester) async {
    await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: seed,
    );
    // 行上是 `@标签` 微胶囊。
    expect(find.text('@家务'), findsNWidgets(2));
    expect(find.text('@采购'), findsOneWidget);

    await tester.tap(find.byIcon(FontAwesomeIcons.angleDown.data).first);
    await settle(tester);
    expect(find.widgetWithText(TodoTagNavRow, '家务'), findsOneWidget);
    await tester.tap(find.widgetWithText(TodoTagNavRow, '家务'));
    await settle(tester);
    expect(openTodoTitles(tester), unorderedEquals(<String>['拖地', '买菜']));
    await unmountTodos(tester);
  });

  testWidgets('to-dos added in a tag view get the tag', (tester) async {
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'tag:家务'),
      seed: seed,
    );
    final l10n = todoL10n(tester);
    expect(openTodoTitles(tester), unorderedEquals(<String>['拖地', '买菜']));

    await tester.tap(find.text(l10n.todoInlineAddHint));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '洗碗 @厨房');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(await tagsOf(tester, db, '洗碗'), <String>['家务', '厨房']);
    expect(openTodoTitles(tester), contains('洗碗'));
    await unmountTodos(tester);
  });

  testWidgets('the detail picker creates and removes tags', (tester) async {
    final db = await pumpTodosPage(
      tester,
      height: 1200,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: seed,
    );
    final l10n = todoL10n(tester);
    await tester.tap(find.text('写周报'));
    await settle(tester);
    expect(find.byType(TodoDetailBody), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TodoDetailBody),
        matching: find.text(l10n.todoFieldTags),
      ),
    );
    await settle(tester);
    // 最近用过的待办标签都在；输入新名字出现“新建”。
    expect(find.text('家务'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, '工作');
    await settle(tester);
    await tester.tap(find.text(l10n.todoTagCreate('工作')));
    await settle(tester);
    expect(await tagsOf(tester, db, '写周报'), <String>['工作']);

    await tester.tap(find.text('家务').last);
    await settle(tester);
    expect(await tagsOf(tester, db, '写周报'), <String>['工作', '家务']);
    await tester.tap(find.text('工作').last);
    await settle(tester);
    expect(await tagsOf(tester, db, '写周报'), <String>['家务']);
    await unmountTodos(tester);
  });

  testWidgets('quick add recognizes @tags and saves them', (tester) async {
    final db = await pumpTodosPage(tester, width: 900, height: 1000);
    showTodoQuickAddSheet(tester.element(find.byType(TodosPage))).ignore();
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      '交水电费 @家务 发给 a@b.com',
    );
    await settle(tester);
    // 标签按钮写出识别到的标签。
    expect(find.text('@家务'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    // 去掉标签后两侧都是中文的接缝直接相连；邮箱原样留在标题里。
    final row = await todoRowTitled(tester, db, '交水电费发给 a@b.com');
    expect(TodoTags.ofMetadataText(row.metadata), <String>['家务']);
    await unmountTodos(tester);
  });

  testWidgets('multi-select adds a tag and undo takes it back', (tester) async {
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: seed,
    );
    final l10n = todoL10n(tester);
    await tester.longPress(find.widgetWithText(TodoTile, '写周报'));
    await settle(tester);
    await tester.tap(find.text(l10n.todoMore).last);
    await settle(tester);
    await tester.tap(find.text(l10n.todoBatchAddTag));
    await settle(tester);
    await tester.tap(find.text('采购').last);
    await settle(tester);
    expect(await tagsOf(tester, db, '写周报'), <String>['采购']);
    expect(find.text(l10n.todoBatchTaggedNotice(1, '采购')), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await settle(tester);
    expect(await tagsOf(tester, db, '写周报'), isEmpty);
    await unmountTodos(tester);
  });
}
