import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/feature_tips.dart';
import 'package:node_diary/ui/diaries/controllers/tag_filter_pull_hint_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diaries_tag_filter_test_support.dart';

void main() {
  const showDelay = TagFilterPullHintController.showDelay;
  const tagCount = 30;
  const hintText = '下拉查看全部 $tagCount 个标签';
  final hintFinder = find.byKey(DiaryTagFilterBar.pullHintKey);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  bool hintVisible(WidgetTester tester) =>
      tester.widget<DiaryTagFilterBar>(tagBarFinder).pullHintVisible;

  Future<FeatureTipRecord> storedRecord() async {
    final prefs = await SharedPreferences.getInstance();
    return FeatureTips.decode(
      prefs.getString('app.settings.feature_tips'),
    ).recordOf(FeatureTip.tagFilterPull);
  }

  /// Home mounts the page under a finished launch reveal; wait out the pause
  /// and let the hint row and its peek settle.
  Future<void> pumpHomeTagPage(
    WidgetTester tester, {
    int tagCount = tagCount,
    bool disableAnimations = false,
    bool underHome = true,
  }) async {
    await pumpTagPage(
      tester,
      tagCount: tagCount,
      diaries: createGestureDiaries(40),
      launchReveal: underHome ? kAlwaysCompleteAnimation : null,
      disableAnimations: disableAnimations,
    );
    await tester.pump(showDelay);
    await tester.pumpAndSettle();
  }

  testWidgets('a first-time user sees the hint until pulling the bar down', (
    tester,
  ) async {
    await pumpHomeTagPage(tester);

    expect(hintVisible(tester), isTrue);
    expect(find.text(hintText).hitTestable(), findsOneWidget);
    expect(await storedRecord(), const FeatureTipRecord(shown: 1));

    final barRect = tester.getRect(tagBarFinder);
    await dragTagPanel(
      tester,
      start: Offset(barRect.right - 24, barRect.top + 20),
      step: const Offset(0, 12),
    );

    expect(tagExpansionProgress(tester), 1);
    expect(hintVisible(tester), isFalse);
    expect(
      await storedRecord(),
      const FeatureTipRecord(learned: true, shown: 1),
    );
  });

  testWidgets('tapping the hint expands the tag bar', (tester) async {
    await pumpHomeTagPage(tester);

    await tester.tap(hintFinder);
    await tester.pumpAndSettle();

    expect(tagExpansionProgress(tester), 1);
    expect(hintVisible(tester), isFalse);
    expect((await storedRecord()).learned, isTrue);
  });

  testWidgets('after learning the gesture the hint never comes back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.feature_tips': '{"tagFilterPull":{"learned":true}}',
    });
    await pumpHomeTagPage(tester);
    await tester.pump(showDelay * 3);

    expect(hintVisible(tester), isFalse);
    expect(find.text(hintText).hitTestable(), findsNothing);
  });

  testWidgets('the hint stops after three launches without use', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.feature_tips': '{"tagFilterPull":{"shown":3}}',
    });
    await pumpHomeTagPage(tester);
    await tester.pump(showDelay * 3);

    expect(hintVisible(tester), isFalse);
  });

  testWidgets('no hint when every tag already fits in one row', (tester) async {
    await pumpHomeTagPage(tester, tagCount: 1);
    await tester.pump(showDelay * 3);

    expect(hintVisible(tester), isFalse);
    expect(await storedRecord(), FeatureTipRecord.initial);
  });

  testWidgets('no hint outside Home’s launch choreography', (tester) async {
    await pumpHomeTagPage(tester, underHome: false);
    await tester.pump(showDelay * 3);

    expect(hintVisible(tester), isFalse);
  });

  testWidgets('scrolling the diaries dismisses the hint for this launch', (
    tester,
  ) async {
    await pumpHomeTagPage(tester);
    expect(hintVisible(tester), isTrue);

    await tester.drag(find.text('Diary 3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(hintVisible(tester), isFalse);

    await tester.pump(showDelay * 3);
    expect(hintVisible(tester), isFalse);
    expect(await storedRecord(), const FeatureTipRecord(shown: 1));
  });

  testWidgets('the hint hides by itself after a while', (tester) async {
    await pumpHomeTagPage(tester);
    expect(hintVisible(tester), isTrue);

    await tester.pump(TagFilterPullHintController.visibleDuration);
    await tester.pumpAndSettle();
    expect(hintVisible(tester), isFalse);
    expect(find.text(hintText).hitTestable(), findsNothing);
  });

  testWidgets('with reduced motion the hint appears without the peek', (
    tester,
  ) async {
    await pumpTagPage(
      tester,
      tagCount: tagCount,
      launchReveal: kAlwaysCompleteAnimation,
      disableAnimations: true,
    );
    final collapsedHeight = tester.getSize(tagBarFinder).height;

    await tester.pump(showDelay);
    await tester.pump();
    expect(hintVisible(tester), isTrue);
    // The row opens at once, and the tags never dip below it.
    final withHint = collapsedHeight + DiaryTagFilterBar.pullHintExtent;
    expect(tester.getSize(tagBarFinder).height, withHint);
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(tagBarFinder).height, withHint);
    }
  });
}
