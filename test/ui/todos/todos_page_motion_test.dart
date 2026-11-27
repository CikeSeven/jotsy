import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/widgets/todo_labels.dart';
import 'package:node_diary/ui/todos/widgets/todo_view_switcher.dart';
import 'package:node_diary/ui/widgets/reorder_handle.dart';

import 'todos_page_harness.dart';

/// 待办页的动效：数据变化时各项滑到新位置（跨组也一样）、移出视图的行原地
/// 收起、已完成组整块折叠、切换视图先退场再错峰入场、拖动松手不弹回、
/// 跨过零点自动翻到新的一天，以及减少动画时直接到位。
void main() {
  double topOf(WidgetTester tester, String title) =>
      tester.getTopLeft(find.text(title)).dy;

  /// 让 drift 把这次写入推送过来（真实异步里要几轮），每轮推一帧但不推进
  /// 时间：新数据排好版、各项从原位置画起，弹簧还没走。
  Future<void> deliver(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  /// 等数据与动效都落定。分成多帧推：刚起步的弹簧从下一帧才开始计时，
  /// 一次推一大段时间只会停在起点。
  Future<void> settleMotion(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a todo moved to another day slides into its new group', (
    tester,
  ) async {
    final tomorrow = todoToday.add(const Duration(days: 1));
    late String moving;
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'planned'),
      seed: (db) async {
        moving = await db.createTodo(
          TodoInput(title: '今天写完', dueDate: todoToday),
        );
        await db.createTodo(TodoInput(title: '明天再说', dueDate: tomorrow));
      },
    );
    final before = topOf(tester, '今天写完');
    expect(before, lessThan(topOf(tester, '明天再说')));

    await tester.runAsync(
      () => db.setTodoDue(moving, date: tomorrow.add(const Duration(days: 1))),
    );
    await deliver(tester);
    // 新数据到了（多出后天那一组），但这一行仍从原位置画起，不是一下
    // 跳过去。
    final l10n = todoL10n(tester);
    final later = tomorrow.add(const Duration(days: 1));
    expect(
      find.text(
        l10n.todoHeroDate(
          TodoLabels.weekdayName(l10n, later.weekday, short: false),
          l10n.formatMonthDay(later),
        ),
      ),
      findsOneWidget,
    );
    expect(topOf(tester, '今天写完'), moreOrLessEquals(before, epsilon: 1));

    await tester.pump(const Duration(milliseconds: 120));
    final mid = topOf(tester, '今天写完');
    expect(mid, greaterThan(before));

    await settleMotion(tester);
    final after = topOf(tester, '今天写完');
    expect(after, greaterThan(mid));
    expect(after, greaterThan(topOf(tester, '明天再说')));
    await unmountTodos(tester);
  });

  testWidgets('a row that leaves the view folds away where it was', (
    tester,
  ) async {
    late String lowered;
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'important'),
      seed: (db) async {
        lowered = await db.createTodo(
          const TodoInput(title: '降级的', priority: TodoPriority.high),
        );
        await db.createTodo(
          const TodoInput(title: '仍重要', priority: TodoPriority.high),
        );
      },
    );
    await tester.runAsync(() => db.setTodoPriority(lowered, TodoPriority.none));
    await deliver(tester);
    // 数据里已经没有它了，但它先留在原处收起。
    expect(find.text('降级的'), findsOneWidget);

    await settleMotion(tester);
    expect(find.text('降级的'), findsNothing);
    expect(openTodoTitles(tester), <String>['仍重要']);
    await unmountTodos(tester);
  });

  testWidgets('the completed group folds and unfolds as a block', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '还没做', dueDate: todoToday));
        final done = await db.createTodo(
          TodoInput(title: '做完了', dueDate: todoToday),
        );
        await db.completeTodo(done);
      },
    );
    final l10n = todoL10n(tester);
    expect(find.text('做完了'), findsOneWidget);

    await tester.tap(find.text(l10n.todoGroupCompletedToday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 收起途中这一行还在，只是被裁掉一部分。
    expect(find.text('做完了'), findsOneWidget);

    await settleMotion(tester);
    expect(find.text('做完了'), findsNothing);

    await tester.tap(find.text(l10n.todoGroupCompletedToday));
    await settleMotion(tester);
    expect(find.text('做完了'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmountTodos(tester);
  });

  testWidgets('switching views lets the old list leave before the new enters', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      seed: (db) async {
        final list = await db.createTodoList(name: '工作');
        await db.createTodo(TodoInput(title: '开会', listId: list));
        await db.createTodo(TodoInput(title: '买菜', dueDate: todoToday));
      },
    );
    await tester.tap(find.byIcon(FontAwesomeIcons.angleDown.data).first);
    await settleTodos(tester);
    await tester.tap(find.widgetWithText(TodoListNavRow, '工作'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 旧视图正在退场：还没换成新视图。
    expect(openTodoTitles(tester), <String>['买菜']);

    await settleMotion(tester);
    expect(openTodoTitles(tester), <String>['开会']);
    expect(tester.takeException(), isNull);
    await unmountTodos(tester);
  });

  testWidgets('reduced motion swaps views at once', (tester) async {
    await pumpTodosPage(
      tester,
      disableAnimations: true,
      seed: (db) async {
        final list = await db.createTodoList(name: '工作');
        await db.createTodo(TodoInput(title: '开会', listId: list));
        await db.createTodo(TodoInput(title: '买菜', dueDate: todoToday));
      },
    );
    await tester.tap(find.byIcon(FontAwesomeIcons.angleDown.data).first);
    await settleTodos(tester);
    await tester.tap(find.widgetWithText(TodoListNavRow, '工作'));
    await tester.pump();
    await tester.pump();
    expect(openTodoTitles(tester), <String>['开会']);
    await unmountTodos(tester);
  });

  testWidgets('a dropped row stays where it was dropped while it is saved', (
    tester,
  ) async {
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(
        defaultViewKey: 'inbox',
        sort: TodoSortMode.manual,
      ),
      seed: (db) async {
        // 手动排序新建的在前：显示为 丙、乙、甲。
        await db.createTodo(const TodoInput(title: '甲'));
        await db.createTodo(const TodoInput(title: '乙'));
        await db.createTodo(const TodoInput(title: '丙'));
      },
    );
    expect(openTodoTitles(tester), <String>['丙', '乙', '甲']);

    final handle = find.byType(ReorderHandle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 库里还没推送回来，列表已按松手时的顺序排，不弹回原处。
    expect(openTodoTitles(tester), <String>['乙', '甲', '丙']);

    await settleMotion(tester);
    expect(openTodoTitles(tester), <String>['乙', '甲', '丙']);
    final open = await tester.runAsync(db.getOpenTodos);
    expect(open!.map((row) => row.title), <String>['乙', '甲', '丙']);
    await unmountTodos(tester);
  });

  testWidgets('the today view rolls over at midnight while it stays open', (
    tester,
  ) async {
    final today = todoToday;
    final tomorrow = today.add(const Duration(days: 1));
    var now = today.add(const Duration(hours: 23, minutes: 59, seconds: 50));
    await pumpTodosPage(
      tester,
      now: () => now,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '明天的', dueDate: tomorrow));
      },
    );
    expect(openTodoTitles(tester), isEmpty);

    now = tomorrow.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 12));
    await settleMotion(tester);
    expect(openTodoTitles(tester), <String>['明天的']);
    await unmountTodos(tester);
  });
}
