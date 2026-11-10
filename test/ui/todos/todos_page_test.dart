import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/providers/todo_providers.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_detail_pane.dart';
import 'package:node_diary/ui/todos/widgets/todo_labels.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:node_diary/ui/todos/widgets/todo_view_switcher.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/todo_check_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 挂载待办页（真实的内存库与设置）。返回库，测试可在运行中写数据。
Future<AppDatabase> _pumpTodos(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  Locale locale = const Locale('zh'),
  double width = 400,
  double height = 860,
  Brightness brightness = Brightness.light,
  ValueChanged<bool>? onSelectionModeChanged,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  if (seed != null) await tester.runAsync(() => seed(database));
  Future<void> Function()? create;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        locale: locale,
        theme: expressiveTestTheme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TodosPage(
            onCreateActionChanged: (action) => create = action,
            onSelectionModeChanged: onSelectionModeChanged,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  expect(create, isNotNull, reason: '页面注册了新建入口');
  return database;
}

/// drift 的查询在真实异步里完成：让出几轮再推帧。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// 列表里未完成的行（已完成的在“今天已完成”等组里另算）。
List<String> _openTitles(WidgetTester tester) => tester
    .widgetList<TodoTile>(find.byType(TodoTile))
    .where((tile) => tile.row.completedAt == null)
    .map((tile) => tile.row.title)
    .toList();

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(TodosPage)).l10n;

Future<TodoRow> _rowTitled(
  WidgetTester tester,
  AppDatabase db,
  String title,
) async {
  final rows = await tester.runAsync(() async {
    final open = await db.getOpenTodos();
    final done = await db.watchCompletedTodos().first;
    return <TodoRow>[...open, ...done];
  });
  return rows!.firstWhere((row) => row.title == title);
}

void main() {
  testWidgets('today shows overdue above today and hides undated todos', (
    tester,
  ) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(const TodoInput(title: '没有日期'));
        await db.createTodo(TodoInput(title: '今天的', dueDate: _today));
        await db.createTodo(
          TodoInput(
            title: '上周的',
            dueDate: _today.subtract(const Duration(days: 7)),
          ),
        );
      },
    );
    final l10n = _l10n(tester);
    expect(_openTitles(tester), <String>['上周的', '今天的']);
    expect(find.text(l10n.todoGroupOverdue), findsOneWidget);
    // 概览卡：还有 2 件，逾期 1。
    expect(find.text(l10n.todoHeroRemaining(2)), findsOneWidget);
    expect(find.text(l10n.todoHeroOverdue(1)), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('ticking a todo collapses it, completes it and undo restores', (
    tester,
  ) async {
    final db = await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '寄快递', dueDate: _today));
      },
    );
    final l10n = _l10n(tester);
    await tester.tap(find.byType(TodoCheckBoxVisual));
    await tester.pump();
    // 行内动效播完后才开始收起，收起后才写库。
    await tester.pump(const Duration(milliseconds: 300));
    expect((await _rowTitled(tester, db, '寄快递')).completedAt, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    expect(_openTitles(tester), isEmpty);
    expect((await _rowTitled(tester, db, '寄快递')).completedAt, isNotNull);
    expect(find.text(l10n.todoCompletedNotice), findsOneWidget);
    // 今天完成的出现在“今天已完成”组里。
    expect(find.text(l10n.todoGroupCompletedToday), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await _settle(tester);
    expect(_openTitles(tester), <String>['寄快递']);
    await _unmount(tester);
  });

  testWidgets('swiping right completes a todo, swiping left deletes one', (
    tester,
  ) async {
    final db = await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '右滑完成', dueDate: _today));
        await db.createTodo(TodoInput(title: '左滑删除', dueDate: _today));
      },
    );
    await tester.drag(find.text('右滑完成'), const Offset(300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    expect((await _rowTitled(tester, db, '右滑完成')).completedAt, isNotNull);

    await tester.drag(find.text('左滑删除'), const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    final open = await tester.runAsync(db.getOpenTodos);
    expect(open!.map((row) => row.title), isNot(contains('左滑删除')));
    await _unmount(tester);
  });

  testWidgets('the view sheet switches to a list', (tester) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        final list = await db.createTodoList(name: '工作');
        await db.createTodo(TodoInput(title: '开会', listId: list));
        await db.createTodo(const TodoInput(title: '买菜'));
      },
    );
    await tester.tap(find.byIcon(FontAwesomeIcons.angleDown.data).first);
    await _settle(tester);
    expect(find.text(_l10n(tester).todoViewSheetTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(TodoListNavRow, '工作'));
    await _settle(tester);
    expect(_openTitles(tester), <String>['开会']);
    await _unmount(tester);
  });

  testWidgets('more is a popup menu whose sort submenu stays open', (
    tester,
  ) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '买菜', dueDate: _today));
      },
    );
    final l10n = _l10n(tester);
    Future<void> settleMenu() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    await tester.tap(find.byTooltip(l10n.todoMore));
    await settleMenu();
    // 弹出菜单而不是底部面板：今天视图有排序与管理清单，没有清单专属的项。
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ExpressiveSubmenuItem), findsOneWidget);
    expect(find.text(l10n.todoListManage), findsOneWidget);
    expect(find.text(l10n.todoListDelete), findsNothing);

    await tester.tap(find.text(l10n.todoSortTitle));
    await settleMenu();
    final due = TodoLabels.sortMode(l10n, TodoSortMode.due);
    await tester.tap(find.text(due));
    await settleMenu();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodosPage)),
    );
    expect(container.read(todoSettingsProvider).sort, TodoSortMode.due);
    // 点了即生效、菜单保持打开，对勾移到新选的一项。
    final dueItem = tester.widget<ExpressiveMenuItem>(
      find.ancestor(
        of: find.text(due),
        matching: find.byType(ExpressiveMenuItem),
      ),
    );
    expect(dueItem.selected, isTrue);

    // 点外部先收回二级菜单，再点关掉菜单。
    await tester.tapAt(const Offset(200, 700));
    await settleMenu();
    expect(find.text(due), findsNothing);
    await tester.tapAt(const Offset(200, 700));
    await settleMenu();
    expect(find.text(l10n.todoListManage), findsNothing);
    await _unmount(tester);
  });

  testWidgets('long press selects rows and completes them in a batch', (
    tester,
  ) async {
    final selecting = <bool>[];
    final db = await _pumpTodos(
      tester,
      onSelectionModeChanged: selecting.add,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '甲', dueDate: _today));
        await db.createTodo(TodoInput(title: '乙', dueDate: _today));
        await db.createTodo(TodoInput(title: '丙', dueDate: _today));
      },
    );
    final l10n = _l10n(tester);
    await tester.longPress(find.text('甲'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(selecting.last, isTrue);
    expect(find.text(l10n.todoSelectedCount(1)), findsOneWidget);
    await tester.tap(find.text('乙'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.todoSelectedCount(2)), findsOneWidget);

    await tester.tap(find.text(l10n.todoBatchActionComplete));
    await _settle(tester);
    expect(selecting.last, isFalse);
    expect(_openTitles(tester), <String>['丙']);
    expect(find.text(l10n.todoBatchCompleted(2)), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await _settle(tester);
    final open = await tester.runAsync(db.getOpenTodos);
    expect(open!.map((row) => row.title).toSet(), <String>{'甲', '乙', '丙'});
    await _unmount(tester);
  });

  testWidgets('inline add recognizes the date and list from the text', (
    tester,
  ) async {
    late String listId;
    final db = await _pumpTodos(
      tester,
      seed: (db) async {
        listId = await db.createTodoList(name: '工作');
      },
    );
    final l10n = _l10n(tester);
    await tester.tap(find.text(l10n.todoInlineAddHint));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '明天 交周报 #工作 !!!');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    final row = await _rowTitled(tester, db, '交周报');
    expect(row.listId, listId);
    expect(row.priority, TodoPriority.high.index);
    expect(
      row.dueDate,
      formatAnniversaryDate(_today.add(const Duration(days: 1))),
    );
    // 输入框清空后留着，接着记下一条。
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await _unmount(tester);
  });

  testWidgets('closing the keyboard releases the inline field and the gap', (
    tester,
  ) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '今天的', dueDate: _today));
      },
    );
    final l10n = _l10n(tester);
    double viewportHeight() =>
        tester.getSize(find.byType(CustomScrollView)).height;
    final fullHeight = viewportHeight();

    await tester.tap(find.text(l10n.todoInlineAddHint));
    // 切换在重建的那一帧才开始，再推过 fast 的时长与移除旧子项的一帧。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text(l10n.todoInlineAddHint), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump();
    expect(viewportHeight(), lessThan(fullHeight), reason: '列表让出键盘');

    // 用返回键 / 手势收起键盘：输入框失焦，空的就收回占位行，列表复原。
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
    expect(find.text(l10n.todoInlineAddHint), findsOneWidget);
    expect(viewportHeight(), fullHeight);
    await _unmount(tester);
  });

  testWidgets('the overdue header moves every overdue todo to today', (
    tester,
  ) async {
    final db = await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(
          TodoInput(
            title: '交房租',
            dueDate: _today.subtract(const Duration(days: 2)),
            dueMinute: 9 * 60,
          ),
        );
      },
    );
    await tester.tap(find.text(_l10n(tester).todoMoveOverdueToToday));
    await _settle(tester);
    final row = await _rowTitled(tester, db, '交房租');
    expect(row.dueDate, formatAnniversaryDate(_today));
    expect(row.dueMinute, 9 * 60, reason: '各自的时刻保留');
    await _unmount(tester);
  });

  testWidgets('an empty today view shows the empty hint', (tester) async {
    await _pumpTodos(tester);
    final l10n = _l10n(tester);
    expect(find.text(l10n.todoEmptyToday), findsOneWidget);
    expect(find.text(l10n.todoHeroNothing), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping a row opens the detail sheet', (tester) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '写周报', dueDate: _today));
      },
    );
    await tester.tap(find.text('写周报'));
    await _settle(tester);
    expect(find.byType(TodoDetailBody), findsOneWidget);
    expect(find.byType(TodoDetailPane), findsNothing);
    await _unmount(tester);
  });

  testWidgets('wide desktop windows open details in the side pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pumpTodos(
        tester,
        width: 1280,
        height: 800,
        seed: (db) async {
          await db.createTodo(TodoInput(title: '写周报', dueDate: _today));
        },
      );
      await tester.tap(find.text('写周报'));
      await _settle(tester);
      expect(find.byType(TodoDetailPane), findsOneWidget);
      expect(find.byType(TodoSidebar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('fits 320dp without overflow (${locale.languageCode})', (
      tester,
    ) async {
      await _pumpTodos(
        tester,
        width: 320,
        locale: locale,
        brightness: Brightness.dark,
        seed: (db) async {
          final list = await db.createTodoList(name: '一个名字很长很长的清单');
          await db.createTodo(
            TodoInput(
              title: '一条标题很长很长很长很长很长很长很长很长很长的待办',
              listId: list,
              priority: TodoPriority.high,
              dueDate: _today,
              dueMinute: 15 * 60,
              reminders: const <TodoReminder>[TodoReminder.beforeDue(15)],
              steps: const <TodoStep>[TodoStep(id: 'a', title: '一步')],
              note: '备注',
            ),
          );
          await db.createTodo(
            TodoInput(
              title: '逾期',
              dueDate: _today.subtract(const Duration(days: 3)),
            ),
          );
        },
      );
      expect(tester.takeException(), isNull);
      // 多选态的页头与操作栏同样不溢出。
      await tester.longPress(find.text('逾期'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
}
