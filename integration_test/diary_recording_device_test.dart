import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses the real microphone and local player, but a memory DB and mock settings.
/// Never opens the user's diary DB; cleanup only removes this test's recording.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('microphone pause resume finish inserts playable M4A audio', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    String? createdRecording;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await const DiaryAudioStorageService().deleteManagedRecording(
        createdRecording,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            // Keep toolbar layout deterministic without depending on an installed
            // keyboard. The actual microphone/player still use native plugins.
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 240)),
            child: child!,
          ),
          home: const EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            restoreCreateDraft: false,
          ),
        ),
      ),
    );
    await _pumpUntil(tester, () => find.byTooltip('录音').evaluate().isNotEmpty);
    await tester.ensureVisible(find.byTooltip('录音'));
    await tester.tap(find.byTooltip('录音'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('开始录音').evaluate().isNotEmpty,
    );
    await tester.tap(find.byTooltip('开始录音'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('暂停录音').evaluate().isNotEmpty,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );

    await tester.tap(find.byTooltip('暂停录音'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('继续录音').evaluate().isNotEmpty,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.tap(find.byTooltip('继续录音'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('暂停录音').evaluate().isNotEmpty,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );

    await tester.tap(find.byTooltip('结束录音'));
    await _pumpUntil(
      tester,
      () => find.byType(DiaryAudioPlayer).evaluate().isNotEmpty,
    );
    final attachment = tester
        .widget<DiaryAudioPlayer>(find.byType(DiaryAudioPlayer))
        .recording;
    createdRecording = attachment.path;
    final bytes = await File(attachment.path).readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(4, 8)), 'ftyp');
    expect(attachment.duration.inMilliseconds, greaterThan(1500));

    await tester.ensureVisible(find.byTooltip('播放录音'));
    await tester.tap(find.byTooltip('播放录音'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('暂停播放').evaluate().isNotEmpty,
    );
    await tester.tap(find.byTooltip('暂停播放'));
    await _pumpUntil(
      tester,
      () => find.byTooltip('播放录音').evaluate().isNotEmpty,
    );
    expect(find.text('录音无法播放'), findsNothing);
    debugPrint(
      'recording device check: M4A bytes=${bytes.length}, durationMs=${attachment.duration.inMilliseconds}, pause/resume/playback passed',
    );
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  fail('Recording device check did not reach the expected state');
}
