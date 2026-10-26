import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_host.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_view.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../pages/diaries_wide_test_support.dart';

/// 挂载一篇预览；[host] 为 null 时与独立路由相同。
Future<WideDiaryStore> _pump(
  WidgetTester tester, {
  required DiaryWithTags diary,
  DiaryPreviewHost? host,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  final store = WideDiaryStore(<DiaryWithTags>[diary]);
  final database = WideDiaryDatabase(store);
  addTearDown(() async {
    await store.close();
    await database.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
        diaryNotebooksProvider.overrideWith(
          (ref, diaryId) async => const <NotebookView>[],
        ),
        diaryDetailProvider.overrideWith(
          (ref, diaryId) async => store.byId(diaryId),
        ),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryPreviewView(
          diaryId: diary.diary.diaryId,
          initialDetail: diary,
          host: host,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return store;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets(
    'an embedded preview has no back button and hands deletion to its host',
    (tester) async {
      final deleted = <String>[];
      final diary = wideDiary('embedded', 0);
      final store = await _pump(
        tester,
        diary: diary,
        host: DiaryPreviewHost(onDeleted: deleted.add, onVanished: () {}),
      );
      final l10n = tester.element(find.byType(DiaryPreviewView)).l10n;

      expect(find.byTooltip(l10n.commonBack), findsNothing);
      expect(find.byTooltip(l10n.commonEdit), findsOneWidget);
      expect(find.byTooltip(l10n.autoT0125), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.autoT0125));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      // 确认框右侧的“删除”。
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.commonDelete),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.deleted, <String>{'embedded-0'});
      expect(deleted, <String>['embedded-0']);
      // 没有退出路由：预览仍在。
      expect(find.byType(DiaryPreviewView), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets('a standalone preview keeps its back button', (tester) async {
    await _pump(tester, diary: wideDiary('standalone', 0));
    final l10n = tester.element(find.byType(DiaryPreviewView)).l10n;
    expect(find.byTooltip(l10n.commonBack), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets(
    'an embedded sealed capsule shows the sealed page without a back button',
    (tester) async {
      final deleted = <String>[];
      final diary = wideDiary(
        'sealed',
        0,
        unlockAt: DateTime.now().add(const Duration(days: 30)),
      );
      final store = await _pump(
        tester,
        diary: diary,
        host: DiaryPreviewHost(onDeleted: deleted.add, onVanished: () {}),
      );
      final l10n = tester.element(find.byType(DiaryPreviewView)).l10n;

      expect(find.byType(LockedDiaryPage), findsOneWidget);
      expect(find.text(l10n.timeCapsuleLockedTitle), findsOneWidget);
      // 正文不露出。
      expect(find.textContaining('sealed body'), findsNothing);
      expect(find.byTooltip(l10n.commonBack), findsNothing);

      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.commonDelete),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.deleted, <String>{'sealed-0'});
      expect(deleted, <String>['sealed-0']);
      expect(find.byType(LockedDiaryPage), findsOneWidget);
      await _unmount(tester);
    },
  );
}
