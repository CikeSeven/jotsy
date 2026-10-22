import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/settings/pages/home_bar_style_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expressive_test_theme.dart';

// 导航栏样式页的组件测试共用的装配与操作：真实的 SettingsService（内存
// SharedPreferences）、按标签页滚动到懒构建的选项再点按。

Widget homeBarStyleApp(
  SettingsService settings,
  Widget home, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
}) {
  return ProviderScope(
    overrides: [settingsServiceProvider.overrideWith((ref) async => settings)],
    child: MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<(SettingsService, AppLocalizations)> pumpHomeBarStylePage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
  Size size = const Size(400, 860),
  HomeBarSettings? initial,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (initial != null) 'app.settings.home_bar_style': initial.encode()!,
  });
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    homeBarStyleApp(
      settings,
      HomeBarStylePage(settingsService: settings),
      brightness: brightness,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return (settings, l10n);
}

HomeBarSettings storedHomeBarSettings(SettingsService settings) =>
    HomeBarSettings.decode(settings.homeBarStyleRaw);

Future<void> openHomeBarStyleTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// 选项列表是懒构建的：目标还没进树时先在当前标签页里向下滚动。
Future<void> scrollToHomeBarOption(WidgetTester tester, Finder finder) async {
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

Future<void> tapHomeBarOption(WidgetTester tester, Finder finder) async {
  await scrollToHomeBarOption(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 选项面板里的某个文字（不含上方预览）。
Finder inHomeBarOptions(String text) =>
    find.descendant(of: find.byType(TabBarView), matching: find.text(text));
