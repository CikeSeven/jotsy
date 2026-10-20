import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/settings/pages/diary_code_block_style_page.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';
import 'package:node_diary/ui/settings/sections/diary_code_block_style/diary_code_block_style_preview.dart';
import 'package:node_diary/ui/settings/sections/diary_code_block_style/diary_code_theme_card.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/diary_typography_test_harness.dart';
import '../../../support/expressive_test_theme.dart';

const _mono = DiaryImportedFont(
  id: 'fmono',
  name: 'Iosevka',
  fileName: 'fmono.ttf',
);

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('zh'));

Future<SettingsService> _pump(
  WidgetTester tester, {
  Widget Function(SettingsService settings)? home,
  Map<String, Object> prefs = const <String, Object>{},
  List<DiaryImportedFont> fonts = const <DiaryImportedFont>[_mono],
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        diaryFontStorageServiceProvider.overrideWithValue(
          FakeDiaryFontStorage(fonts),
        ),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: (home ?? (s) => DiaryCodeBlockStylePage(settingsService: s))(
          settings,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

DiaryCodeBlockStyle _stored(SettingsService settings) =>
    DiaryCodeBlockStyle.decode(settings.diaryCodeBlockStyleRaw);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

/// 选项列表是懒构建的：目标还没进树时先在当前标签页里向下滚动。
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _themeCard(DiaryCodeThemeId id) => find.byWidgetPredicate(
  (widget) => widget is DiaryCodeThemeCard && widget.theme == id,
);

void main() {
  testWidgets('the preview renders the sample code blocks', (tester) async {
    await _pump(tester);
    expect(find.byType(DiaryCodeBlockStylePreview), findsOneWidget);
    final editor = tester.widget<quill.QuillEditor>(
      find.descendant(
        of: find.byType(DiaryCodeBlockStylePreview),
        matching: find.byType(quill.QuillEditor),
      ),
    );
    final text = editor.controller.document.toPlainText();
    expect(text, startsWith(_l10n.codeBlockPreviewIntro));
    expect(text, contains('def greet(name: str)'));
    expect(text, contains('"steps": 8421'));
  });

  testWidgets('tapping a theme card persists it', (tester) async {
    final settings = await _pump(tester);
    expect(
      tester
          .widget<DiaryCodeThemeCard>(_themeCard(DiaryCodeThemeId.app))
          .selected,
      isTrue,
    );

    await _reveal(tester, _themeCard(DiaryCodeThemeId.nord));
    await tester.tap(_themeCard(DiaryCodeThemeId.nord));
    await tester.pumpAndSettle();

    expect(_stored(settings).theme, DiaryCodeThemeId.nord);
    expect(
      tester
          .widget<DiaryCodeThemeCard>(_themeCard(DiaryCodeThemeId.nord))
          .selected,
      isTrue,
    );
  });

  testWidgets('the brightness group persists the chosen brightness', (
    tester,
  ) async {
    final settings = await _pump(tester);
    await tester.tap(find.text(_l10n.codeBlockBrightnessDark));
    await tester.pumpAndSettle();
    expect(_stored(settings).brightness, DiaryCodeBrightness.dark);
  });

  testWidgets(
    'the preview brightness button sits in the app bar and only switches the preview',
    (tester) async {
      final settings = await _pump(tester);
      final toggle = find.byTooltip(_l10n.styleEditorPreviewDark);
      // 在标题栏里，与“重置”同一行，不为它单独占一行挤占预览。
      expect(
        find.descendant(of: find.byType(AppTopBar), matching: toggle),
        findsOneWidget,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byTooltip(_l10n.styleEditorPreviewLight), findsOneWidget);
      // 预览明暗只影响预览，不写入设置。
      expect(settings.diaryCodeBlockStyleRaw, isNull);
      final previewTheme = Theme.of(
        tester.element(find.byType(quill.QuillEditor)),
      );
      expect(previewTheme.brightness, Brightness.dark);
    },
  );

  testWidgets('toggling line numbers persists', (tester) async {
    final settings = await _pump(tester);
    await _openTab(tester, _l10n.codeBlockStyleTabDisplay);
    final tile = find.widgetWithText(
      SwitchListTile,
      _l10n.codeBlockLineNumbersTitle,
    );
    await _reveal(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(_stored(settings).lineNumbers, isFalse);
  });

  testWidgets('dragging the font size slider persists only on release', (
    tester,
  ) async {
    final settings = await _pump(tester);
    await _openTab(tester, _l10n.codeBlockStyleTabFont);
    final slider = find.descendant(
      of: find.widgetWithText(SettingsSliderTile, _l10n.codeBlockFontSizeTitle),
      matching: find.byType(Slider),
    );
    await _reveal(tester, slider);

    final rect = tester.getRect(slider);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump();
    await gesture.moveBy(Offset(rect.width * 0.3, 0));
    await tester.pump();
    expect(settings.diaryCodeBlockStyleRaw, isNull);
    final dragging = tester
        .widget<SettingsSliderTile>(
          find.widgetWithText(SettingsSliderTile, _l10n.codeBlockFontSizeTitle),
        )
        .value;
    expect(dragging, greaterThan(DiaryCodeBlockStyle.defaultFontScale));
    expect(
      find.text(_l10n.codeBlockFontSizeValue((dragging * 100).round())),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_stored(settings).fontScale, dragging);
  });

  testWidgets('font chips list imported fonts and commit on tap', (
    tester,
  ) async {
    final settings = await _pump(tester);
    await _openTab(tester, _l10n.codeBlockStyleTabFont);
    expect(find.text(_l10n.codeBlockFontMono), findsOneWidget);
    expect(find.text(_l10n.codeBlockFontBody), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, _mono.name));
    await tester.pumpAndSettle();
    expect(_stored(settings).fontId, _mono.id);
    expect(find.text(_l10n.codeBlockFontMissing), findsNothing);
  });

  testWidgets('a missing imported font stays selected with a note', (
    tester,
  ) async {
    final settings = await _pump(
      tester,
      prefs: <String, Object>{
        'app.settings.diary_code_block_style': const DiaryCodeBlockStyle(
          fontId: 'gone',
        ).encode()!,
      },
      fonts: const <DiaryImportedFont>[],
    );
    await _openTab(tester, _l10n.codeBlockStyleTabFont);
    expect(find.text(_l10n.codeBlockFontMissing), findsOneWidget);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.selected, isFalse);
    }
    expect(_stored(settings).fontId, 'gone');
  });

  testWidgets('reset restores the defaults and can be undone', (tester) async {
    final settings = await _pump(tester);
    await _reveal(tester, _themeCard(DiaryCodeThemeId.dracula));
    await tester.tap(_themeCard(DiaryCodeThemeId.dracula));
    await tester.pumpAndSettle();
    expect(_stored(settings).theme, DiaryCodeThemeId.dracula);

    await tester.tap(find.widgetWithText(TextButton, _l10n.commonReset));
    await tester.pumpAndSettle();
    expect(settings.diaryCodeBlockStyleRaw, isNull);

    await tester.tap(find.text(_l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).theme, DiaryCodeThemeId.dracula);
  });

  testWidgets(
    'the toolbar order page opens the page from the code block gear',
    (tester) async {
      await _pump(
        tester,
        home: (s) => DiaryToolbarOrderPage(settingsService: s),
      );
      final row = find.byKey(
        ValueKey<String>(DiaryToolbarItem.codeBlock.storageKey),
      );
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      final gear = find.descendant(
        of: row,
        matching: find.byTooltip(_l10n.diaryToolbarToolSettingsTooltip),
      );
      expect(gear, findsOneWidget);

      await tester.tap(gear);
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCodeBlockStylePage), findsOneWidget);
    },
  );

  testWidgets('the editor settings entry opens the page', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(
      Scaffold(
        body: ListView(
          children: <Widget>[
            SettingsEditorSection(settingsAsync: AsyncData(h.settings)),
          ],
        ),
      ),
      overrides: [
        diaryFontStorageServiceProvider.overrideWithValue(
          FakeDiaryFontStorage(const <DiaryImportedFont>[]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final typography = tester.getRect(find.text(_l10n.diaryTypographyTitle));
    final entry = find.text(_l10n.codeBlockStyleTitle);
    expect(entry, findsOneWidget);
    // 紧跟在“正文字体与排版”之后。
    expect(tester.getRect(entry).top, greaterThan(typography.top));
    expect(find.text(_l10n.codeBlockStyleSubtitle), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCodeBlockStylePage), findsOneWidget);
    await h.unmount();
  });
}
