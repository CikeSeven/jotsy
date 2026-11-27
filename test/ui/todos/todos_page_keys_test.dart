import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_complete_motion.dart';
import 'package:node_diary/ui/todos/widgets/todo_hover_actions.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:node_diary/ui/todos/widgets/todo_view_switcher.dart';

import 'todos_page_harness.dart';

/// 桌面键盘流：方向键移动焦点行、空格勾选、回车打开详情、Delete 删除、
/// Alt + 数字切视图、Esc 逐层退出，以及 Shift 连选与悬停快捷按钮。
void main() {
  /// 桌面平台下跑 [body]：平台覆盖要在测试体里复位（收尾检查先于 tearDown）。
  void desktopTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> pump(WidgetTester tester) => pumpTodosPage(
    tester,
    width: 1280,
    height: 900,
    seed: (db) async {
      for (final title in <String>['丙', '乙', '甲']) {
        await db.createTodo(TodoInput(title: title, dueDate: todoToday));
      }
    },
  );

  String? highlighted(WidgetTester tester) {
    for (final tile in tester.widgetList<TodoTile>(find.byType(TodoTile))) {
      if (tile.selected) return tile.row.title;
    }
    return null;
  }

  desktopTest('arrows move the focus row; space, enter and delete act on it', (
    tester,
  ) async {
    final db = await pump(tester);
    expect(highlighted(tester), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final first = highlighted(tester);
    expect(first, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final second = highlighted(tester)!;
    expect(second, isNot(first));

    // 回车：宽窗口在详情栏里打开这一条。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byType(TodoDetailBody), findsOneWidget);
    // Esc：先关详情栏。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(TodoDetailBody), findsNothing);

    // 空格：勾选（收起后写库）。
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(TodoCompleteMotion.collapse);
    await settle(tester);
    expect((await todoRowTitled(tester, db, second)).completedAt, isNotNull);

    // Delete：删掉焦点行（它离开后，焦点接到补上来的那一行）。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    final target = highlighted(tester)!;
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    final open = await tester.runAsync(db.getOpenTodos);
    expect(open!.map((r) => r.title), isNot(contains(target)));
    await unmountTodos(tester);
  });

  desktopTest('alt + digit switches smart views', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    final grid = tester.widget<TodoSmartViewGrid>(
      find.byType(TodoSmartViewGrid),
    );
    expect(grid.view.key, 'planned');
    await unmountTodos(tester);
  });

  desktopTest('shift click selects a range; rows show hover actions', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(TodoHoverActions), findsNWidgets(3));
    final titles = tester
        .widgetList<TodoTile>(find.byType(TodoTile))
        .map((t) => t.row.title)
        .toList();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text(titles.first));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text(titles.last));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle(tester);
    final selected = tester
        .widgetList<TodoTile>(find.byType(TodoTile))
        .where((t) => t.selectionMode && t.selected);
    expect(selected, hasLength(3));
    await unmountTodos(tester);
  });
}
