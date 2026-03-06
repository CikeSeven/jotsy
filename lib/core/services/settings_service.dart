import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._({
    required SharedPreferences prefs,
    required ThemeMode mode
  }) : _prefs = prefs,
      themeModeNotifier = ValueNotifier<ThemeMode>(mode);
  
  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  static const _keyThemeMode = 'app.settings.theme_mode';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = _parseMode(prefs.getString(_keyThemeMode));
    return SettingsService._(
        prefs: prefs,
        mode: mode
      );
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _prefs.setString(_keyThemeMode, mode.name);
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