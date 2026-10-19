import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_rule_count_controller.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 编辑页的规则区：示例、添加 / 编辑 / 移除条件、组合方式、实时篇数、
/// 没有条件时不能保存、编辑已有智能日记本时的未保存确认。
void main() {
  Future<(DiaryDraftsHarness, List<String?>)> open(
    WidgetTester tester, {
    Future<String?> Function(DiaryDraftsHarness h)? seed,
    NotebookKind initialKind = NotebookKind.smart,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    final notebookId = await seed?.call(h);
    final results = <String?>[];
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push(
                NotebookEditorPage.route(
                  notebookId: notebookId,
                  initialKind: initialKind,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    return (h, results);
  }

  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> showRules(DiaryDraftsHarness h) async {
    await h.tester.scrollUntilVisible(
      find.text('条件'),
      200,
      scrollable: scrollable(),
    );
    await h.tester.pumpAndSettle();
  }

  Future<void> tapVisible(DiaryDraftsHarness h, Finder finder) async {
    await h.tester.scrollUntilVisible(finder, 200, scrollable: scrollable());
    await h.tester.pumpAndSettle();
    await h.tester.tap(finder);
    await h.tester.pumpAndSettle();
  }

  /// 等防抖到期，再让 drift 的计数查询推送。
  Future<void> settleCount(DiaryDraftsHarness h) async {
    await h.tester.pump(NotebookRuleCountController.debounce);
    await h.settleAll();
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, '保存'));

  Future<String> pinnedDiary(DiaryDraftsHarness h, String title) async {
    final id = await h.diary(title);
    await h.tester.runAsync(() => h.database.pinDiary(id));
    return id;
  }

  testWidgets('an example fills the rule and the name, then saves', (
    tester,
  ) async {
    final (h, results) = await open(
      tester,
      seed: (h) async {
        await pinnedDiary(h, '置顶一');
        await h.diary('普通');
        return null;
      },
    );
    await showRules(h);
    expect(find.text('至少添加一个条件才能保存'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tapVisible(h, find.text('置顶的日记'));
    await settleCount(h);
    expect(find.text('已置顶'), findsOneWidget);
    expect(find.text('符合条件：1 篇'), findsOneWidget);
    // 示例只在还没有条件时出现。
    expect(find.text('从示例开始'), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final row = (await h.shelf()).single;
    expect(results, <String?>[row.notebookId]);
    expect(row.notebookKind, NotebookKind.smart);
    // 名称还空着时，示例一并填上名称。
    expect(row.name, '置顶的日记');
    expect(
      NotebookRuleSet.decode(row.parsedPayload.rules),
      NotebookRuleSet(
        rules: const <NotebookRule>[NotebookFlagRule(NotebookFlagKind.pinned)],
      ),
    );
    await h.unmount();
  });

  testWidgets('add, edit and remove a rule through the sheets', (tester) async {
    final (h, _) = await open(
      tester,
      seed: (h) async {
        await h.diary('樱花之旅');
        await h.diary('海边');
        return null;
      },
    );
    await tester.enterText(find.byType(TextField).first, '旅行');
    await showRules(h);

    await tapVisible(h, find.text('添加条件'));
    await tester.tap(find.text('关键词'));
    await tester.pumpAndSettle();
    final sheetField = find.byType(TextField).last;
    expect(find.widgetWithText(TextButton, '完成'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '完成'))
          .onPressed,
      isNull,
    );
    await tester.enterText(sheetField, '樱花');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    await settleCount(h);
    expect(find.text('标题或正文包含“樱花”'), findsOneWidget);
    expect(find.text('符合条件：1 篇'), findsOneWidget);

    // 编辑：面板带着原值打开。
    await tester.tap(find.text('标题或正文包含“樱花”'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '樱花'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '海');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    await settleCount(h);
    expect(find.text('标题或正文包含“海”'), findsOneWidget);
    expect(find.text('符合条件：1 篇'), findsOneWidget);

    // 移除：行收起后规则清空，保存键回到不可用。
    await tester.tap(find.byTooltip('移除条件'));
    await tester.pumpAndSettle();
    expect(find.text('标题或正文包含“海”'), findsNothing);
    expect(find.text('至少添加一个条件才能保存'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    await h.unmount();
  });

  testWidgets('switching all / any updates the live count', (tester) async {
    final (h, _) = await open(
      tester,
      seed: (h) async {
        await pinnedDiary(h, '置顶一');
        await h.diary('普通');
        return null;
      },
    );
    await showRules(h);
    await tapVisible(h, find.text('置顶的日记'));
    await tapVisible(h, find.text('添加条件'));
    await tester.tap(find.text('封面与置顶'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('有封面'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    await settleCount(h);
    // 全部满足：既置顶又有封面，没有。
    expect(find.text('符合条件：0 篇'), findsOneWidget);

    await tapVisible(h, find.text('任一满足'));
    await settleCount(h);
    expect(find.text('符合条件：1 篇'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the date sheet builds a recent-days rule', (tester) async {
    final (h, _) = await open(tester);
    await showRules(h);
    await tapVisible(h, find.text('添加条件'));
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    // 默认“最近几天”30 天，加一天。
    await tester.tap(find.byTooltip('增加一天'));
    await tester.pumpAndSettle();
    expect(find.text('最近 31 天'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    expect(find.text('最近 31 天'), findsOneWidget);

    await tapVisible(h, find.text('添加条件'));
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每年某月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3月'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    expect(find.text('每年 3 月'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('editing a smart notebook loads rules and tracks changes', (
    tester,
  ) async {
    final (h, results) = await open(
      tester,
      seed: (h) => h.notebook(
        '有图',
        kind: NotebookKind.smart,
        payload: NotebookPayload(
          rules: NotebookRuleSet(
            rules: <NotebookRule>[
              const NotebookMediaRule(NotebookMediaKind.image),
              NotebookUnknownRule(const <String, Object?>{'type': 'future'}),
            ],
          ).encode(),
        ),
      ),
    );
    await showRules(h);
    expect(find.text('有图片'), findsOneWidget);
    expect(find.text('无法识别的条件（来自更新的版本）'), findsOneWidget);
    // 智能日记本没有类型与隐私设置。
    expect(find.text('隐私'), findsNothing);

    await tapVisible(h, find.text('任一满足'));
    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.autoT0131), findsOneWidget);
    await tester.tap(find.text(h.l10n.commonCancel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final row = (await h.shelf()).single;
    expect(results, <String?>[row.notebookId]);
    final saved = NotebookRuleSet.decode(row.parsedPayload.rules);
    expect(saved.match, NotebookRuleMatch.any);
    // 认不出的规则原样保存回去。
    expect(saved.rules.last, isA<NotebookUnknownRule>());
    expect(saved.rules.last.toJson(), <String, Object?>{'type': 'future'});
    await h.unmount();
  });

  testWidgets('manual notebooks never store rules', (tester) async {
    final (h, _) = await open(tester, initialKind: NotebookKind.manual);
    await tester.enterText(find.byType(TextField).first, '旅行');
    await tester.pump();
    await tapVisible(h, find.text('智能'));
    await showRules(h);
    await tapVisible(h, find.text('最近 30 天'));
    await tapVisible(h, find.text('普通'));
    expect(find.text('条件'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final row = (await h.shelf()).single;
    expect(row.notebookKind, NotebookKind.manual);
    expect(row.parsedPayload.rules, isNull);
    await h.unmount();
  });

  testWidgets('the rules section and sheets fit a 320dp screen', (
    tester,
  ) async {
    final (h, _) = await open(tester);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await showRules(h);
    await tapVisible(h, find.text('最近 30 天'));
    await tapVisible(h, find.text('添加条件'));
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每年某月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近几天'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    expect(find.text('最近 30 天'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await h.unmount();
  });
}
