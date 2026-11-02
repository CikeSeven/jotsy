import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/sections/diary_tag_batch_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_tag_search_bar.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/expressive_test_theme.dart';
import '../../notebooks/notebook_test_support.dart';

/// 多选日记的标签面板：三态初始状态、点按循环与日记本选本面板一致，
/// “完成”只返回变化，检索词可直接新建并勾选。
void main() {
  Finder row(int id) => find.byKey(ValueKey<String>('tag_batch_$id'));

  Finder iconIn(int id, FaIconData icon) =>
      find.descendant(of: row(id), matching: find.byIcon(icon.data));

  Future<int> tag(DiaryDraftsHarness h, String name) async => (await h.tester
      .runAsync(() => h.database.createTag(name: name, color: 0xff2196f3)))!;

  /// 放一个“open”按钮：点开面板，关闭后把结果交给 [onResult]。
  Future<void> host(
    DiaryDraftsHarness h, {
    required Map<int, TriStatePick> initial,
    required ValueChanged<TriStatePickResult<int>?> onResult,
  }) async {
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => onResult(
                await showDiaryTagBatchSheet(
                  context,
                  diaryCount: 3,
                  initial: initial,
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
  }

  testWidgets('shows each tag as all, some or none of the selection', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await tag(h, '旅行');
    final food = await tag(h, '美食');
    final work = await tag(h, '工作');
    await host(
      h,
      initial: <int, TriStatePick>{
        travel: TriStatePick.all,
        food: TriStatePick.some,
      },
      onResult: (_) {},
    );

    expect(find.text('给 3 篇日记设置标签'), findsOneWidget);
    expect(find.byType(PublishTagSearchBar), findsOneWidget);
    expect(iconIn(travel, FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    expect(iconIn(food, FontAwesomeIcons.circleMinus), findsOneWidget);
    expect(iconIn(work, FontAwesomeIcons.circle), findsOneWidget);

    // 部分 → 全部 → 都没有 → 全部。
    await tester.tap(row(food));
    await tester.pumpAndSettle();
    expect(iconIn(food, FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    await tester.tap(row(food));
    await tester.pumpAndSettle();
    expect(iconIn(food, FontAwesomeIcons.circle), findsOneWidget);
    await tester.tap(row(food));
    await tester.pumpAndSettle();
    expect(iconIn(food, FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('done returns only the changes; no change returns null', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await tag(h, '旅行');
    final food = await tag(h, '美食');
    final work = await tag(h, '工作');
    final reading = await tag(h, '读书');
    TriStatePickResult<int>? result;
    var closed = false;
    await host(
      h,
      initial: <int, TriStatePick>{
        travel: TriStatePick.all,
        food: TriStatePick.some,
        reading: TriStatePick.some,
      },
      onResult: (value) {
        result = value;
        closed = true;
      },
    );

    await tester.tap(row(travel)); // 全部 → 都没有：去掉
    await tester.tap(row(food)); // 部分 → 全部：加上
    await tester.tap(row(work)); // 都没有 → 全部：加上
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();
    expect(closed, isTrue);
    // 没点过的“部分有”（读书）不出现在结果里。
    expect(
      result,
      TriStatePickResult<int>(add: <int>{food, work}, remove: <int>{travel}),
    );

    closed = false;
    await tester.tap(find.text('open'));
    await h.settleAll();
    await tester.tap(row(travel));
    await tester.tap(row(travel)); // 点回初始状态，不算变化。
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();
    expect(closed, isTrue);
    expect(result, isNull);
    await h.unmount();
  });

  testWidgets('creating a tag from the search query selects it', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await tag(h, '旅行');
    TriStatePickResult<int>? result;
    await host(h, initial: const {}, onResult: (value) => result = value);

    await tester.enterText(
      find.descendant(
        of: find.byType(PublishTagSearchBar),
        matching: find.byType(TextField),
      ),
      '露营',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建「露营」'));
    await tester.pumpAndSettle();
    // 与发布面板同一个新建弹窗，名称已预填。
    await tester.tap(find.text('创建'));
    await h.settleAll();

    final created = (await tester.runAsync(
      () => h.database.watchAllTags().first,
    ))!.singleWhere((t) => t.name == '露营');
    expect(
      iconIn(created.id, FontAwesomeIcons.solidCircleCheck),
      findsOneWidget,
    );

    await tester.tap(find.text('完成'));
    await h.settleAll();
    expect(result, TriStatePickResult<int>(add: <int>{created.id}));
    await h.unmount();
  });

  testWidgets('fits a 320dp screen in dark mode', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(320, 640);
    for (final name in <String>['旅行', '美食', '工作', '读书', '电影']) {
      await tag(h, name);
    }
    await h.pump(
      Builder(
        builder: (context) => Theme(
          data: expressiveTestTheme(Brightness.dark),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showDiaryTagBatchSheet(context, diaryCount: 120),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    expect(find.text('给 120 篇日记设置标签'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });
}
