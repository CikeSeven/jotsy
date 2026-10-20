import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diary_typography.dart';

export 'diary_typography.dart';

part 'settings_service_backup.dart';

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

class SettingsService {
  static const int defaultThemeSeedColorValue = 0xFF1E6586;
  static const HomeTabSwitchCurveType defaultHomeTabSwitchCurveType =
      HomeTabSwitchCurveType.easeOutCirc;
  static const double defaultFontScale = 1.0;
  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.25;
  static const double fontScaleStep = 0.05;
  static const int defaultDiaryCardTagLimit = 2;
  static const int minDiaryCardTagLimit = 0;
  static const int maxDiaryCardTagLimit = 20;

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
    required this._prefs,
    required ThemeMode mode,
    required Color themeSeedColor,
    required HomeTabSwitchCurveType homeTabSwitchCurveType,
    required DiaryTypography diaryTypography,
    required double fontScale,
    required Locale locale,
    required bool appLockEnabled,
    required bool tagFilterMemoryEnabled,
    required bool dayPhotoSuggestionsEnabled,
    required int diaryCardTagLimit,
    required String? diaryToolbarOrderRaw,
    required String? diaryToolbarHiddenItemsRaw,
    required String? diaryToolbarCurrentTimeFormatRaw,
    required String? moodOptionsRaw,
    required String? calendarDisplayOptionsRaw,
    required String? diaryCardStyleRaw,
    required String? diaryPreviewStyleRaw,
    required String? diaryTemplatePrefsRaw,
    required String? diaryRecentColorsRaw,
    required String? appFeaturesRaw,
  }) : themeModeNotifier = ValueNotifier<ThemeMode>(mode),
       themeSeedColorNotifier = ValueNotifier<Color>(themeSeedColor),
       homeTabSwitchCurveNotifier = ValueNotifier<HomeTabSwitchCurveType>(
         homeTabSwitchCurveType,
       ),
       diaryTypographyNotifier = ValueNotifier<DiaryTypography>(
         diaryTypography,
       ),
       fontScaleNotifier = ValueNotifier<double>(fontScale),
       localeNotifier = ValueNotifier<Locale>(locale),
       appLockEnabledNotifier = ValueNotifier<bool>(appLockEnabled),
       tagFilterMemoryEnabledNotifier = ValueNotifier<bool>(
         tagFilterMemoryEnabled,
       ),
       dayPhotoSuggestionsEnabledNotifier = ValueNotifier<bool>(
         dayPhotoSuggestionsEnabled,
       ),
       diaryCardTagLimitNotifier = ValueNotifier<int>(diaryCardTagLimit),
       diaryToolbarOrderRawNotifier = ValueNotifier<String?>(
         diaryToolbarOrderRaw,
       ),
       diaryToolbarHiddenItemsRawNotifier = ValueNotifier<String?>(
         diaryToolbarHiddenItemsRaw,
       ),
       diaryToolbarCurrentTimeFormatRawNotifier = ValueNotifier<String?>(
         diaryToolbarCurrentTimeFormatRaw,
       ),
       moodOptionsRawNotifier = ValueNotifier<String?>(moodOptionsRaw),
       calendarDisplayOptionsRawNotifier = ValueNotifier<String?>(
         calendarDisplayOptionsRaw,
       ),
       diaryCardStyleRawNotifier = ValueNotifier<String?>(diaryCardStyleRaw),
       diaryPreviewStyleRawNotifier = ValueNotifier<String?>(
         diaryPreviewStyleRaw,
       ),
       diaryTemplatePrefsRawNotifier = ValueNotifier<String?>(
         diaryTemplatePrefsRaw,
       ),
       diaryRecentColorsRawNotifier = ValueNotifier<String?>(
         diaryRecentColorsRaw,
       ),
       appFeaturesRawNotifier = ValueNotifier<String?>(appFeaturesRaw);

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> themeSeedColorNotifier;
  final ValueNotifier<HomeTabSwitchCurveType> homeTabSwitchCurveNotifier;

  /// 日记正文排版（编辑 / 预览 / 发布三处共用）。
  final ValueNotifier<DiaryTypography> diaryTypographyNotifier;
  final ValueNotifier<double> fontScaleNotifier;
  final ValueNotifier<Locale> localeNotifier;
  final ValueNotifier<bool> appLockEnabledNotifier;
  final ValueNotifier<bool> tagFilterMemoryEnabledNotifier;

  /// 补写过去某天的日记时，是否在编辑页列出相册里这天拍的照片（默认开）。
  /// 与相册权限一样属于本机偏好，不随备份导出。
  final ValueNotifier<bool> dayPhotoSuggestionsEnabledNotifier;
  final ValueNotifier<int> diaryCardTagLimitNotifier;
  final ValueNotifier<String?> diaryToolbarOrderRawNotifier;
  final ValueNotifier<String?> diaryToolbarHiddenItemsRawNotifier;
  final ValueNotifier<String?> diaryToolbarCurrentTimeFormatRawNotifier;
  final ValueNotifier<String?> moodOptionsRawNotifier;

  /// 日历页显示选项（单个 JSON 字符串）；解析与默认值由日历模块负责，
  /// 服务层只保存原文，不依赖 UI 模型。
  final ValueNotifier<String?> calendarDisplayOptionsRawNotifier;

  /// 日记卡片样式设置（单个 JSON 字符串：当前样式 + 已保存的样式）；解析与
  /// 默认值由日记模块负责，服务层只保存原文。
  final ValueNotifier<String?> diaryCardStyleRawNotifier;

  /// 日记预览页设置（单个 JSON 字符串：当前样式 + 已保存的样式 + 阅读行为）；
  /// 解析与默认值由日记模块负责，服务层只保存原文。
  final ValueNotifier<String?> diaryPreviewStyleRawNotifier;

  /// 日记模板偏好（单个 JSON 字符串：建议条开关、自动套用的模板、隐藏的
  /// 内置模板、最近使用）；解析与默认值由模板模块负责，服务层只保存原文。
  /// 用户模板本身存在数据库 `diary_templates` 表里。
  final ValueNotifier<String?> diaryTemplatePrefsRawNotifier;

  /// 编辑器颜色面板最近用过的自定义颜色（单个 JSON 字符串，文字色与背景色
  /// 各一组）；解析与上限由日记模块（`DiaryRecentColors`）负责。
  final ValueNotifier<String?> diaryRecentColorsRawNotifier;

  /// 功能管理（单个 JSON 字符串：日历、探索、日记本、纪念日、模板、时间胶囊
  /// 各自是否开启）；解析与默认值由 `AppFeatures` 负责，服务层只保存原文。
  /// 用 notifier 是因为首页底栏与各处入口要在开关变化（含备份恢复与失败
  /// 回滚）时立即重建。
  final ValueNotifier<String?> appFeaturesRawNotifier;

  static const _keyThemeMode = 'app.settings.theme_mode';
  static const _keyThemeSeedColorValue = 'app.settings.theme_seed_color_value';
  static const _keyHomeTabSwitchCurve = 'app.settings.home_tab_switch_curve';
  static const _keyDiaryTypography = 'app.settings.diary_typography';
  // 旧版三档预设，只在启动迁移时读取一次，迁移后删除。
  static const _keyLegacyEditorBodyFontSizePreset =
      'app.settings.editor_body_font_size_preset';
  static const _keyLegacyEditorBodyLineHeightPreset =
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
  static const _keyTagFilterMemoryEnabled =
      'app.settings.tag_filter_memory_enabled';
  static const _keyDayPhotoSuggestionsEnabled =
      'app.settings.day_photo_suggestions_enabled';
  static const _keyRememberedTagFilterIds =
      'app.settings.remembered_tag_filter_ids';
  static const _keyDiaryCardTagLimit = 'app.settings.diary_card_tag_limit';
  static const _keyCalendarDisplayOptions =
      'app.settings.calendar_display_options';
  static const _keyDiaryCardStyle = 'app.settings.diary_card_style';
  static const _keyDiaryPreviewStyle = 'app.settings.diary_preview_style';
  static const _keyDiaryTemplatePrefs = 'app.settings.diary_template_prefs';
  static const _keyDiaryRecentColors = 'app.settings.diary_recent_colors';
  static const _keyDiaryShareOptions = 'app.settings.diary_share_options';
  static const _keyDiaryExportOptions = 'app.settings.diary_export_options';
  static const _keyAppFeatures = 'app.settings.app_features';

  static const _keyTagOrder = 'app.settings.tag_order';
  static const _keyTagPickerSort = 'app.settings.tag_picker_sort';
  // 草稿箱之前的单份新建草稿：只作迁移来源（见 migrateLegacyCreateDraft），
  // 不再写入；迁移成功或覆盖恢复后清除。
  static const _keyCreateDiaryDraft = 'app.settings.diary_create_draft';
  static const _keyDiaryLocationPrecision =
      'app.settings.diary_location_precision';
  // 旧版更新检查记录的镜像序号，已并入 [_keyAppUpdatePreferences]；启动时删除。
  static const _keyLegacyReleaseMirrorStartIndex =
      'app.settings.release_mirror_start_index';
  static const _keyAppUpdatePreferences = 'app.update.preferences';
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
    final diaryTypography = await _loadDiaryTypography(prefs);
    final fontScale = _normalizeFontScale(
      prefs.getDouble(_keyFontScale) ?? defaultFontScale,
    );
    if (!prefs.containsKey(_keyFontScale)) {
      await prefs.setDouble(_keyFontScale, fontScale);
    }
    if (prefs.containsKey(_keyLegacyReleaseMirrorStartIndex)) {
      await prefs.remove(_keyLegacyReleaseMirrorStartIndex);
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
    final tagFilterMemoryEnabled =
        prefs.getBool(_keyTagFilterMemoryEnabled) ?? false;
    final storedDayPhotoSuggestions = prefs.get(_keyDayPhotoSuggestionsEnabled);
    final storedDiaryCardTagLimit = prefs.get(_keyDiaryCardTagLimit);
    final diaryCardTagLimit = _normalizeDiaryCardTagLimit(
      storedDiaryCardTagLimit is int
          ? storedDiaryCardTagLimit
          : defaultDiaryCardTagLimit,
    );
    if (storedDiaryCardTagLimit is! int ||
        storedDiaryCardTagLimit != diaryCardTagLimit) {
      await prefs.setInt(_keyDiaryCardTagLimit, diaryCardTagLimit);
    }
    // getString 遇到类型不符的旧值会抛异常；卡片样式只是外观偏好，读不出来
    // 就按默认样式展示，不能让它阻断启动。
    final storedDiaryCardStyle = prefs.get(_keyDiaryCardStyle);
    final storedDiaryPreviewStyle = prefs.get(_keyDiaryPreviewStyle);
    final storedDiaryTemplatePrefs = prefs.get(_keyDiaryTemplatePrefs);
    final storedDiaryRecentColors = prefs.get(_keyDiaryRecentColors);
    final storedAppFeatures = prefs.get(_keyAppFeatures);
    return SettingsService._(
      prefs: prefs,
      mode: mode,
      themeSeedColor: Color(themeSeedColorValue),
      homeTabSwitchCurveType: homeTabSwitchCurveType,
      diaryTypography: diaryTypography,
      fontScale: fontScale,
      locale: _localeFromCode(localeCode),
      appLockEnabled: appLockEnabled,
      tagFilterMemoryEnabled: tagFilterMemoryEnabled,
      dayPhotoSuggestionsEnabled: storedDayPhotoSuggestions is bool
          ? storedDayPhotoSuggestions
          : true,
      diaryCardTagLimit: diaryCardTagLimit,
      diaryToolbarOrderRaw: prefs.getString(_keyDiaryToolbarOrder),
      diaryToolbarHiddenItemsRaw: prefs.getString(_keyDiaryToolbarHiddenItems),
      diaryToolbarCurrentTimeFormatRaw:
          prefs.getString(_keyDiaryToolbarCurrentTimeFormat) ??
          _defaultDiaryToolbarCurrentTimeFormat,
      moodOptionsRaw: prefs.getString(_keyMoodOptions),
      calendarDisplayOptionsRaw: prefs.getString(_keyCalendarDisplayOptions),
      diaryCardStyleRaw: storedDiaryCardStyle is String
          ? storedDiaryCardStyle
          : null,
      diaryPreviewStyleRaw: storedDiaryPreviewStyle is String
          ? storedDiaryPreviewStyle
          : null,
      diaryTemplatePrefsRaw: storedDiaryTemplatePrefs is String
          ? storedDiaryTemplatePrefs
          : null,
      diaryRecentColorsRaw: storedDiaryRecentColors is String
          ? storedDiaryRecentColors
          : null,
      appFeaturesRaw: storedAppFeatures is String ? storedAppFeatures : null,
    );
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _writePreference(_prefs.setString(_keyThemeMode, mode.name));
  }

  Future<void> setThemeSeedColor(Color color) async {
    final value = color.toARGB32();
    themeSeedColorNotifier.value = Color(value);
    await _writePreference(_prefs.setInt(_keyThemeSeedColorValue, value));
  }

  Future<void> setHomeTabSwitchCurveType(
    HomeTabSwitchCurveType curveType,
  ) async {
    homeTabSwitchCurveNotifier.value = curveType;
    await _writePreference(
      _prefs.setString(_keyHomeTabSwitchCurve, curveType.storageValue),
    );
  }

  Future<void> setDiaryTypography(DiaryTypography typography) async {
    // 经 copyWith 归一化：调用方直接构造的越界值不会落盘。
    final normalized = typography.copyWith();
    diaryTypographyNotifier.value = normalized;
    await _writePreference(
      _prefs.setString(_keyDiaryTypography, normalized.toRaw()),
    );
  }

  Future<void> setFontScale(double scale) async {
    final normalized = _normalizeFontScale(scale);
    fontScaleNotifier.value = normalized;
    await _writePreference(_prefs.setDouble(_keyFontScale, normalized));
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
  String? get calendarDisplayOptionsRaw =>
      calendarDisplayOptionsRawNotifier.value;
  String? get diaryCardStyleRaw => diaryCardStyleRawNotifier.value;
  String? get diaryPreviewStyleRaw => diaryPreviewStyleRawNotifier.value;
  String? get diaryTemplatePrefsRaw => diaryTemplatePrefsRawNotifier.value;

  String? get diaryRecentColorsRaw => diaryRecentColorsRawNotifier.value;
  String? get appFeaturesRaw => appFeaturesRawNotifier.value;
  List<String> get moodOptions =>
      decodeMoodOptions(moodOptionsRawNotifier.value);
  int get diaryCardTagLimit => diaryCardTagLimitNotifier.value;
  String? get tagOrderRaw => _prefs.getString(_keyTagOrder);

  /// 发布面板标签子页的排序方式（枚举名）；解析与未知值回退由日记模块
  /// （`TagPickerSort`）负责。类型不符的旧值按未设置处理。
  String? get tagPickerSortRaw {
    final value = _prefs.get(_keyTagPickerSort);
    return value is String ? value : null;
  }

  bool get isTagFilterMemoryEnabled => tagFilterMemoryEnabledNotifier.value;
  bool get isDayPhotoSuggestionsEnabled =>
      dayPhotoSuggestionsEnabledNotifier.value;
  String? get rememberedTagFilterIdsRaw =>
      _prefs.getString(_keyRememberedTagFilterIds);

  String? get createDiaryDraftRaw => _prefs.getString(_keyCreateDiaryDraft);

  /// 最近一次选择的日记地址层级，新建日记沿用；原样保存枚举名，解析与
  /// 未知值回退由日记模块负责，服务层不依赖 UI 模型。
  String? get diaryLocationPrecisionRaw =>
      _prefs.getString(_keyDiaryLocationPrecision);

  /// 分享面板的内容开关（单个 JSON 字符串）；解析与默认值由日记模块负责。
  /// 只在打开分享面板时读取，不需要通知。类型不符的旧值按未设置处理。
  String? get diaryShareOptionsRaw {
    final value = _prefs.get(_keyDiaryShareOptions);
    return value is String ? value : null;
  }

  /// 导出面板上次的格式与开关（单个 JSON 字符串）；解析由日记模块负责。
  String? get diaryExportOptionsRaw {
    final value = _prefs.get(_keyDiaryExportOptions);
    return value is String ? value : null;
  }

  /// 应用更新的本机偏好（单个 JSON 字符串，见 `AppUpdatePreferences`）；
  /// 只描述本机，不随备份导出。类型不符的旧值按未设置处理。
  String? get appUpdatePreferencesRaw {
    final value = _prefs.get(_keyAppUpdatePreferences);
    return value is String ? value : null;
  }

  Future<void> setDiarySortModeRaw(String value) async {
    await _writePreference(_prefs.setString(_keyDiarySortMode, value));
  }

  Future<void> setDiaryLayoutModeRaw(String value) async {
    await _writePreference(_prefs.setString(_keyDiaryLayoutMode, value));
  }

  Future<void> setDiaryToolbarOrderRaw(String value) async {
    diaryToolbarOrderRawNotifier.value = value;
    await _writePreference(_prefs.setString(_keyDiaryToolbarOrder, value));
  }

  Future<void> setDiaryToolbarHiddenItemsRaw(String value) async {
    final normalized = value.trim();
    diaryToolbarHiddenItemsRawNotifier.value = normalized.isEmpty
        ? null
        : normalized;
    if (normalized.isEmpty) {
      await _writePreference(_prefs.remove(_keyDiaryToolbarHiddenItems));
      return;
    }
    await _writePreference(
      _prefs.setString(_keyDiaryToolbarHiddenItems, normalized),
    );
  }

  Future<void> setDiaryToolbarCurrentTimeFormatRaw(String value) async {
    final normalized = value.trim().isEmpty
        ? _defaultDiaryToolbarCurrentTimeFormat
        : value.trim();
    diaryToolbarCurrentTimeFormatRawNotifier.value = normalized;
    await _writePreference(
      _prefs.setString(_keyDiaryToolbarCurrentTimeFormat, normalized),
    );
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

  /// 保存日历显示选项；空值移除该键，回到默认选项。
  Future<void> setCalendarDisplayOptionsRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      calendarDisplayOptionsRawNotifier.value = null;
      await _writePreference(_prefs.remove(_keyCalendarDisplayOptions));
      return;
    }
    calendarDisplayOptionsRawNotifier.value = normalized;
    await _writePreference(
      _prefs.setString(_keyCalendarDisplayOptions, normalized),
    );
  }

  /// 保存分享面板的内容开关；空值移除该键，回到默认开关。
  Future<void> setDiaryShareOptionsRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _writePreference(_prefs.remove(_keyDiaryShareOptions));
      return;
    }
    await _writePreference(_prefs.setString(_keyDiaryShareOptions, normalized));
  }

  /// 保存导出面板的格式与开关；空值移除该键，回到默认选项。
  Future<void> setDiaryExportOptionsRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _writePreference(_prefs.remove(_keyDiaryExportOptions));
      return;
    }
    await _writePreference(
      _prefs.setString(_keyDiaryExportOptions, normalized),
    );
  }

  /// 保存日记卡片样式设置；空值移除该键，回到默认样式。
  Future<void> setDiaryCardStyleRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      diaryCardStyleRawNotifier.value = null;
      await _writePreference(_prefs.remove(_keyDiaryCardStyle));
      return;
    }
    diaryCardStyleRawNotifier.value = normalized;
    await _writePreference(_prefs.setString(_keyDiaryCardStyle, normalized));
  }

  /// 保存日记预览页设置；空值移除该键，回到默认外观与阅读行为。
  Future<void> setDiaryPreviewStyleRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      diaryPreviewStyleRawNotifier.value = null;
      await _writePreference(_prefs.remove(_keyDiaryPreviewStyle));
      return;
    }
    diaryPreviewStyleRawNotifier.value = normalized;
    await _writePreference(_prefs.setString(_keyDiaryPreviewStyle, normalized));
  }

  /// 保存日记模板偏好；空值移除该键，回到默认（显示建议条、不自动套用）。
  Future<void> setDiaryTemplatePrefsRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      diaryTemplatePrefsRawNotifier.value = null;
      await _writePreference(_prefs.remove(_keyDiaryTemplatePrefs));
      return;
    }
    diaryTemplatePrefsRawNotifier.value = normalized;
    await _writePreference(
      _prefs.setString(_keyDiaryTemplatePrefs, normalized),
    );
  }

  /// 保存功能管理开关；空值移除该键，回到默认（全部功能开启）。
  Future<void> setAppFeaturesRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      appFeaturesRawNotifier.value = null;
      await _writePreference(_prefs.remove(_keyAppFeatures));
      return;
    }
    appFeaturesRawNotifier.value = normalized;
    await _writePreference(_prefs.setString(_keyAppFeatures, normalized));
  }

  /// 保存颜色面板最近用过的自定义颜色；空值移除该键（没有最近颜色）。
  Future<void> setDiaryRecentColorsRaw(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      diaryRecentColorsRawNotifier.value = null;
      await _writePreference(_prefs.remove(_keyDiaryRecentColors));
      return;
    }
    diaryRecentColorsRawNotifier.value = normalized;
    await _writePreference(_prefs.setString(_keyDiaryRecentColors, normalized));
  }

  Future<void> setDiaryCardTagLimit(int value) async {
    final normalized = _normalizeDiaryCardTagLimit(value);
    diaryCardTagLimitNotifier.value = normalized;
    await _writePreference(_prefs.setInt(_keyDiaryCardTagLimit, normalized));
  }

  Future<void> setTagFilterMemoryEnabled(bool enabled) async {
    tagFilterMemoryEnabledNotifier.value = enabled;
    await _writePreference(_prefs.setBool(_keyTagFilterMemoryEnabled, enabled));
    if (!enabled) {
      await clearRememberedTagFilterIds();
    }
  }

  Future<void> setDayPhotoSuggestionsEnabled(bool enabled) async {
    dayPhotoSuggestionsEnabledNotifier.value = enabled;
    await _writePreference(
      _prefs.setBool(_keyDayPhotoSuggestionsEnabled, enabled),
    );
  }

  Future<void> setRememberedTagFilterIdsRaw(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await clearRememberedTagFilterIds();
      return;
    }
    await _writePreference(
      _prefs.setString(_keyRememberedTagFilterIds, normalized),
    );
  }

  Future<void> clearRememberedTagFilterIds() async {
    await _writePreference(_prefs.remove(_keyRememberedTagFilterIds));
  }

  Future<void> setTagOrderRaw(String value) async {
    await _writePreference(_prefs.setString(_keyTagOrder, value));
  }

  Future<void> setTagPickerSortRaw(String value) async {
    await _writePreference(_prefs.setString(_keyTagPickerSort, value));
  }

  /// 只供测试构造“升级前留下旧草稿”的状态；应用内不再写入此键。
  @visibleForTesting
  Future<void> setCreateDiaryDraftRaw(String value) async {
    await _writePreference(_prefs.setString(_keyCreateDiaryDraft, value));
  }

  Future<void> clearCreateDiaryDraft() async {
    await _writePreference(_prefs.remove(_keyCreateDiaryDraft));
  }

  Future<void> setDiaryLocationPrecisionRaw(String value) async {
    await _writePreference(_prefs.setString(_keyDiaryLocationPrecision, value));
  }

  Future<void> setAppUpdatePreferencesRaw(String value) async {
    await _writePreference(_prefs.setString(_keyAppUpdatePreferences, value));
  }

  String get appLocaleCode => _codeFromLocale(localeNotifier.value);
  bool get isAppLockEnabled => appLockEnabledNotifier.value;
  int get themeSeedColorValue => themeSeedColorNotifier.value.toARGB32();
  String get homeTabSwitchCurveTypeValue =>
      homeTabSwitchCurveNotifier.value.storageValue;
  DiaryTypography get diaryTypography => diaryTypographyNotifier.value;
  double get fontScaleValue => fontScaleNotifier.value;

  Future<void> setAppLocale(Locale locale) async {
    await setAppLocaleCode(_codeFromLocale(locale));
  }

  Future<void> setAppLocaleCode(String localeCode) async {
    final normalized = _normalizeLocaleCode(localeCode) ?? 'en';
    final nextLocale = _localeFromCode(normalized);
    localeNotifier.value = nextLocale;
    await _writePreference(_prefs.setString(_keyAppLocaleCode, normalized));
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    appLockEnabledNotifier.value = enabled;
    await _writePreference(_prefs.setBool(_keyAppLockEnabled, enabled));
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

  /// 读取正文排版；没有新键但存在旧版三档预设时迁移一次：写入新键后删除
  /// 旧键，之后旧键不再参与读取，避免两处来源互相覆盖。
  static Future<DiaryTypography> _loadDiaryTypography(
    SharedPreferences prefs,
  ) async {
    if (prefs.containsKey(_keyDiaryTypography)) {
      return DiaryTypography.fromRaw(prefs.getString(_keyDiaryTypography));
    }
    final legacyFontSize = prefs.getString(_keyLegacyEditorBodyFontSizePreset);
    final legacyLineHeight = prefs.getString(
      _keyLegacyEditorBodyLineHeightPreset,
    );
    if (legacyFontSize == null && legacyLineHeight == null) {
      return const DiaryTypography();
    }
    final migrated = DiaryTypography.fromLegacyPresets(
      fontSizePreset: legacyFontSize,
      lineHeightPreset: legacyLineHeight,
    );
    await prefs.setString(_keyDiaryTypography, migrated.toRaw());
    await prefs.remove(_keyLegacyEditorBodyFontSizePreset);
    await prefs.remove(_keyLegacyEditorBodyLineHeightPreset);
    return migrated;
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
    return _moodScoreForWeight(weight);
  }

  /// 批量聚合时一次建立评分表；沿用默认符号别名与自定义符号的覆盖顺序，
  /// 避免为每篇日记重新规范化设置、分配两份映射。
  static Map<String, double> buildMoodScoreMap(List<String> moodOptions) =>
      buildMoodWeightMap(
        moodOptions,
      ).map((mood, weight) => MapEntry(mood, _moodScoreForWeight(weight)));

  static double _moodScoreForWeight(int weight) =>
      1 + ((weight - 1) / (moodOptionCount - 1)) * 4;

  static String moodForWeight(int weight, List<String> moodOptions) {
    final normalized = normalizeMoodOptions(moodOptions);
    final clamped = weight.clamp(1, moodOptionCount).toInt();
    return normalized[clamped - 1];
  }

  static double _normalizeFontScale(double raw) {
    return raw.clamp(minFontScale, maxFontScale).toDouble();
  }

  static int _normalizeDiaryCardTagLimit(int value) {
    return value.clamp(minDiaryCardTagLimit, maxDiaryCardTagLimit).toInt();
  }
}
