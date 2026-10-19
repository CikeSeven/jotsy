import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

Widget _host({
  required bool selection,
  int count = 3,
  int draftCount = 0,
  VoidCallback? onOpenDrafts,
  bool inManualNotebook = false,
  VoidCallback? onAddToNotebook,
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
      onAddToNotebookSelected: onAddToNotebook ?? () {},
      onRemoveFromNotebookSelected: inManualNotebook ? () {} : null,
      onMoveToNotebookSelected: inManualNotebook ? () {} : null,
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

  testWidgets('selection bar fits 320dp with a large count', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(selection: true, count: 1234, inManualNotebook: true),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 数量放不下时缩小而不是省略，仍能读出完整数字。
    expect(find.text('已选择 1234 项'), findsOneWidget);
    expect(find.byTooltip('收进日记本'), findsOneWidget);
    expect(find.byTooltip('归档'), findsOneWidget);
    expect(find.byTooltip('删除'), findsOneWidget);
  });

  testWidgets('add to notebook calls back from the selection bar', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(selection: true, onAddToNotebook: () => tapped++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收进日记本'));
    expect(tapped, 1);
  });

  testWidgets('remove / move only appear in the more menu of a manual '
      'notebook', (tester) async {
    await tester.pumpWidget(_host(selection: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('导出'), findsOneWidget);
    expect(find.text('从本日记本移出'), findsNothing);
    expect(find.text('移动到…'), findsNothing);

    await tester.tapAt(const Offset(5, 500));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(selection: true, inManualNotebook: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('从本日记本移出'), findsOneWidget);
    expect(find.text('移动到…'), findsOneWidget);
  });
}
