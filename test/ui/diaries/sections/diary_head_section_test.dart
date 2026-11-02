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
  VoidCallback? onSetTags,
  VoidCallback? onOpenAi,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DiaryHeadSection(
      isSelectionMode: selection,
      selectedCount: count,
      onCancelSelection: () {},
      allSelected: false,
      onToggleSelectAll: () {},
      isPinActionUnpin: false,
      onPinSelected: () {},
      onArchiveSelected: () {},
      onSetTagsSelected: onSetTags ?? () {},
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
      onOpenAi: onOpenAi,
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
    // 勾选框占去一截宽度后“已选择 N 项”读不清：只显示完整数字（不省略），
    // 读屏仍是完整的“已选择 N 项”。
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('已选择 1234 项'), findsNothing);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey<String>('head_select_all')),
      ),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: '全选',
        value: '已选择 1234 项',
      ),
    );
    expect(find.byTooltip('收进日记本'), findsOneWidget);
    expect(find.byTooltip('归档'), findsOneWidget);
    expect(find.byTooltip('删除'), findsOneWidget);
  });

  testWidgets('a wide selection bar keeps the full count beside the box', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(selection: true, count: 1234));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1234 项'), findsOneWidget);
    expect(find.byTooltip('全选'), findsOneWidget);
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
    expect(find.text('设置标签'), findsOneWidget);
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

  testWidgets('set tags sits between pin and export in the more menu', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(selection: true, inManualNotebook: true, onSetTags: () => tapped++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    final pin = tester.getTopLeft(find.text('置顶')).dy;
    final tags = tester.getTopLeft(find.text('设置标签')).dy;
    final export = tester.getTopLeft(find.text('导出')).dy;
    expect(pin < tags && tags < export, isTrue);
    // 普通日记本里菜单为 5 项，仍放得下。
    expect(find.text('移动到…'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('设置标签'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('the AI button appears only when AI can be opened', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.pumpWidget(_host(selection: false));
    expect(find.byTooltip(l10n.aiHubTooltip), findsNothing);
    var opened = 0;
    await tester.pumpWidget(_host(selection: false, onOpenAi: () => opened++));
    await tester.tap(find.byTooltip(l10n.aiHubTooltip));
    expect(opened, 1);
  });
}
