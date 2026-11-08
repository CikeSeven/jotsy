import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/pages/todo_detail_page.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:node_diary/ui/todos/widgets/todo_view_switcher.dart';
import 'package:node_diary/ui/widgets/todo_check_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 挂载待办页（真实的内存库与设置）。返回库，测试可在运行中写数据。
Future<AppDatabase> _pumpTodos(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  Locale locale = const Locale('zh'),
  double width = 400,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 860);
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
          body: TodosPage(onCreateActionChanged: (action) => create = action),
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

List<String> _tileTitles(WidgetTester tester) => tester
    .widgetList<TodoTile>(find.byType(TodoTile))
    .map((tile) => tile.row.title)
    .toList();

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
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
    final l10n = tester.element(find.byType(TodosPage)).l10n;
    expect(_tileTitles(tester), <String>['上周的', '今天的']);
    expect(find.text(l10n.todoGroupOverdue), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('ticking a todo completes it and undo brings it back', (
    tester,
  ) async {
    final db = await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '寄快递', dueDate: _today));
      },
    );
    final l10n = tester.element(find.byType(TodosPage)).l10n;
    await tester.tap(find.byType(TodoCheckBoxVisual));
    await _settle(tester);
    expect(_tileTitles(tester), isEmpty);
    expect(find.text(l10n.todoCompletedNotice), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await _settle(tester);
    expect(_tileTitles(tester), <String>['寄快递']);
    final rows = await tester.runAsync(db.getOpenTodos);
    expect(rows!.single.completedAt, isNull);
    await _unmount(tester);
  });

  testWidgets('switching to a list shows only its todos', (tester) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        final list = await db.createTodoList(name: '工作');
        await db.createTodo(TodoInput(title: '开会', listId: list));
        await db.createTodo(const TodoInput(title: '买菜'));
      },
    );
    // 清单胶囊排在智能视图之后，窄屏上要先横向滚过去。
    await tester.scrollUntilVisible(
      find.text('工作 1'),
      120,
      scrollable: find.descendant(
        of: find.byType(TodoViewStrip),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '工作 1'));
    await _settle(tester);
    expect(_tileTitles(tester), <String>['开会']);
    await _unmount(tester);
  });

  testWidgets('an empty today view shows the empty hint', (tester) async {
    await _pumpTodos(tester);
    final l10n = tester.element(find.byType(TodosPage)).l10n;
    expect(find.text(l10n.todoEmptyToday), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping a row opens the detail page', (tester) async {
    await _pumpTodos(
      tester,
      seed: (db) async {
        await db.createTodo(TodoInput(title: '写周报', dueDate: _today));
      },
    );
    await tester.tap(find.text('写周报'));
    await _settle(tester);
    expect(find.byType(TodoDetailPage), findsOneWidget);
    await _unmount(tester);
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
        },
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
}
