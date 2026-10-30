import 'package:flutter/material.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';

// “背景与材质”设置的文案映射与几个共用的小工具：枚举 → 本地化标签，入口
// 副标题的概括。只做映射，不含状态。

String appSurfaceAreaLabel(AppLocalizations l10n, AppBackgroundArea? area) =>
    switch (area) {
      null => l10n.appSurfaceAreaGlobal,
      AppBackgroundArea.diaries => l10n.appSurfaceAreaDiaries,
      AppBackgroundArea.calendar => l10n.appSurfaceAreaCalendar,
      AppBackgroundArea.explore => l10n.appSurfaceAreaExplore,
      AppBackgroundArea.settings => l10n.appSurfaceAreaSettings,
      AppBackgroundArea.editor => l10n.appSurfaceAreaEditor,
      AppBackgroundArea.preview => l10n.appSurfaceAreaPreview,
      AppBackgroundArea.other => l10n.appSurfaceAreaOther,
    };

/// 跟随来源的名字：全局或页面区域名。
String appSurfaceSourceLabel(
  AppLocalizations l10n,
  AppBackgroundSource source,
) => appSurfaceAreaLabel(l10n, source.area);

String appSurfaceAreaModeLabel(
  AppLocalizations l10n,
  AppAreaBackgroundMode mode,
) => switch (mode) {
  AppAreaBackgroundMode.follow => l10n.appSurfaceAreaModeFollow,
  AppAreaBackgroundMode.off => l10n.appSurfaceAreaModeOff,
  AppAreaBackgroundMode.custom => l10n.appSurfaceAreaModeCustom,
};

String appSurfaceKindLabel(AppLocalizations l10n, AppBackgroundKind kind) =>
    switch (kind) {
      AppBackgroundKind.none => l10n.appSurfaceKindNone,
      AppBackgroundKind.color => l10n.appSurfaceKindColor,
      AppBackgroundKind.image => l10n.appSurfaceKindImage,
    };

String appSurfaceGlassModeLabel(AppLocalizations l10n, AppGlassMode mode) =>
    switch (mode) {
      AppGlassMode.classic => l10n.appSurfaceGlassClassic,
      AppGlassMode.glass => l10n.appSurfaceGlassGlass,
    };

String appSurfaceComponentLabel(
  AppLocalizations l10n,
  AppGlassComponent component,
) => switch (component) {
  AppGlassComponent.topBars => l10n.appSurfaceComponentTopBars,
  AppGlassComponent.toolbar => l10n.appSurfaceComponentToolbar,
  AppGlassComponent.sheets => l10n.appSurfaceComponentSheets,
  AppGlassComponent.dialogs => l10n.appSurfaceComponentDialogs,
  AppGlassComponent.cards => l10n.appSurfaceComponentCards,
  AppGlassComponent.controls => l10n.appSurfaceComponentControls,
};

String appSurfaceOverrideLabel(AppLocalizations l10n, AppGlassOverride value) =>
    switch (value) {
      AppGlassOverride.follow => l10n.appSurfaceOverrideFollow,
      AppGlassOverride.classic => l10n.appSurfaceGlassClassic,
      AppGlassOverride.glass => l10n.appSurfaceGlassGlass,
    };

/// 一类组件的实际效果：跟随时写成“跟随（玻璃）”，固定时直接写材质名。
String appSurfaceComponentEffect(
  AppLocalizations l10n,
  AppGlassStyle glass,
  AppGlassComponent component,
) {
  final material = glass.isGlass(component)
      ? l10n.appSurfaceGlassGlass
      : l10n.appSurfaceGlassClassic;
  return glass.overrideFor(component) == AppGlassOverride.follow
      ? l10n.appSurfaceOverrideFollowResult(material)
      : material;
}

/// 入口副标题：全为默认时“默认”，否则依次概括全局背景（有可见背景时）、
/// 整体组件风格、单独设置（不跟随全局）的区域个数，以“ · ”连接。
String appSurfaceEntrySummary(
  AppLocalizations l10n,
  AppSurfaceSettings settings,
) {
  if (settings.isDefault) return l10n.appSurfaceEntryDefault;
  final global = settings.global;
  final overridden = AppBackgroundArea.values
      .where(
        (area) => settings.areaOf(area).mode != AppAreaBackgroundMode.follow,
      )
      .length;
  return <String>[
    if (global.isVisible)
      global.kind == AppBackgroundKind.image
          ? l10n.appSurfaceEntryImage
          : l10n.appSurfaceEntryColor,
    settings.glass.mode == AppGlassMode.glass
        ? l10n.appSurfaceEntryGlass
        : l10n.appSurfaceEntryClassic,
    if (overridden > 0) l10n.appSurfaceEntryAreas(overridden),
  ].join(' · ');
}

/// 浅色主题的配色：背景与玻璃的自定义颜色都以浅色值为主、深色由它推导，
/// 第一次切到自定义时的起始颜色因此取浅色主题下的值（深色界面里也一样）。
ColorScheme appSurfaceLightScheme(
  BuildContext context,
  SettingsService settings,
) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.light) return theme.colorScheme;
  return SeededThemeCache.of(
    Color(settings.themeSeedColorValue),
    Brightness.light,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  ).colorScheme;
}

/// 去掉透明度的 ARGB：背景色与玻璃底色一律存为不透明色。
int appSurfaceOpaqueArgb(Color color) =>
    0xFF000000 | (color.toARGB32() & 0xFFFFFF);
