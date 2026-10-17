import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_content.dart';
import 'package:node_diary/ui/settings/pages/diary_card_style_page.dart';
import 'package:node_diary/ui/settings/pages/diary_preview_style_page.dart';
import 'package:node_diary/ui/settings/sections/diary_card_style/diary_card_style_preview.dart';
import 'package:node_diary/ui/settings/sections/diary_preview_style/diary_preview_style_preview.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 完整页面的工具条回归：只点按钮并等待绘制，不用返回手势或其他交互
/// 触发额外重建，确保工具条与实际预览在窄屏、宽屏及明暗主题下同步。
Future<AppLocalizations> _pumpPage(
  WidgetTester tester, {
  required Widget Function(SettingsService settings) buildPage,
  required Brightness brightness,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: buildPage(settings),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
}

Future<void> _toggleBrightnessRepeatedly(
  WidgetTester tester, {
  required AppLocalizations l10n,
  required Brightness initialBrightness,
  required Finder toolbar,
  required Finder preview,
}) async {
  String tooltip(Brightness brightness) => brightness == Brightness.light
      ? l10n.styleEditorPreviewDark
      : l10n.styleEditorPreviewLight;

  void expectBrightness(Brightness brightness) {
    expect(preview, findsWidgets);
    for (final element in preview.evaluate()) {
      expect(Theme.of(element).brightness, brightness);
    }
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byTooltip(tooltip(brightness)),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FaIcon>(
            find.descendant(of: toolbar, matching: find.byType(FaIcon)),
          )
          .icon
          ?.codePoint,
      (brightness == Brightness.light
              ? FontAwesomeIcons.moon
              : FontAwesomeIcons.sun)
          .codePoint,
    );
  }

  var brightness = initialBrightness;
  expectBrightness(brightness);
  // 连续往返：旧回调捕获的明暗值可能让第一次切换成功，第二次起失效。
  for (var i = 0; i < 4; i++) {
    await tester.tap(
      find.descendant(
        of: toolbar,
        matching: find.byTooltip(tooltip(brightness)),
      ),
    );
    await tester.pumpAndSettle();
    brightness = brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    expectBrightness(brightness);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final size in <Size>[const Size(400, 860), const Size(900, 700)]) {
      final environment = '${size.width}dp in ${brightness.name}';

      testWidgets('card layout selection follows each tap at $environment', (
        tester,
      ) async {
        final l10n = await _pumpPage(
          tester,
          buildPage: (settings) =>
              DiaryCardStylePage(settingsService: settings),
          brightness: brightness,
          size: size,
        );
        final group = find.descendant(
          of: find.byType(DiaryCardStylePreviewToolbar),
          matching: find.byType(ExpressiveButtonGroup<DiaryCardMode>),
        );

        void expectLayout(DiaryCardMode mode) {
          expect(
            tester.widget<ExpressiveButtonGroup<DiaryCardMode>>(group).selected,
            <DiaryCardMode>{mode},
          );
          expect(
            tester
                .widget<DiariesListSection>(find.byType(DiariesListSection))
                .layoutMode,
            mode == DiaryCardMode.list
                ? DiaryLayoutMode.list
                : DiaryLayoutMode.waterfall,
          );
        }

        expectLayout(DiaryCardMode.list);
        for (final mode in <DiaryCardMode>[
          DiaryCardMode.waterfall,
          DiaryCardMode.list,
          DiaryCardMode.list,
          DiaryCardMode.waterfall,
        ]) {
          await tester.tap(
            find.descendant(
              of: group,
              matching: find.text(
                mode == DiaryCardMode.list ? l10n.autoT0146 : l10n.autoT0147,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expectLayout(mode);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('card brightness toggles on every tap at $environment', (
        tester,
      ) async {
        final l10n = await _pumpPage(
          tester,
          buildPage: (settings) =>
              DiaryCardStylePage(settingsService: settings),
          brightness: brightness,
          size: size,
        );
        await _toggleBrightnessRepeatedly(
          tester,
          l10n: l10n,
          initialBrightness: brightness,
          toolbar: find.byType(DiaryCardStylePreviewToolbar),
          preview: find.byType(DiariesListSection),
        );
      });

      testWidgets('reader brightness toggles on every tap at $environment', (
        tester,
      ) async {
        final l10n = await _pumpPage(
          tester,
          buildPage: (settings) =>
              DiaryPreviewStylePage(settingsService: settings),
          brightness: brightness,
          size: size,
        );
        await _toggleBrightnessRepeatedly(
          tester,
          l10n: l10n,
          initialBrightness: brightness,
          toolbar: find.byType(DiaryPreviewStylePreviewToolbar),
          preview: find.byType(DiaryPreviewContent),
        );
      });
    }
  }
}
