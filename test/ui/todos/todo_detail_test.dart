import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_complete_motion.dart';
import 'package:node_diary/ui/todos/widgets/todo_step_row.dart';
import 'package:node_diary/ui/todos/widgets/todo_streak_card.dart';
import 'package:node_diary/ui/todos/widgets/todo_streak_grid.dart';
import 'package:node_diary/ui/widgets/reorder_handle.dart';
import 'package:node_diary/ui/widgets/todo_check_box.dart';

import 'todos_page_harness.dart';

/// 待办详情：步骤（粘贴多行、删除收起、全勾完后顺便完成、转为独立待办）、
/// 备注（清单行转步骤、链接）、坚持记录、推迟次数与大方框的勾选。
void main() {
  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> openDetail(
    WidgetTester tester,
    String title,
    Future<void> Function(AppDatabase db) seed,
  ) async {
    final db = await pumpTodosPage(tester, height: 1200, seed: seed);
    await tester.tap(find.text(title));
    await settle(tester);
    expect(find.byType(TodoDetailBody), findsOneWidget);
    return db;
  }

  Finder addStepField(WidgetTester tester) => find.descendant(
    of: find.byType(TodoDetailBody),
    matching: find.widgetWithText(TextField, todoL10n(tester).todoStepAdd),
  );

  testWidgets('pasted lines become steps; all ticked offers completing', (
    tester,
  ) async {
    final db = await openDetail(tester, '搬家', (db) async {
      await db.createTodo(TodoInput(title: '搬家', dueDate: todoToday));
    });
    final l10n = todoL10n(tester);
    await tester.enterText(addStepField(tester), '打包\n叫车\n');
    await settle(tester);
    var row = await todoRowTitled(tester, db, '搬家');
    expect(decodeTodoSteps(row.steps).map((s) => s.title), <String>[
      '打包',
      '叫车',
    ]);
    // 还没勾完：按钮收着（0 高，点不到）。
    expect(
      find.text(l10n.todoStepsAllDoneComplete).hitTestable(),
      findsNothing,
    );

    for (final title in <String>['打包', '叫车']) {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(TodoStepRow),
          ),
          matching: find.byType(TodoCheckBoxVisual),
        ),
      );
      await settle(tester);
    }
    expect(
      find.text(l10n.todoStepsAllDoneComplete).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.todoStepsAllDoneComplete));
    await settle(tester);
    row = await todoRowTitled(tester, db, '搬家');
    expect(row.completedAt, isNotNull);
    await unmountTodos(tester);
  });

  testWidgets('a step collapses before it is deleted, or becomes a todo', (
    tester,
  ) async {
    final db = await openDetail(tester, '搬家', (db) async {
      await db.createTodo(
        TodoInput(
          title: '搬家',
          dueDate: todoToday,
          steps: const <TodoStep>[
            TodoStep(id: 's0', title: '打包'),
            TodoStep(id: 's1', title: '退押金'),
          ],
        ),
      );
    });
    final l10n = todoL10n(tester);
    Future<void> openMenu(String title) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(TodoStepRow),
          ),
          matching: find.byTooltip(l10n.todoStepActions),
        ),
      );
      await settle(tester);
    }

    await openMenu('打包');
    await tester.tap(find.text(l10n.todoStepDelete));
    await tester.pump();
    // 先原地收起，收起后才写库。
    expect(
      decodeTodoSteps((await todoRowTitled(tester, db, '搬家')).steps),
      hasLength(2),
    );
    await settle(tester);
    expect(
      decodeTodoSteps((await todoRowTitled(tester, db, '搬家')).steps),
      hasLength(1),
    );

    await openMenu('退押金');
    await tester.tap(find.text(l10n.todoStepToTodo));
    await settle(tester);
    expect(
      decodeTodoSteps((await todoRowTitled(tester, db, '搬家')).steps),
      isEmpty,
    );
    expect((await todoRowTitled(tester, db, '退押金')).completedAt, isNull);
    expect(find.text(l10n.todoStepToTodoNotice), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('dragging a step handle reorders the steps', (tester) async {
    final db = await openDetail(tester, '搬家', (db) async {
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
    });
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ReorderHandle).first),
    );
    await tester.pump(kLongPressTimeout);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await settle(tester);
    final row = await todoRowTitled(tester, db, '搬家');
    expect(decodeTodoSteps(row.steps).map((s) => s.title), <String>[
      '叫车',
      '打包',
    ]);
    await unmountTodos(tester);
  });

  testWidgets('note checklist lines turn into steps; links show up', (
    tester,
  ) async {
    final db = await openDetail(tester, '周末', (db) async {
      await db.createTodo(
        TodoInput(
          title: '周末',
          dueDate: todoToday,
          note: '参考 https://example.com/guide\n- [ ] 洗车\n- [x] 加油',
        ),
      );
    });
    final l10n = todoL10n(tester);
    expect(find.text('example.com'), findsOneWidget);
    await tester.tap(find.text(l10n.todoNoteChecklistToSteps(2)));
    await settle(tester);
    final row = await todoRowTitled(tester, db, '周末');
    expect(row.note, '参考 https://example.com/guide');
    expect(
      decodeTodoSteps(row.steps).map((s) => (s.title, s.done)),
      <(String, bool)>[('洗车', false), ('加油', true)],
    );
    expect(find.text(l10n.todoNoteChecklistToSteps(2)), findsNothing);
    await unmountTodos(tester);
  });

  testWidgets('repeating todos show their streak; postpones are counted', (
    tester,
  ) async {
    await openDetail(tester, '浇花', (db) async {
      final id = await db.createTodo(
        TodoInput(
          title: '浇花',
          dueDate: todoToday,
          repeat: TodoRepeatRule(
            frequency: TodoRepeatFrequency.daily,
            anchor: todoToday,
          ),
        ),
      );
      await db.setTodoDue(id, date: todoToday.add(const Duration(days: 1)));
      await db.setTodoDue(id, date: todoToday);
    });
    final l10n = todoL10n(tester);
    // 改到明天又改回今天（详情打开前写的），只算一次推迟。
    expect(find.byType(TodoStreakCard), findsOneWidget);
    expect(find.text(l10n.todoStreakSummary(0, 0)), findsOneWidget);
    expect(find.text(l10n.todoPostponedCount(1)), findsOneWidget);
    await unmountTodos(tester);
  });

  Future<String> seedDoneOccurrence(AppDatabase db) async {
    final id = await db.createTodo(
      TodoInput(
        title: '浇花',
        dueDate: todoToday,
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.daily,
          anchor: todoToday,
        ),
      ),
    );
    await db.completeTodo(id);
    return id;
  }

  for (final (label, width) in <(String, double)>[
    ('the sheet', 400),
    ('the detail pane', 1400),
  ]) {
    testWidgets(
      'a done occurrence shows streak and switches in place in $label',
      (tester) async {
        late String seriesId;
        await pumpTodosPage(
          tester,
          width: width,
          height: 1200,
          todoSettings: const TodoSettings(defaultViewKey: 'completed'),
          seed: (db) async => seriesId = await seedDoneOccurrence(db),
        );
        final l10n = todoL10n(tester);
        // 已完成视图里只有这一次（原待办已推到明天）。
        await tester.tap(find.text('浇花'));
        await settle(tester);
        final copy = tester.widget<TodoDetailBody>(find.byType(TodoDetailBody));
        expect(copy.todoId, isNot(seriesId));
        // 已完成副本直接展示真实的重复规则与完整坚持记录热力图，不再显示“属于xxx”。
        expect(find.text(l10n.todoRepeatDaily), findsOneWidget);
        expect(find.byType(TodoStreakCard), findsOneWidget);
        expect(find.text(l10n.todoStreakSummary(1, 1)), findsOneWidget);
        final gridSize = tester.getSize(find.byType(TodoStreakGrid));
        expect(gridSize.width, greaterThan(240));

        await tester.tap(find.text(l10n.todoViewNextOccurrence));
        await settle(tester);
        final bodies = tester
            .widgetList<TodoDetailBody>(find.byType(TodoDetailBody))
            .map((body) => body.todoId)
            .toList();
        // 无论手机底部面板还是宽窗口详情栏，都原地切换，绝不叠两层面板。
        expect(bodies, <String>[seriesId]);
        expect(find.byType(TodoStreakCard), findsOneWidget);
        await unmountTodos(tester);
      },
    );
  }

  testWidgets(
    'unchecking a done occurrence in detail rolls back the series in place',
    (tester) async {
      late String seriesId;
      final db = await pumpTodosPage(
        tester,
        width: 400,
        height: 1200,
        todoSettings: const TodoSettings(defaultViewKey: 'completed'),
        seed: (db) async => seriesId = await seedDoneOccurrence(db),
      );
      final l10n = todoL10n(tester);
      await tester.tap(find.text('浇花'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(TodoDetailBody),
          matching: find.byType(TodoCheckBoxVisual),
        ),
      );
      await settle(tester);
      // 回滚后原地切回原待办：不会闪现“已被删除”，重复规则完好，方框变为未勾选。
      expect(find.text(l10n.todoNotFound), findsNothing);
      final body = tester.widget<TodoDetailBody>(find.byType(TodoDetailBody));
      expect(body.todoId, seriesId);
      expect(find.text(l10n.todoRepeatDaily), findsOneWidget);
      final box = tester.widget<TodoCheckBoxVisual>(
        find.descendant(
          of: find.byType(TodoDetailBody),
          matching: find.byType(TodoCheckBoxVisual),
        ),
      );
      expect(box.checked, isFalse);
      final series = (await db.getTodo(seriesId))!;
      expect(series.dueDate, formatAnniversaryDate(todoToday));
      expect(decodeTodoRepeat(series.repeat), isNotNull);
      await unmountTodos(tester);
    },
  );

  testWidgets(
    'completing a repeating todo in detail resets the checkbox and allows next tick',
    (tester) async {
      late String seriesId;
      final db = await openDetail(tester, '浇花', (db) async {
        seriesId = await db.createTodo(
          TodoInput(
            title: '浇花',
            dueDate: todoToday,
            repeat: TodoRepeatRule(
              frequency: TodoRepeatFrequency.daily,
              anchor: todoToday,
            ),
          ),
        );
      });
      final checkbox = find.descendant(
        of: find.byType(TodoDetailBody),
        matching: find.byType(TodoCheckBoxVisual),
      );
      // 第一次完成：推进到明天，方框平滑复位为未勾选而不是卡死在已勾选。
      await tester.tap(checkbox);
      await tester.pump();
      await tester.pump(TodoCompleteMotion.check);
      await settle(tester);
      expect(
        (await db.getTodo(seriesId))!.dueDate,
        formatAnniversaryDate(todoToday.add(const Duration(days: 1))),
      );
      expect(tester.widget<TodoCheckBoxVisual>(checkbox).checked, isFalse);

      // 第二次依然可以直接点按完成，推进到后天。
      await tester.tap(checkbox);
      await tester.pump();
      await tester.pump(TodoCompleteMotion.check);
      await settle(tester);
      expect(
        (await db.getTodo(seriesId))!.dueDate,
        formatAnniversaryDate(todoToday.add(const Duration(days: 2))),
      );
      expect(tester.widget<TodoCheckBoxVisual>(checkbox).checked, isFalse);
      await unmountTodos(tester);
    },
  );

  testWidgets('the big checkbox plays before it writes', (tester) async {
    final db = await openDetail(tester, '写周报', (db) async {
      await db.createTodo(TodoInput(title: '写周报', dueDate: todoToday));
    });
    await tester.tap(
      find.descendant(
        of: find.byType(TodoDetailBody),
        matching: find.byType(TodoCheckBoxVisual),
      ),
    );
    await tester.pump();
    await tester.pump(TodoCompleteMotion.check * 0.5);
    expect((await todoRowTitled(tester, db, '写周报')).completedAt, isNull);
    await tester.pump(TodoCompleteMotion.check);
    await settle(tester);
    expect((await todoRowTitled(tester, db, '写周报')).completedAt, isNotNull);
    await unmountTodos(tester);
  });
}
