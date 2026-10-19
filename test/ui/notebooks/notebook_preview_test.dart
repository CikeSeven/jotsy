import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/home/providers/home_tab_request_provider.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 预览页：信息栏里的日记本胶囊（点按回到首页打开那本），“更多”里的
/// “收进日记本”。
void main() {
  late String travel;
  late String work;
  late String diary;

  Future<DiaryDraftsHarness> open(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    travel = await h.notebook('旅行');
    work = await h.notebook('工作');
    diary = await h.diary('在京都', notebookIds: <String>[travel]);
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DiaryPreviewPage(diaryId: diary),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await tester.tap(find.text('home'));
    await h.settleAll();
    return h;
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.text('home')));

  testWidgets('shows notebook capsules that open the notebook at home', (
    tester,
  ) async {
    final h = await open(tester);
    final capsule = find.byKey(ValueKey<String>('preview_notebook_$travel'));
    expect(capsule, findsOneWidget);

    await tester.tap(capsule);
    await h.settleAll();
    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(
      container(tester).read(homeNotebookScopeProvider).notebookId,
      travel,
    );
    expect(container(tester).read(homeDiariesTabRequestProvider), 1);
    await h.unmount();
  });

  testWidgets('More → add to notebook updates the memberships', (tester) async {
    final h = await open(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    final item = find.widgetWithText(ListTile, '收进日记本');
    expect(item, findsOneWidget);
    expect(
      find.descendant(of: item, matching: find.text('旅行')),
      findsOneWidget,
    );

    await tester.tap(item);
    await h.settleAll();
    await tester.tap(find.byKey(ValueKey<String>('notebook_pick_$work')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();

    final ids = (await tester.runAsync(
      () => h.database.getDiaryNotebookIds(diary),
    ))!;
    expect(ids, <String>{travel, work});
    expect(find.text('已收进 1 本日记本'), findsOneWidget);
    // 胶囊随数据库流出现。
    expect(
      find.byKey(ValueKey<String>('preview_notebook_$work')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await h.unmount();
  });
}
