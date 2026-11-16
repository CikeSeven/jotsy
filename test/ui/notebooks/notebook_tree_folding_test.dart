import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_choice_sheet.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_picker_sheet.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_tree_rows.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 选本列表的收起：有子本的行尾可收起 / 展开（不改勾选），收起状态与管理页
/// 共用；打开时选中的本子所在的上级按展开排。
void main() {
  Finder pickRow(String id) =>
      find.byKey(ValueKey<String>('notebook_pick_$id'));
  Finder pickToggle(String id) =>
      find.byKey(ValueKey<String>('notebook_pick_toggle_$id'));
  Finder choiceRow(String id) =>
      find.byKey(ValueKey<String>('notebook_choice_$id'));
  Finder choiceToggle(String id) =>
      find.byKey(ValueKey<String>('notebook_choice_toggle_$id'));

  Finder presenceOf(Finder row) =>
      find.ancestor(of: row, matching: find.byType(ListItemPresence)).first;

  /// 行是否显示着：没收起，且已经展开到原高（收起的行收到 0 高度）。
  bool shown(WidgetTester tester, Finder row) {
    final presence = presenceOf(row);
    return tester.widget<ListItemPresence>(presence).visible &&
        tester.getSize(presence).height > 0;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.text('open')));

  Future<void> pumpOpener(
    DiaryDraftsHarness h,
    Future<Object?> Function(BuildContext context) open,
  ) => h.pump(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => unawaited(open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('the picker folds sub-notebooks without touching the checks', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final year = await h.notebook('2025', parentId: travel);
    final tokyo = await h.notebook('东京', parentId: year);
    final books = await h.notebook('读书');
    await pumpOpener(
      h,
      (context) => showNotebookPickerSheet(
        context,
        initial: <String, NotebookPickState>{year: NotebookPickState.all},
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();

    // 只有下面有子本的行有展开 / 收起，默认展开。
    expect(pickToggle(travel), findsOneWidget);
    expect(pickToggle(year), findsOneWidget);
    expect(pickToggle(tokyo), findsNothing);
    expect(pickToggle(books), findsNothing);
    expect(find.byTooltip('收起子本'), findsNWidgets(2));
    for (final id in <String>[travel, year, tokyo, books]) {
      expect(shown(tester, pickRow(id)), isTrue);
    }

    await tester.tap(pickToggle(travel));
    await tester.pumpAndSettle();
    expect(shown(tester, pickRow(year)), isFalse);
    expect(shown(tester, pickRow(tokyo)), isFalse);
    expect(shown(tester, pickRow(books)), isTrue);
    expect(find.byTooltip('展开子本'), findsOneWidget);
    // 点箭头不改勾选；收起状态与管理页共用。
    expect(
      find.descendant(
        of: pickRow(year),
        matching: find.byIcon(FontAwesomeIcons.solidCircleCheck.data),
      ),
      findsOneWidget,
    );
    expect(containerOf(tester).read(notebookTreeCollapsedProvider), <String>{
      travel,
    });

    await tester.tap(pickToggle(travel));
    await tester.pumpAndSettle();
    expect(shown(tester, pickRow(year)), isTrue);
    expect(shown(tester, pickRow(tokyo)), isTrue);
    expect(containerOf(tester).read(notebookTreeCollapsedProvider), isEmpty);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('opening reveals checked notebooks inside collapsed parents', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final tokyo = await h.notebook('东京', parentId: travel);
    final food = await h.notebook('美食');
    final snacks = await h.notebook('小吃', parentId: food);
    await pumpOpener(
      h,
      (context) => showNotebookPickerSheet(
        context,
        initial: <String, NotebookPickState>{tokyo: NotebookPickState.some},
      ),
    );
    containerOf(tester)
        .read(notebookTreeCollapsedProvider.notifier)
        .collapseAll(<String>[travel, food]);
    await tester.tap(find.text('open'));
    await h.settleAll();

    // 勾着的东京露出来；没勾的小吃照旧收着。
    expect(shown(tester, pickRow(tokyo)), isTrue);
    expect(shown(tester, pickRow(snacks)), isFalse);

    // 露出只在这个面板里，不改共用状态；再收起就照常收起。
    final collapsed = containerOf(tester).read(notebookTreeCollapsedProvider);
    expect(collapsed, <String>{travel, food});
    await tester.tap(pickToggle(travel));
    await tester.pumpAndSettle();
    expect(shown(tester, pickRow(tokyo)), isFalse);
    expect(containerOf(tester).read(notebookTreeCollapsedProvider), <String>{
      travel,
      food,
    });
    await h.unmount();
  });

  testWidgets('the single-choice sheet lists the tree, folds and returns '
      'the tapped notebook', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final tokyo = await h.notebook('东京', parentId: travel);
    final books = await h.notebook('读书');
    // 书架顺序把读书排在东京前面；面板按树序，东京紧跟旅行。
    await tester.runAsync(
      () => h.database.reorderNotebooks(<String>[travel, books, tokyo]),
    );
    final results = <NotebookChoiceResult?>[];
    await pumpOpener(h, (context) async {
      final container = ProviderScope.containerOf(context);
      final tree = container.read(notebookTreeProvider)!;
      final result = await showNotebookChoiceSheet(
        context,
        title: '选一本',
        rows: notebookTreeRows(tree),
        selectedId: tokyo,
        lead: const NotebookChoiceLead(
          label: '全部',
          icon: FontAwesomeIcons.layerGroup,
        ),
      );
      results.add(result);
      return result;
    });
    // 书架常驻订阅（应用里由首页订阅着），开面板时取当前的树。
    final shelf = containerOf(tester).listen(notebooksProvider, (_, _) {});
    addTearDown(shelf.close);
    // 选中的东京在收起的旅行下面：打开时露出来。
    containerOf(tester)
        .read(notebookTreeCollapsedProvider.notifier)
        .collapseAll(<String>[travel]);
    await h.settleAll();
    await tester.tap(find.text('open'));
    await h.settleAll();

    final top = <String, double>{
      for (final id in <String>[travel, tokyo, books])
        id: tester.getTopLeft(choiceRow(id)).dy,
    };
    expect(top[travel]!, lessThan(top[tokyo]!));
    expect(top[tokyo]!, lessThan(top[books]!));
    expect(
      tester.getTopLeft(find.text('东京')).dx,
      tester.getTopLeft(find.text('旅行')).dx + notebookTreeIndentStep,
    );
    expect(shown(tester, choiceRow(tokyo)), isTrue);
    expect(choiceToggle(travel), findsOneWidget);
    expect(choiceToggle(books), findsNothing);

    await tester.tap(choiceToggle(travel));
    await tester.pumpAndSettle();
    expect(shown(tester, choiceRow(tokyo)), isFalse);
    expect(results, isEmpty);

    await tester.tap(choiceRow(books));
    await h.settleAll();
    expect(results.single?.notebookId, books);

    await tester.tap(find.text('open'));
    await h.settleAll();
    await tester.tap(find.text('全部'));
    await h.settleAll();
    expect(results.last, isNotNull);
    expect(results.last?.notebookId, isNull);
    await h.unmount();
  });
}
