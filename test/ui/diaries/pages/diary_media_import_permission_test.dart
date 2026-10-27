import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  const gallery = MethodChannel('com.jotsy.diary/video_gallery');

  for (final brightness in Brightness.values) {
    for (final code in ['permission_denied', 'gallery_unavailable']) {
      testWidgets(
        '$brightness video import $code shows a hint and permits retry',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({});
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final settings = await SettingsService.create();
          var calls = 0;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(gallery, (_) async {
                if (calls++ == 0) throw PlatformException(code: code);
                return null;
              });
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(gallery, null);
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(database),
                settingsServiceProvider.overrideWith((ref) async => settings),
              ],
              child: MaterialApp(
                theme: expressiveTestTheme(brightness),
                locale: Locale(brightness == Brightness.light ? 'zh' : 'en'),
                localizationsDelegates: const [
                  ...AppLocalizations.localizationsDelegates,
                  af.AppFlowyEditorLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(viewInsets: const EdgeInsets.only(bottom: 240)),
                  child: child!,
                ),
                home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
          final original = editor.controller.contentJson;
          await _requestVideo(tester);
          final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
          expect(
            find.text(
              code == 'permission_denied'
                  ? l10n.diaryMediaImportPermissionDenied
                  : l10n.diaryMediaPickerUnavailable,
            ),
            findsOneWidget,
          );
          expect(editor.controller.contentJson, original);
          await _requestVideo(tester);
          expect(calls, 2);
          expect(find.byType(EditDiaryPage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }
}

Future<void> _requestVideo(WidgetTester tester) async {
  final toolbar = tester.widget<DiaryFloatingToolbar>(
    find.byType(DiaryFloatingToolbar),
  );
  final importer = toolbar.mediaImportController!;
  // Stream cancellation can complete on the real event loop; pumping fake
  // animation frames alone does not guarantee that the import has finished.
  await tester.runAsync(() async {
    final idle = Completer<void>();
    void onChanged() {
      if (!importer.isBusy && !idle.isCompleted) idle.complete();
    }

    importer.addListener(onChanged);
    try {
      toolbar.onMediaPressed!(DiaryMediaKind.video);
      await idle.future.timeout(const Duration(seconds: 5));
    } finally {
      importer.removeListener(onChanged);
    }
  });
  await tester.pumpAndSettle();
}
