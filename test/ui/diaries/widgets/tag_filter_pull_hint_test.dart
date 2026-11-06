import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/expanded_tag_filter_list.dart';

import '../../../support/expressive_test_theme.dart';
import 'tag_filter_bar_test_support.dart';

void main() {
  final barFinder = find.byType(DiaryTagFilterBar);
  final hintFinder = find.byKey(DiaryTagFilterBar.pullHintKey);

  Widget buildBar({
    required List<Tag> tags,
    bool hintVisible = false,
    Animation<double>? peek,
    VoidCallback? onHintTap,
    ValueChanged<bool>? onHiddenTagsChanged,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: expressiveTestTheme(brightness),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: DiaryTagFilterBar(
            tags: tags,
            expansionProgress: const AlwaysStoppedAnimation<double>(0),
            canExpand: () => true,
            canCollapse: () => false,
            selectedTagFilterIds: const <int>{},
            onToggleTagFilter: (_, __) {},
            onClearTagFilters: () {},
            onVerticalDragStart: (_) {},
            onVerticalDragUpdate: (_, __) {},
            onVerticalDragEnd: (_) {},
            onCollapse: () {},
            pullHintVisible: hintVisible,
            pullHintPeek: peek,
            onPullHintTap: onHintTap ?? () {},
            onHiddenTagsChanged: onHiddenTagsChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('reports whether the collapsed row hides any tags', (
    tester,
  ) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      buildBar(tags: createTags(30), onHiddenTagsChanged: reports.add),
    );
    await tester.pump();
    expect(reports, <bool>[true]);

    await tester.pumpWidget(
      buildBar(tags: createTags(1), onHiddenTagsChanged: reports.add),
    );
    await tester.pump();
    expect(reports, <bool>[true, false]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('the hint row opens below the tags and expands on tap in '
        '${brightness.name} mode', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        buildBar(tags: createTags(30), brightness: brightness),
      );
      await tester.pumpAndSettle();
      final collapsedHeight = tester.getSize(barFinder).height;

      await tester.pumpWidget(
        buildBar(
          tags: createTags(30),
          hintVisible: true,
          brightness: brightness,
          onHintTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pull down to see all 30 tags'), findsOneWidget);
      expect(
        tester.getSize(barFinder).height,
        collapsedHeight + DiaryTagFilterBar.pullHintExtent,
      );
      final label = tester.widget<Text>(
        find.text('Pull down to see all 30 tags'),
      );
      final theme = Theme.of(tester.element(hintFinder));
      expect(label.style?.color, theme.colorScheme.primary);

      await tester.tap(hintFinder);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a hidden hint takes no space, focus or semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildBar(tags: createTags(30)));
    await tester.pumpAndSettle();

    final excludeFocus = tester.widget<ExcludeFocus>(
      find.ancestor(of: hintFinder, matching: find.byType(ExcludeFocus)).first,
    );
    expect(excludeFocus.excluding, isTrue);
    expect(find.bySemanticsLabel('Pull down to see all 30 tags'), findsNothing);
    final hiddenHeight = tester.getSize(barFinder).height;

    await tester.pumpWidget(buildBar(tags: createTags(30), hintVisible: true));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Pull down to see all 30 tags'),
      findsOneWidget,
    );
    expect(
      tester.getSize(barFinder).height,
      hiddenHeight + DiaryTagFilterBar.pullHintExtent,
    );
    semantics.dispose();
  });

  testWidgets('the peek lowers the tags part of a row, never a full expand', (
    tester,
  ) async {
    final peek = AnimationController(vsync: const TestVSync());
    addTearDown(peek.dispose);
    await tester.pumpWidget(
      buildBar(tags: createTags(30), hintVisible: true, peek: peek),
    );
    await tester.pumpAndSettle();
    final restingHeight = tester.getSize(barFinder).height;
    final hintTop = tester.getTopLeft(hintFinder).dy;

    peek.value = 1;
    await tester.pump();
    final lowered = tester.getSize(barFinder).height - restingHeight;
    expect(lowered, greaterThan(DiaryTagFilterBar.chipExtent * 0.5));
    expect(lowered, lessThan(DiaryTagFilterBar.chipExtent));
    expect(tester.getTopLeft(hintFinder).dy, hintTop + lowered);
    // The rows below start to show, exactly as when dragging the bar.
    expect(find.byType(ExpandedTagFilterList), findsOneWidget);

    peek.value = 0;
    await tester.pump();
    expect(tester.getSize(barFinder).height, restingHeight);
    expect(find.byType(ExpandedTagFilterList), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop wording mentions clicking', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        buildBar(tags: createTags(30), hintVisible: true),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Drag down or click to see all 30 tags'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
