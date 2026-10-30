import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/widgets/app_background_layers_view.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_surface.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/settings/pages/diary_card_style_page.dart';
import 'package:node_diary/ui/settings/pages/diary_code_block_style_page.dart';
import 'package:node_diary/ui/settings/pages/diary_preview_style_page.dart';
import 'package:node_diary/ui/settings/pages/home_bar_style_page.dart';
import 'package:node_diary/ui/settings/sections/diary_card_style/diary_card_style_preview.dart';
import 'package:node_diary/ui/settings/sections/diary_code_block_style/diary_code_block_style_preview.dart';
import 'package:node_diary/ui/settings/sections/diary_preview_style/diary_preview_style_preview.dart';
import 'package:node_diary/ui/settings/sections/home_bar_style/home_bar_style_preview.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../app_surface/app_surface_test_images.dart';

/// 样式编辑页的实时预览画在“样式实际所在区域”的背景上：卡片 / 导航栏 →
/// 日记页，预览页样式 → 预览页，代码块 → 编辑页；该区域没有背景时与原来
/// 相同（预览铺预览主题的页面底色）。
const Color _bg = Color(0xFF3A6B8C);
const Color _bgDark = Color(0xFF102030);

AppSurfaceSettings _colorIn(AppBackgroundArea area) =>
    AppSurfaceSettings.defaults.withArea(
      area,
      AppAreaBackground(
        mode: AppAreaBackgroundMode.custom,
        custom: AppBackground(
          kind: AppBackgroundKind.color,
          colorLight: _bg.toARGB32(),
          colorDark: _bgDark.toARGB32(),
        ),
      ),
    );

AppSurfaceSettings _imageIn(AppBackgroundArea area) =>
    AppSurfaceSettings.defaults.withArea(
      area,
      const AppAreaBackground(
        mode: AppAreaBackgroundMode.custom,
        custom: AppBackground(
          kind: AppBackgroundKind.image,
          image: 'bg.png',
          scrimLight: 0.2,
        ),
      ),
    );

class _FakeSurface extends AppSurfaceSettingsNotifier {
  _FakeSurface(this.value);

  final AppSurfaceSettings value;

  @override
  AppSurfaceSettings build() => value;
}

Future<SettingsService> _pump(
  WidgetTester tester,
  Widget Function(SettingsService settings) page, {
  required AppSurfaceSettings surface,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final settings = (await tester.runAsync(SettingsService.create))!;
  final cache = AppBackgroundImageCache(loader: FakeBackgroundLoader().call);
  addTearDown(cache.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        appSurfaceSettingsProvider.overrideWith(() => _FakeSurface(surface)),
        appBackgroundImageCacheProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: page(settings),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

/// 等图片背景解码（真实异步）并推进帧。
Future<void> _settleImage(WidgetTester tester, Finder within) async {
  bool done() => AppPageBackdrop.of(
    tester.element(
      find.descendant(of: within, matching: find.byType(Material)).first,
    ),
  ).hasImage;
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// [preview] 之内的页面背景组件。
Finder _previewBackground(Finder preview) =>
    find.descendant(of: preview, matching: find.byType(AppPageBackground));

List<Color> _layerColors(WidgetTester tester, Finder preview) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.descendant(
          of: preview,
          matching: find.byType(AppBackgroundLayersView),
        ),
        matching: find.byType(ColoredBox),
      ),
    )
    .map((box) => box.color)
    .toList();

Color _pageBackgroundOf(WidgetTester tester, Finder finder) =>
    ExpressiveSurfaces.pageBackground(
      Theme.of(tester.element(finder.first)).colorScheme,
    );

void main() {
  group('diary card style', () {
    final preview = find.byType(DiaryCardStylePreview);
    Finder pageMaterial() => find
        .ancestor(
          of: find.byType(DiariesListSection),
          matching: find.byType(Material),
        )
        .first;

    testWidgets('the preview sits on the diaries background', (tester) async {
      await _pump(
        tester,
        (s) => DiaryCardStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.diaries),
      );
      final background = tester.widget<AppPageBackground>(
        _previewBackground(preview),
      );
      expect(background.area, AppBackgroundArea.diaries);
      expect(_layerColors(tester, preview), <Color>[_bg]);
      expect(tester.widget<Material>(pageMaterial()).color, Colors.transparent);
      // 卡片按日记页背景估计对比度。
      expect(
        AppPageBackdrop.estimatedColorOf(
          tester.element(find.byType(DiariesListSection)),
        ),
        _bg,
      );
    });

    testWidgets('without a diaries background the preview is unchanged', (
      tester,
    ) async {
      // 设置区域的背景不进预览。
      await _pump(
        tester,
        (s) => DiaryCardStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.settings),
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.byType(AppBackgroundLayersView),
        ),
        findsNothing,
      );
      expect(
        tester.widget<Material>(pageMaterial()).color,
        _pageBackgroundOf(tester, find.byType(DiariesListSection)),
      );
      final backdrop = AppPageBackdrop.of(
        tester.element(find.byType(DiariesListSection)),
      );
      expect(backdrop.hasBackground, isFalse);
      expect(backdrop.area, AppBackgroundArea.diaries);
    });

    testWidgets('glass cards blur the preview\'s background image', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => DiaryCardStylePage(settingsService: s),
        surface: _imageIn(AppBackgroundArea.diaries),
        prefs: <String, Object>{
          'app.settings.diary_card_style': DiaryCardStyleSettings(
            current: DiaryCardPresets.styleOf(DiaryCardPresetId.glass),
          ).encode()!,
        },
      );
      await _settleImage(tester, preview);
      final backdrop = AppPageBackdrop.of(
        tester.element(find.byType(DiariesListSection)),
      );
      expect(backdrop.hasImage, isTrue);
      expect(backdrop.area, AppBackgroundArea.diaries);
      final blurs = tester
          .widgetList<BackdropFilter>(
            find.byWidgetPredicate(
              (w) =>
                  w is BackdropFilter &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'diary_selection_blur_',
                  ),
            ),
          )
          .toList();
      expect(blurs, isNotEmpty);
      for (final blur in blurs) {
        expect(blur.enabled, isTrue);
        expect(blur.backdropGroupKey, backdrop.contentBackdropKey);
      }
    });

    testWidgets('the preview brightness switch also switches the background', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => DiaryCardStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.diaries),
      );
      expect(_layerColors(tester, preview), <Color>[_bg]);
      await tester.tap(find.byType(StylePreviewBrightnessButton).first);
      await tester.pumpAndSettle();
      expect(_layerColors(tester, preview), <Color>[_bgDark]);
    });
  });

  group('home bar style', () {
    final preview = find.byType(HomeBarStylePreview);
    Finder frameMaterial() => find
        .descendant(
          of: _previewBackground(preview),
          matching: find.byType(Material),
        )
        .first;

    testWidgets('the miniature home shows the diaries background', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => HomeBarStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.diaries),
      );
      expect(
        tester.widget<AppPageBackground>(_previewBackground(preview)).area,
        AppBackgroundArea.diaries,
      );
      expect(_layerColors(tester, preview), <Color>[_bg]);
      expect(
        tester.widget<Material>(frameMaterial()).color,
        Colors.transparent,
      );
      final topBar = find.descendant(
        of: preview,
        matching: find.byType(HomeTopBarSurface),
      );
      expect(
        tester.widget<HomeTopBarSurface>(topBar).solidColor,
        AppPageBackdrop.solidBarColorOf(tester.element(topBar)),
      );
      // 纯色背景时实色栏与背景同色。
      expect(tester.widget<HomeTopBarSurface>(topBar).solidColor, _bg);
    });

    testWidgets('without a background the frame keeps its page colors', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => HomeBarStylePage(settingsService: s),
        surface: AppSurfaceSettings.defaults,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.byType(AppBackgroundLayersView),
        ),
        findsNothing,
      );
      expect(
        tester.widget<Material>(frameMaterial()).color,
        _pageBackgroundOf(tester, frameMaterial()),
      );
      final topBar = find.descendant(
        of: preview,
        matching: find.byType(HomeTopBarSurface),
      );
      expect(
        tester.widget<HomeTopBarSurface>(topBar).solidColor,
        Theme.of(tester.element(topBar)).colorScheme.surface,
      );
    });
  });

  group('diary preview style', () {
    final preview = find.byType(DiaryPreviewStylePreview);
    Color surfaceScaffold(WidgetTester tester) => tester
        .widget<Scaffold>(
          find
              .descendant(
                of: find.byType(DiaryPreviewSurface),
                matching: find.byType(Scaffold),
              )
              .first,
        )
        .backgroundColor!;

    testWidgets('a theme paper gives way to the preview background', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => DiaryPreviewStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.preview),
      );
      expect(
        tester.widget<AppPageBackground>(_previewBackground(preview)).area,
        AppBackgroundArea.preview,
      );
      expect(_layerColors(tester, preview), <Color>[_bg]);
      expect(surfaceScaffold(tester), Colors.transparent);
    });

    testWidgets('a tinted veil is painted by each page in its basis color', (
      tester,
    ) async {
      String moodStyle({required bool tintScrim}) => DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(
            colorSeed: DiaryPreviewColorSeed.mood,
            tintScrim: tintScrim,
          ),
        ),
      ).encode()!;

      // 关着：背景自己画中性遮罩，页面透明。
      await _pump(
        tester,
        (s) => DiaryPreviewStylePage(settingsService: s),
        surface: _imageIn(AppBackgroundArea.preview),
        prefs: <String, Object>{
          'app.settings.diary_preview_style': moodStyle(tintScrim: false),
        },
      );
      await _settleImage(tester, preview);
      final scheme = Theme.of(
        tester.element(_previewBackground(preview)),
      ).colorScheme;
      final neutral = scheme.surface.withValues(alpha: 0.2);
      expect(_layerColors(tester, preview), contains(neutral));
      expect(surfaceScaffold(tester), Colors.transparent);

      // 打开：背景只画图，示例日记（有心情）的页面画染过色的遮罩，
      // 不透明度仍是背景设置里的 0.2。先卸下页面，换一份设置重新打开。
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(
        tester,
        (s) => DiaryPreviewStylePage(settingsService: s),
        surface: _imageIn(AppBackgroundArea.preview),
        prefs: <String, Object>{
          'app.settings.diary_preview_style': moodStyle(tintScrim: true),
        },
      );
      await _settleImage(tester, preview);
      expect(_layerColors(tester, preview), isNot(contains(neutral)));
      final veil = surfaceScaffold(tester);
      expect(veil.a, closeTo(0.2, 0.01));
      expect(veil, isNot(neutral));
    });

    testWidgets('a chosen paper color stays opaque on the background', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => DiaryPreviewStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.preview),
        prefs: <String, Object>{
          'app.settings.diary_preview_style': const DiaryPreviewSettings(
            current: DiaryPreviewStyle(
              page: DiaryPreviewPageStyle(paper: DiaryPreviewPaper.warm),
            ),
          ).encode()!,
        },
      );
      final color = surfaceScaffold(tester);
      expect(color, isNot(Colors.transparent));
      expect(color.a, 1);
    });

    testWidgets('another area\'s background does not reach the preview', (
      tester,
    ) async {
      await _pump(
        tester,
        (s) => DiaryPreviewStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.diaries),
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.byType(AppBackgroundLayersView),
        ),
        findsNothing,
      );
      expect(surfaceScaffold(tester), isNot(Colors.transparent));
    });
  });

  group('code block style', () {
    final preview = find.byType(DiaryCodeBlockStylePreview);

    testWidgets('the sample sits on the editor background', (tester) async {
      await _pump(
        tester,
        (s) => DiaryCodeBlockStylePage(settingsService: s),
        surface: _colorIn(AppBackgroundArea.editor),
      );
      expect(
        tester.widget<AppPageBackground>(_previewBackground(preview)).area,
        AppBackgroundArea.editor,
      );
      expect(_layerColors(tester, preview), <Color>[_bg]);
      final material = find
          .descendant(
            of: _previewBackground(preview),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.widget<Material>(material).color, Colors.transparent);
    });
  });
}
