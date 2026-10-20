import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_filter_bar.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_filter_sheet.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_notebook_tiles.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_lock_layer.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher_chip.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

import '../../support/calendar_test_harness.dart';
import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';
import '../../support/publish_panel_driver.dart';
import 'notebook_test_support.dart';

/// 功能管理关闭日记本：各处入口都隐藏，数据保留；在日记本里关闭时首页回到
/// 全部日记，但不关掉首页之上的页面、不误报“日记本已删除”，重锁遮罩失效。
void main() {
  const featuresKey = 'app.settings.app_features';
  const notebooksOff = '{"notebooks":false}';

  Future<void> turnOff(DiaryDraftsHarness h) =>
      h.settings.setAppFeaturesRaw(notebooksOff);

  Finder card(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiarySelectionSurface),
  );

  Future<void> openShelfAndPick(DiaryDraftsHarness h, String name) async {
    await h.tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await h.tester.tap(
      find.descendant(
        of: find.byType(NotebookShelf),
        matching: find.text(name),
      ),
    );
    await h.settleAll();
  }

  group('diaries page', () {
    Future<DiaryDraftsHarness> pumpHome(
      WidgetTester tester, {
      required bool enabled,
    }) async {
      final h = await DiaryDraftsHarness.create(tester);
      if (!enabled) await turnOff(h);
      final travel = await h.notebook('旅行');
      await h.diary('在京都', notebookIds: <String>[travel]);
      await h.diary('上班路上');
      await h.pump(
        const DiariesPage(),
        overrides: [
          deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
        ],
      );
      await h.settleAll();
      return h;
    }

    testWidgets('off: no switcher chip, shelf entry or multi-select actions', (
      tester,
    ) async {
      final h = await pumpHome(tester, enabled: false);
      expect(find.byType(NotebookSwitcherChip), findsNothing);

      await tester.tap(find.byTooltip(h.l10n.autoT0125));
      await h.settleAll();
      expect(find.text(h.l10n.notebookViewOptionsEntry), findsNothing);
      await tester.tapAt(const Offset(200, 40));
      await h.settleAll();

      await tester.longPress(card('上班路上'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(h.l10n.notebookPickerTitle), findsNothing);
      await tester.tap(find.byTooltip(h.l10n.notebookSelectionMore));
      await tester.pumpAndSettle();
      expect(find.text(h.l10n.notebookRemoveFromCurrent), findsNothing);
      expect(find.text(h.l10n.notebookMoveTo), findsNothing);
      expect(find.text(h.l10n.diaryExportSelected), findsOneWidget);
      await h.unmount();
    });

    testWidgets('on: the switcher chip, shelf entry and add action appear', (
      tester,
    ) async {
      final h = await pumpHome(tester, enabled: true);
      expect(find.byType(NotebookSwitcherChip), findsOneWidget);

      await tester.tap(find.byTooltip(h.l10n.autoT0125));
      await h.settleAll();
      expect(find.text(h.l10n.notebookViewOptionsEntry), findsOneWidget);
      await tester.tapAt(const Offset(200, 40));
      await h.settleAll();

      await tester.longPress(card('上班路上'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(h.l10n.notebookPickerTitle), findsOneWidget);
      await h.unmount();
    });
  });

  group('turning the feature off inside a notebook', () {
    // 首页被推上来的页面盖住后不在台上（find 默认跳过），从始终挂着的
    // MaterialApp 取容器。
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    Future<void> pushAboveHome(WidgetTester tester) async {
      unawaited(
        Navigator.of(tester.element(find.byType(DiariesPage))).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('功能管理')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('returns home to all diaries without popping the page above', (
      tester,
    ) async {
      final h = await DiaryDraftsHarness.create(tester);
      // 失败时也先卸载，免得打开的 drift 库让测试进程挂住。
      addTearDown(h.unmount);
      final travel = await h.notebook('旅行');
      await h.diary('在京都', notebookIds: <String>[travel]);
      await h.diary('上班路上');
      await h.pump(
        const DiariesPage(),
        overrides: [
          deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
        ],
      );
      await h.settleAll();
      await openShelfAndPick(h, '旅行');
      expect(
        containerOf(tester).read(homeNotebookScopeProvider).notebookId,
        travel,
      );

      await pushAboveHome(tester);
      unawaited(turnOff(h));
      await h.settleAll();

      // 设置页还在，首页已回到全部日记，没有“日记本已删除”。
      expect(find.text('功能管理'), findsOneWidget);
      expect(containerOf(tester).read(homeNotebookScopeProvider).isAll, isTrue);
      expect(find.text(h.l10n.notebookScopeDeleted), findsNothing);

      Navigator.of(tester.element(find.text('功能管理'))).pop();
      await h.settleAll();
      expect(find.text('功能管理'), findsNothing);
      expect(find.text('上班路上'), findsOneWidget);
      expect(find.text('在京都'), findsOneWidget);
      expect(find.byType(NotebookHeaderCard), findsNothing);
      expect(find.byType(NotebookSwitcherChip), findsNothing);
      expect(find.text(h.l10n.notebookScopeDeleted), findsNothing);

      // 重新开启：入口回来，本子与收录都还在。
      unawaited(h.settings.setAppFeaturesRaw(null));
      await h.settleAll();
      expect(find.byType(NotebookSwitcherChip), findsOneWidget);
      await openShelfAndPick(h, '旅行');
      expect(find.text('在京都'), findsOneWidget);
      expect(find.text('上班路上'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.unmount();
    });

    testWidgets('a locked notebook leaves the lock layer inert afterwards', (
      tester,
    ) async {
      final h = await DiaryDraftsHarness.create(tester);
      addTearDown(h.unmount);
      final vault = await h.notebook(
        '保险箱',
        visibility: NotebookVisibility.locked,
      );
      await h.diary('秘密', notebookIds: <String>[vault]);
      await h.diary('上班路上');
      final auth = FakeDeviceAuth(results: <bool>[true]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(h.database),
            settingsServiceProvider.overrideWith((ref) async => h.settings),
            diaryMediaCleanupServiceProvider.overrideWithValue(h.mediaCleanup),
            deviceAuthServiceProvider.overrideWithValue(auth),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) =>
                NotebookLockLayer(child: child!),
            home: const DiariesPage(),
          ),
        ),
      );
      await h.settleAll();
      await openShelfAndPick(h, '保险箱');
      expect(auth.reasons, hasLength(1));
      expect(
        containerOf(tester).read(homeNotebookScopeProvider).notebookId,
        vault,
      );

      await pushAboveHome(tester);
      unawaited(turnOff(h));
      await h.settleAll();
      expect(find.text('功能管理'), findsOneWidget);
      final scope = containerOf(tester).read(homeNotebookScopeProvider);
      expect(scope.isAll, isTrue);
      expect(scope.relocked, isFalse);

      // 切到后台再回来：不在上锁的本子里，遮罩不出现，也不再验证。
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await h.settleAll();
      expect(find.text('「保险箱」已上锁'), findsNothing);
      expect(
        containerOf(tester).read(homeNotebookScopeProvider).relocked,
        isFalse,
      );
      expect(auth.reasons, hasLength(1));
      expect(find.text('功能管理'), findsOneWidget);
      await h.unmount();
    });
  });

  group('preview page', () {
    Future<(DiaryDraftsHarness, String)> open(
      WidgetTester tester, {
      required bool enabled,
    }) async {
      final h = await DiaryDraftsHarness.create(tester);
      if (!enabled) await turnOff(h);
      final travel = await h.notebook('旅行');
      final diary = await h.diary('在京都', notebookIds: <String>[travel]);
      await h.pump(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DiaryPreviewPage(diaryId: diary),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
        overrides: [
          deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
        ],
      );
      await tester.tap(find.text('home'));
      await h.settleAll();
      return (h, travel);
    }

    for (final enabled in <bool>[false, true]) {
      testWidgets('${enabled ? 'on' : 'off'}: notebook capsule and More entry '
          '${enabled ? 'show' : 'are hidden'}', (tester) async {
        final (h, travel) = await open(tester, enabled: enabled);
        expect(
          find.byKey(ValueKey<String>('preview_notebook_$travel')),
          enabled ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byTooltip('更多'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ListTile, h.l10n.notebookPickerTitle),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(
          find.widgetWithText(ListTile, h.l10n.previewExport),
          findsOneWidget,
        );
        await h.unmount();
      });
    }
  });

  group('edit page publish panel', () {
    for (final enabled in <bool>[false, true]) {
      testWidgets('${enabled ? 'on' : 'off'}: notebook tile and summary item '
          '${enabled ? 'show' : 'are hidden'}', (tester) async {
        final h = await DiaryDraftsHarness.create(tester);
        if (!enabled) await turnOff(h);
        final travel = await h.notebook('旅行');
        final diary = await h.diary('在京都', notebookIds: <String>[travel]);
        await h.pump(EditDiaryPage(diaryId: diary));
        await h.settleAll();
        final driver = PublishPanelDriver(tester);

        // 草稿里仍读回所在的本子（数据保留），只是不显示。
        expect(driver.draft.value.notebookIds, <String>{travel});
        expect(
          find.descendant(
            of: driver.collapsedHeader,
            matching: find.textContaining('旅行'),
          ),
          enabled ? findsOneWidget : findsNothing,
        );
        await driver.expand();
        expect(
          find.byType(PublishNotebookTile),
          enabled ? findsOneWidget : findsNothing,
        );

        // 改正文自动保存：收录原样保留。
        await tester.enterText(find.widgetWithText(TextField, '在京都'), '在大阪');
        await tester.pump(const Duration(milliseconds: 600));
        await h.settleAll();
        expect(
          await tester.runAsync(() => h.database.getDiaryNotebookIds(diary)),
          <String>{travel},
        );
        await h.unmount();
      });
    }
  });

  group('search page', () {
    for (final enabled in <bool>[false, true]) {
      testWidgets('${enabled ? 'on' : 'off'}: save as smart notebook '
          '${enabled ? 'shows' : 'is hidden'}', (tester) async {
        final h = await DiaryDraftsHarness.create(tester);
        if (!enabled) await turnOff(h);
        const tag = Tag(id: 1, name: '旅行', color: 0xff336699);
        await h.pump(
          const DiarySearchPage(initialKeyword: '樱花', initialTagIds: <int>{1}),
          overrides: [
            tagListProvider.overrideWith(
              (ref) => Stream.value(const <Tag>[tag]),
            ),
            searchDiariesProvider.overrideWith(
              (ref, query) => Stream.value(
                PagedDiariesResult(
                  items: const <DiaryWithTags>[],
                  limit: query.limit,
                  hasMore: false,
                ),
              ),
            ),
          ],
        );
        await h.settleAll();
        expect(
          find.byTooltip(h.l10n.notebookSaveSearchAsSmart),
          enabled ? findsOneWidget : findsNothing,
        );
        await h.unmount();
      });
    }
  });

  group('calendar', () {
    final now = DateTime.now();
    final trip = NotebookView(
      NotebookRow(
        id: 1,
        notebookId: 'trip',
        name: '旅行本',
        kind: NotebookKind.manual.name,
        visibility: NotebookVisibility.normal.name,
        payload: NotebookPayload.defaults.encode(),
        isPinned: false,
        isClosed: false,
        sortOrder: 0,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    final markers = <DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'in-trip',
        createdAt: DateTime(now.year, now.month, 5, 9),
        tagIds: const <int>[],
        notebookIds: const <String>['trip'],
      ),
      DiaryCalendarMarker(
        diaryId: 'plain',
        createdAt: DateTime(now.year, now.month, 7, 9),
        tagIds: const <int>[],
        notebookIds: const <String>[],
      ),
    ];

    Finder cellOf(int day) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is CalendarDayCell &&
          !widget.isOutside &&
          widget.day.day == day,
    );

    bool hasEntries(WidgetTester tester, int day) =>
        tester.widget<CalendarDayCell>(cellOf(day)).summary?.hasEntries ??
        false;

    AppLocalizations l10nOf(WidgetTester tester) =>
        tester.element(find.byType(CalendarPage)).l10n;

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(CalendarFilterSheet), matching: finder);

    for (final enabled in <bool>[false, true]) {
      testWidgets('${enabled ? 'on' : 'off'}: the filter sheet notebook group '
          '${enabled ? 'shows' : 'is hidden'}', (tester) async {
        await pumpCalendarPage(
          tester,
          prefs: <String, Object>{if (!enabled) featuresKey: notebooksOff},
          markers: markers,
          notebooks: <NotebookView>[trip],
        );
        final l10n = l10nOf(tester);
        await tester.tap(find.byTooltip(l10n.calendarFilterTooltip));
        await tester.pumpAndSettle();
        expect(inSheet(find.text(l10n.calendarFilterMoods)), findsOneWidget);
        expect(
          inSheet(find.text(l10n.calendarFilterNotebooks)),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(
          inSheet(find.text('旅行本')),
          enabled ? findsOneWidget : findsNothing,
        );
      });

      testWidgets('${enabled ? 'on' : 'off'}: the range header save button '
          '${enabled ? 'shows' : 'is hidden'}', (tester) async {
        await pumpCalendarPage(
          tester,
          prefs: <String, Object>{if (!enabled) featuresKey: notebooksOff},
          markers: markers,
          notebooks: <NotebookView>[trip],
        );
        final l10n = l10nOf(tester);
        await tester.longPress(cellOf(3));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.calendarDayActionRange));
        await tester.pumpAndSettle();
        await tester.tap(cellOf(12));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextButton, l10n.notebookSaveRange),
          enabled ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('turning the feature off drops a selected notebook filter', (
      tester,
    ) async {
      final settings = await pumpCalendarPage(
        tester,
        markers: markers,
        notebooks: <NotebookView>[trip],
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.calendarFilterTooltip));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('旅行本')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(hasEntries(tester, 5), isTrue);
      expect(hasEntries(tester, 7), isFalse);

      unawaited(settings.setAppFeaturesRaw(notebooksOff));
      await tester.pumpAndSettle();
      // 日记本筛选去掉后，其他日子的打点回来，筛选面板也不再记着它。
      expect(hasEntries(tester, 5), isTrue);
      expect(hasEntries(tester, 7), isTrue);

      unawaited(settings.setAppFeaturesRaw(null));
      await tester.pumpAndSettle();
      expect(hasEntries(tester, 7), isTrue);
      // 重新开启后不恢复已去掉的条件：筛选条不再出现。
      expect(find.byType(CalendarFilterBar), findsNothing);
    });
  });
}
