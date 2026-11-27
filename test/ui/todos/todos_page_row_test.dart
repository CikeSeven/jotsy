import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/sections/todos_page_frame.dart';
import 'package:node_diary/ui/todos/widgets/todo_complete_motion.dart';
import 'package:node_diary/ui/todos/widgets/todo_labels.dart';
import 'package:node_diary/ui/todos/widgets/todo_row_drag.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile_check.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile_steps.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile_text.dart';
import 'package:node_diary/ui/todos/widgets/todo_view_switcher.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';
import 'package:node_diary/ui/widgets/todo_check_box.dart';

import 'todos_page_harness.dart';

/// 待办行：勾选三拍、合并撤销、到期倒数、就地展开步骤、左滑改期、今天
/// 清零、多选操作栏的进出与桌面拖到左栏。
void main() {
  Future<void> settleMotion(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 点一行的方框，等勾选三拍与收起都走完、写进库里。
  Future<void> tick(WidgetTester tester, String title) async {
    final tile = find.ancestor(
      of: find.text(title),
      matching: find.byType(TodoTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(TodoCheckBoxVisual)),
    );
    await tester.pump();
    await tester.pump(TodoCompleteMotion.check);
    await tester.pump(TodoCompleteMotion.collapse);
    await settleTodos(tester);
    await settleTodos(tester);
  }

  testWidgets('ticking presses, bounces and strikes before collapsing', (
    tester,
  ) async {
    final db = await pumpTodosPage(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '寄快递', dueDate: todoToday));
      },
    );
    double boxScale() => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(TodoTileCheckButton),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    TodoStrikePainter? strike() {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(TodoTileText),
          matching: find.byType(CustomPaint),
        ),
      );
      return paint.foregroundPainter as TodoStrikePainter?;
    }

    // 按下：方框压小。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TodoCheckBoxVisual)),
    );
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(boxScale(), lessThan(0.95));
    expect(strike(), isNull);

    // 松手：方框弹起、删除线划到一半，还没写库。
    await gesture.up();
    await tester.pump();
    await tester.pump(TodoCompleteMotion.check * 0.4);
    expect(boxScale(), greaterThan(1));
    final mid = strike()!.progress;
    expect(mid, inExclusiveRange(0, 1));
    expect((await todoRowTitled(tester, db, '寄快递')).completedAt, isNull);

    // 停一拍之后收起、写库。
    await tester.pump(TodoCompleteMotion.check * 0.6);
    await tester.pump(TodoCompleteMotion.collapse);
    await settleTodos(tester);
    expect((await todoRowTitled(tester, db, '寄快递')).completedAt, isNotNull);
    await unmountTodos(tester);
  });

  testWidgets('completing in a row merges the undo hints', (tester) async {
    final db = await pumpTodosPage(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '甲', dueDate: todoToday));
        await db.createTodo(TodoInput(title: '乙', dueDate: todoToday));
        await db.createTodo(TodoInput(title: '丙', dueDate: todoToday));
      },
    );
    final l10n = todoL10n(tester);
    await tick(tester, '甲');
    expect(find.text(l10n.todoCompletedNotice), findsOneWidget);
    await tick(tester, '乙');
    await settleMotion(tester);
    expect(find.text(l10n.todoBatchCompleted(2)), findsOneWidget);
    expect(openTodoTitles(tester), <String>['丙']);

    await tester.tap(find.text(l10n.commonUndo));
    await settleMotion(tester);
    final open = await tester.runAsync(db.getOpenTodos);
    expect(open!.map((row) => row.title).toSet(), <String>{'甲', '乙', '丙'});
    await unmountTodos(tester);
  });

  testWidgets('a todo due within the hour counts down by the minute', (
    tester,
  ) async {
    var now = todoToday.add(const Duration(hours: 9));
    await pumpTodosPage(
      tester,
      now: () => now,
      seed: (db) async {
        await db.createTodo(
          TodoInput(title: '开会', dueDate: todoToday, dueMinute: 9 * 60 + 25),
        );
        await db.createTodo(
          TodoInput(title: '晚饭', dueDate: todoToday, dueMinute: 18 * 60),
        );
      },
    );
    final l10n = todoL10n(tester);
    final context = tester.element(find.byType(TodosPage));
    String at(int minute) =>
        TodoLabels.due(context, todoToday, minute, todoToday);
    expect(find.text(l10n.todoDueInMinutes(25)), findsOneWidget);
    // 一小时以外的照旧写时刻。
    expect(find.text(at(18 * 60)), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1, seconds: 2));
    await tester.pump();
    expect(find.text(l10n.todoDueInMinutes(24)), findsOneWidget);

    // 到点后回到时刻的说法。
    now = now.add(const Duration(minutes: 24));
    await tester.pump(const Duration(minutes: 1, seconds: 2));
    await tester.pump();
    expect(find.text(l10n.todoDueInMinutes(1)), findsNothing);
    expect(find.text(at(9 * 60 + 25)), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('the steps pill expands steps in place and ticks one', (
    tester,
  ) async {
    final db = await pumpTodosPage(
      tester,
      seed: (db) async {
        await db.createTodo(
          TodoInput(
            title: '搬家',
            dueDate: todoToday,
            steps: const <TodoStep>[
              TodoStep(id: 's0', title: '打包'),
              TodoStep(id: 's1', title: '叫车'),
            ],
          ),
        );
      },
    );
    final l10n = todoL10n(tester);
    expect(find.byType(TodoTileSteps), findsNothing);
    await tester.tap(find.text(l10n.todoStepsProgress(0, 2)));
    await settleMotion(tester);
    expect(find.text('打包'), findsOneWidget);
    expect(find.text('叫车'), findsOneWidget);

    await tester.tap(find.text('打包'));
    await settleMotion(tester);
    final row = await todoRowTitled(tester, db, '搬家');
    expect(decodeTodoSteps(row.steps).first.done, isTrue);
    // 行没打开详情，步骤还展开着，进度跟着变。
    expect(find.text(l10n.todoStepsProgress(1, 2)), findsOneWidget);
    expect(find.text('叫车'), findsOneWidget);

    await tester.tap(find.text(l10n.todoStepsProgress(1, 2)));
    await settleMotion(tester);
    // 收起到 0 高（留在树里好演下一次展开）。
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byType(TodoTileSteps),
                  matching: find.byType(ListItemPresence),
                )
                .first,
          )
          .height,
      0,
    );
    await unmountTodos(tester);
  });

  testWidgets('swiping left reschedules when set to, and the row stays', (
    tester,
  ) async {
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(swipeLeft: TodoSwipeAction.reschedule),
      seed: (db) async {
        await db.createTodo(TodoInput(title: '理发', dueDate: todoToday));
      },
    );
    final l10n = todoL10n(tester);
    await tester.drag(find.text('理发'), const Offset(-300, 0));
    await settleMotion(tester);
    expect(find.text(l10n.todoDueTomorrow), findsOneWidget);
    await tester.tap(find.text(l10n.todoDueTomorrow));
    await settleMotion(tester);
    final row = await todoRowTitled(tester, db, '理发');
    expect(
      row.dueDate,
      formatAnniversaryDate(todoToday.add(const Duration(days: 1))),
    );
    await unmountTodos(tester);
  });

  testWidgets('clearing today closes the ring into a check once', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpTodosPage(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '跑步', dueDate: todoToday));
      },
    );
    final l10n = todoL10n(tester);
    await settleMotion(tester);
    expect(find.text('0/1'), findsOneWidget);
    await tick(tester, '跑步');
    await settleMotion(tester);
    expect(find.text(l10n.todoHeroAllDone), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is FaIcon && w.icon == FontAwesomeIcons.check.data,
      ),
      findsOneWidget,
    );
    expect(
      haptics.where((String type) => type.contains('mediumImpact')),
      hasLength(1),
    );
    await unmountTodos(tester);
  });

  testWidgets('the selection bar rises, then sinks before leaving', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '甲', dueDate: todoToday));
      },
    );
    final l10n = todoL10n(tester);
    Finder bar() => find.descendant(
      of: find.byType(TodosPageFrame),
      matching: find.text(l10n.todoBatchActionComplete),
    );
    await tester.longPress(find.text('甲'));
    await settleMotion(tester);
    expect(bar(), findsOneWidget);
    final shown = tester.getRect(bar());

    await tester.tap(find.byTooltip(l10n.todoSelectionExit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 还在树里，正往下沉。
    expect(bar(), findsOneWidget);
    expect(tester.getRect(bar()).top, greaterThan(shown.top));
    await settleMotion(tester);
    expect(bar(), findsNothing);
    await unmountTodos(tester);
  });

  testWidgets('desktop rows drag onto a list in the sidebar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      late String listId;
      final db = await pumpTodosPage(
        tester,
        width: 1280,
        seed: (db) async {
          listId = await db.createTodoList(name: '工作');
          await db.createTodo(TodoInput(title: '周报', dueDate: todoToday));
        },
      );
      expect(find.byType(TodoRowDraggable), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('周报')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.widgetWithText(TodoListNavRow, '工作')),
      );
      await tester.pump();
      await gesture.up();
      await settleMotion(tester);
      final row = await todoRowTitled(tester, db, '周报');
      expect(row.listId, listId);
      await unmountTodos(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the strike runs line by line, mirrored for RTL', (tester) async {
    const title = '一个足够长的待办标题会在两行里断开再接着写完';
    Future<RenderObject> pumpText(double strike, TextDirection dir) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: dir,
            child: Center(
              child: SizedBox(
                width: 160,
                child: TodoTileText(
                  title: title,
                  note: null,
                  meta: const <Widget>[],
                  titleStyle: const TextStyle(fontSize: 16),
                  strike: strike,
                  strikeColor: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
      return tester.renderObject(
        find.descendant(
          of: find.byType(TodoTileText),
          matching: find.byType(CustomPaint),
        ),
      );
    }

    expect(
      await pumpText(0.3, TextDirection.ltr),
      paintsExactlyCountTimes(#drawLine, 1),
    );
    expect(
      await pumpText(1, TextDirection.ltr),
      paintsExactlyCountTimes(#drawLine, 2),
    );
    // RTL：从右往左划。
    expect(
      await pumpText(0.3, TextDirection.rtl),
      paints..something((Symbol method, List<dynamic> args) {
        if (method != #drawLine) return false;
        return (args[0] as Offset).dx > (args[1] as Offset).dx;
      }),
    );
  });
}
