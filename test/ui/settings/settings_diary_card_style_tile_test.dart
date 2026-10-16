import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/settings/pages/diary_card_style_page.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_card_style_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  testWidgets('the entry names the current style and opens the editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettingsDiaryCardStyleTile(settingsAsync: AsyncData(settings)),
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(
      find.text(
        l10n.diaryCardStyleEntrySubtitle(l10n.diaryCardStylePresetClassic),
      ),
      findsOneWidget,
    );

    await settings.setDiaryCardStyleRaw(
      DiaryCardStyleSettings.defaults
          .withCurrent(DiaryCardPresets.styleOf(DiaryCardPresetId.gallery))
          .encode(),
    );
    await tester.pump();
    expect(
      find.text(
        l10n.diaryCardStyleEntrySubtitle(l10n.diaryCardStylePresetGallery),
      ),
      findsOneWidget,
    );

    await settings.setDiaryCardStyleRaw(
      DiaryCardStyleSettings.defaults
          .withCurrent(
            const DiaryCardStyle(
              surface: DiaryCardSurfaceStyle(cornerRadius: 3),
            ),
          )
          .encode(),
    );
    await tester.pump();
    expect(
      find.text(l10n.diaryCardStyleEntrySubtitle(l10n.diaryCardStyleCustom)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.diaryCardStyleTitle));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCardStylePage), findsOneWidget);
  });
}
