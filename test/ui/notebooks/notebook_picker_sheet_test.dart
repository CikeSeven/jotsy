import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_picker_sheet.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 收录选择器：只列没合上的普通日记本，三态显示与点按循环，“完成”只返回
/// 变化；单选模式点一下即返回且不列当前这本。
void main() {
  Future<NotebookPickerResult?> openPicker(
    DiaryDraftsHarness h, {
    NotebookPickerMode mode = NotebookPickerMode.multi,
    Map<String, NotebookPickState> initial = const {},
    Set<String> excluded = const {},
  }) async {
    final completer = Completer<NotebookPickerResult?>();
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => completer.complete(
                showNotebookPickerSheet(
                  context,
                  mode: mode,
                  initial: initial,
                  excludedIds: excluded,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await h.tester.tap(find.text('open'));
    await h.settleAll();
    return null;
  }

  Finder pickRow(String id) =>
      find.byKey(ValueKey<String>('notebook_pick_$id'));

  Finder iconIn(String id, FaIconData icon) =>
      find.descendant(of: pickRow(id), matching: find.byIcon(icon.data));

  testWidgets('lists open manual notebooks with tri-state checks', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final food = await h.notebook('美食', visibility: NotebookVisibility.locked);
    final work = await h.notebook('工作');
    await h.notebook('旧事', closed: true);
    await h.notebook('有照片的', kind: NotebookKind.smart);
    await openPicker(
      h,
      initial: <String, NotebookPickState>{
        travel: NotebookPickState.all,
        food: NotebookPickState.some,
      },
    );

    expect(find.text('收进日记本'), findsOneWidget);
    expect(find.text('新建日记本'), findsOneWidget);
    expect(find.text('旧事'), findsNothing);
    expect(find.text('有照片的'), findsNothing);
    expect(iconIn(travel, FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    expect(iconIn(food, FontAwesomeIcons.circleMinus), findsOneWidget);
    expect(iconIn(food, FontAwesomeIcons.lock), findsOneWidget);
    expect(iconIn(work, FontAwesomeIcons.circle), findsOneWidget);

    // 部分 → 全部 → 都不在。
    await tester.tap(pickRow(food));
    await tester.pumpAndSettle();
    expect(iconIn(food, FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    await tester.tap(pickRow(food));
    await tester.pumpAndSettle();
    expect(iconIn(food, FontAwesomeIcons.circle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('done returns only the changes; no change returns null', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final work = await h.notebook('工作');
    NotebookPickerResult? result;
    var closed = false;
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showNotebookPickerSheet(
                  context,
                  initial: <String, NotebookPickState>{
                    travel: NotebookPickState.all,
                  },
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    await tester.tap(pickRow(travel));
    await tester.tap(pickRow(work));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();
    expect(closed, isTrue);
    expect(
      result,
      NotebookPickerResult(add: <String>{work}, remove: <String>{travel}),
    );

    closed = false;
    await tester.tap(find.text('open'));
    await h.settleAll();
    await tester.tap(find.text('完成'));
    await h.settleAll();
    expect(closed, isTrue);
    expect(result, isNull);
    await h.unmount();
  });

  testWidgets('single mode excludes the current notebook and returns on tap', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final work = await h.notebook('工作');
    NotebookPickerResult? result;
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showNotebookPickerSheet(
                  context,
                  mode: NotebookPickerMode.single,
                  title: '移动到…',
                  excludedIds: <String>{travel},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    expect(find.text('移动到…'), findsOneWidget);
    expect(pickRow(travel), findsNothing);
    expect(find.text('完成'), findsNothing);
    await tester.tap(pickRow(work));
    await h.settleAll();
    expect(result, NotebookPickerResult(add: <String>{work}));
    await h.unmount();
  });

  testWidgets('shows a hint when there is no notebook to choose', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('有照片的', kind: NotebookKind.smart);
    await openPicker(h);
    expect(find.text('还没有可以收进的日记本'), findsOneWidget);
    expect(find.text('新建日记本'), findsOneWidget);
    await h.unmount();
  });
}
