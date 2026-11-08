import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/feature_tips.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../notebooks/notebook_test_support.dart';

/// 首页标签筛选栏的选择（#196）：单击只看一个标签（换掉已选的，再点取消），
/// 长按在已选的标签里增减（多选，同时带有才显示），桌面上 Ctrl / ⌘ + 点击
/// 与长按相同；单击换掉已选标签时提示一次长按可以多选。
void main() {
  late int work;
  late int travel;

  Future<DiaryDraftsHarness> pumpHome(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    work = (await tester.runAsync(
      () => h.database.createTag(name: '工作', color: 0xff336699),
    ))!;
    travel = (await tester.runAsync(
      () => h.database.createTag(name: '旅行', color: 0xff993366),
    ))!;
    Future<void> diary(String title, List<int> tagIds) async {
      await tester.runAsync(
        () => h.database.createDiary(
          title: title,
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
          tagIds: tagIds,
        ),
      );
    }

    await diary('只带工作', <int>[work]);
    await diary('只带旅行', <int>[travel]);
    await diary('两个都带', <int>[work, travel]);
    await h.pump(const DiariesPage());
    await h.settleAll();
    return h;
  }

  Finder chip(String name) => find.descendant(
    of: find.byType(DiaryTagFilterBar),
    matching: find.text(name),
  );

  Set<int> selected(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DiariesPage)),
  ).read(diaryFilterProvider).selectedTagIds;

  FeatureTipRecord tipRecord(DiaryDraftsHarness h) => FeatureTips.decode(
    h.settings.featureTipsRaw,
  ).recordOf(FeatureTip.tagFilterMultiSelect);

  const mobileTip = '长按标签可以同时选多个';

  testWidgets('a tap switches to one tag and a long press adds another', (
    tester,
  ) async {
    final h = await pumpHome(tester);

    await tester.tap(chip('工作'));
    await h.settleAll();
    expect(selected(tester), <int>{work});
    expect(find.text('只带工作'), findsOneWidget);
    expect(find.text('只带旅行'), findsNothing);
    // 从无到有不是“换掉”，不提示。
    expect(find.text(mobileTip), findsNothing);

    // 单击另一个标签：换成它，而不是两个都选。
    await tester.tap(chip('旅行'));
    await h.settleAll();
    expect(selected(tester), <int>{travel});
    expect(find.text('只带旅行'), findsOneWidget);
    expect(find.text('只带工作'), findsNothing);
    expect(find.text('两个都带'), findsOneWidget);
    expect(find.text(mobileTip), findsOneWidget);
    expect(tipRecord(h).shown, 1);

    // 长按：保留已选的，再加上它（同时带有才显示）。
    await tester.longPress(chip('工作'));
    await h.settleAll();
    expect(selected(tester), <int>{work, travel});
    expect(find.text('两个都带'), findsOneWidget);
    expect(find.text('只带工作'), findsNothing);
    expect(find.text('只带旅行'), findsNothing);
    expect(tipRecord(h).learned, isTrue);

    // 多选时单击其中一个：收成只选它；再点一次取消。
    await tester.tap(chip('旅行'));
    await h.settleAll();
    expect(selected(tester), <int>{travel});
    await tester.tap(chip('旅行'));
    await h.settleAll();
    expect(selected(tester), isEmpty);
    expect(find.text('只带工作'), findsOneWidget);

    // 长按已选的标签把它去掉，其余保留。
    await tester.longPress(chip('工作'));
    await h.settleAll();
    await tester.longPress(chip('旅行'));
    await h.settleAll();
    await tester.longPress(chip('工作'));
    await h.settleAll();
    expect(selected(tester), <int>{travel});
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('the multi-select tip shows once per run and not once learned', (
    tester,
  ) async {
    final h = await pumpHome(tester);

    await tester.tap(chip('工作'));
    await h.settleAll();
    await tester.tap(chip('旅行'));
    await h.settleAll();
    expect(find.text(mobileTip), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(DiariesPage)),
    ).removeCurrentSnackBar();
    await h.settleAll();

    // 同一次启动里再换一次：不再打扰。
    await tester.tap(chip('工作'));
    await h.settleAll();
    expect(selected(tester), <int>{work});
    expect(find.text(mobileTip), findsNothing);
    expect(tipRecord(h).shown, 1);
    expect(tipRecord(h).learned, isFalse);
    await h.unmount();
  });

  testWidgets('a learned tip stays quiet', (tester) async {
    final h = await pumpHome(tester);
    await tester.runAsync(
      () => h.settings.setFeatureTipsRaw(
        FeatureTips.empty
            .markLearned(FeatureTip.tagFilterMultiSelect)
            // 别的提示的进度不受影响。
            .markShown(FeatureTip.tagFilterPull)
            .encode(),
      ),
    );

    await tester.tap(chip('工作'));
    await h.settleAll();
    await tester.tap(chip('旅行'));
    await h.settleAll();
    expect(selected(tester), <int>{travel});
    expect(find.text(mobileTip), findsNothing);
    final tips = FeatureTips.decode(h.settings.featureTipsRaw);
    expect(tips.recordOf(FeatureTip.tagFilterPull).shown, 1);
    await h.unmount();
  });

  testWidgets('on desktop Ctrl + click adds a tag like a long press', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final h = await pumpHome(tester);

      await tester.tap(chip('工作'));
      await h.settleAll();
      await tester.tap(chip('旅行'));
      await h.settleAll();
      expect(selected(tester), <int>{travel});
      expect(find.text('按住 Ctrl 再点标签可以同时选多个'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(chip('工作'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await h.settleAll();
      expect(selected(tester), <int>{work, travel});
      expect(tipRecord(h).learned, isTrue);
      await h.unmount();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('on phones a held Ctrl key does not change a tap', (
    tester,
  ) async {
    final h = await pumpHome(tester);
    await tester.tap(chip('工作'));
    await h.settleAll();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(chip('旅行'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await h.settleAll();
    expect(selected(tester), <int>{travel});
    await h.unmount();
  });
}
