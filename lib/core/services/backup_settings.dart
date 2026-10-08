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
    'editorBodyFontSizePreset':
        settingsService.editorBodyFontSizePresetStorageValue,
    'editorBodyLineHeightPreset':
        settingsService.editorBodyLineHeightPresetStorageValue,
    'fontScale': settingsService.fontScaleValue,
    'appLocaleCode': settingsService.appLocaleCode,
    'appLockEnabled': settingsService.isAppLockEnabled,
    'diarySortModeRaw': settingsService.diarySortModeRaw,
    'diaryLayoutModeRaw': settingsService.diaryLayoutModeRaw,
    'diaryCardTagLimit': settingsService.diaryCardTagLimit,
    'diaryToolbarOrderRaw': settingsService.diaryToolbarOrderRaw,
    'diaryToolbarHiddenItemsRaw': settingsService.diaryToolbarHiddenItemsRaw,
    'diaryToolbarCurrentTimeFormatRaw':
        settingsService.diaryToolbarCurrentTimeFormatRaw,
    'tagOrderRaw': settingsService.tagOrderRaw,
    'tagFilterMemoryEnabled': settingsService.isTagFilterMemoryEnabled,
    'rememberedTagFilterIdsRaw': settingsService.rememberedTagFilterIdsRaw,
    'createDiaryDraftRaw': settingsService.createDiaryDraftRaw,
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

    final editorBodyFontSizeRaw = settingsNode['editorBodyFontSizePreset']
        ?.toString();
    if (editorBodyFontSizeRaw != null && editorBodyFontSizeRaw.isNotEmpty) {
      await settingsService.setEditorBodyFontSizePreset(
        switch (editorBodyFontSizeRaw) {
          'small' => EditorBodyFontSizePreset.small,
          'large' => EditorBodyFontSizePreset.large,
          'medium' => EditorBodyFontSizePreset.medium,
          _ => SettingsService.defaultEditorBodyFontSizePreset,
        },
      );
    }

    final editorBodyLineHeightRaw = settingsNode['editorBodyLineHeightPreset']
        ?.toString();
    if (editorBodyLineHeightRaw != null && editorBodyLineHeightRaw.isNotEmpty) {
      await settingsService.setEditorBodyLineHeightPreset(
        switch (editorBodyLineHeightRaw) {
          'compact' => EditorBodyLineHeightPreset.compact,
          'relaxed' => EditorBodyLineHeightPreset.relaxed,
          'normal' => EditorBodyLineHeightPreset.normal,
          _ => SettingsService.defaultEditorBodyLineHeightPreset,
        },
      );
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
