import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_background_storage_service.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/settings/pages/app_surface_page.dart';
import 'package:node_diary/ui/settings/pages/appearance_language_page.dart';
import 'package:node_diary/ui/settings/sections/app_surface/app_surface_area_chips.dart';
import 'package:node_diary/ui/settings/sections/app_surface/app_surface_labels.dart';
import 'package:node_diary/ui/settings/sections/app_surface/app_surface_preview.dart';
import 'package:node_diary/ui/settings/sections/settings_app_surface_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_home_bar_style_tile.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/home_bar_style_page_harness.dart'
    show scrollToHomeBarOption, tapHomeBarOption, openHomeBarStyleTab;

/// 背景与材质设置页：入口位置、区域胶囊与取值方式的展开收起、玻璃质感
/// 分组的条件出现、预览随材质与明暗变化、选图失败提示、重置与撤销。
Widget _app(SettingsService settings, Widget home) {
  return ProviderScope(
    overrides: [
      settingsServiceProvider.overrideWith((ref) async => settings),
      // 测试里不碰真实的托管目录：图片一律按读取失败处理。
      appBackgroundImageCacheProvider.overrideWith(
        (ref) => AppBackgroundImageCache(loader: (_) async => null),
      ),
    ],
    child: MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _Harness {
  _Harness(this.settings, this.l10n, this.cleaned);

  final SettingsService settings;
  final AppLocalizations l10n;
  final List<Set<String>> cleaned;

  AppSurfaceSettings get stored =>
      AppSurfaceSettings.decode(settings.appSurfaceRaw);
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  AppSurfaceSettings? initial,
  AppBackgroundPickResult pick = const AppBackgroundPickCancelled(),
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (initial?.encode() != null)
      'app.settings.app_surface': initial!.encode()!,
  });
  final settings = (await tester.runAsync(SettingsService.create))!;
  final cleaned = <Set<String>>[];
  await tester.pumpWidget(
    _app(
      settings,
      AppSurfacePage(
        settingsService: settings,
        pickImage: () async => pick,
        deleteUnreferenced: (Set<String> keep) async {
          cleaned.add(keep);
          return 0;
        },
        resolveImage: (_) async => null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return _Harness(settings, l10n, cleaned);
}

Finder _inOptions(String text) =>
    find.descendant(of: find.byType(TabBarView), matching: find.text(text));

Finder _segment<T>(String label) => find.descendant(
  of: find.byType(ExpressiveButtonGroup<T>),
  matching: find.text(label),
);

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

Finder get _previewGlass => find.descendant(
  of: find.byType(AppSurfacePreview),
  matching: find.byType(GlassSurface),
);

void main() {
  testWidgets('entry is the first row of the appearance style group', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(_app(settings, const AppearanceLanguagePage()));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    final entry = find.byType(SettingsAppSurfaceTile);
    expect(entry, findsOneWidget);
    expect(
      tester.getTopLeft(entry).dy,
      lessThan(tester.getTopLeft(find.byType(SettingsHomeBarStyleTile)).dy),
    );
    expect(
      find.descendant(of: entry, matching: find.text(l10n.appSurfaceTitle)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: entry,
        matching: find.text(l10n.appSurfaceEntryDefault),
      ),
      findsOneWidget,
    );

    // 副标题随设置实时更新。
    await tester.runAsync(
      () => settings.setAppSurfaceRaw(
        AppSurfaceSettings.defaults
            .withGlobal(
              const AppBackground(
                kind: AppBackgroundKind.image,
                image: 'bg.jpg',
              ),
            )
            .withGlass(AppGlassStyle.defaults.withMode(AppGlassMode.glass))
            .encode(),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: entry,
        matching: find.text(
          '${l10n.appSurfaceEntryImage} · ${l10n.appSurfaceEntryGlass}',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry summary counts areas set separately', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    var settings = AppSurfaceSettings.defaults;
    for (final area in <AppBackgroundArea>[
      AppBackgroundArea.calendar,
      AppBackgroundArea.editor,
      AppBackgroundArea.other,
    ]) {
      settings = settings.withArea(
        area,
        const AppAreaBackground(mode: AppAreaBackgroundMode.off),
      );
    }
    expect(
      appSurfaceEntrySummary(l10n, settings),
      '${l10n.appSurfaceEntryClassic} · ${l10n.appSurfaceEntryAreas(3)}',
    );
  });

  testWidgets('opens on the global editor with two tabs and cleans up', (
    tester,
  ) async {
    final h = await _pumpPage(tester);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(_inOptions(h.l10n.appSurfaceGlobalBackground), findsOneWidget);
    expect(find.byType(AppSurfacePreview), findsOneWidget);
    expect(_previewGlass, findsNothing);
    // 打开时清理一次，按已保存（默认）的引用。
    expect(h.cleaned, <Set<String>>[<String>{}]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('area chips swap the editor and custom mode reveals it', (
    tester,
  ) async {
    final h = await _pumpPage(tester);
    final l10n = h.l10n;
    await tester.tap(_chip(l10n.appSurfaceAreaCalendar));
    await tester.pumpAndSettle();
    expect(_inOptions(l10n.appSurfaceGlobalBackground), findsNothing);
    expect(
      _inOptions(l10n.appSurfaceAreaFollowNote(l10n.appSurfaceKindNone)),
      findsOneWidget,
    );
    expect(_inOptions(l10n.appSurfaceAreaBackground), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('appSurfaceCustomizedDot')),
      findsNothing,
    );

    await tapHomeBarOption(
      tester,
      _segment<AppAreaBackgroundMode>(l10n.appSurfaceAreaModeCustom),
    );
    expect(
      h.stored.areaOf(AppBackgroundArea.calendar).mode,
      AppAreaBackgroundMode.custom,
    );
    expect(_inOptions(l10n.appSurfaceAreaBackground), findsOneWidget);
    expect(_inOptions(l10n.appSurfaceAreaCustomNote), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('appSurfaceCustomizedDot')),
      findsOneWidget,
    );

    // 颜色类型展开颜色行，起始色为不透明色。
    await tapHomeBarOption(
      tester,
      _segment<AppBackgroundKind>(l10n.appSurfaceKindColor),
    );
    final custom = h.stored.areaOf(AppBackgroundArea.calendar).custom;
    expect(custom.kind, AppBackgroundKind.color);
    expect(custom.colorLight, isNotNull);
    expect(custom.colorLight! >> 24, 0xFF);
    expect(_inOptions(l10n.appSurfaceBackgroundColor), findsOneWidget);

    await scrollToHomeBarOption(
      tester,
      _segment<AppAreaBackgroundMode>(l10n.appSurfaceAreaModeOff),
    );
    await tapHomeBarOption(
      tester,
      _segment<AppAreaBackgroundMode>(l10n.appSurfaceAreaModeOff),
    );
    expect(_inOptions(l10n.appSurfaceAreaBackground), findsNothing);
    expect(_inOptions(l10n.appSurfaceAreaOffNote), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview area shows the extra paper note', (tester) async {
    final h = await _pumpPage(tester);
    final l10n = h.l10n;
    final chip = _chip(l10n.appSurfaceAreaPreview);
    // 胶囊行是横向懒构建的：先横向拖到“预览”出现。
    await tester.dragUntilVisible(
      chip,
      find.byType(AppSurfaceAreaChips),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TabBarView),
        matching: find.textContaining(l10n.appSurfaceAreaPreviewNote),
      ),
      findsOneWidget,
    );
  });

  testWidgets('image type: failed and unavailable picks show a message', (
    tester,
  ) async {
    final h = await _pumpPage(tester, pick: const AppBackgroundPickFailed());
    final l10n = h.l10n;
    await tapHomeBarOption(
      tester,
      _segment<AppBackgroundKind>(l10n.appSurfaceKindImage),
    );
    expect(_inOptions(l10n.appSurfaceImageEmpty), findsOneWidget);
    await tapHomeBarOption(tester, find.text(l10n.appSurfaceImagePick));
    expect(find.text(l10n.appSurfaceImageImportFailed), findsOneWidget);
    expect(h.stored.global.image, isNull);
  });

  testWidgets('a picked image whose file is gone shows the missing note', (
    tester,
  ) async {
    final h = await _pumpPage(
      tester,
      pick: const AppBackgroundPicked('bg_9.jpg'),
    );
    final l10n = h.l10n;
    await tapHomeBarOption(
      tester,
      _segment<AppBackgroundKind>(l10n.appSurfaceKindImage),
    );
    await tapHomeBarOption(tester, find.text(l10n.appSurfaceImagePick));
    expect(h.stored.global.image, 'bg_9.jpg');
    expect(_inOptions(l10n.appSurfaceImageMissing), findsOneWidget);
    expect(_inOptions(l10n.appSurfaceImageChange), findsOneWidget);
    expect(_inOptions(l10n.appSurfaceImageRemove), findsOneWidget);
    expect(_inOptions(l10n.appSurfaceScrimLight), findsOneWidget);

    await tapHomeBarOption(tester, find.text(l10n.appSurfaceImageRemove));
    expect(h.stored.global.image, isNull);
    expect(h.stored.global.kind, AppBackgroundKind.image);
  });

  testWidgets('glass tab: texture group follows actual glass, preview too', (
    tester,
  ) async {
    final h = await _pumpPage(tester);
    final l10n = h.l10n;
    await openHomeBarStyleTab(tester, l10n.appSurfaceTabGlass);
    expect(_inOptions(l10n.appSurfaceGlassTexture), findsNothing);
    expect(_previewGlass, findsNothing);

    await tapHomeBarOption(
      tester,
      _segment<AppGlassMode>(l10n.appSurfaceGlassGlass).first,
    );
    expect(h.stored.glass.mode, AppGlassMode.glass);
    // 顶栏、两张卡片、工具栏与新建按钮都换成玻璃。
    expect(_previewGlass, findsNWidgets(5));
    // 各组件都跟随整体：副标题写实际效果（列表懒构建，只看已建出的行）。
    expect(
      _inOptions(
        l10n.appSurfaceOverrideFollowResult(l10n.appSurfaceGlassGlass),
      ),
      findsWidgets,
    );
    await scrollToHomeBarOption(
      tester,
      _inOptions(l10n.appSurfaceGlassTexture),
    );
    expect(_inOptions(l10n.appSurfaceGlassTexture), findsOneWidget);

    // 整体改回经典、只让卡片固定为玻璃：分组仍在，预览只有两张卡片是玻璃。
    // （外部改动经 raw notifier 同步进来，与备份恢复同一路径。）
    await tester.runAsync(
      () => h.settings.setAppSurfaceRaw(
        h.stored
            .withGlass(h.stored.glass.withMode(AppGlassMode.classic))
            .encode(),
      ),
    );
    await tester.pumpAndSettle();
    expect(_previewGlass, findsNothing);
    expect(_inOptions(l10n.appSurfaceGlassTexture), findsNothing);
    await tester.runAsync(
      () => h.settings.setAppSurfaceRaw(
        h.stored
            .withGlass(
              h.stored.glass.withOverride(
                AppGlassComponent.cards,
                AppGlassOverride.glass,
              ),
            )
            .encode(),
      ),
    );
    await tester.pumpAndSettle();
    expect(_previewGlass, findsNWidgets(2));
    await scrollToHomeBarOption(
      tester,
      _inOptions(l10n.appSurfaceGlassTexture),
    );
    expect(_inOptions(l10n.appSurfaceGlassTexture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brightness button switches the preview theme only', (
    tester,
  ) async {
    final h = await _pumpPage(tester);
    final sample = find.descendant(
      of: find.byType(AppSurfacePreview),
      matching: find.text(h.l10n.appSurfacePreviewCardTitle1),
    );
    expect(Theme.of(tester.element(sample)).brightness, Brightness.light);
    await tester.tap(find.byTooltip(h.l10n.styleEditorPreviewDark));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(sample)).brightness, Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(TabBarView))).brightness,
      Brightness.light,
    );
  });

  testWidgets('reset offers undo and keeps undo images out of cleanup', (
    tester,
  ) async {
    final h = await _pumpPage(
      tester,
      initial: AppSurfaceSettings.defaults.withGlobal(
        const AppBackground(kind: AppBackgroundKind.image, image: 'keep.jpg'),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, h.l10n.commonReset));
    await tester.pump();
    expect(h.settings.appSurfaceRaw, isNull);
    expect(find.text(h.l10n.styleEditorResetDone), findsOneWidget);

    // 撤销窗口仍开着时关闭页面：清理保留快照里的图片。
    await tester.pumpWidget(_app(h.settings, const SizedBox()));
    await tester.pump();
    expect(h.cleaned.last, <String>{'keep.jpg'});
  });

  testWidgets('undo restores the settings from before the reset', (
    tester,
  ) async {
    final initial = AppSurfaceSettings.defaults.withGlass(
      AppGlassStyle.defaults.withMode(AppGlassMode.glass),
    );
    final h = await _pumpPage(tester, initial: initial);
    await tester.tap(find.widgetWithText(TextButton, h.l10n.commonReset));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SnackBarAction, h.l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(h.stored, initial);
  });
}
