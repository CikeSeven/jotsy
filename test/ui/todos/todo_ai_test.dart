import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/sections/todo_detail_body.dart';
import 'package:node_diary/ui/todos/widgets/todo_ai_organize_item.dart';
import 'package:node_diary/ui/todos/widgets/todo_quick_add_sheet.dart';

import '../../support/fake_ai.dart';
import 'todos_page_harness.dart';

/// 待办助手：详情步骤卡的“AI 拆解”与快速新建的“AI 整理”只在 AI 可用且
/// 待办模块开启时出现；拆解的建议去掉已有的、勾掉的不写；整理逐条校验，
/// 可改标题，确认后一次建好。
void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;
  var reply = '';

  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> pump(
    WidgetTester tester, {
    bool featureOn = true,
    bool configured = true,
    bool moduleOn = true,
    Future<void> Function(AppDatabase db)? seed,
  }) {
    requests = <AiRequest>[];
    return pumpTodosPage(
      tester,
      width: 900,
      height: 1200,
      todoSettings: const TodoSettings(defaultViewKey: 'all'),
      seed: seed,
      prepare: (SettingsService settings) async {
        store = await AiProviderStore.create();
        addTearDown(store.dispose);
        if (configured) await seedFakeAiProvider(store);
        if (featureOn) await settings.setAppFeaturesRaw('{"ai":true}');
        if (!moduleOn) {
          await saveAiPreferences(
            settings,
            const AiPreferences().withModule(AiModule.todos, false),
          );
        }
      },
      overrides: [
        aiProviderStoreProvider.overrideWith((ref) async => store),
        aiServiceProvider.overrideWith(
          (ref) async =>
              fakeAiService(store, reply: (_) => reply, requests: requests),
        ),
      ],
    );
  }

  Future<void> openQuickAdd(WidgetTester tester) async {
    showTodoQuickAddSheet(tester.element(find.byType(TodosPage))).ignore();
    await settle(tester);
  }

  Finder quickInput() => find
      .descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      )
      .first;

  for (final (String name, bool featureOn, bool configured, bool moduleOn)
      in <(String, bool, bool, bool)>[
        ('AI is off', false, true, true),
        ('no service is set up', true, false, true),
        ('the to-do module is off', true, true, false),
      ]) {
    testWidgets('no AI entries when $name', (tester) async {
      await pump(
        tester,
        featureOn: featureOn,
        configured: configured,
        moduleOn: moduleOn,
        seed: (db) => db.createTodo(const TodoInput(title: '装修客厅')),
      );
      final l10n = todoL10n(tester);
      await tester.tap(find.text('装修客厅'));
      await settle(tester);
      expect(find.byType(TodoDetailBody), findsOneWidget);
      expect(find.text(l10n.todoAiBreakdown), findsNothing);
      await unmountTodos(tester);

      await pump(
        tester,
        featureOn: featureOn,
        configured: configured,
        moduleOn: moduleOn,
      );
      await openQuickAdd(tester);
      await tester.enterText(quickInput(), '明天交房租，周五约牙医');
      await settle(tester);
      expect(find.byTooltip(l10n.todoAiOrganize), findsNothing);
      await unmountTodos(tester);
    });
  }

  testWidgets('AI breakdown adds the ticked new steps after the old ones', (
    tester,
  ) async {
    reply = '1. 量尺寸\n2. 选材料\n- 找师傅\n以下可选：\n[ ] 约时间';
    final db = await pump(
      tester,
      seed: (db) => db.createTodo(
        const TodoInput(
          title: '装修客厅',
          steps: <TodoStep>[TodoStep(id: 's1', title: '量尺寸')],
        ),
      ),
    );
    final l10n = todoL10n(tester);
    await tester.tap(find.text('装修客厅'));
    await settle(tester);
    await tester.tap(find.text(l10n.todoAiBreakdown));
    await settle(tester);

    expect(requests, hasLength(1));
    final sent = requests.single.messages.single.text;
    expect(sent, contains('装修客厅'));
    expect(sent, contains('量尺寸'), reason: '已有的步骤一起发给模型');
    // 已有的“量尺寸”与引导句不算；编号、符号与勾选框去掉。
    expect(find.text(l10n.todoAiStepsTitle), findsOneWidget);
    expect(find.text('选材料'), findsOneWidget);
    expect(find.text('约时间'), findsOneWidget);

    await tester.tap(find.text('找师傅'));
    await settle(tester);
    await tester.tap(find.text(l10n.todoAiUseSteps(2)));
    await settle(tester);
    final row = await todoRowTitled(tester, db, '装修客厅');
    expect(decodeTodoSteps(row.steps).map((step) => step.title), <String>[
      '量尺寸',
      '选材料',
      '约时间',
    ]);
    // 预览收起（收起后仍画最后的内容，但已经点不到）。
    expect(find.text(l10n.todoAiStepsTitle).hitTestable(), findsNothing);
    await unmountTodos(tester);
  });

  testWidgets('AI organize checks each field and creates the to-dos at once', (
    tester,
  ) async {
    final tomorrow = todoToday.add(const Duration(days: 1));
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    late String life;
    reply = <String>[
      '{"title": "交房租", "date": "${iso(tomorrow)}", "time": "09:30", '
          '"list": "生活", "priority": 3}',
      '{"title": "买猫粮", "tags": ["@宠物"], "list": "不存在的清单"}',
      '这一行不是 JSON',
      '{"title": "  "}',
      '{"title": "约牙医", "date": "2026-02-30", "priority": 9}',
    ].join('\n');
    final db = await pump(
      tester,
      seed: (db) async => life = await db.createTodoList(name: '生活'),
    );
    final l10n = todoL10n(tester);
    await openQuickAdd(tester);
    await tester.enterText(quickInput(), '明天早上交房租，顺便买猫粮，还要约牙医');
    await settle(tester);
    await tester.tap(find.byTooltip(l10n.todoAiOrganize));
    await settle(tester);

    expect(find.byType(TodoAiOrganizeItem), findsNWidgets(3));
    final sent = requests.single.messages.single.text;
    expect(sent, contains('生活'), reason: '清单名发给模型挑');
    // 第二条改个标题。
    await tester.enterText(
      find.descendant(
        of: find.byType(TodoAiOrganizeItem).at(1),
        matching: find.byType(TextField),
      ),
      '买猫粮和猫砂',
    );
    await settle(tester);
    await tester.tap(find.text(l10n.todoAiAddTodos(3)));
    await settle(tester);

    final rent = await todoRowTitled(tester, db, '交房租');
    expect(rent.listId, life);
    expect(rent.dueDate, iso(tomorrow));
    expect(rent.dueMinute, 9 * 60 + 30);
    expect(rent.priority, TodoPriority.high.index);
    final food = await todoRowTitled(tester, db, '买猫粮和猫砂');
    expect(food.listId, isNull, reason: '认不出的清单不带');
    expect(TodoTags.ofMetadataText(food.metadata), <String>['宠物']);
    final dentist = await todoRowTitled(tester, db, '约牙医');
    expect(dentist.dueDate, isNull, reason: '不存在的日子丢掉');
    expect(dentist.priority, TodoPriority.none.index);
    // 原文清空，三条进了“已添加”。
    expect(tester.widget<TextField>(quickInput()).controller!.text, isEmpty);
    await unmountTodos(tester);
  });
}
