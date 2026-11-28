import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/todos/controllers/todo_focus_controller.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todo_focus_page.dart';
import 'package:node_diary/ui/todos/providers/todo_reminder_providers.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_focus_banner.dart';
import 'package:node_diary/ui/todos/widgets/todo_focus_dial.dart';
import 'package:node_diary/ui/todos/widgets/todo_focus_task_card.dart';

import '../../support/fake_todo_notifications.dart';
import 'todos_page_harness.dart';

/// 专注计时页：
/// - 从详情“更多”开始专注，暂停 / 继续，加 5 分钟，走完后完成这条待办；
/// - 专注途中就地勾选子步骤、切换纯净模式与调整专注节奏；
/// - 空闲准备态切换时长预设、挑选待办并开始专注；
/// - 宽窗口双栏工作台与桌面键盘快捷键（Space / `+` / Esc）；
/// - 达到 240 分钟上限时禁用加时、减少动画与暗色主题渲染正常；
/// - 专注计时关着时没有入口。
void main() {
  final start = DateTime(2026, 11, 28, 9);
  late DateTime clock;

  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> pump(
    WidgetTester tester, {
    bool focusOn = true,
    double width = 430,
    double height = 960,
    Future<void> Function(AppDatabase db)? seed,
  }) {
    clock = start;
    return pumpTodosPage(
      tester,
      width: width,
      height: height,
      now: () => clock,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: seed ?? (db) => db.createTodo(const TodoInput(title: '写报告')),
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

  Future<void> openMenu(WidgetTester tester, {String title = '写报告'}) async {
    await tester.tap(find.text(title));
    await settle(tester);
    expect(find.byType(TodoDetailBody), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(TodoDetailBody),
        matching: find.byTooltip(todoL10n(tester).todoMore),
      ),
    );
    await settle(tester);
  }

  Future<void> openFocusFromDetails(
    WidgetTester tester, {
    String title = '写报告',
  }) async {
    await openMenu(tester, title: title);
    await tester.tap(find.text(todoL10n(tester).todoFocusAction));
    await settle(tester);
    expect(find.byType(TodoFocusPage), findsOneWidget);
  }

  testWidgets('focus from the details, pause, extend, run out and complete', (
    tester,
  ) async {
    final db = await pump(tester);
    final l10n = todoL10n(tester);
    await openFocusFromDetails(tester);

    expect(find.text(l10n.todoFocusPhaseFocus(1, 4)), findsOneWidget);
    expect(find.text('25:00'), findsWidgets);
    expect(find.byType(TodoFocusTaskCard), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.todoFocusPause));
    await settle(tester);
    expect(find.byTooltip(l10n.todoFocusResume), findsOneWidget);
    expect(find.text(l10n.todoFocusPaused), findsOneWidget);

    // 暂停中加 5 分钟，倒计时立即跳到 30:00。
    await tester.tap(find.byTooltip(l10n.todoFocusExtend));
    await settle(tester);
    expect(find.text('30:00'), findsWidgets);

    await tester.tap(find.byTooltip(l10n.todoFocusResume));
    await settle(tester);
    expect(find.byTooltip(l10n.todoFocusPause), findsOneWidget);

    // 墙钟走过 31 分钟，控制器每秒看一次。
    clock = start.add(const Duration(minutes: 31));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text(l10n.todoFocusDoneTitle), findsOneWidget);
    final id = (await todoRowTitled(tester, db, '写报告')).todoId;
    final seconds = await tester.runAsync(
      () => db.watchTodoFocusSeconds(id).first,
    );
    expect(seconds, 1800);

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

  testWidgets('toggle steps inline, toggle zen mode, and adjust rhythm', (
    tester,
  ) async {
    final db = await pump(
      tester,
      seed: (db) async {
        final id = await db.createTodo(const TodoInput(title: '准备演讲'));
        await db.setTodoSteps(id, const <TodoStep>[
          TodoStep(id: 's1', title: '整理大纲'),
          TodoStep(id: 's2', title: '制作幻灯片'),
        ]);
      },
    );
    final l10n = todoL10n(tester);
    await openFocusFromDetails(tester, title: '准备演讲');

    // 任务卡默认露出下一条未完成步骤，直接勾选并落库。
    expect(find.text('整理大纲'), findsOneWidget);
    await tester.tap(find.text('整理大纲'));
    await settle(tester);
    final updated = await todoRowTitled(tester, db, '准备演讲');
    final steps = decodeTodoSteps(updated.steps);
    expect(steps.first.done, isTrue);
    expect(find.text('制作幻灯片'), findsOneWidget);

    // 切换纯净模式：顶栏滑出、手机端隐藏系统栏、任务卡收起，再点退出恢复。
    final systemUiCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            systemUiCalls.add(call);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.tap(find.byTooltip(l10n.todoFocusZenEnter));
    await settle(tester);
    expect(find.byType(TodoFocusTaskCard), findsNothing);
    expect(
      systemUiCalls.map((c) => c.arguments),
      contains('SystemUiMode.immersiveSticky'),
    );
    await tester.tap(find.byTooltip(l10n.todoFocusZenExit));
    await settle(tester);
    expect(find.byType(TodoFocusTaskCard), findsOneWidget);
    expect(systemUiCalls.last.arguments, 'SystemUiMode.edgeToEdge');

    // 顶栏节奏设置面板：把专注时长改为 45 分钟并立刻写入设置。
    await tester.tap(find.byTooltip(l10n.todoFocusRhythm));
    await settle(tester);
    expect(find.text(l10n.todoFocusRhythm), findsOneWidget);
    await tester.tap(find.text(l10n.todoFocusMinutes(45)).first);
    await settle(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // 提前结束本段后再看空闲准备态，已继承 45 分钟。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodoFocusPage)),
    );
    await container.read(todoFocusProvider.notifier).stop();
    await settle(tester);
    expect(find.byType(TodoFocusPreviewDial), findsOneWidget);
    expect(find.text('45:00'), findsWidgets);

    // 空闲态挑选待办并开始专注。
    await tester.tap(find.text(l10n.todoFocusFreeSession));
    await settle(tester);
    await tester.tap(find.text('准备演讲').last);
    await settle(tester);
    await tester.tap(find.text(l10n.todoFocusStart(45)));
    await settle(tester);
    expect(find.byType(TodoFocusDial), findsOneWidget);
    expect(find.text('准备演讲'), findsWidgets);

    await unmountTodos(tester);
  });

  testWidgets('desktop wide workbench and keyboard shortcuts work', (
    tester,
  ) async {
    await pump(
      tester,
      width: 1200,
      height: 820,
      seed: (db) async {
        final id = await db.createTodo(const TodoInput(title: '重构引擎'));
        await db.setTodoSteps(id, const <TodoStep>[
          TodoStep(id: 'a', title: '拆分模块'),
          TodoStep(id: 'b', title: '补齐单测'),
        ]);
      },
    );
    final l10n = todoL10n(tester);
    // 宽屏待办页点开详情在右侧详情栏，点“更多”进入专注页。
    await openFocusFromDetails(tester, title: '重构引擎');

    // 宽屏双栏：完整步骤直接平铺显示，并显示桌面键盘提示。
    expect(find.text('拆分模块'), findsOneWidget);
    expect(find.text('补齐单测'), findsOneWidget);
    expect(find.text(l10n.todoFocusKeyboardHint), findsOneWidget);

    // Space 暂停，再按 Space 继续。
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(find.byTooltip(l10n.todoFocusResume), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(find.byTooltip(l10n.todoFocusPause), findsOneWidget);

    // `+`（equal 键）加 5 分钟。
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await settle(tester);
    expect(find.text('30:00'), findsWidgets);

    // Esc 返回上一页，计时继续在后台跑。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(TodoFocusPage), findsNothing);
    expect(find.byType(TodoFocusBanner), findsOneWidget);

    await unmountTodos(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('extend button disables at 240 minute cap and respects break', (
    tester,
  ) async {
    await pump(tester);
    final l10n = todoL10n(tester);
    await openFocusFromDetails(tester);

    // 通过 controller 连续加时到 240 分钟上限，按钮自动置灰不可点。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodoFocusPage)),
    );
    final notifier = container.read(todoFocusProvider.notifier);
    for (var i = 0; i < 45; i++) {
      await notifier.extend();
    }
    await settle(tester);
    final extendButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(l10n.todoFocusExtendShort),
        matching: find.byType(FilledButton),
      ),
    );
    expect(extendButton.onPressed, isNull);

    // 走完后进入休息，右侧换成跳过休息。
    clock = start.add(const Duration(minutes: 245));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    await tester.tap(find.text(l10n.todoFocusStartBreak(5)));
    await settle(tester);
    expect(find.text(l10n.todoFocusPhaseShortBreak), findsOneWidget);
    expect(find.byTooltip(l10n.todoFocusSkipBreak), findsOneWidget);

    await unmountTodos(tester);
  });

  testWidgets('no focus entry when the focus timer is off', (tester) async {
    await pump(tester, focusOn: false);
    await openMenu(tester);
    expect(find.text(todoL10n(tester).todoFocusAction), findsNothing);
    expect(find.text(todoL10n(tester).todoDuplicate), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('renders cleanly with reduced motion enabled', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester);
    final l10n = todoL10n(tester);
    await openFocusFromDetails(tester);
    expect(find.byType(TodoFocusDial), findsOneWidget);
    expect(find.text('25:00'), findsWidgets);
    clock = start.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('24:58'), findsWidgets);
    await tester.tap(find.byTooltip(l10n.todoFocusPause));
    await settle(tester);
    expect(find.byTooltip(l10n.todoFocusResume), findsOneWidget);
    await unmountTodos(tester);
  });
}
