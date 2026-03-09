import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._({required SharedPreferences prefs, required ThemeMode mode})
    : _prefs = prefs,
      themeModeNotifier = ValueNotifier<ThemeMode>(mode);

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  static const _keyThemeMode = 'app.settings.theme_mode';
  static const _keyDiarySortMode = 'app.settings.diary_sort_mode';
  static const _keyDiaryLayoutMode = 'app.settings.diary_layout_mode';
  static const _keyDiaryToolbarOrder = 'app.settings.diary_toolbar_order';
  static const _keyCreateDiaryDraft = 'app.settings.diary_create_draft';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = _parseMode(prefs.getString(_keyThemeMode));
    return SettingsService._(prefs: prefs, mode: mode);
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  String get diarySortModeRaw =>
      _prefs.getString(_keyDiarySortMode) ?? 'updatedDesc';

  String get diaryLayoutModeRaw =>
      _prefs.getString(_keyDiaryLayoutMode) ?? 'list';

  String? get diaryToolbarOrderRaw => _prefs.getString(_keyDiaryToolbarOrder);

  String? get createDiaryDraftRaw => _prefs.getString(_keyCreateDiaryDraft);

  Future<void> setDiarySortModeRaw(String value) async {
    await _prefs.setString(_keyDiarySortMode, value);
  }

  Future<void> setDiaryLayoutModeRaw(String value) async {
    await _prefs.setString(_keyDiaryLayoutMode, value);
  }

  Future<void> setDiaryToolbarOrderRaw(String value) async {
    await _prefs.setString(_keyDiaryToolbarOrder, value);
  }

  Future<void> setCreateDiaryDraftRaw(String value) async {
    await _prefs.setString(_keyCreateDiaryDraft, value);
  }

  Future<void> clearCreateDiaryDraft() async {
    await _prefs.remove(_keyCreateDiaryDraft);
  }

  static ThemeMode _parseMode(String? modeRaw) {
    switch (modeRaw) {
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
