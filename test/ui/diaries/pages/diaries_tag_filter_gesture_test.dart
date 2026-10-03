import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/expanded_tag_filter_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diaries_tag_filter_test_support.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final brightness in Brightness.values) {
    for (final tagCount in <int>[3, 30]) {
      testWidgets(
        'slow vertical drags resize the actual pinned tag header with '
        '$tagCount tags in ${brightness.name} mode',
        (tester) async {
          await pumpTagPage(tester, brightness: brightness, tagCount: tagCount);
          final initialHeight = tester.getSize(tagBarFinder).height;
          expect(tagExpansionProgress(tester), 0);
          expect(verticalDiaryScroll(tester).position.maxScrollExtent, 0);

          final barRect = tester.getRect(tagBarFinder);
          await dragTagPanel(
            tester,
            start: Offset(barRect.right - 24, barRect.center.dy),
            step: const Offset(0, 10),
          );

          expect(tagExpansionProgress(tester), 1);
          expect(
            tester.getSize(tagBarFinder).height,
            greaterThan(initialHeight),
          );
          expect(
            tester.getSize(tagBarFinder).height,
            DiaryTagFilterBar.expandedBarExtent,
          );
          expect(verticalDiaryScroll(tester).position.pixels, 0);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(DiariesPage)),
          );
          expect(container.read(diaryFilterProvider).selectedTagIds, isEmpty);

          await dragTagPanel(
            tester,
            start: tester.getCenter(
              find.byKey(DiaryTagFilterBar.collapseHandleKey),
            ),
            step: const Offset(0, -10),
          );

          expect(tagExpansionProgress(tester), 0);
          expect(tester.getSize(tagBarFinder).height, initialHeight);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('short slow pulls expand and collapse without a fling', (
    tester,
  ) async {
    await pumpTagPage(tester, tagCount: 30);
    await dragTagPanel(
      tester,
      start: tester.getCenter(find.text('Tag 1')),
      step: const Offset(0, 4),
      steps: 8,
    );
    expect(tagExpansionProgress(tester), 1);

    await dragTagPanel(
      tester,
      start: tester.getCenter(find.byKey(DiaryTagFilterBar.collapseHandleKey)),
      step: const Offset(0, -4),
      steps: 8,
    );
    expect(tagExpansionProgress(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'device touch slop does not let the diary scroll steal tag pulls',
    (tester) async {
      await pumpTagPage(
        tester,
        tagCount: 30,
        diaries: createGestureDiaries(20),
        deviceTouchSlop: 8,
      );
      await dragTagPanel(
        tester,
        start: tester.getCenter(find.text('Tag 1')),
        step: const Offset(0, 4),
        steps: 8,
      );

      expect(tagExpansionProgress(tester), 1);
      expect(verticalDiaryScroll(tester).position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('horizontal tag scrolling does not expand or change home tabs', (
    tester,
  ) async {
    await pumpTagPage(tester, tagCount: 30);

    final horizontal = tester.state<ScrollableState>(
      find.descendant(
        of: tagBarFinder,
        matching: find.byWidgetPredicate((widget) => widget is Scrollable),
      ),
    );
    await dragTagPanel(
      tester,
      start: tester.getCenter(find.text('Tag 1')),
      step: const Offset(-12, 1),
    );

    expect(horizontal.position.pixels, greaterThan(0));
    expect(tagExpansionProgress(tester), 0);
    expect(find.byType(DiariesPage).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning a slow pull to its starting position cancels it', (
    tester,
  ) async {
    await pumpTagPage(tester, tagCount: 30);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tag 1')),
    );
    await tester.pump(const Duration(milliseconds: 40));
    for (final direction in <double>[1, -1]) {
      for (var index = 0; index < 8; index++) {
        await gesture.moveBy(Offset(0, 4 * direction));
        await tester.pump(const Duration(milliseconds: 32));
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tagExpansionProgress(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diary scrolling starts on diary content, not the tag region', (
    tester,
  ) async {
    await pumpTagPage(tester, tagCount: 3, diaries: createGestureDiaries(20));
    expect(
      verticalDiaryScroll(tester).position.maxScrollExtent,
      greaterThan(0),
    );

    await dragTagPanel(
      tester,
      start: tester.getCenter(find.text('Tag 1')),
      step: const Offset(0, -10),
    );

    expect(verticalDiaryScroll(tester).position.pixels, 0);
    expect(tagExpansionProgress(tester), 0);
    await dragTagPanel(
      tester,
      start: tester.getCenter(find.text('Diary 2')),
      step: const Offset(0, -10),
    );
    expect(verticalDiaryScroll(tester).position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'expanded content scrolls independently and only its footer collapses',
    (tester) async {
      await pumpTagPage(
        tester,
        tagCount: 100,
        diaries: createGestureDiaries(20),
        deviceTouchSlop: 8,
      );
      await dragTagPanel(
        tester,
        start: tester.getCenter(find.text('Tag 1')),
        step: const Offset(0, 4),
        steps: 8,
      );
      expect(tagExpansionProgress(tester), 1);
      final content = find.byType(ExpandedTagFilterList);
      final inner = tester.state<ScrollableState>(
        find.descendant(of: content, matching: find.byType(Scrollable)),
      );
      await dragTagPanel(
        tester,
        start: tester.getCenter(content),
        step: const Offset(0, -10),
      );
      expect(inner.position.pixels, greaterThan(0));
      expect(tagExpansionProgress(tester), 1);
      expect(verticalDiaryScroll(tester).position.pixels, 0);
      inner.position.jumpTo(inner.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Tag 100').hitTestable(), findsOneWidget);
      await dragTagPanel(
        tester,
        start: tester.getCenter(content),
        step: const Offset(0, -10),
      );
      expect(tagExpansionProgress(tester), 1);
      expect(verticalDiaryScroll(tester).position.pixels, 0);
      await tester.tap(find.byKey(DiaryTagFilterBar.collapseHandleKey));
      await tester.pumpAndSettle();
      expect(tagExpansionProgress(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );
}
