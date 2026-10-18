import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

Widget _host({
  required bool selection,
  int count = 3,
  int draftCount = 0,
  VoidCallback? onOpenDrafts,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DiaryHeadSection(
      isSelectionMode: selection,
      selectedCount: count,
      onCancelSelection: () {},
      isPinActionUnpin: false,
      onPinSelected: () {},
      onArchiveSelected: () {},
      onExportSelected: () {},
      onDeleteSelected: () {},
      onOpenArchived: () {},
      onOpenDrafts: onOpenDrafts ?? () {},
      draftCount: draftCount,
      onOpenViewOptions: () {},
      onOpenSearchPage: () {},
    ),
  ),
);

void main() {
  testWidgets('selection header shows the selected count and cross-fades', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selection: false));
    expect(find.byKey(const ValueKey<String>('head_default')), findsOneWidget);

    await tester.pumpWidget(_host(selection: true));
    await tester.pump(const Duration(milliseconds: 60));
    // 过渡中两态同时存在（交叉淡入），而不是硬切。
    expect(find.byKey(const ValueKey<String>('head_default')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('head_selection')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('head_default')), findsNothing);
    expect(find.text('已选择 3 项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion switches the header immediately', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(selection: false));
    await tester.pumpWidget(_host(selection: true));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('head_default')), findsNothing);
  });
  testWidgets('the header has no title and searches "in Jotsy"', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selection: false));
    expect(find.text('Jotsy'), findsNothing);
    expect(find.text('在 Jotsy 中搜索'), findsOneWidget);
  });

  testWidgets('the drafts button shows the draft count only when non-zero', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(selection: false, draftCount: 0, onOpenDrafts: () => opened++),
    );
    Badge badge() => tester.widget<Badge>(
      find.descendant(of: find.byTooltip('草稿箱'), matching: find.byType(Badge)),
    );
    expect(badge().isLabelVisible, isFalse);

    await tester.pumpWidget(
      _host(selection: false, draftCount: 3, onOpenDrafts: () => opened++),
    );
    expect(badge().isLabelVisible, isTrue);
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(_host(selection: false, draftCount: 120));
    expect(find.text('99+'), findsOneWidget);

    await tester.pumpWidget(
      _host(selection: false, draftCount: 3, onOpenDrafts: () => opened++),
    );
    await tester.tap(find.byTooltip('草稿箱'));
    expect(opened, 1);
  });
}
