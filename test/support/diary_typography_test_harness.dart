import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'expressive_test_theme.dart';

/// 内存中的导入字体库：不读写文件、不向引擎注册字体，测试只关心列表与
/// 选择流程。
class FakeDiaryFontStorage extends DiaryFontStorageService {
  FakeDiaryFontStorage(List<DiaryImportedFont> fonts) : fonts = List.of(fonts);

  final List<DiaryImportedFont> fonts;

  @override
  Future<List<DiaryImportedFont>> listFonts() async => List.of(fonts);

  @override
  Future<void> deleteFont(String fontId) async {
    fonts.removeWhere((font) => font.id == fontId);
  }

  @override
  Future<String> loadFontFamily(DiaryImportedFont font) async =>
      DiaryFontStorageService.familyFor(font.id);
}

/// 以真实 SettingsService 与假字体库挂载排版相关界面。
Future<void> pumpDiaryTypographyHarness(
  WidgetTester tester, {
  required SettingsService settings,
  required FakeDiaryFontStorage storage,
  required Widget home,
  Brightness brightness = Brightness.light,
}) async {
  // 足够高的竖屏，设置页的全部分组无需滚动即可点到。
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        diaryFontStorageServiceProvider.overrideWithValue(storage),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
