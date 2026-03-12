import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._({
    required SharedPreferences prefs,
    required ThemeMode mode,
    required Locale locale,
  })
    : _prefs = prefs,
      themeModeNotifier = ValueNotifier<ThemeMode>(mode),
      localeNotifier = ValueNotifier<Locale>(locale);

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Locale> localeNotifier;

  static const _keyThemeMode = 'app.settings.theme_mode';
  static const _keyDiarySortMode = 'app.settings.diary_sort_mode';
  static const _keyDiaryLayoutMode = 'app.settings.diary_layout_mode';
  static const _keyDiaryToolbarOrder = 'app.settings.diary_toolbar_order';
  static const _keyTagOrder = 'app.settings.tag_order';
  static const _keyCreateDiaryDraft = 'app.settings.diary_create_draft';
  static const _keyAppLocaleCode = 'app.settings.locale_code';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = _parseMode(prefs.getString(_keyThemeMode));
    final storedLocaleCode = _normalizeLocaleCode(
      prefs.getString(_keyAppLocaleCode),
    );
    final localeCode =
        storedLocaleCode ?? _resolveInitialLocaleCodeFromSystem();
    if (storedLocaleCode == null) {
      await prefs.setString(_keyAppLocaleCode, localeCode);
    }
    return SettingsService._(
      prefs: prefs,
      mode: mode,
      locale: _localeFromCode(localeCode),
    );
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
  String? get tagOrderRaw => _prefs.getString(_keyTagOrder);

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

  Future<void> setTagOrderRaw(String value) async {
    await _prefs.setString(_keyTagOrder, value);
  }

  Future<void> setCreateDiaryDraftRaw(String value) async {
    await _prefs.setString(_keyCreateDiaryDraft, value);
  }

  Future<void> clearCreateDiaryDraft() async {
    await _prefs.remove(_keyCreateDiaryDraft);
  }

  String get appLocaleCode => _codeFromLocale(localeNotifier.value);

  Future<void> setAppLocale(Locale locale) async {
    await setAppLocaleCode(_codeFromLocale(locale));
  }

  Future<void> setAppLocaleCode(String localeCode) async {
    final normalized = _normalizeLocaleCode(localeCode) ?? 'en';
    final nextLocale = _localeFromCode(normalized);
    localeNotifier.value = nextLocale;
    await _prefs.setString(_keyAppLocaleCode, normalized);
  }

  static String _resolveInitialLocaleCodeFromSystem() {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    for (final locale in locales) {
      final normalized = _normalizeLocaleCode(locale.languageCode);
      if (normalized != null) {
        return normalized;
      }
    }
    return 'en';
  }

  static String? _normalizeLocaleCode(String? rawCode) {
    final code = rawCode?.trim().toLowerCase();
    if (code == null || code.isEmpty) {
      return null;
    }
    if (code.startsWith('zh')) {
      return 'zh';
    }
    if (code.startsWith('en')) {
      return 'en';
    }
    return null;
  }

  static Locale _localeFromCode(String code) {
    switch (code) {
      case 'zh':
        return const Locale('zh');
      case 'en':
      default:
        return const Locale('en');
    }
  }

  static String _codeFromLocale(Locale locale) {
    return _normalizeLocaleCode(locale.languageCode) ?? 'en';
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
