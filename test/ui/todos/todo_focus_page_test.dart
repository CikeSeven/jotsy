import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todo_focus_page.dart';
import 'package:node_diary/ui/todos/providers/todo_reminder_providers.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_focus_banner.dart';

import '../../support/fake_todo_notifications.dart';
import 'todos_page_harness.dart';

/// 专注计时页：从详情“更多”开始专注，暂停 / 继续，走完后完成这条待办；
/// 回到待办页时顶上的胶囊带回专注页；专注计时关着时没有入口。
void main() {
  final start = DateTime(2026, 11, 28, 9);
  late DateTime clock;

  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> pump(WidgetTester tester, {bool focusOn = true}) {
    clock = start;
    return pumpTodosPage(
      tester,
      height: 1000,
      now: () => clock,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: (db) => db.createTodo(const TodoInput(title: '写报告')),
      prepare: (SettingsService settings) => settings.setAppFeaturesRaw(
        focusOn ? '{"todos":true}' : '{"todos":true,"todoFocus":false}',
      ),
      overrides: [
        todoNotificationGatewayProvider.overrideWithValue(
          FakeTodoNotificationGateway(),
        ),
      ],
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('写报告'));
    await settle(tester);
    expect(find.byType(TodoDetailBody), findsOneWidget);
    await tester.tap(find.byTooltip(todoL10n(tester).todoMore).last);
    await settle(tester);
  }

  testWidgets('focus from the details, pause, run out and complete', (
    tester,
  ) async {
    final db = await pump(tester);
    final l10n = todoL10n(tester);
    await openMenu(tester);
    await tester.tap(find.text(l10n.todoFocusAction));
    await settle(tester);

    expect(find.byType(TodoFocusPage), findsOneWidget);
    expect(find.text(l10n.todoFocusPhaseFocus(1, 4)), findsOneWidget);
    expect(find.text('25:00'), findsWidgets);

    await tester.tap(find.byTooltip(l10n.todoFocusPause));
    await settle(tester);
    expect(find.byTooltip(l10n.todoFocusResume), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.todoFocusResume));
    await settle(tester);

    // 墙钟走过 26 分钟，控制器每秒看一次。
    clock = start.add(const Duration(minutes: 26));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text(l10n.todoFocusDoneTitle), findsOneWidget);
    final id = (await todoRowTitled(tester, db, '写报告')).todoId;
    final seconds = await tester.runAsync(
      () => db.watchTodoFocusSeconds(id).first,
    );
    expect(seconds, 1500);

    await tester.tap(find.text(l10n.todoFocusCompleteTodo));
    await settle(tester);
    final row = await todoRowTitled(tester, db, '写报告');
    expect(row.completedAt, isNotNull);
    expect(find.text(l10n.todoFocusCompleteTodo), findsNothing);

    // 回到待办页：顶上的胶囊写“时间到了”，点开回到专注页。
    await tester.tap(find.byTooltip(l10n.commonBack).last);
    await settle(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(find.text(l10n.todoFocusBannerEnded), findsOneWidget);
    await tester.tap(find.byType(TodoFocusBanner));
    await settle(tester);
    expect(find.byType(TodoFocusPage), findsOneWidget);
    await tester.tap(find.text(l10n.todoFocusStop).last);
    await settle(tester);
    expect(find.byType(TodoFocusPage), findsNothing);
    await unmountTodos(tester);
  });

  testWidgets('no focus entry when the focus timer is off', (tester) async {
    await pump(tester, focusOn: false);
    await openMenu(tester);
    expect(find.text(todoL10n(tester).todoFocusAction), findsNothing);
    expect(find.text(todoL10n(tester).todoDuplicate), findsOneWidget);
    await unmountTodos(tester);
  });
}
