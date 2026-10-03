import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/expanded_tag_filter_list.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_chip.dart';

import 'tag_filter_bar_test_support.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final selected in <bool>[false, true]) {
      testWidgets('expansion keeps chip dimensions in ${brightness.name} mode '
          'when selected is $selected', (tester) async {
        final key = GlobalKey<TagBarHarnessState>();
        await tester.pumpWidget(
          buildTagBarHarness(
            key: key,
            tags: createTags(8),
            brightness: brightness,
            selectedTagIds: selected ? <int>{1} : <int>{},
          ),
        );
        await tester.pumpAndSettle();
        final chip = find.byWidgetPredicate(
          (widget) => widget is TagFilterChip && widget.label == 'Tag 1',
        );
        final before = tester.getSize(chip);
        await tester.drag(find.text('Tag 1'), const Offset(0, 100));
        await tester.pumpAndSettle();

        expect(key.currentState!.expanded, isTrue);
        expect(tester.getSize(chip), before);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final expanded in <bool>[false, true]) {
    testWidgets(
      'horizontal drags cannot leave the tag region when expanded is $expanded',
      (tester) async {
        final controller = PageController();
        addTearDown(controller.dispose);
        final key = GlobalKey<TagBarHarnessState>();
        await tester.pumpWidget(
          buildTagBarHarness(
            key: key,
            tags: createTags(1),
            initiallyExpanded: expanded,
            pageController: controller,
          ),
        );
        await tester.pumpAndSettle();
        await tester.fling(find.text('Tag 1'), const Offset(-220, 0), 1000);
        await tester.pumpAndSettle();

        expect(controller.page, 0);
        expect(key.currentState!.expanded, expanded);
        expect(key.currentState!.pageScrollController.offset, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'downward drag expands from empty space when both lists fit the viewport',
    (tester) async {
      final key = GlobalKey<TagBarHarnessState>();
      await tester.pumpWidget(
        buildTagBarHarness(
          key: key,
          tags: createTags(3),
          pageContentHeight: 120,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        key.currentState!.pageScrollController.position.maxScrollExtent,
        0,
      );
      final barRect = tester.getRect(find.byType(DiaryTagFilterBar));
      final gesture = await tester.startGesture(
        Offset(barRect.right - 24, barRect.center.dy),
      );
      // Allow Flutter to resolve an arena with no scrollable/tap competitor
      // before moving, as happens during an ordinary slow touch on a device.
      await tester.pump(const Duration(milliseconds: 40));
      for (var step = 0; step < 9; step++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(key.currentState!.verticalDragStarts, <bool>[true]);
      expect(key.currentState!.expanded, isTrue);
      expect(find.byType(ExpandedTagFilterList), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vertical drag expands and upward drag collapses the tag rows', (
    tester,
  ) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(8)));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Tag 1'), const Offset(0, 90));
    await tester.pumpAndSettle();

    expect(key.currentState!.expanded, isTrue);
    expect(find.byType(ExpandedTagFilterList), findsOneWidget);
    expect(
      tester.getSize(find.byType(DiaryTagFilterBar)).height,
      DiaryTagFilterBar.expandedBarExtent,
    );

    await tester.drag(
      find.byKey(DiaryTagFilterBar.collapseHandleKey),
      const Offset(0, -90),
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.expanded, isFalse);
    expect(find.byType(ExpandedTagFilterList), findsNothing);
  });

  testWidgets('horizontal drags stay with the chip scroller', (tester) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(20)));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Tag 1'), const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(key.currentState!.expanded, isFalse);
    expect(find.byType(ExpandedTagFilterList), findsNothing);
    expect(key.currentState!.verticalDragStarts, isEmpty);
  });

  testWidgets('panel padding does not hand vertical drags to diary scrolling', (
    tester,
  ) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(8)));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(DiaryTagFilterBar));
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(key.currentState!.pageScrollController.offset, 0);
    expect(key.currentState!.expanded, isFalse);
  });

  testWidgets('padding drags do not switch Home tabs even with tag overflow', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(
      buildTagBarHarness(
        key: key,
        tags: createTags(30),
        pageController: controller,
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(DiaryTagFilterBar));
    await tester.flingFrom(
      Offset(rect.right - 4, rect.center.dy),
      const Offset(-220, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    expect(key.currentState!.expanded, isFalse);
  });

  testWidgets('upward drag while collapsed stays inside the tag region', (
    tester,
  ) async {
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(buildTagBarHarness(key: key, tags: createTags(8)));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Tag 1'), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(key.currentState!.expanded, isFalse);
    expect(key.currentState!.verticalDragStarts, isEmpty);
    expect(key.currentState!.pageScrollController.offset, 0);
  });

  testWidgets('four-row viewport scrolls to the last tag without collapsing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(
      buildTagBarHarness(
        key: key,
        tags: createTags(200),
        initiallyExpanded: true,
      ),
    );
    await tester.pumpAndSettle();
    final viewport = find.byType(ExpandedTagFilterList);
    final scrollable = find.descendant(
      of: viewport,
      matching: find.byType(Scrollable),
    );
    final scroll = tester.state<ScrollableState>(scrollable);
    expect(
      scroll.position.viewportDimension,
      DiaryTagFilterBar.expandedRowsExtent,
    );
    expect(find.byType(TagFilterChip).evaluate().length, lessThan(30));
    expect(find.text('Tag 200'), findsNothing);

    await tester.drag(viewport, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(0));
    expect(key.currentState!.expanded, isTrue);
    expect(key.currentState!.pageScrollController.offset, 0);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Tag 200').hitTestable(), findsOneWidget);
    expect(key.currentState!.expanded, isTrue);

    await tester.drag(viewport, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(key.currentState!.expanded, isTrue);
    await tester.tap(find.byKey(DiaryTagFilterBar.collapseHandleKey));
    await tester.pumpAndSettle();
    expect(key.currentState!.expanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short expanded lists keep scroll gestures out of collapse and diaries',
    (tester) async {
      final key = GlobalKey<TagBarHarnessState>();
      await tester.pumpWidget(
        buildTagBarHarness(
          key: key,
          tags: createTags(1),
          initiallyExpanded: true,
        ),
      );
      await tester.pumpAndSettle();
      for (final delta in <double>[-100, 100]) {
        await tester.drag(find.byType(ExpandedTagFilterList), Offset(0, delta));
        await tester.pumpAndSettle();
        expect(key.currentState!.expanded, isTrue);
        expect(key.currentState!.pageScrollController.offset, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('long tag names stay single line without changing chip height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<TagBarHarnessState>();
    await tester.pumpWidget(
      buildTagBarHarness(
        key: key,
        tags: <Tag>[Tag(id: 1, name: 'Long tag name ' * 20, color: 0xff336699)],
        initiallyExpanded: true,
      ),
    );
    await tester.pumpAndSettle();
    final chip = find.byType(TagFilterChip);
    expect(tester.getSize(chip).height, DiaryTagFilterBar.chipExtent);
    expect(tester.getSize(chip).width, lessThanOrEqualTo(296));
    expect(tester.takeException(), isNull);
  });
}
