import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_detail_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_lock_layer.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';
import 'notebook_test_support.dart';

/// 私密日记本在首页之外的表现：切到后台后的重新上锁遮罩、回收站占位、
/// 纪念日关联日记的占位。
void main() {
  group('NotebookLockLayer', () {
    Future<(DiaryDraftsHarness, String)> pumpLayer(
      WidgetTester tester,
      FakeDeviceAuth auth,
    ) async {
      final h = await DiaryDraftsHarness.create(tester);
      final vault = await h.notebook(
        '保险箱',
        visibility: NotebookVisibility.locked,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(h.database),
            settingsServiceProvider.overrideWith((ref) async => h.settings),
            deviceAuthServiceProvider.overrideWithValue(auth),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) =>
                NotebookLockLayer(child: child!),
            home: const Scaffold(body: Text('首页')),
          ),
        ),
      );
      await h.settleAll();
      return (h, vault);
    }

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.text('首页')));

    Future<void> background(WidgetTester tester) async {
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      for (final state in <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('relocks after backgrounding and unlocks with the device', (
      tester,
    ) async {
      final auth = FakeDeviceAuth(results: <bool>[true]);
      final (h, vault) = await pumpLayer(tester, auth);
      final container = containerOf(tester);
      container.read(homeNotebookScopeProvider.notifier).enter(vault);
      await h.settleAll();
      expect(find.text('「保险箱」已上锁'), findsNothing);

      await background(tester);
      await h.settleAll();
      expect(find.text('「保险箱」已上锁'), findsOneWidget);

      await tester.tap(find.text('解锁'));
      await h.settleAll();
      expect(auth.reasons, <String>['解锁「保险箱」']);
      expect(find.text('「保险箱」已上锁'), findsNothing);
      expect(container.read(homeNotebookScopeProvider).notebookId, vault);
      await h.unmount();
    });

    testWidgets('back to all diaries resets the scope', (tester) async {
      final auth = FakeDeviceAuth();
      final (h, vault) = await pumpLayer(tester, auth);
      final container = containerOf(tester);
      container.read(homeNotebookScopeProvider.notifier).enter(vault);
      await h.settleAll();
      await background(tester);
      await h.settleAll();

      await tester.tap(find.text('回到全部日记'));
      await h.settleAll();
      expect(container.read(homeNotebookScopeProvider).isAll, isTrue);
      expect(find.text('「保险箱」已上锁'), findsNothing);
      await h.unmount();
    });

    testWidgets('two failed attempts give up the notebook', (tester) async {
      final auth = FakeDeviceAuth(results: <bool>[false, false]);
      final (h, vault) = await pumpLayer(tester, auth);
      final container = containerOf(tester);
      container.read(homeNotebookScopeProvider.notifier).enter(vault);
      await h.settleAll();
      await background(tester);
      await h.settleAll();

      await tester.tap(find.text('解锁'));
      await h.settleAll();
      expect(find.text('「保险箱」已上锁'), findsOneWidget);
      await tester.tap(find.text('解锁'));
      await h.settleAll();
      expect(container.read(homeNotebookScopeProvider).isAll, isTrue);
      expect(find.text('「保险箱」已上锁'), findsNothing);
      await h.unmount();
    });

    testWidgets('normal notebooks and all diaries never lock', (tester) async {
      final (h, _) = await pumpLayer(tester, FakeDeviceAuth());
      await background(tester);
      final open = await h.notebook('旅行');
      containerOf(tester).read(homeNotebookScopeProvider.notifier).enter(open);
      await h.settleAll();
      await background(tester);
      await h.settleAll();
      expect(find.textContaining('已上锁'), findsNothing);
      await h.unmount();
    });
  });

  testWidgets('the recycle bin hides titles of private diaries', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final hidden = await h.notebook(
      '日记本',
      visibility: NotebookVisibility.hidden,
    );
    final secret = await h.diary('秘密标题', notebookIds: <String>[hidden]);
    final plain = await h.diary('普通标题');
    await tester.runAsync(() async {
      await h.database.softDeleteDiary(secret);
      await h.database.softDeleteDiary(plain);
    });
    await h.pump(const RecycleBinPage());
    await h.settleAll();
    expect(find.text('普通标题'), findsOneWidget);
    expect(find.text('秘密标题'), findsNothing);
    expect(find.text('私密日记本中的日记'), findsOneWidget);

    // 占位行仍可勾选。
    await tester.tap(find.text('私密日记本中的日记'));
    await h.settleAll();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).where((c) => c.value!),
      hasLength(1),
    );
    await h.unmount();
  });

  testWidgets('an anniversary linked to a private diary says so', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(400, 1400);
    final hidden = await h.notebook(
      '日记本',
      visibility: NotebookVisibility.locked,
    );
    final secret = await h.diary('秘密标题', notebookIds: <String>[hidden]);
    final today = DateTime.now();
    final id = (await tester.runAsync(
      () => h.database.createAnniversary(
        title: '纪念',
        baseDate: DateTime(today.year - 1, today.month, today.day),
        recurrence: AnniversaryRecurrence.solarYearly,
        linkedDiaryId: secret,
      ),
    ))!;
    await h.pump(AnniversaryDetailPage(anniversaryId: id));
    await h.settleAll();
    expect(find.text('关联的日记在私密日记本中'), findsOneWidget);
    expect(find.text(h.l10n.anniversaryLinkMissing), findsNothing);
    expect(find.text(h.l10n.anniversaryUnlink), findsNothing);
    expect(find.text('秘密标题'), findsNothing);
    await h.unmount();
  });
}
