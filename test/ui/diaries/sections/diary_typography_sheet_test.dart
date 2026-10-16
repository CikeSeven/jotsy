import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_typography_sheet.dart';
import 'package:node_diary/ui/settings/pages/diary_typography_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_typography_test_harness.dart';

void main() {
  late SettingsService settings;
  late FakeDiaryFontStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    storage = FakeDiaryFontStorage(const <DiaryImportedFont>[
      DiaryImportedFont(id: 'fwen', name: '霞鹜文楷', fileName: 'fwen.ttf'),
    ]);
  });

  Future<AppLocalizations> openSheet(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      brightness: brightness,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showDiaryTypographySheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return tester.element(find.byType(DiaryTypographySheet)).l10n;
  }

  for (final brightness in Brightness.values) {
    testWidgets('quick panel switches fonts and adjusts values in '
        '${brightness.name}', (tester) async {
      final l10n = await openSheet(tester, brightness);

      expect(find.byType(ChoiceChip), findsNWidgets(3));
      // 字体条横向滚动；测试字体（Ahem）比真实字形宽，第三个选项在屏外。
      final wenKaiChip = find.widgetWithText(ChoiceChip, '霞鹜文楷');
      await tester.ensureVisible(wenKaiChip);
      await tester.pumpAndSettle();
      await tester.tap(wenKaiChip);
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.fontId, 'fwen');

      await tester.tap(
        find.byTooltip(
          l10n.diaryTypographyDecrease(l10n.diaryTypographyLineHeight),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.lineHeight, 1.5);

      // 数值偏离默认后才能恢复默认；恢复时保留刚选的字体。
      await tester.tap(find.text(l10n.diaryTypographyReset));
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.lineHeight, 1.55);
      expect(settings.diaryTypography.fontId, 'fwen');
      final reset = tester.widget<TextButton>(
        find.widgetWithText(TextButton, l10n.diaryTypographyReset),
      );
      expect(reset.onPressed, isNull);
    });
  }

  testWidgets('quick panel links to the full settings page', (tester) async {
    final l10n = await openSheet(tester, Brightness.light);

    await tester.tap(find.text(l10n.diaryTypographyMoreSettings));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryTypographyPage), findsOneWidget);
  });
}
