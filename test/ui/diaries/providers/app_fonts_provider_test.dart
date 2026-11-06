import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_typography_test_harness.dart';

const _wenKai = DiaryImportedFont(
  id: 'fwen',
  name: '霞鹜文楷',
  fileName: 'fwen.ttf',
);

/// 注册一直不结束的字体库：模拟超大字体或卡住的读盘。
class _HangingFontStorage extends FakeDiaryFontStorage {
  _HangingFontStorage() : super(const <DiaryImportedFont>[_wenKai]);

  final Completer<String> registration = Completer<String>();

  @override
  Future<String> loadFontFamily(DiaryImportedFont font) => registration.future;
}

Future<ProviderContainer> _container(
  DiaryTypography typography, {
  FakeDiaryFontStorage? storage,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  await settings.setDiaryTypography(typography);
  final container = ProviderContainer(
    overrides: [
      settingsServiceProvider.overrideWith((ref) async => settings),
      diaryFontStorageServiceProvider.overrideWithValue(
        storage ?? FakeDiaryFontStorage(const <DiaryImportedFont>[_wenKai]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(settingsServiceProvider.future);
  return container;
}

void main() {
  group('appFontsProvider', () {
    test(
      'keeps the interface on the bundled font while the switch is off',
      () async {
        final container = await _container(
          const DiaryTypography(fontId: DiaryTypography.systemFontId),
        );

        expect(
          container.read(appFontsProvider),
          const AppFonts(diary: 'sans-serif'),
        );
      },
    );

    test(
      'uses the chosen font for the interface when the switch is on',
      () async {
        final container = await _container(
          const DiaryTypography(
            fontId: DiaryTypography.systemFontId,
            applyFontToApp: true,
          ),
        );

        expect(
          container.read(appFontsProvider),
          const AppFonts(interface: 'sans-serif', diary: 'sans-serif'),
        );
      },
    );

    test('the bundled font never overrides the theme', () async {
      final container = await _container(
        const DiaryTypography(applyFontToApp: true),
      );

      expect(container.read(appFontsProvider), const AppFonts());
    });

    test('an imported font applies once it is registered', () async {
      final container = await _container(
        DiaryTypography(fontId: _wenKai.id, applyFontToApp: true),
      );
      final family = DiaryFontStorageService.familyFor(_wenKai.id);
      container.listen(appFontsProvider, (_, _) {});

      // 注册完成前先按内置字体装配主题。
      expect(container.read(appFontsProvider), const AppFonts());
      await container.read(appFontsStartupReadyProvider.future);

      expect(
        container.read(appFontsProvider),
        AppFonts(interface: family, diary: family),
      );
    });
  });

  group('appFontsStartupReadyProvider', () {
    test('is ready right away without an imported font', () async {
      final container = await _container(
        const DiaryTypography(
          fontId: DiaryTypography.systemFontId,
          applyFontToApp: true,
        ),
      );

      await expectLater(
        container.read(appFontsStartupReadyProvider.future),
        completes,
      );
    });

    testWidgets('stops waiting for a stuck font registration after the cap', (
      tester,
    ) async {
      final storage = _HangingFontStorage();
      final container = await _container(
        DiaryTypography(fontId: _wenKai.id),
        storage: storage,
      );
      container.listen(appFontsStartupReadyProvider, (_, _) {});
      await tester.pump();

      expect(container.read(appFontsStartupReadyProvider).isLoading, isTrue);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(container.read(appFontsStartupReadyProvider).isLoading, isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(appFontsStartupReadyProvider).isLoading, isFalse);
      // 超时只放行启动，字体就绪后照常换上。
      expect(container.read(appFontsProvider), const AppFonts());

      storage.registration.complete(
        DiaryFontStorageService.familyFor(_wenKai.id),
      );
      await tester.pump();
      expect(
        container.read(appFontsProvider).diary,
        DiaryFontStorageService.familyFor(_wenKai.id),
      );
    });
  });
}
