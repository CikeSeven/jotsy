import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_mood_palette.dart';
import 'package:node_diary/ui/settings/pages/mood_options_page.dart';
import 'package:node_diary/ui/settings/widgets/mood_palette_strip.dart';
import 'package:node_diary/ui/widgets/color_swatch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

const String _moodColorsKey = 'app.settings.mood_colors';

/// 从一个按钮推入心情符号页（页面保存后会 pop 回来）。
Future<(SettingsService, AppLocalizations)> _pumpPage(
  WidgetTester tester, {
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MoodOptionsPage(settingsService: settings),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(
    tester.element(find.byType(MoodOptionsPage)),
  );
  return (settings, l10n);
}

List<Color> _stripColors(WidgetTester tester) =>
    tester.widget<MoodPaletteStrip>(find.byType(MoodPaletteStrip)).colors;

void main() {
  testWidgets('a picked mood color is saved together with the emojis', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    expect(_stripColors(tester), <Color>[
      for (final c in kDiaryMoodDefaultColors) Color(c),
    ]);

    final lastSwatch = find.bySemanticsLabel(
      l10n.settingsMoodOptionsColorLabel('10'),
    );
    await tester.scrollUntilVisible(
      lastSwatch,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(lastSwatch);
    await tester.pumpAndSettle();
    // 心情色是种子色：只选一个颜色，没有浅色 / 深色切换。
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.styleEditorHexLabel),
      '2E7D32',
    );
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pumpAndSettle();
    // 色谱条已滚出视野，看这一行的色块。
    expect(
      tester
          .widget<ColorSwatchButton>(
            find.ancestor(
              of: lastSwatch,
              matching: find.byType(ColorSwatchButton),
            ),
          )
          .color,
      const Color(0xFF2E7D32),
    );
    // 保存之前不写设置。
    expect(settings.moodColorsRaw, isNull);

    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();
    expect(find.byType(MoodOptionsPage), findsNothing);
    expect(
      DiaryMoodColors.decode(settings.moodColorsRaw).colorOf(10),
      0xFF2E7D32,
    );
    expect(settings.moodOptions, SettingsService.defaultMoodOptions);
  });

  testWidgets('cancelling the color dialog keeps the color', (tester) async {
    final (_, l10n) = await _pumpPage(tester);
    await tester.tap(
      find.bySemanticsLabel(l10n.settingsMoodOptionsColorLabel('1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, l10n.styleEditorHexLabel),
      '000000',
    );
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(_stripColors(tester).first, Color(kDiaryMoodDefaultColors.first));
  });

  testWidgets('reset brings back default emojis and colors', (tester) async {
    final (settings, l10n) = await _pumpPage(
      tester,
      prefs: <String, Object>{_moodColorsKey: '{"3":"#000000"}'},
    );
    expect(_stripColors(tester)[2], const Color(0xFF000000));
    await tester.enterText(find.byType(TextField).first, '🌧');
    await tester.pump();
    expect(
      tester
          .widget<MoodPaletteStrip>(find.byType(MoodPaletteStrip))
          .moods
          .first,
      '🌧',
    );

    await tester.tap(find.text(l10n.commonReset));
    await tester.pump();
    expect(_stripColors(tester), <Color>[
      for (final c in kDiaryMoodDefaultColors) Color(c),
    ]);
    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();
    expect(settings.moodColorsRaw, isNull);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.containsKey(_moodColorsKey), isFalse);
    expect(settings.moodOptions, SettingsService.defaultMoodOptions);
  });
}
