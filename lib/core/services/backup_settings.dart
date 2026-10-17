import 'dart:convert';

import 'package:flutter/material.dart';

import 'settings_service.dart';

/// 备份设置的映射与应用，复用 SettingsService 的归一化和通知逻辑。
/// 仅修改备份支持的设置；媒体路径在校验阶段已经重绑，失败回滚由服务负责。
class BackupSettings {
  const BackupSettings._();

  static Map<String, Object?> capture(SettingsService settingsService) => {
    'themeMode': settingsService.themeModeNotifier.value.name,
    'themeSeedColorValue': settingsService.themeSeedColorValue,
    'homeTabSwitchCurveType': settingsService.homeTabSwitchCurveTypeValue,
    'diaryTypography': settingsService.diaryTypography.toJson(),
    'fontScale': settingsService.fontScaleValue,
    'appLocaleCode': settingsService.appLocaleCode,
    'appLockEnabled': settingsService.isAppLockEnabled,
    'diarySortModeRaw': settingsService.diarySortModeRaw,
    'diaryLayoutModeRaw': settingsService.diaryLayoutModeRaw,
    'diaryCardTagLimit': settingsService.diaryCardTagLimit,
    'calendarDisplayOptionsRaw': settingsService.calendarDisplayOptionsRaw,
    'diaryCardStyleRaw': settingsService.diaryCardStyleRaw,
    'diaryPreviewStyleRaw': settingsService.diaryPreviewStyleRaw,
    'diaryShareOptionsRaw': settingsService.diaryShareOptionsRaw,
    'diaryExportOptionsRaw': settingsService.diaryExportOptionsRaw,
    'diaryToolbarOrderRaw': settingsService.diaryToolbarOrderRaw,
    'diaryToolbarHiddenItemsRaw': settingsService.diaryToolbarHiddenItemsRaw,
    'diaryToolbarCurrentTimeFormatRaw':
        settingsService.diaryToolbarCurrentTimeFormatRaw,
    'tagOrderRaw': settingsService.tagOrderRaw,
    'tagFilterMemoryEnabled': settingsService.isTagFilterMemoryEnabled,
    'rememberedTagFilterIdsRaw': settingsService.rememberedTagFilterIdsRaw,
    'createDiaryDraftRaw': settingsService.createDiaryDraftRaw,
    'diaryLocationPrecisionRaw': settingsService.diaryLocationPrecisionRaw,
    'releaseMirrorStartIndex': settingsService.releaseMirrorStartIndexRaw,
  };

  static Future<void> restore(
    SettingsService settingsService,
    Map<String, dynamic>? settingsNode,
  ) async {
    if (settingsNode == null) return;
    final themeRaw = settingsNode['themeMode']?.toString();
    if (themeRaw != null) {
      await settingsService.setThemeMode(_parseThemeMode(themeRaw));
    }

    final themeSeedColorRaw = settingsNode['themeSeedColorValue'];
    final themeSeedColorValue = switch (themeSeedColorRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (themeSeedColorValue != null) {
      await settingsService.setThemeSeedColor(Color(themeSeedColorValue));
    }

    final tabSwitchCurveTypeRaw = settingsNode['homeTabSwitchCurveType'];
    if (tabSwitchCurveTypeRaw is String && tabSwitchCurveTypeRaw.isNotEmpty) {
      await settingsService.setHomeTabSwitchCurveType(
        switch (tabSwitchCurveTypeRaw) {
          'easeOutCubic' => HomeTabSwitchCurveType.easeOutCubic,
          'linear' => HomeTabSwitchCurveType.linear,
          'easeOutCirc' => HomeTabSwitchCurveType.easeOutCirc,
          _ => SettingsService.defaultHomeTabSwitchCurveType,
        },
      );
    }

    final diaryTypography = _parseDiaryTypography(settingsNode);
    if (diaryTypography != null) {
      await settingsService.setDiaryTypography(diaryTypography);
    }

    final fontScaleRaw = settingsNode['fontScale'];
    final fontScale = switch (fontScaleRaw) {
      double value => value,
      int value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    if (fontScale != null) {
      await settingsService.setFontScale(fontScale);
    }

    final localeRaw = settingsNode['appLocaleCode']?.toString();
    if (localeRaw != null && localeRaw.trim().isNotEmpty) {
      await settingsService.setAppLocaleCode(localeRaw);
    }

    final appLockRaw = settingsNode['appLockEnabled'];
    if (appLockRaw is bool) {
      await settingsService.setAppLockEnabled(appLockRaw);
    }

    final sortRaw = settingsNode['diarySortModeRaw']?.toString();
    if (sortRaw != null && sortRaw.isNotEmpty) {
      await settingsService.setDiarySortModeRaw(sortRaw);
    }

    final layoutRaw = settingsNode['diaryLayoutModeRaw']?.toString();
    if (layoutRaw != null && layoutRaw.isNotEmpty) {
      await settingsService.setDiaryLayoutModeRaw(layoutRaw);
    }

    final diaryCardTagLimitRaw = settingsNode['diaryCardTagLimit'];
    final diaryCardTagLimit = switch (diaryCardTagLimitRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (diaryCardTagLimit != null) {
      await settingsService.setDiaryCardTagLimit(diaryCardTagLimit);
    }

    // 旧版备份没有该键时保留本机选项；有键（含 null）时按备份还原。
    if (settingsNode.containsKey('calendarDisplayOptionsRaw')) {
      await settingsService.setCalendarDisplayOptionsRaw(
        settingsNode['calendarDisplayOptionsRaw']?.toString(),
      );
    }

    // 同上：旧版备份没有卡片样式时保留本机样式。值是 JSON 字符串；手工
    // 编辑过的备份若写成了对象，按 JSON 重新编码后交给日记模块容错解析。
    if (settingsNode.containsKey('diaryCardStyleRaw')) {
      final cardStyleRaw = settingsNode['diaryCardStyleRaw'];
      await settingsService.setDiaryCardStyleRaw(switch (cardStyleRaw) {
        null => null,
        String value => value,
        Map<dynamic, dynamic> value => jsonEncode(value),
        _ => null,
      });
    }

    // 预览页设置同上：旧版备份没有时保留本机设置，显式 null 时恢复默认。
    if (settingsNode.containsKey('diaryPreviewStyleRaw')) {
      final previewStyleRaw = settingsNode['diaryPreviewStyleRaw'];
      await settingsService.setDiaryPreviewStyleRaw(switch (previewStyleRaw) {
        null => null,
        String value => value,
        Map<dynamic, dynamic> value => jsonEncode(value),
        _ => null,
      });
    }

    // 旧版备份没有分享开关时保留本机选项；值同样按 JSON 字符串交给日记模块。
    if (settingsNode.containsKey('diaryShareOptionsRaw')) {
      final shareOptionsRaw = settingsNode['diaryShareOptionsRaw'];
      await settingsService.setDiaryShareOptionsRaw(switch (shareOptionsRaw) {
        null => null,
        String value => value,
        Map<dynamic, dynamic> value => jsonEncode(value),
        _ => null,
      });
    }

    // 同上：旧版备份没有导出选项时保留本机选项。
    if (settingsNode.containsKey('diaryExportOptionsRaw')) {
      final exportOptionsRaw = settingsNode['diaryExportOptionsRaw'];
      await settingsService.setDiaryExportOptionsRaw(switch (exportOptionsRaw) {
        null => null,
        String value => value,
        Map<dynamic, dynamic> value => jsonEncode(value),
        _ => null,
      });
    }

    final toolbarRaw = settingsNode['diaryToolbarOrderRaw']?.toString();
    if (toolbarRaw != null && toolbarRaw.isNotEmpty) {
      await settingsService.setDiaryToolbarOrderRaw(toolbarRaw);
    }

    if (settingsNode.containsKey('diaryToolbarHiddenItemsRaw')) {
      final toolbarHiddenRaw =
          settingsNode['diaryToolbarHiddenItemsRaw']?.toString() ?? '';
      await settingsService.setDiaryToolbarHiddenItemsRaw(toolbarHiddenRaw);
    }

    if (settingsNode.containsKey('diaryToolbarCurrentTimeFormatRaw')) {
      final toolbarCurrentTimeFormatRaw =
          settingsNode['diaryToolbarCurrentTimeFormatRaw']?.toString() ?? '';
      await settingsService.setDiaryToolbarCurrentTimeFormatRaw(
        toolbarCurrentTimeFormatRaw,
      );
    }

    final tagOrderRaw = settingsNode['tagOrderRaw']?.toString();
    if (tagOrderRaw != null && tagOrderRaw.isNotEmpty) {
      await settingsService.setTagOrderRaw(tagOrderRaw);
    }

    final tagFilterMemoryEnabledRaw = settingsNode['tagFilterMemoryEnabled'];
    final tagFilterMemoryEnabled = switch (tagFilterMemoryEnabledRaw) {
      bool value => value,
      String value => value.toLowerCase() == 'true',
      _ => null,
    };
    if (tagFilterMemoryEnabled != null) {
      await settingsService.setTagFilterMemoryEnabled(tagFilterMemoryEnabled);
    }
    if (settingsNode.containsKey('rememberedTagFilterIdsRaw')) {
      final rememberedTagFilterIdsRaw =
          settingsNode['rememberedTagFilterIdsRaw']?.toString() ?? '';
      if (settingsService.isTagFilterMemoryEnabled &&
          rememberedTagFilterIdsRaw.isNotEmpty) {
        await settingsService.setRememberedTagFilterIdsRaw(
          rememberedTagFilterIdsRaw,
        );
      } else {
        await settingsService.clearRememberedTagFilterIds();
      }
    }

    final draftRaw = settingsNode['createDiaryDraftRaw']?.toString();
    if (draftRaw != null && draftRaw.isNotEmpty) {
      await settingsService.setCreateDiaryDraftRaw(draftRaw);
    } else {
      await settingsService.clearCreateDiaryDraft();
    }

    final locationPrecisionRaw = settingsNode['diaryLocationPrecisionRaw']
        ?.toString();
    if (locationPrecisionRaw != null && locationPrecisionRaw.isNotEmpty) {
      await settingsService.setDiaryLocationPrecisionRaw(locationPrecisionRaw);
    }

    final releaseMirrorStartIndexRaw = settingsNode['releaseMirrorStartIndex'];
    final releaseMirrorStartIndex = switch (releaseMirrorStartIndexRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (releaseMirrorStartIndex != null) {
      await settingsService.setReleaseMirrorStartIndex(releaseMirrorStartIndex);
    }
  }

  /// 新备份带 `diaryTypography` 对象；旧备份只有编辑器字号 / 行距三档预设，
  /// 按本机迁移同一规则换算。两者都没有时返回 null，保留本机排版。
  /// 导入字体只记 id 不含字体文件：目标设备没有该字体时正文按内置字体显示。
  static DiaryTypography? _parseDiaryTypography(Map<String, dynamic> node) {
    final typographyRaw = node['diaryTypography'];
    if (typographyRaw is Map) {
      return DiaryTypography.fromJson(typographyRaw.cast<String, Object?>());
    }
    final legacyFontSize = node['editorBodyFontSizePreset']?.toString();
    final legacyLineHeight = node['editorBodyLineHeightPreset']?.toString();
    if (legacyFontSize == null && legacyLineHeight == null) {
      return null;
    }
    return DiaryTypography.fromLegacyPresets(
      fontSizePreset: legacyFontSize,
      lineHeightPreset: legacyLineHeight,
    );
  }

  static ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
