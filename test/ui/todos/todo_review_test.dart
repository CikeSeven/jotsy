import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/controllers/explore_module_actions.dart';
import 'package:node_diary/ui/explore/sections/explore_todos_card.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_review_stats.dart';
import 'package:node_diary/ui/todos/widgets/todo_review_summary.dart';

import 'todos_page_harness.dart';

TodoRow _done(DateTime at) => TodoRow(
  id: at.millisecondsSinceEpoch,
  todoId: at.toIso8601String(),
  title: 'x',
  note: '',
  priority: 0,
  reminders: '[]',
  steps: '[]',
  sortOrder: 0,
  metadata: '{}',
  completedAt: at,
  createdAt: at,
  updatedAt: at,
);

class _RecordingActions extends ExploreModuleActions {
  int todosOpened = 0;

  @override
  void openTodos() => todosOpened++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 待办回顾：本周完成、最近 7 天、连续天数；已完成视图与探索页的待办卡。
void main() {
  test('review stats count this week, the last 7 days and the streak', () {
    // 2026-11-27 是周五；周一为 11-23。
    final today = DateTime(2026, 11, 27);
    final stats = TodoReviewStats.build(<TodoRow>[
      _done(DateTime(2026, 11, 26, 20)),
      _done(DateTime(2026, 11, 26, 9)),
      _done(DateTime(2026, 11, 25, 9)),
      _done(DateTime(2026, 11, 23, 9)),
      _done(DateTime(2026, 11, 22, 9)), // 上周日：不算本周
    ], today);
    expect(stats.weekDone, 4);
    expect(stats.days, <int>[0, 1, 1, 0, 1, 2, 0]);
    // 今天还没完成：从昨天往前数，24 号断开。
    expect(stats.streak, 2);
    expect(
      TodoReviewStats.build(<TodoRow>[
        _done(DateTime(2026, 11, 27, 8)),
        _done(DateTime(2026, 11, 26, 8)),
      ], today).streak,
      2,
    );
    expect(TodoReviewStats.build(const <TodoRow>[], today).streak, 0);
  });

  testWidgets('the completed view opens with the review counting up', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'completed'),
      seed: (db) async {
        for (final title in <String>['一', '二']) {
          final id = await db.createTodo(TodoInput(title: title));
          await db.completeTodo(id);
        }
      },
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final l10n = todoL10n(tester);
    expect(find.byType(TodoReviewSummary), findsOneWidget);
    expect(find.text(l10n.todoReviewWeekDone(2)), findsOneWidget);
    expect(find.text(l10n.todoReviewStreak(1)), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('the explore to-do card shows today and opens the tab', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(
      () => db.createTodo(TodoInput(title: '寄快递', dueDate: todoToday)),
    );
    final actions = _RecordingActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExploreActionsScope(
              actions: actions,
              child: const ExploreTodosCard(),
            ),
          ),
        ),
      ),
    );
    await settleTodos(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final l10n = tester.element(find.byType(ExploreTodosCard)).l10n;
    expect(find.text(l10n.todoHeroRemaining(1)), findsOneWidget);
    await tester.tap(find.text(l10n.exploreTodosOpen));
    expect(actions.todosOpened, 1);
    // 卸下（零点计时器随之取消），在真实异步里关库。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(db.close);
  });
}
