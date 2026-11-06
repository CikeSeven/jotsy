import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/diary_typography_test_harness.dart';

const _wenKai = DiaryImportedFont(
  id: 'fwen',
  name: '霞鹜文楷',
  fileName: 'fwen.ttf',
);

final String _wenKaiFamily = DiaryFontStorageService.familyFor(_wenKai.id);

/// 字体注册由测试手动放行：模拟大字体注册期间的启动。
class _GatedFontStorage extends FakeDiaryFontStorage {
  _GatedFontStorage() : super(const <DiaryImportedFont>[_wenKai]);

  final Completer<String> registration = Completer<String>();

  @override
  Future<String> loadFontFamily(DiaryImportedFont font) => registration.future;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required DiaryTypography typography,
  required FakeDiaryFontStorage storage,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await settings.setDiaryTypography(typography);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
        diaryFontStorageServiceProvider.overrideWithValue(storage),
      ],
      child: const NodeDiaryApp(),
    ),
  );
}

/// 推进 [frames] 帧（每帧 16ms），内存库的真实异步也随之完成。
Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntilHome(WidgetTester tester) async {
  for (var frame = 0; frame < 160; frame++) {
    if (find.byType(HomePage).evaluate().isNotEmpty) {
      return;
    }
    await _pumpFrames(tester, 1);
  }
  fail('the home page never mounted');
}

ThemeData _homeTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(HomePage)));

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('the whole-app switch puts the chosen font into the app theme', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      typography: const DiaryTypography(
        fontId: DiaryTypography.systemFontId,
        applyFontToApp: true,
      ),
      storage: FakeDiaryFontStorage(const <DiaryImportedFont>[]),
    );
    await _pumpUntilHome(tester);

    final theme = _homeTheme(tester);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'sans-serif');
    expect(theme.textTheme.titleLarge?.fontFamily, 'sans-serif');
    expect(
      AppFonts.of(theme),
      const AppFonts(interface: 'sans-serif', diary: 'sans-serif'),
    );
    await _unmount(tester);
  });

  testWidgets('with the switch off the interface keeps the bundled font and '
      'only diary cards get the chosen one', (tester) async {
    await _pumpApp(
      tester,
      typography: const DiaryTypography(fontId: DiaryTypography.systemFontId),
      storage: FakeDiaryFontStorage(const <DiaryImportedFont>[]),
    );
    await _pumpUntilHome(tester);

    final theme = _homeTheme(tester);
    expect(theme.textTheme.bodyMedium?.fontFamily, kAppBundledFontFamily);
    expect(AppFonts.of(theme), const AppFonts(diary: 'sans-serif'));
    await _unmount(tester);
  });

  testWidgets('home waits for the imported font so cards never re-layout', (
    tester,
  ) async {
    final storage = _GatedFontStorage();
    await _pumpApp(
      tester,
      typography: DiaryTypography(fontId: _wenKai.id),
      storage: storage,
    );
    // 约 0.8 秒：设置与首屏日记早已就绪，字体仍在注册。
    await _pumpFrames(tester, 50);
    expect(find.byType(HomePage), findsNothing);

    storage.registration.complete(_wenKaiFamily);
    await _pumpUntilHome(tester);

    // 首页第一帧就是导入字体；界面字体仍是内置字体。
    final theme = _homeTheme(tester);
    expect(AppFonts.of(theme), AppFonts(diary: _wenKaiFamily));
    expect(theme.textTheme.bodyMedium?.fontFamily, kAppBundledFontFamily);
    await _unmount(tester);
  });

  testWidgets('a stuck font registration does not block startup forever', (
    tester,
  ) async {
    final storage = _GatedFontStorage();
    await _pumpApp(
      tester,
      typography: DiaryTypography(fontId: _wenKai.id, applyFontToApp: true),
      storage: storage,
    );
    await _pumpUntilHome(tester);

    // 超过等待上限后照常进入首页，先按内置字体显示。
    expect(AppFonts.of(_homeTheme(tester)), const AppFonts());

    storage.registration.complete(_wenKaiFamily);
    await _pumpFrames(tester, 2);
    final theme = _homeTheme(tester);
    expect(
      AppFonts.of(theme),
      AppFonts(interface: _wenKaiFamily, diary: _wenKaiFamily),
    );
    expect(theme.textTheme.bodyMedium?.fontFamily, _wenKaiFamily);
    await _unmount(tester);
  });
}
