import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_action_sheets.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_sliver.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 写作目标的界面：编辑页“写作目标”分组读写 payload.goal（开关、周期、
/// 篇数，参与未保存确认）；首页头部卡片的目标行文字与达成后的变化、点按
/// 打开编辑；没有目标时不显示。
void main() {
  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> tapVisible(DiaryDraftsHarness h, Finder finder) async {
    await h.tester.scrollUntilVisible(finder, 200, scrollable: scrollable());
    await h.tester.pumpAndSettle();
    await h.tester.tap(finder);
    await h.tester.pumpAndSettle();
  }

  Future<DiaryDraftsHarness> openEditor(
    WidgetTester tester,
    NotebookPayload payload,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final id = await h.notebook('旅行', payload: payload);
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(NotebookEditorPage.route(notebookId: id)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    return h;
  }

  testWidgets('editor goal group round-trips payload.goal', (tester) async {
    final h = await openEditor(
      tester,
      NotebookPayload(
        goal: NotebookGoal(period: NotebookGoalPeriod.week, target: 3),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('每周写 3 篇'),
      200,
      scrollable: scrollable(),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('notebook_goal_switch')),
              matching: find.byType(SwitchListTile),
            ),
          )
          .value,
      isTrue,
    );

    await tapVisible(h, find.text('每天'));
    await tapVisible(
      h,
      find.byKey(const ValueKey<String>('notebook_goal_plus')),
    );
    await tapVisible(
      h,
      find.byKey(const ValueKey<String>('notebook_goal_plus')),
    );
    expect(find.text('每天写 5 篇'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    expect(
      (await h.shelf()).single.parsedPayload.goal,
      NotebookGoal(period: NotebookGoalPeriod.day, target: 5),
    );
    await h.unmount();
  });

  testWidgets('turning the goal off clears it and counts as a change', (
    tester,
  ) async {
    final h = await openEditor(
      tester,
      NotebookPayload(
        goal: NotebookGoal(period: NotebookGoalPeriod.month, target: 1),
      ),
    );
    await tapVisible(
      h,
      find.byKey(const ValueKey<String>('notebook_goal_switch')),
    );
    expect(find.text('每月写 1 篇'), findsNothing);
    // 篇数到下限时减号不可用（重新打开后检查）。
    await tapVisible(
      h,
      find.byKey(const ValueKey<String>('notebook_goal_switch')),
    );
    final minus = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('notebook_goal_minus')),
    );
    expect(minus.onPressed, isNull);
    await tapVisible(
      h,
      find.byKey(const ValueKey<String>('notebook_goal_switch')),
    );

    // 有未保存改动：返回先确认。
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    expect((await h.shelf()).single.parsedPayload.goal, isNull);
    await h.unmount();
  });

  group('header goal row', () {
    Future<(DiaryDraftsHarness, String, List<NotebookAction>)> pumpHeader(
      WidgetTester tester, {
      NotebookGoal? goal,
      int entries = 0,
    }) async {
      final h = await DiaryDraftsHarness.create(tester);
      final id = await h.notebook('旅行', payload: NotebookPayload(goal: goal));
      for (var i = 0; i < entries; i++) {
        await h.diary('第 $i 篇', notebookIds: <String>[id]);
      }
      final row = (await h.notebookRow(id))!;
      final actions = <NotebookAction>[];
      await h.pump(
        Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              NotebookHeaderSliver(
                notebook: NotebookView(row),
                onAction: actions.add,
                onOpenInsights: () {},
              ),
            ],
          ),
        ),
      );
      await h.settleAll();
      return (h, id, actions);
    }

    String goalLine(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey<String>('notebook_goal_line')))
        .data!;

    testWidgets('shows weekly progress and opens the editor on tap', (
      tester,
    ) async {
      final (h, id, actions) = await pumpHeader(
        tester,
        goal: NotebookGoal(period: NotebookGoalPeriod.week, target: 3),
        entries: 2,
      );
      expect(goalLine(tester), '本周 2 / 3 篇');
      expect(find.text('统计'), findsOneWidget);

      await h.diary('第三篇', notebookIds: <String>[id]);
      await h.settleAll();
      expect(goalLine(tester), '本周已完成 ✓ · 连续达成 1 周');

      await tester.tap(
        find.byKey(const ValueKey<String>('notebook_goal_line')),
      );
      await tester.pumpAndSettle();
      expect(actions, <NotebookAction>[NotebookAction.edit]);
      await h.unmount();
    });

    testWidgets('no goal means no goal row', (tester) async {
      final (h, _, _) = await pumpHeader(tester, entries: 1);
      expect(
        find.byKey(const ValueKey<String>('notebook_goal_line')),
        findsNothing,
      );
      await h.unmount();
    });
  });
}
