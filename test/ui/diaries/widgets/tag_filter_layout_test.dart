import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/expanded_tag_filter_list.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_chip.dart';

import 'tag_filter_bar_test_support.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final tagCount in <int>[1, 3, 8]) {
      testWidgets(
        'short expanded tag panels fit their rows with $tagCount tags '
        'in ${brightness.name} mode',
        (tester) async {
          tester.view.physicalSize = const Size(390, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            buildTagBarHarness(
              key: GlobalKey<TagBarHarnessState>(),
              tags: createTags(tagCount),
              initiallyExpanded: true,
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();

          final chip = find.byWidgetPredicate(
            (widget) =>
                widget is TagFilterChip && widget.label == 'Tag $tagCount',
          );
          expect(
            tester
                .getTopLeft(find.byKey(DiaryTagFilterBar.collapseHandleKey))
                .dy,
            tester.getBottomLeft(chip).dy,
          );
          final scroll = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(ExpandedTagFilterList),
              matching: find.byType(Scrollable),
            ),
          );
          expect(scroll.position.maxScrollExtent, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('empty tag panels stay collapsed after downward drags', (
    tester,
  ) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(0)));
    await tester.drag(find.byType(DiaryTagFilterBar), const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(key.currentState!.expanded, isFalse);
    expect(key.currentState!.verticalDragStarts, isEmpty);
    expect(find.byType(ExpandedTagFilterList), findsNothing);
    expect(tester.getSize(find.byType(DiaryTagFilterBar)).height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded panels resize when tags are added and removed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<TagBarHarnessState>();
    final bar = find.byType(DiaryTagFilterBar);

    Future<void> updateTags(int count) async {
      await tester.pumpWidget(
        buildTagBarHarness(
          key: key,
          tags: createTags(count),
          initiallyExpanded: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.expanded, isTrue);
      expect(tester.takeException(), isNull);
    }

    await updateTags(1);
    final oneRowHeight = tester.getSize(bar).height;
    await updateTags(8);
    expect(tester.getSize(bar).height, greaterThan(oneRowHeight));
    expect(
      tester.getSize(bar).height,
      lessThan(DiaryTagFilterBar.maxExpandedBarExtent),
    );
    await updateTags(30);
    expect(tester.getSize(bar).height, DiaryTagFilterBar.maxExpandedBarExtent);
    final scrollFinder = find.descendant(
      of: find.byType(ExpandedTagFilterList),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollFinder).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Tag 30').hitTestable(), findsOneWidget);

    await updateTags(1);
    expect(tester.getSize(bar).height, oneRowHeight);
    expect(tester.state<ScrollableState>(scrollFinder).position.pixels, 0);
    expect(find.text('Tag 1').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(DiaryTagFilterBar.collapseHandleKey));
    await tester.pumpAndSettle();
    expect(key.currentState!.expanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded panels reflow when the available width changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildTagBarHarness(
        key: GlobalKey<TagBarHarnessState>(),
        tags: createTags(8),
        initiallyExpanded: true,
      ),
    );
    await tester.pumpAndSettle();
    final bar = find.byType(DiaryTagFilterBar);
    final wideHeight = tester.getSize(bar).height;

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, greaterThan(wideHeight));
    tester.view.physicalSize = const Size(800, 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, wideHeight);
    expect(tester.takeException(), isNull);
  });
}
