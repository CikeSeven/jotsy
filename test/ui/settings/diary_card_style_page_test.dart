import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_code.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_view_data.dart';
import 'package:node_diary/ui/settings/pages/diary_card_style_page.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 模拟系统剪贴板：Clipboard.setData / getData 走 platform channel。
String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          _clipboard = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return _clipboard == null
              ? null
              : <String, Object?>{'text': _clipboard};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

Future<(SettingsService, AppLocalizations)> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 860),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiaryCardStylePage(settingsService: settings),
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return (settings, l10n);
}

DiaryCardStyleSettings _stored(SettingsService settings) =>
    DiaryCardStyleSettings.decode(settings.diaryCardStyleRaw);

Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// 选项列表是懒构建的：目标还没进树时先在当前标签页里向下滚动。
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
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
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 等撤销提示自行关闭，避免它的强制关闭计时器在用例结束时仍未触发。
Future<void> _dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(DiaryCardViewData.debugClearCache);

  testWidgets('shows a live preview above nine option tabs', (tester) async {
    final (_, l10n) = await _pumpPage(tester);
    expect(find.byType(DiariesListSection), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(9));
    expect(find.text(l10n.diaryCardStyleSampleTitle1), findsOneWidget);
    // 默认样式时“重置”不可用。
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, l10n.commonReset))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches persist immediately and update the preview', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabContent);
    await _tapVisible(
      tester,
      find.widgetWithText(SwitchListTile, l10n.diaryCardStyleShowPreview),
    );
    expect(_stored(settings).current.content.showPreview, isFalse);
    expect(find.text(l10n.diaryCardStyleSampleBody1), findsNothing);
  });

  testWidgets('the untitled switch updates the preview and follows the title', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    // 预览里第 4 篇示例没写标题：滚到它，默认显示“无标题”。
    await tester.scrollUntilVisible(
      find.text(l10n.diaryCardStyleSampleBody4),
      120,
      scrollable: find
          .ancestor(
            of: find.byType(DiariesListSection),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(l10n.autoT0033), findsOneWidget);

    await _openTab(tester, l10n.diaryCardStyleTabContent);
    final untitledSwitch = find.widgetWithText(
      SwitchListTile,
      l10n.diaryCardStyleShowUntitled,
    );
    await _tapVisible(tester, untitledSwitch);
    expect(_stored(settings).current.content.showUntitled, isFalse);
    expect(find.text(l10n.diaryCardStyleSampleBody4), findsOneWidget);
    expect(find.text(l10n.autoT0033), findsNothing);

    // 标题整体关闭后这个开关没有意义，随之收起。
    await _tapVisible(
      tester,
      find.widgetWithText(SwitchListTile, l10n.diaryCardStyleShowTitle),
    );
    expect(_stored(settings).current.content.showTitle, isFalse);
    expect(untitledSwitch, findsNothing);
  });

  testWidgets('date choices center their radio dots beside the examples', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabDate);
    for (final label in <String>[
      l10n.diaryCardStyleDateFull,
      l10n.diaryCardStyleFooterRelative,
    ]) {
      final text = find.text(label);
      await _tapVisible(tester, text);
      final tile = find.ancestor(of: text, matching: find.byType(ListTile));
      final dot = find.descendant(of: tile, matching: find.byType(FaIcon));
      expect(
        (tester.getCenter(dot).dy - tester.getCenter(tile).dy).abs(),
        lessThan(0.5),
        reason: label,
      );
    }
  });

  testWidgets('sliders preview while dragging and persist on release', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabLayout);
    final tile = tester.widget<SettingsSliderTile>(
      find.widgetWithText(SettingsSliderTile, l10n.diaryCardStyleCornerRadius),
    );
    tile.onChanged!(7);
    await tester.pump();
    expect(settings.diaryCardStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleValueDp('7')), findsOneWidget);

    tile.onChangeEnd!(7);
    await tester.pumpAndSettle();
    expect(_stored(settings).current.surface.cornerRadius, 7);
  });

  testWidgets('reset restores the default style and can be undone', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetMagazine));
    await _dismissSnackBars(tester);
    final magazine = DiaryCardPresets.styleOf(DiaryCardPresetId.magazine);
    expect(_stored(settings).current, magazine);

    await tester.tap(find.widgetWithText(TextButton, l10n.commonReset));
    await tester.pumpAndSettle();
    expect(settings.diaryCardStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleResetDone), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).current, magazine);
  });

  testWidgets('applying a preset can be undone', (tester) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetMinimal));
    expect(
      _stored(settings).current,
      DiaryCardPresets.styleOf(DiaryCardPresetId.minimal),
    );
    expect(
      find.text(l10n.diaryCardStyleApplied(l10n.diaryCardStylePresetMinimal)),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(settings.diaryCardStyleRaw, isNull);
  });

  testWidgets('saved styles can be saved, renamed and deleted with undo', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetCompact));
    await _dismissSnackBars(tester);

    await _tapVisible(tester, find.text(l10n.diaryCardStyleSaveCurrent));
    await tester.enterText(find.byType(TextField), 'Dense');
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pumpAndSettle();
    await _dismissSnackBars(tester);
    expect(_stored(settings).saved.single.name, 'Dense');
    expect(
      _stored(settings).saved.single.style,
      DiaryCardPresets.styleOf(DiaryCardPresetId.compact),
    );

    await _tapVisible(
      tester,
      find.byTooltip(l10n.diaryCardStyleSavedActions('Dense')),
    );
    await tester.tap(find.text(l10n.diaryCardStyleRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tight');
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pumpAndSettle();
    expect(_stored(settings).saved.single.name, 'Tight');

    await _tapVisible(
      tester,
      find.byTooltip(l10n.diaryCardStyleSavedActions('Tight')),
    );
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(_stored(settings).saved, isEmpty);
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).saved.single.name, 'Tight');
  });

  testWidgets('style codes are copied and imported through the clipboard', (
    tester,
  ) async {
    _mockClipboard(tester);
    final (settings, l10n) = await _pumpPage(tester);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetJournal));
    await _dismissSnackBars(tester);

    await _tapVisible(tester, find.text(l10n.diaryCardStyleCopyCode));
    expect(_clipboard, startsWith('${DiaryCardStyleCode.scheme}:v1:'));
    await _dismissSnackBars(tester);

    final code = _clipboard!;
    await tester.tap(find.widgetWithText(TextButton, l10n.commonReset));
    await tester.pumpAndSettle();
    await _dismissSnackBars(tester);
    expect(settings.diaryCardStyleRaw, isNull);

    _clipboard = 'Try this one: $code';
    await _tapVisible(tester, find.text(l10n.diaryCardStyleImportCode));
    expect(
      _stored(settings).current,
      DiaryCardPresets.styleOf(DiaryCardPresetId.journal),
    );
    expect(
      find.text(
        l10n.diaryCardStyleImportedNamed(l10n.diaryCardStylePresetJournal),
      ),
      findsOneWidget,
    );
    await _dismissSnackBars(tester);

    _clipboard = 'definitely not a style';
    await _tapVisible(tester, find.text(l10n.diaryCardStyleImportCode));
    expect(find.text(l10n.diaryCardStyleImportInvalid), findsOneWidget);
    expect(
      _stored(settings).current,
      DiaryCardPresets.styleOf(DiaryCardPresetId.journal),
    );
    await _dismissSnackBars(tester);
  });

  testWidgets('the layout toggle edits the waterfall-only options', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await tester.tap(find.text(l10n.autoT0147));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DiariesListSection>(find.byType(DiariesListSection))
          .layoutMode,
      DiaryLayoutMode.waterfall,
    );
    await _openTab(tester, l10n.diaryCardStyleTabLayout);
    expect(find.text(l10n.diaryCardStyleWaterfallGroup), findsOneWidget);
    await _tapVisible(tester, find.text(l10n.diaryCardStyleColumnsValue(3)));
    expect(_stored(settings).current.waterfall.columns, 3);
    expect(_stored(settings).current.list, DiaryCardModeStyle.listDefaults);
  });

  testWidgets('the preview can switch to the opposite brightness', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
    Brightness previewBrightness() =>
        Theme.of(tester.element(find.byType(DiariesListSection))).brightness;
    expect(previewBrightness(), Brightness.light);
    await tester.tap(find.byTooltip(l10n.diaryCardStylePreviewDark));
    await tester.pumpAndSettle();
    expect(previewBrightness(), Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('every tab fits a 320dp screen in $brightness', (tester) async {
      final (_, l10n) = await _pumpPage(
        tester,
        brightness: brightness,
        size: const Size(320, 640),
      );
      for (final label in <String>[
        l10n.diaryCardStyleTabPresets,
        l10n.diaryCardStyleTabLayout,
        l10n.diaryCardStyleTabCover,
        l10n.diaryCardStyleTabContent,
        l10n.diaryCardStyleTabDate,
        l10n.diaryCardStyleTabOrder,
        l10n.diaryCardStyleTabText,
        l10n.diaryCardStyleTabColor,
        l10n.diaryCardStyleTabTexture,
      ]) {
        await _openTab(tester, label);
        await tester.drag(find.byType(TabBarView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }
}
