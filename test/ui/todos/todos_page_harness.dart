import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/providers/todo_providers.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 待办页的测试装置：挂载待办页（真实的内存库与设置），以及几个常用的
/// 等待与查找。待办页的各个测试文件共用。

/// 挂载待办页。返回库，测试可在运行中写数据。[todoSettings] 为打开前的
/// 待办偏好（如“打开时显示”某个视图、手动排序）；[now] 给出时替换“此刻”
/// （模拟跨过零点）；[disableAnimations] 模拟系统的减少动态效果。
Future<AppDatabase> pumpTodosPage(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  Locale locale = const Locale('zh'),
  double width = 400,
  double height = 860,
  Brightness brightness = Brightness.light,
  ValueChanged<bool>? onSelectionModeChanged,
  TodoSettings? todoSettings,
  DateTime Function()? now,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  if (todoSettings != null) {
    await settings.setTodoSettingsRaw(todoSettings.encode());
  }
  if (seed != null) await tester.runAsync(() => seed(database));
  Future<void> Function()? create;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
        if (now != null) todoNowProvider.overrideWithValue(now),
      ],
      child: MaterialApp(
        locale: locale,
        theme: expressiveTestTheme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: disableAnimations
            ? (BuildContext context, Widget? child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : null,
        home: Scaffold(
          body: TodosPage(
            onCreateActionChanged: (action) => create = action,
            onSelectionModeChanged: onSelectionModeChanged,
          ),
        ),
      ),
    ),
  );
  await settleTodos(tester);
  expect(create, isNotNull, reason: '页面注册了新建入口');
  return database;
}

/// drift 的查询在真实异步里完成：让出几轮再推帧。
Future<void> settleTodos(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> unmountTodos(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// 列表里未完成的行（已完成的在“今天已完成”等组里另算）。
List<String> openTodoTitles(WidgetTester tester) => tester
    .widgetList<TodoTile>(find.byType(TodoTile))
    .where((tile) => tile.row.completedAt == null)
    .map((tile) => tile.row.title)
    .toList();

DateTime get todoToday {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

AppLocalizations todoL10n(WidgetTester tester) =>
    tester.element(find.byType(TodosPage)).l10n;

Future<TodoRow> todoRowTitled(
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
