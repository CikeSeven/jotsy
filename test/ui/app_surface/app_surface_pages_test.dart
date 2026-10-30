import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_list_page.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/widgets/app_background_layers_view.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/diaries/models/diary_mood_palette.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_resolved_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_host.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_surface.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_auto_apply_page.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';

/// 各区域的页面接入“背景与材质”：设了纯色背景时页面 Scaffold 透明、背景
/// 画在下面；没有背景时 Scaffold 仍是主题 surface（与接入前一致）。
/// 预览页另测纸张颜色优先与宽窗口双栏嵌入。
const Color _bg = Color(0xFF3A6B8C);

AppSurfaceSettings _colorIn(AppBackgroundArea area) =>
    AppSurfaceSettings.defaults.withArea(
      area,
      AppAreaBackground(
        mode: AppAreaBackgroundMode.custom,
        custom: AppBackground(
          kind: AppBackgroundKind.color,
          colorLight: _bg.toARGB32(),
        ),
      ),
    );

/// 固定返回给定设置的设置 notifier。
class _FakeSurface extends AppSurfaceSettingsNotifier {
  _FakeSurface(this.value);

  final AppSurfaceSettings value;

  @override
  AppSurfaceSettings build() => value;
}

Override _surface(AppSurfaceSettings settings) =>
    appSurfaceSettingsProvider.overrideWith(() => _FakeSurface(settings));

/// 页面背景组件之下的第一个 Scaffold（即页面本身）。
Color _pageScaffoldColor(WidgetTester tester) => tester
    .widget<Scaffold>(
      find
          .descendant(
            of: find.byType(AppPageBackground),
            matching: find.byType(Scaffold),
          )
          .first,
    )
    .backgroundColor!;

/// 背景层里铺满的纯色。
List<Color> _layerColors(WidgetTester tester) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(AppBackgroundLayersView),
        matching: find.byType(ColoredBox),
      ),
    )
    .map((box) => box.color)
    .toList();

Color _surfaceOf(WidgetTester tester) => Theme.of(
  tester.element(find.byType(AppPageBackground).first),
).colorScheme.surface;

void main() {
  group('settings area', () {
    Future<DiaryDraftsHarness> open(
      WidgetTester tester,
      AppSurfaceSettings settings,
    ) async {
      final h = await DiaryDraftsHarness.create(tester);
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(
        const DiaryTemplateAutoApplyPage(),
        overrides: [_surface(settings)],
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('a settings background shows through the page', (tester) async {
      final h = await open(tester, _colorIn(AppBackgroundArea.settings));
      final background = tester.widget<AppPageBackground>(
        find.byType(AppPageBackground),
      );
      expect(background.area, AppBackgroundArea.settings);
      expect(_pageScaffoldColor(tester), Colors.transparent);
      expect(_layerColors(tester), <Color>[_bg]);
      await h.unmount();
      await tester.pump(Duration.zero);
    });

    testWidgets('without a background the page stays on surface', (
      tester,
    ) async {
      final h = await open(tester, AppSurfaceSettings.defaults);
      expect(_pageScaffoldColor(tester), _surfaceOf(tester));
      expect(find.byType(AppBackgroundLayersView), findsNothing);
      await h.unmount();
      await tester.pump(Duration.zero);
    });

    testWidgets('another area\'s background does not reach settings pages', (
      tester,
    ) async {
      final h = await open(tester, _colorIn(AppBackgroundArea.editor));
      expect(_pageScaffoldColor(tester), _surfaceOf(tester));
      expect(find.byType(AppBackgroundLayersView), findsNothing);
      await h.unmount();
      await tester.pump(Duration.zero);
    });
  });

  group('editor area', () {
    Future<DiaryDraftsHarness> open(
      WidgetTester tester,
      AppSurfaceSettings settings,
    ) async {
      final h = await DiaryDraftsHarness.create(tester);
      await h.pump(
        const DiaryTemplateEditorPage(),
        overrides: [_surface(settings)],
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('the template editor draws the editor background', (
      tester,
    ) async {
      final h = await open(tester, _colorIn(AppBackgroundArea.editor));
      expect(
        tester.widget<AppPageBackground>(find.byType(AppPageBackground)).area,
        AppBackgroundArea.editor,
      );
      expect(_pageScaffoldColor(tester), Colors.transparent);
      expect(_layerColors(tester), <Color>[_bg]);
      await h.unmount();
      await tester.pump(Duration.zero);
    });

    testWidgets('without a background the editor stays on surface', (
      tester,
    ) async {
      final h = await open(tester, AppSurfaceSettings.defaults);
      expect(_pageScaffoldColor(tester), _surfaceOf(tester));
      await h.unmount();
      await tester.pump(Duration.zero);
    });
  });

  group('other area', () {
    Future<void> open(WidgetTester tester, AppSurfaceSettings settings) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StreamController<List<Anniversary>>();
      addTearDown(controller.close);
      controller.add(const <Anniversary>[]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anniversaryListProvider.overrideWith((ref) => controller.stream),
            _surface(settings),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            theme: expressiveTestTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AnniversaryListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a secondary page draws the other-pages background', (
      tester,
    ) async {
      await open(tester, _colorIn(AppBackgroundArea.other));
      expect(
        tester.widget<AppPageBackground>(find.byType(AppPageBackground)).area,
        AppBackgroundArea.other,
      );
      expect(_pageScaffoldColor(tester), Colors.transparent);
      expect(_layerColors(tester), <Color>[_bg]);
    });

    testWidgets('without a background the page stays on surface', (
      tester,
    ) async {
      await open(tester, AppSurfaceSettings.defaults);
      expect(_pageScaffoldColor(tester), _surfaceOf(tester));
    });
  });

  group('preview area', () {
    final theme = expressiveTestTheme(Brightness.light);

    DiaryPreviewResolvedStyle resolve(DiaryPreviewStyle style) =>
        DiaryPreviewResolvedStyle.resolve(
          style: style,
          appTheme: theme,
          appSeed: const Color(0xff1e6586),
          screenSize: const Size(400, 800),
          reduceMotion: false,
          moodPalette: DiaryMoodPalette.defaults,
        );

    final followsTheme = resolve(const DiaryPreviewStyle());
    final warmPaper = resolve(
      const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(paper: DiaryPreviewPaper.warm),
      ),
    );

    /// [wrap] 把预览外壳放进某种宿主（页面背景、双栏右栏等）。
    Future<void> pumpSurface(
      WidgetTester tester, {
      required AppSurfaceSettings settings,
      required DiaryPreviewResolvedStyle resolved,
      required Widget Function(Widget surface) wrap,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_surface(settings)],
          child: MaterialApp(
            theme: theme,
            home: wrap(
              DiaryPreviewSurface(
                resolved: resolved,
                scrollController: scroll,
                content: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Color surfaceScaffold(WidgetTester tester) => tester
        .widget<Scaffold>(
          find.descendant(
            of: find.byType(DiaryPreviewSurface),
            matching: find.byType(Scaffold),
          ),
        )
        .backgroundColor!;

    Widget previewPage(Widget surface) =>
        AppPageBackground(area: AppBackgroundArea.preview, child: surface);

    testWidgets('paper following the theme shows the preview background', (
      tester,
    ) async {
      expect(followsTheme.paperFollowsTheme, isTrue);
      await pumpSurface(
        tester,
        settings: _colorIn(AppBackgroundArea.preview),
        resolved: followsTheme,
        wrap: previewPage,
      );
      expect(surfaceScaffold(tester), Colors.transparent);
      expect(_layerColors(tester), <Color>[_bg]);
    });

    testWidgets('without a background the preview keeps the theme surface', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        settings: AppSurfaceSettings.defaults,
        resolved: followsTheme,
        wrap: previewPage,
      );
      expect(surfaceScaffold(tester), theme.colorScheme.surface);
      expect(surfaceScaffold(tester), followsTheme.background);
    });

    testWidgets('a paper color covers the preview background', (tester) async {
      expect(warmPaper.paperFollowsTheme, isFalse);
      await pumpSurface(
        tester,
        settings: _colorIn(AppBackgroundArea.preview),
        resolved: warmPaper,
        wrap: previewPage,
      );
      expect(surfaceScaffold(tester), warmPaper.background);
      expect(surfaceScaffold(tester), isNot(Colors.transparent));
    });

    testWidgets('embedded in the two-pane host it shows the host background', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        settings: _colorIn(AppBackgroundArea.diaries),
        resolved: followsTheme,
        wrap: (surface) => AppPageBackground(
          area: AppBackgroundArea.diaries,
          child: DiaryPreviewHostScope(child: surface),
        ),
      );
      // 右栏不自己画背景，透明以露出宿主日记页的背景。
      expect(surfaceScaffold(tester), Colors.transparent);
      expect(find.byType(AppBackgroundLayersView), findsOneWidget);
    });

    testWidgets('embedded without a host background it stays on surface', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        settings: AppSurfaceSettings.defaults,
        resolved: followsTheme,
        wrap: (surface) => AppPageBackground(
          area: AppBackgroundArea.diaries,
          child: DiaryPreviewHostScope(child: surface),
        ),
      );
      expect(surfaceScaffold(tester), theme.colorScheme.surface);
    });

    testWidgets('the settings live preview ignores the settings background', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        settings: _colorIn(AppBackgroundArea.settings),
        resolved: followsTheme,
        wrap: (surface) =>
            AppPageBackground(area: AppBackgroundArea.settings, child: surface),
      );
      expect(surfaceScaffold(tester), followsTheme.background);
    });
  });
}
