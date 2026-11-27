import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/controllers/todo_debounced_writer.dart';
import 'package:node_diary/ui/todos/pages/todo_search_page.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_search_filter.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import 'todos_page_harness.dart';

TodoRow _row({
  String? listId,
  int priority = 0,
  String? due,
  DateTime? completedAt,
}) {
  final at = DateTime(2026, 11, 28);
  return TodoRow(
    id: 1,
    todoId: 't',
    title: 'x',
    note: '',
    listId: listId,
    priority: priority,
    dueDate: due,
    reminders: '[]',
    steps: '[]',
    sortOrder: 0,
    metadata: '{}',
    completedAt: completedAt,
    createdAt: at,
    updatedAt: at,
  );
}

/// 挂载待办搜索页（真实的内存库）。[textScale] 模拟系统字号。
Future<AppDatabase> _pumpSearch(
  WidgetTester tester, {
  required Future<void> Function(AppDatabase db) seed,
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.runAsync(() => seed(database));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TodoSearchPage(),
      ),
    ),
  );
  await settleTodos(tester);
  return database;
}

Future<void> _type(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.pump(TodoDebouncedWriter.searchDelay);
  await settleTodos(tester);
}

List<String> _titles(WidgetTester tester) => tester
    .widgetList<TodoTile>(find.byType(TodoTile))
    .map((tile) => tile.row.title)
    .toList();

Future<void> _seed(AppDatabase db) async {
  await db.createTodo(const TodoInput(title: '买牛奶'));
  await db.createTodo(
    TodoInput(
      title: '买机票',
      priority: TodoPriority.high,
      dueDate: DateTime(2026, 12, 3),
    ),
  );
  final done = await db.createTodo(const TodoInput(title: '买书'));
  await db.completeTodo(done);
  await db.createTodo(const TodoInput(title: '写周报', note: '记得附上牛奶账单'));
}

/// 待办搜索：筛选胶囊、无关键词按筛选列出、命中词高亮、小屏大字号。
void main() {
  test('the filter keeps rows matching every chosen condition', () {
    const all = TodoSearchFilter();
    expect(all.isEmpty, isTrue);
    expect(all.matches(_row(completedAt: DateTime(2026))), isTrue);

    const open = TodoSearchFilter(status: TodoSearchStatus.open);
    expect(open.matches(_row()), isTrue);
    expect(open.matches(_row(completedAt: DateTime(2026))), isFalse);

    final inbox = all.withList(null);
    expect(inbox.listChosen, isTrue);
    expect(inbox.matches(_row()), isTrue);
    expect(inbox.matches(_row(listId: 'work')), isFalse);
    expect(inbox.withoutList().isEmpty, isTrue);

    final strict = all
        .withList('work')
        .copyWith(highOnly: true, datedOnly: true);
    // 换别的条件不会丢掉已选的清单。
    expect(strict.copyWith(status: TodoSearchStatus.done).listId, 'work');
    expect(
      strict.matches(
        _row(
          listId: 'work',
          priority: TodoPriority.high.index,
          due: '2026-12-01',
        ),
      ),
      isTrue,
    );
    expect(strict.matches(_row(listId: 'work', priority: 2)), isFalse);
    expect(strict.matches(_row(listId: 'work', due: '2026-12-01')), isFalse);
  });

  testWidgets('chips narrow the keyword results and highlight the terms', (
    tester,
  ) async {
    // 够宽：一排胶囊不必横滚（窄屏横滚见最后一个测试）。
    await _pumpSearch(tester, seed: _seed, width: 720);
    await _type(tester, '买');
    expect(_titles(tester), containsAll(<String>['买牛奶', '买机票', '买书']));
    expect(_titles(tester).first, isNot('买书'), reason: '未完成的在前');

    // 标题里的“买”高亮（主色容器底）。
    final scheme = Theme.of(
      tester.element(find.byType(TodoTile).first),
    ).colorScheme;
    final highlighted = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((RichText text) {
          final spans = <TextSpan>[];
          text.text.visitChildren((InlineSpan span) {
            if (span is TextSpan &&
                span.style?.backgroundColor == scheme.primaryContainer) {
              spans.add(span);
            }
            return true;
          });
          return spans;
        })
        .map((TextSpan span) => span.text)
        .toSet();
    expect(highlighted, <String?>{'买'});

    await tester.tap(find.text('未完成'));
    await settleTodos(tester);
    expect(_titles(tester), unorderedEquals(<String>['买牛奶', '买机票']));

    await tester.tap(find.text('高优先级'));
    await settleTodos(tester);
    expect(_titles(tester), <String>['买机票']);

    // 去掉高优先级、改看已完成。
    await tester.tap(find.text('高优先级'));
    await tester.pump();
    await tester.tap(find.text('已完成'));
    await settleTodos(tester);
    expect(_titles(tester), <String>['买书']);

    await _type(tester, '不存在的词');
    expect(find.text('没有找到相关的待办'), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('without a keyword the chosen filters list matching to-dos', (
    tester,
  ) async {
    await _pumpSearch(tester, seed: _seed, width: 720);
    // 什么都没输、没选：不列出任何待办。
    expect(find.byType(TodoTile), findsNothing);

    await tester.tap(find.text('有日期'));
    await settleTodos(tester);
    debugPrint(
      'DBG tiles=${_titles(tester)} empty=${find.text('没有找到相关的待办').evaluate().length}',
    );
    expect(_titles(tester), <String>['买机票']);

    await tester.tap(find.text('有日期'));
    await tester.pump();
    await tester.tap(find.text('已完成'));
    await settleTodos(tester);
    expect(_titles(tester), <String>['买书']);
    await unmountTodos(tester);
  });

  testWidgets('a note match shows the excerpt around the hit', (tester) async {
    await _pumpSearch(tester, seed: _seed);
    await _type(tester, '牛奶');
    expect(_titles(tester), unorderedEquals(<String>['买牛奶', '写周报']));
    expect(find.text('记得附上牛奶账单'), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('320dp at 1.3x text lays out the filters and rows', (
    tester,
  ) async {
    await _pumpSearch(tester, seed: _seed, width: 320, textScale: 1.3);
    await _type(tester, '买');
    expect(tester.takeException(), isNull);
    expect(find.byType(TodoTile), findsNWidgets(3));
    // 筛选一排横向滚动：最后一颗胶囊滚进来后可点。
    await tester.dragUntilVisible(
      find.text('有日期'),
      find.byType(SingleChildScrollView).first,
      const Offset(-120, 0),
    );
    await tester.tap(find.text('有日期'));
    await settleTodos(tester);
    expect(tester.takeException(), isNull);
    expect(_titles(tester), <String>['买机票']);
    await unmountTodos(tester);
  });
}
