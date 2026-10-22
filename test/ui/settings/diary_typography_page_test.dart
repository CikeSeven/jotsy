import '../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/diary_typography_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/diary_typography_test_harness.dart';

const _wenKai = DiaryImportedFont(
  id: 'fwen',
  name: '霞鹜文楷',
  fileName: 'fwen.ttf',
);

/// 预览卡里正文实际使用的 Quill 段落样式。
({TextStyle style, ({double bottom}) verticalSpacing}) _previewParagraph(
  WidgetTester tester,
) {
  final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor).first);
  return (
    style: editor.controller.state.editorStyle.textStyleConfiguration.text,
    verticalSpacing: (bottom: editor.appearance.typography.paragraphSpacing),
  );
}

TextStyle _previewParagraphStyle(WidgetTester tester) =>
    _previewParagraph(tester).style;

void main() {
  late SettingsService settings;
  late FakeDiaryFontStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    storage = FakeDiaryFontStorage(const <DiaryImportedFont>[_wenKai]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('choosing fonts and stepping values commits immediately in '
        '${brightness.name}', (tester) async {
      await pumpDiaryTypographyHarness(
        tester,
        settings: settings,
        storage: storage,
        home: const DiaryTypographyPage(),
        brightness: brightness,
      );
      final l10n = tester.element(find.byType(DiaryTypographyPage)).l10n;

      expect(find.text(l10n.diaryTypographySampleTitle), findsOneWidget);
      expect(find.text(_wenKai.name), findsOneWidget);

      await tester.tap(find.text(l10n.diaryTypographyFontSystem));
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.fontId, DiaryTypography.systemFontId);

      await tester.tap(
        find.byTooltip(
          l10n.diaryTypographyIncrease(l10n.diaryTypographyFontSize),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.fontSize, 17);
      expect(_previewParagraphStyle(tester).fontSize, 17);
      expect(_previewParagraphStyle(tester).fontFamily, 'sans-serif');

      await tester.tap(find.text(l10n.diaryTypographyReset));
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.hasDefaultMetrics, isTrue);
      // 恢复默认排版只重置数值，保留字体选择。
      expect(settings.diaryTypography.fontId, DiaryTypography.systemFontId);
    });
  }

  testWidgets('dragging a slider previews the draft and commits on release', (
    tester,
  ) async {
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      home: const DiaryTypographyPage(),
    );
    final paragraphSlider = find.byType(Slider).at(3);
    final start = tester.getCenter(paragraphSlider);
    // 段间距默认 0，滑块在最左端，从轨道起点开始拖。
    final from = Offset(tester.getTopLeft(paragraphSlider).dx + 30, start.dy);

    final gesture = await tester.startGesture(from);
    await tester.pump();
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();

    // 拖动中：预览按草稿排版，设置尚未提交。
    final draftSpacing = _previewParagraph(tester).verticalSpacing.bottom;
    expect(draftSpacing, greaterThan(0));
    expect(settings.diaryTypography.paragraphSpacing, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(settings.diaryTypography.paragraphSpacing, draftSpacing);
    expect(_previewParagraph(tester).verticalSpacing.bottom, draftSpacing);
  });

  testWidgets('deleting the font in use falls back to the bundled font', (
    tester,
  ) async {
    await settings.setDiaryTypography(
      const DiaryTypography().copyWith(fontId: _wenKai.id),
    );
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      home: const DiaryTypographyPage(),
    );
    final l10n = tester.element(find.byType(DiaryTypographyPage)).l10n;
    expect(
      _previewParagraphStyle(tester).fontFamily,
      DiaryFontStorageService.familyFor(_wenKai.id),
    );

    await tester.tap(find.byTooltip(l10n.diaryTypographyDeleteFont));
    await tester.pumpAndSettle();
    // 取消不删除。
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(storage.fonts, hasLength(1));

    await tester.tap(find.byTooltip(l10n.diaryTypographyDeleteFont));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();

    expect(storage.fonts, isEmpty);
    expect(find.text(_wenKai.name), findsNothing);
    expect(settings.diaryTypography.fontId, DiaryTypography.bundledFontId);
    expect(find.byIcon(FontAwesomeIcons.trashCan.data), findsNothing);
  });

  testWidgets('a selected font that is no longer on disk is explained', (
    tester,
  ) async {
    await settings.setDiaryTypography(
      const DiaryTypography().copyWith(fontId: 'frestored'),
    );
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      home: const DiaryTypographyPage(),
    );
    final l10n = tester.element(find.byType(DiaryTypographyPage)).l10n;

    expect(find.text(l10n.diaryTypographyFontMissing), findsOneWidget);
    // 正文回落到主题字体（不覆盖字族）。
    expect(_previewParagraphStyle(tester).fontFamily, 'HarmonyOSSansSC');
  });
}
