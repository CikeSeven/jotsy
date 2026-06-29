import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _defaultDiaryToolbarCurrentTimeFormat = 'M月d日 HH:mm';

enum HomeTabSwitchCurveType { easeOutCirc, easeOutCubic, linear }

extension HomeTabSwitchCurveTypeX on HomeTabSwitchCurveType {
  String get storageValue => switch (this) {
    HomeTabSwitchCurveType.easeOutCirc => 'easeOutCirc',
    HomeTabSwitchCurveType.easeOutCubic => 'easeOutCubic',
    HomeTabSwitchCurveType.linear => 'linear',
  };

  Curve get curve => switch (this) {
    HomeTabSwitchCurveType.easeOutCirc => Curves.easeOutCirc,
    HomeTabSwitchCurveType.easeOutCubic => Curves.easeOutCubic,
    HomeTabSwitchCurveType.linear => Curves.linear,
  };
}

enum EditorBodyFontSizePreset { small, medium, large }

extension EditorBodyFontSizePresetX on EditorBodyFontSizePreset {
  String get storageValue => switch (this) {
    EditorBodyFontSizePreset.small => 'small',
    EditorBodyFontSizePreset.medium => 'medium',
    EditorBodyFontSizePreset.large => 'large',
  };

  double get fontSize => switch (this) {
    EditorBodyFontSizePreset.small => 14,
    EditorBodyFontSizePreset.medium => 16,
    EditorBodyFontSizePreset.large => 18,
  };
}

enum EditorBodyLineHeightPreset { compact, normal, relaxed }

extension EditorBodyLineHeightPresetX on EditorBodyLineHeightPreset {
  String get storageValue => switch (this) {
    EditorBodyLineHeightPreset.compact => 'compact',
    EditorBodyLineHeightPreset.normal => 'normal',
    EditorBodyLineHeightPreset.relaxed => 'relaxed',
  };

  double get lineHeight => switch (this) {
    EditorBodyLineHeightPreset.compact => 1.35,
    EditorBodyLineHeightPreset.normal => 1.55,
    EditorBodyLineHeightPreset.relaxed => 1.75,
  };
}

class SettingsService {
  static const int defaultThemeSeedColorValue = 0xFF1E6586;
  static const HomeTabSwitchCurveType defaultHomeTabSwitchCurveType =
      HomeTabSwitchCurveType.easeOutCirc;
  static const EditorBodyFontSizePreset defaultEditorBodyFontSizePreset =
      EditorBodyFontSizePreset.medium;
  static const EditorBodyLineHeightPreset defaultEditorBodyLineHeightPreset =
      EditorBodyLineHeightPreset.normal;
  static const double defaultFontScale = 1.0;
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.25;
  static const double fontScaleStep = 0.05;

  static const int moodOptionCount = 10;
  static const List<String> defaultMoodOptions = <String>[
    '😭',
    '😢',
    '😞',
    '😕',
    '😐',
    '🙂',
    '😊',
    '😄',
    '😀',
    '🤩',
  ];
  SettingsService._({
    required SharedPreferences prefs,
    required ThemeMode mode,
    required Color themeSeedColor,
    required HomeTabSwitchCurveType homeTabSwitchCurveType,
    required EditorBodyFontSizePreset editorBodyFontSizePreset,
    required EditorBodyLineHeightPreset editorBodyLineHeightPreset,
    required double fontScale,
    required Locale locale,
    required bool appLockEnabled,
    required String? diaryToolbarOrderRaw,
    required String? diaryToolbarHiddenItemsRaw,
    required String? diaryToolbarCurrentTimeFormatRaw,
    required String? moodOptionsRaw,
  }) : _prefs = prefs,
       themeModeNotifier = ValueNotifier<ThemeMode>(mode),
       themeSeedColorNotifier = ValueNotifier<Color>(themeSeedColor),
       homeTabSwitchCurveNotifier = ValueNotifier<HomeTabSwitchCurveType>(
         homeTabSwitchCurveType,
       ),
       editorBodyFontSizePresetNotifier =
           ValueNotifier<EditorBodyFontSizePreset>(editorBodyFontSizePreset),
       editorBodyLineHeightPresetNotifier =
           ValueNotifier<EditorBodyLineHeightPreset>(
             editorBodyLineHeightPreset,
           ),
       fontScaleNotifier = ValueNotifier<double>(fontScale),
       localeNotifier = ValueNotifier<Locale>(locale),
       appLockEnabledNotifier = ValueNotifier<bool>(appLockEnabled),
       diaryToolbarOrderRawNotifier = ValueNotifier<String?>(
         diaryToolbarOrderRaw,
       ),
       diaryToolbarHiddenItemsRawNotifier = ValueNotifier<String?>(
         diaryToolbarHiddenItemsRaw,
       ),
       diaryToolbarCurrentTimeFormatRawNotifier = ValueNotifier<String?>(
         diaryToolbarCurrentTimeFormatRaw,
       ),
       moodOptionsRawNotifier = ValueNotifier<String?>(moodOptionsRaw);

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> themeSeedColorNotifier;
  final ValueNotifier<HomeTabSwitchCurveType> homeTabSwitchCurveNotifier;
  final ValueNotifier<EditorBodyFontSizePreset>
  editorBodyFontSizePresetNotifier;
  final ValueNotifier<EditorBodyLineHeightPreset>
  editorBodyLineHeightPresetNotifier;
  final ValueNotifier<double> fontScaleNotifier;
  final ValueNotifier<Locale> localeNotifier;
  final ValueNotifier<bool> appLockEnabledNotifier;
  final ValueNotifier<String?> diaryToolbarOrderRawNotifier;
  final ValueNotifier<String?> diaryToolbarHiddenItemsRawNotifier;
  final ValueNotifier<String?> diaryToolbarCurrentTimeFormatRawNotifier;
  final ValueNotifier<String?> moodOptionsRawNotifier;

  static const _keyThemeMode = 'app.settings.theme_mode';
  static const _keyThemeSeedColorValue = 'app.settings.theme_seed_color_value';
  static const _keyHomeTabSwitchCurve = 'app.settings.home_tab_switch_curve';
  static const _keyEditorBodyFontSizePreset =
      'app.settings.editor_body_font_size_preset';
  static const _keyEditorBodyLineHeightPreset =
      'app.settings.editor_body_line_height_preset';
  static const _keyFontScale = 'app.settings.font_scale';
  static const _keyDiarySortMode = 'app.settings.diary_sort_mode';
  static const _keyDiaryLayoutMode = 'app.settings.diary_layout_mode';
  static const _keyDiaryToolbarOrder = 'app.settings.diary_toolbar_order';
  static const _keyDiaryToolbarHiddenItems =
      'app.settings.diary_toolbar_hidden_items';
  static const _keyDiaryToolbarCurrentTimeFormat =
      'app.settings.diary_toolbar_current_time_format';
  static const _keyMoodOptions = 'app.settings.mood_options';

  static const _keyTagOrder = 'app.settings.tag_order';
  static const _keyCreateDiaryDraft = 'app.settings.diary_create_draft';
  static const _keyReleaseMirrorStartIndex =
      'app.settings.release_mirror_start_index';
  static const _keyAppLocaleCode = 'app.settings.locale_code';
  static const _keyAppLockEnabled = 'app.settings.app_lock_enabled';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = _parseMode(prefs.getString(_keyThemeMode));
    final themeSeedColorValue =
        prefs.getInt(_keyThemeSeedColorValue) ?? defaultThemeSeedColorValue;
    final homeTabSwitchCurveType = _parseHomeTabSwitchCurveType(
      prefs.getString(_keyHomeTabSwitchCurve),
    );
    final editorBodyFontSizePreset = _parseEditorBodyFontSizePreset(
      prefs.getString(_keyEditorBodyFontSizePreset),
    );
    if (!prefs.containsKey(_keyEditorBodyFontSizePreset)) {
      await prefs.setString(
        _keyEditorBodyFontSizePreset,
        editorBodyFontSizePreset.storageValue,
      );
    }
    final editorBodyLineHeightPreset = _parseEditorBodyLineHeightPreset(
      prefs.getString(_keyEditorBodyLineHeightPreset),
    );
    if (!prefs.containsKey(_keyEditorBodyLineHeightPreset)) {
      await prefs.setString(
        _keyEditorBodyLineHeightPreset,
        editorBodyLineHeightPreset.storageValue,
      );
    }
    final fontScale = _normalizeFontScale(
      prefs.getDouble(_keyFontScale) ?? defaultFontScale,
    );
    if (!prefs.containsKey(_keyFontScale)) {
      await prefs.setDouble(_keyFontScale, fontScale);
    }
    if (!prefs.containsKey(_keyReleaseMirrorStartIndex)) {
      await prefs.setInt(_keyReleaseMirrorStartIndex, 0);
    }
    final storedLocaleCode = _normalizeLocaleCode(
      prefs.getString(_keyAppLocaleCode),
    );
    final localeCode =
        storedLocaleCode ?? _resolveInitialLocaleCodeFromSystem();
    if (storedLocaleCode == null) {
      await prefs.setString(_keyAppLocaleCode, localeCode);
    }
    final appLockEnabled = prefs.getBool(_keyAppLockEnabled) ?? false;
    return SettingsService._(
      prefs: prefs,
      mode: mode,
      themeSeedColor: Color(themeSeedColorValue),
      homeTabSwitchCurveType: homeTabSwitchCurveType,
      editorBodyFontSizePreset: editorBodyFontSizePreset,
      editorBodyLineHeightPreset: editorBodyLineHeightPreset,
      fontScale: fontScale,
      locale: _localeFromCode(localeCode),
      appLockEnabled: appLockEnabled,
      diaryToolbarOrderRaw: prefs.getString(_keyDiaryToolbarOrder),
      diaryToolbarHiddenItemsRaw: prefs.getString(_keyDiaryToolbarHiddenItems),
      diaryToolbarCurrentTimeFormatRaw:
          prefs.getString(_keyDiaryToolbarCurrentTimeFormat) ??
          _defaultDiaryToolbarCurrentTimeFormat,
      moodOptionsRaw: prefs.getString(_keyMoodOptions),
    );
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setThemeSeedColor(Color color) async {
    final value = color.toARGB32();
    themeSeedColorNotifier.value = Color(value);
    await _prefs.setInt(_keyThemeSeedColorValue, value);
  }

  Future<void> setHomeTabSwitchCurveType(
    HomeTabSwitchCurveType curveType,
  ) async {
    homeTabSwitchCurveNotifier.value = curveType;
    await _prefs.setString(_keyHomeTabSwitchCurve, curveType.storageValue);
  }

  Future<void> setEditorBodyFontSizePreset(
    EditorBodyFontSizePreset preset,
  ) async {
    editorBodyFontSizePresetNotifier.value = preset;
    await _prefs.setString(_keyEditorBodyFontSizePreset, preset.storageValue);
  }

  Future<void> setEditorBodyLineHeightPreset(
    EditorBodyLineHeightPreset preset,
  ) async {
    editorBodyLineHeightPresetNotifier.value = preset;
    await _prefs.setString(_keyEditorBodyLineHeightPreset, preset.storageValue);
  }

  Future<void> setFontScale(double scale) async {
    final normalized = _normalizeFontScale(scale);
    fontScaleNotifier.value = normalized;
    await _prefs.setDouble(_keyFontScale, normalized);
  }

  String get diarySortModeRaw =>
      _prefs.getString(_keyDiarySortMode) ?? 'updatedDesc';

  String get diaryLayoutModeRaw =>
      _prefs.getString(_keyDiaryLayoutMode) ?? 'list';

  String? get diaryToolbarOrderRaw => diaryToolbarOrderRawNotifier.value;
  String? get diaryToolbarHiddenItemsRaw =>
      diaryToolbarHiddenItemsRawNotifier.value;
  String? get diaryToolbarCurrentTimeFormatRaw =>
      diaryToolbarCurrentTimeFormatRawNotifier.value;
  String? get moodOptionsRaw => moodOptionsRawNotifier.value;
  List<String> get moodOptions =>
      decodeMoodOptions(moodOptionsRawNotifier.value);
  String? get tagOrderRaw => _prefs.getString(_keyTagOrder);

  String? get createDiaryDraftRaw => _prefs.getString(_keyCreateDiaryDraft);
  int get releaseMirrorStartIndexRaw =>
      _prefs.getInt(_keyReleaseMirrorStartIndex) ?? 0;

  Future<void> setDiarySortModeRaw(String value) async {
    await _prefs.setString(_keyDiarySortMode, value);
  }

  Future<void> setDiaryLayoutModeRaw(String value) async {
    await _prefs.setString(_keyDiaryLayoutMode, value);
  }

  Future<void> setDiaryToolbarOrderRaw(String value) async {
    diaryToolbarOrderRawNotifier.value = value;
    await _prefs.setString(_keyDiaryToolbarOrder, value);
  }

  Future<void> setDiaryToolbarHiddenItemsRaw(String value) async {
    final normalized = value.trim();
    diaryToolbarHiddenItemsRawNotifier.value =
        normalized.isEmpty ? null : normalized;
    if (normalized.isEmpty) {
      await _prefs.remove(_keyDiaryToolbarHiddenItems);
      return;
    }
    await _prefs.setString(_keyDiaryToolbarHiddenItems, normalized);
  }

  Future<void> setDiaryToolbarCurrentTimeFormatRaw(String value) async {
    final normalized =
        value.trim().isEmpty
            ? _defaultDiaryToolbarCurrentTimeFormat
            : value.trim();
    diaryToolbarCurrentTimeFormatRawNotifier.value = normalized;
    await _prefs.setString(_keyDiaryToolbarCurrentTimeFormat, normalized);
  }

  Future<void> setMoodOptions(List<String> options) async {
    final encoded = encodeMoodOptions(options);
    moodOptionsRawNotifier.value = encoded;
    await _prefs.setString(_keyMoodOptions, encoded);
  }

  Future<void> resetMoodOptions() async {
    moodOptionsRawNotifier.value = null;
    await _prefs.remove(_keyMoodOptions);
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

  Future<void> setReleaseMirrorStartIndex(int index) async {
    final normalized = index < 0 ? 0 : index;
    await _prefs.setInt(_keyReleaseMirrorStartIndex, normalized);
  }

  String get appLocaleCode => _codeFromLocale(localeNotifier.value);
  bool get isAppLockEnabled => appLockEnabledNotifier.value;
  int get themeSeedColorValue => themeSeedColorNotifier.value.toARGB32();
  String get homeTabSwitchCurveTypeValue =>
      homeTabSwitchCurveNotifier.value.storageValue;
  EditorBodyFontSizePreset get editorBodyFontSizePresetValue =>
      editorBodyFontSizePresetNotifier.value;
  String get editorBodyFontSizePresetStorageValue =>
      editorBodyFontSizePresetNotifier.value.storageValue;
  EditorBodyLineHeightPreset get editorBodyLineHeightPresetValue =>
      editorBodyLineHeightPresetNotifier.value;
  String get editorBodyLineHeightPresetStorageValue =>
      editorBodyLineHeightPresetNotifier.value.storageValue;
  double get fontScaleValue => fontScaleNotifier.value;

  Future<void> setAppLocale(Locale locale) async {
    await setAppLocaleCode(_codeFromLocale(locale));
  }

  Future<void> setAppLocaleCode(String localeCode) async {
    final normalized = _normalizeLocaleCode(localeCode) ?? 'en';
    final nextLocale = _localeFromCode(normalized);
    localeNotifier.value = nextLocale;
    await _prefs.setString(_keyAppLocaleCode, normalized);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    appLockEnabledNotifier.value = enabled;
    await _prefs.setBool(_keyAppLockEnabled, enabled);
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

  static HomeTabSwitchCurveType _parseHomeTabSwitchCurveType(String? raw) {
    return switch (raw) {
      'easeOutCubic' => HomeTabSwitchCurveType.easeOutCubic,
      'linear' => HomeTabSwitchCurveType.linear,
      'easeOutCirc' => HomeTabSwitchCurveType.easeOutCirc,
      _ => defaultHomeTabSwitchCurveType,
    };
  }

  static EditorBodyFontSizePreset _parseEditorBodyFontSizePreset(String? raw) {
    return switch (raw) {
      'small' => EditorBodyFontSizePreset.small,
      'large' => EditorBodyFontSizePreset.large,
      'medium' => EditorBodyFontSizePreset.medium,
      _ => defaultEditorBodyFontSizePreset,
    };
  }

  static EditorBodyLineHeightPreset _parseEditorBodyLineHeightPreset(
    String? raw,
  ) {
    return switch (raw) {
      'compact' => EditorBodyLineHeightPreset.compact,
      'relaxed' => EditorBodyLineHeightPreset.relaxed,
      'normal' => EditorBodyLineHeightPreset.normal,
      _ => defaultEditorBodyLineHeightPreset,
    };
  }

  static List<String> decodeMoodOptions(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return List<String>.unmodifiable(defaultMoodOptions);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return normalizeMoodOptions(
          decoded.map((item) => item?.toString() ?? ''),
        );
      }
    } catch (_) {
      // 旧版或损坏配置回退到默认值，避免设置脏数据阻断编辑/发布流程。
    }
    return List<String>.unmodifiable(defaultMoodOptions);
  }

  static String encodeMoodOptions(List<String> options) {
    return jsonEncode(normalizeMoodOptions(options));
  }

  static List<String> normalizeMoodOptions(Iterable<String> options) {
    final raw = options.toList(growable: false);
    final normalized = <String>[];
    for (var index = 0; index < moodOptionCount; index += 1) {
      final candidate = index < raw.length ? raw[index].trim() : '';
      normalized.add(candidate.isEmpty ? defaultMoodOptions[index] : candidate);
    }
    return List<String>.unmodifiable(normalized);
  }

  static Map<String, int> buildMoodWeightMap(List<String> moodOptions) {
    final normalized = normalizeMoodOptions(moodOptions);
    final weights = <String, int>{};
    for (var index = 0; index < defaultMoodOptions.length; index += 1) {
      weights[defaultMoodOptions[index]] = index + 1;
    }
    for (var index = 0; index < normalized.length; index += 1) {
      weights[normalized[index]] = index + 1;
    }
    return weights;
  }

  static int? moodWeight(String? mood, List<String> moodOptions) {
    final normalizedMood = mood?.trim();
    if (normalizedMood == null || normalizedMood.isEmpty) {
      return null;
    }
    return buildMoodWeightMap(moodOptions)[normalizedMood];
  }

  static double? moodScore(String? mood, List<String> moodOptions) {
    final weight = moodWeight(mood, moodOptions);
    if (weight == null) {
      return null;
    }
    return 1 + ((weight - 1) / (moodOptionCount - 1)) * 4;
  }

  static String moodForWeight(int weight, List<String> moodOptions) {
    final normalized = normalizeMoodOptions(moodOptions);
    final clamped = weight.clamp(1, moodOptionCount).toInt();
    return normalized[clamped - 1];
  }

  static double _normalizeFontScale(double raw) {
    return raw.clamp(minFontScale, maxFontScale).toDouble();
  }
}
