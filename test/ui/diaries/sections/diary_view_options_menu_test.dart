import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_view_options_menu.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_panel.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_submenu.dart';

import '../../../support/expressive_test_theme.dart';

/// 记录菜单发出的各类回调。
class _Calls {
  final List<DiarySortMode> sorts = <DiarySortMode>[];
  final List<DiaryLayoutMode> layouts = <DiaryLayoutMode>[];
  final List<NotebookSort> notebookSorts = <NotebookSort>[];
  int cardStyle = 0;
  int settings = 0;
}

/// 顶栏右侧放一个“更多”按钮（zh），返回回调记录与文案。
Future<(_Calls, AppLocalizations)> _pump(
  WidgetTester tester, {
  DiarySortMode sortMode = DiarySortMode.updatedDesc,
  DiaryLayoutMode layoutMode = DiaryLayoutMode.list,
  NotebookSort? notebookSort,
  bool allowBookOrder = false,
  bool withSettings = true,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            DiaryViewOptionsMenuButton(
              options: DiaryViewMenuOptions(
                sortMode: sortMode,
                layoutMode: layoutMode,
                onSortModeChanged: calls.sorts.add,
                onLayoutModeChanged: calls.layouts.add,
                onOpenCardStyle: () => calls.cardStyle++,
                notebookSort: notebookSort,
                allowBookOrder: allowBookOrder,
                onNotebookSortChanged: calls.notebookSorts.add,
                onOpenSettings: withSettings ? () => calls.settings++ : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  final l10n = tester.element(find.byType(Scaffold)).l10n;
  return (calls, l10n);
}

Future<void> _openMenu(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byTooltip(l10n.autoT0125));
  await tester.pumpAndSettle();
}

Future<void> _openSubmenu(
  WidgetTester tester,
  AppLocalizations l10n,
  String label,
) async {
  await _openMenu(tester, l10n);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool? _selected(WidgetTester tester, String label) => tester
    .widget<ExpressiveMenuItem>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(ExpressiveMenuItem),
      ),
    )
    .selected;

void main() {
  testWidgets('the menu lists sort, layout and settings', (tester) async {
    final (_, l10n) = await _pump(tester);
    await _openMenu(tester, l10n);

    expect(find.byType(ExpressiveSubmenuItem), findsNWidgets(2));
    expect(find.text(l10n.autoT0141), findsOneWidget);
    expect(find.text(l10n.autoT0145), findsOneWidget);
    expect(find.text(l10n.navSettings), findsOneWidget);
    // 选项都在二级菜单里，第一级只有三项入口。
    expect(find.text(l10n.diarySortFieldUpdated), findsNothing);
    expect(find.text(l10n.autoT0146), findsNothing);
  });

  testWidgets('settings closes the menu and opens settings', (tester) async {
    final (calls, l10n) = await _pump(tester);
    await _openMenu(tester, l10n);

    await tester.tap(find.text(l10n.navSettings));
    await tester.pumpAndSettle();
    expect(calls.settings, 1);
    expect(find.byType(ExpressiveMenuItem), findsNothing);
  });

  testWidgets('settings is left out when there is nowhere to go', (
    tester,
  ) async {
    final (_, l10n) = await _pump(tester, withSettings: false);
    await _openMenu(tester, l10n);
    expect(find.text(l10n.navSettings), findsNothing);
    expect(find.byType(ExpressiveSubmenuItem), findsNWidgets(2));
  });

  testWidgets('sort options apply on tap while the menu stays open', (
    tester,
  ) async {
    final (calls, l10n) = await _pump(tester);
    await _openSubmenu(tester, l10n, l10n.autoT0141);

    expect(_selected(tester, l10n.diarySortFieldUpdated), isTrue);
    expect(_selected(tester, l10n.diarySortHintUpdatedDesc), isTrue);
    expect(_selected(tester, l10n.diarySortHintUpdatedAsc), isFalse);

    // 换依据保留方向；方向选项的文字随依据换成实际效果。
    await tester.tap(find.text(l10n.diarySortFieldTitle));
    await tester.pumpAndSettle();
    expect(calls.sorts, <DiarySortMode>[DiarySortMode.titleDesc]);
    expect(_selected(tester, l10n.diarySortFieldTitle), isTrue);
    expect(_selected(tester, l10n.diarySortFieldUpdated), isFalse);
    expect(find.text(l10n.diarySortHintUpdatedDesc), findsNothing);
    expect(_selected(tester, l10n.diarySortHintTitleDesc), isTrue);

    await tester.tap(find.text(l10n.diarySortHintTitleAsc));
    await tester.pumpAndSettle();
    expect(calls.sorts, <DiarySortMode>[
      DiarySortMode.titleDesc,
      DiarySortMode.titleAsc,
    ]);
    expect(_selected(tester, l10n.diarySortHintTitleAsc), isTrue);

    // 点当前项不重复回调。
    await tester.tap(find.text(l10n.diarySortFieldTitle));
    await tester.pumpAndSettle();
    expect(calls.sorts, hasLength(2));
    expect(find.byType(ExpressiveMenuItem), findsWidgets);
  });

  testWidgets('the header row folds the submenu back into its row', (
    tester,
  ) async {
    final (_, l10n) = await _pump(tester);
    await _openSubmenu(tester, l10n, l10n.autoT0141);
    expect(find.byType(ExpressiveSubmenuHeader), findsOneWidget);

    // 二级菜单顶部的标题行就是“排序方式”那一行的副本。
    await tester.tap(find.text(l10n.autoT0141).last);
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveSubmenuHeader), findsNothing);
    expect(find.text(l10n.navSettings), findsOneWidget);
    expect(find.text(l10n.diarySortFieldUpdated), findsNothing);
  });

  testWidgets('in a notebook the sort is the notebook sort', (tester) async {
    final (calls, l10n) = await _pump(
      tester,
      notebookSort: NotebookSort.createdDesc,
      allowBookOrder: true,
    );
    await _openSubmenu(tester, l10n, l10n.autoT0141);

    expect(find.text(l10n.diarySortFieldUpdated), findsNothing);
    expect(_selected(tester, l10n.notebookSortCreatedDesc), isTrue);
    expect(find.text(l10n.notebookSortBook), findsOneWidget);

    await tester.tap(find.text(l10n.notebookSortBook));
    await tester.pumpAndSettle();
    expect(calls.notebookSorts, <NotebookSort>[NotebookSort.book]);
    expect(calls.sorts, isEmpty);
    expect(_selected(tester, l10n.notebookSortBook), isTrue);
    expect(_selected(tester, l10n.notebookSortCreatedDesc), isFalse);
  });

  testWidgets('a smart notebook has no book order', (tester) async {
    final (_, l10n) = await _pump(
      tester,
      notebookSort: NotebookSort.updatedDesc,
    );
    await _openSubmenu(tester, l10n, l10n.autoT0141);
    expect(find.text(l10n.notebookSortBook), findsNothing);
    expect(_selected(tester, l10n.notebookSortUpdatedDesc), isTrue);
  });

  testWidgets('layout options apply on tap while the menu stays open', (
    tester,
  ) async {
    final (calls, l10n) = await _pump(tester);
    await _openSubmenu(tester, l10n, l10n.autoT0145);

    expect(_selected(tester, l10n.autoT0146), isTrue);
    await tester.tap(find.text(l10n.autoT0147));
    await tester.pumpAndSettle();
    expect(calls.layouts, <DiaryLayoutMode>[DiaryLayoutMode.waterfall]);
    expect(_selected(tester, l10n.autoT0147), isTrue);
    expect(_selected(tester, l10n.autoT0146), isFalse);
  });

  testWidgets('card style closes the menu before opening', (tester) async {
    final (calls, l10n) = await _pump(tester);
    await _openSubmenu(tester, l10n, l10n.autoT0145);

    await tester.tap(find.text(l10n.diaryCardStyleSheetSection));
    await tester.pumpAndSettle();
    expect(calls.cardStyle, 1);
    expect(calls.layouts, isEmpty);
    expect(find.byType(ExpressiveMenuItem), findsNothing);
  });

  testWidgets('reopening starts from the first level', (tester) async {
    final (_, l10n) = await _pump(tester);
    await _openSubmenu(tester, l10n, l10n.autoT0145);

    // 点外部先收回二级菜单，再点才关掉整个菜单。
    await tester.tapAt(const Offset(200, 500));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveSubmenuHeader), findsNothing);
    expect(find.text(l10n.navSettings), findsOneWidget);
    await tester.tapAt(const Offset(200, 500));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveMenuItem), findsNothing);

    await _openMenu(tester, l10n);
    expect(find.text(l10n.navSettings), findsOneWidget);
    expect(find.text(l10n.autoT0146), findsNothing);
  });

  testWidgets('a 320dp screen with large text keeps the menu on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (_, l10n) = await _pump(tester);
    await _openSubmenu(tester, l10n, l10n.autoT0141);

    expect(tester.takeException(), isNull);
    final panels = find.byType(ExpressiveMenuPanel);
    expect(panels, findsNWidgets(2));
    for (final panel in tester.widgetList(panels).indexed) {
      final rect = tester.getRect(panels.at(panel.$1));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.bottom, lessThanOrEqualTo(480));
    }
  });
}
