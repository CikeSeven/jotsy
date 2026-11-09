// AI 能查看与修改的应用设置（`get_settings` / `change_settings`）：唯一的
// 登记处。每项一个稳定的键（发给模型的参数名，发布后不改）、参数 schema、
// 界面上的名称、读写函数，以及它依附的功能开关与平台。
//
// 读写只经各设置自己的模型与保存函数（`TodoSettings` / `saveTodoSettings`、
// `CalendarDisplayOptions` / `saveCalendarDisplayOptions` 等），每次都在最新
// 的存储值上只改这一项，不覆盖同一个 JSON 键里的其他字段；值按“存储口径”
// 读写（布尔、枚举名、一天中的分钟数、清单 id），撤销时原样写回。
//
// 只收录用户在设置页里点一下就能改、改错了也无伤的开关与选项。以下一律不在
// 这里（只经 `open_page` 给前往按钮）：AI 助手自己的设置（AI 不能改自己的
// 权限、隐私与服务商）、应用锁与密码、备份 / 网盘 / 局域网同步 / 存储、
// 各样式页（选项多、要看着预览调）；主题、语言、字号与功能开关另有专门的
// 工具（`ai_tools_settings.dart`）。新增一项须在 `ai_tools_test` 的设置往返
// 测试里覆盖，并同步使用指南里“AI 能改的设置”。

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/calendar_display_options.dart';
import '../../calendar/providers/calendar_display_options_provider.dart';
import '../../diaries/models/diary_create_prefs.dart';
import '../../diaries/models/diary_preview_style/diary_preview_behavior.dart';
import '../../diaries/models/diary_preview_style/diary_preview_settings.dart';
import '../../diaries/providers/diary_create_prefs_provider.dart';
import '../../diaries/providers/diary_preview_style_provider.dart';
import '../../todos/models/todo_settings.dart';
import '../../todos/models/todo_view.dart';
import '../../todos/providers/todo_providers.dart';
import '../../todos/widgets/todo_labels.dart';

/// 设置所在的页面（卡片上写作“页面 · 设置名”）。
enum AiSettingPage { editor, preview, calendar, todos }

/// 一项 AI 能改的设置。
class AiSettingSpec {
  const AiSettingSpec({
    required this.key,
    required this.page,
    required this.schema,
    required this.name,
    required this.read,
    required this.write,
    this.feature,
    this.onPlatform,
    this.valueText,
    this.check,
  });

  /// 参数名（snake_case，发布后不改）。
  final String key;
  final AiSettingPage page;

  /// 参数 schema（说明写在 schema 的 description 里）。
  final AiSchema schema;

  /// 设置页里的名称。
  final String Function(AppLocalizations l10n) name;

  /// 现在的值（存储口径）。
  final Object? Function(SettingsService settings) read;

  /// 写入 [value]（存储口径）。
  final Future<void> Function(SettingsService settings, Object? value) write;

  /// 依附的功能开关；null 为总是可用。
  final bool Function(AppFeatures features)? feature;

  /// 本平台有没有这项；null 为全平台。
  final bool Function()? onPlatform;

  /// 卡片详情里值的说法（参数原值）；null 走通用格式。
  final String? Function(AppLocalizations l10n, Object? value)? valueText;

  /// schema 之外的校验（写库之前做）：不合规时返回回传模型的说明。
  final String? Function(Object? value)? check;

  bool get onThisPlatform => onPlatform?.call() ?? true;

  bool enabledBy(AppFeatures features) => feature?.call(features) ?? true;

  /// 卡片上的全名：“待办 · 显示已完成”。
  String label(AppLocalizations l10n) => l10n.aiToolSettingName(switch (page) {
    AiSettingPage.editor => l10n.settingsEditor,
    AiSettingPage.preview => l10n.diaryPreviewStyleTitle,
    AiSettingPage.calendar => l10n.navCalendar,
    AiSettingPage.todos => l10n.navTodos,
  }, name(l10n));
}

/// 按键找设置。
AiSettingSpec? aiSettingSpec(String key) =>
    aiSettingSpecs.where((spec) => spec.key == key).firstOrNull;

// ---------------------------------------------------------------------------
// 各存储的读写包装：在最新的存储值上只改这一项。

AiSettingSpec _editorBool(
  String key,
  String description, {
  required String Function(AppLocalizations l10n) name,
  required bool Function(SettingsService settings) get,
  required Future<void> Function(SettingsService settings, bool value) set,
  bool Function()? onPlatform,
}) => AiSettingSpec(
  key: key,
  page: AiSettingPage.editor,
  schema: AiBooleanSchema(description: description),
  name: name,
  read: get,
  write: (settings, value) => set(settings, value! as bool),
  onPlatform: onPlatform,
);

AiSettingSpec _previewBool(
  String key,
  String description, {
  required String Function(AppLocalizations l10n) name,
  required bool Function(DiaryPreviewBehavior behavior) get,
  required DiaryPreviewBehavior Function(DiaryPreviewBehavior b, bool value)
  set,
  bool Function()? onPlatform,
}) {
  DiaryPreviewSettings current(SettingsService settings) =>
      DiaryPreviewSettings.decode(settings.diaryPreviewStyleRawNotifier.value);
  return AiSettingSpec(
    key: key,
    page: AiSettingPage.preview,
    schema: AiBooleanSchema(description: description),
    name: name,
    read: (settings) => get(current(settings).behavior),
    write: (settings, value) {
      final now = current(settings);
      return saveDiaryPreviewSettings(
        settings,
        now.withBehavior(set(now.behavior, value! as bool)),
      );
    },
    onPlatform: onPlatform,
  );
}

AiSettingSpec _calendar(
  String key,
  AiSchema schema, {
  required String Function(AppLocalizations l10n) name,
  required Object Function(CalendarDisplayOptions options) get,
  required CalendarDisplayOptions Function(
    CalendarDisplayOptions options,
    Object value,
  )
  set,
  bool Function(AppFeatures features)? feature,
  String? Function(AppLocalizations l10n, Object? value)? valueText,
}) {
  CalendarDisplayOptions current(SettingsService settings) =>
      CalendarDisplayOptions.decode(
        settings.calendarDisplayOptionsRawNotifier.value,
      );
  return AiSettingSpec(
    key: key,
    page: AiSettingPage.calendar,
    schema: schema,
    name: name,
    read: (settings) => get(current(settings)),
    write: (settings, value) =>
        saveCalendarDisplayOptions(settings, set(current(settings), value!)),
    feature: feature ?? (features) => features.calendar,
    valueText: valueText,
  );
}

AiSettingSpec _todo(
  String key,
  AiSchema schema, {
  required String Function(AppLocalizations l10n) name,
  required Object? Function(TodoSettings settings) get,
  required TodoSettings Function(TodoSettings settings, Object? value) set,
  bool Function()? onPlatform,
  String? Function(AppLocalizations l10n, Object? value)? valueText,
  String? Function(Object? value)? check,
}) {
  TodoSettings current(SettingsService settings) =>
      TodoSettings.decode(settings.todoSettingsRawNotifier.value);
  return AiSettingSpec(
    key: key,
    page: AiSettingPage.todos,
    schema: schema,
    name: name,
    read: (settings) => get(current(settings)),
    write: (settings, value) =>
        saveTodoSettings(settings, set(current(settings), value)),
    feature: (features) => features.todos,
    onPlatform: onPlatform,
    valueText: valueText,
    check: check,
  );
}

/// 农历 / 节假日的显示方式：参数值 ↔ 存储的枚举。
const Map<String, CalendarLunarMode> _almanacModes =
    <String, CalendarLunarMode>{
      'language': CalendarLunarMode.locale,
      'show': CalendarLunarMode.always,
      'hide': CalendarLunarMode.never,
    };

const AiStringSchema _almanacSchema = AiStringSchema(
  enumValues: <String>['language', 'show', 'hide'],
  description: 'language = only when the app is in Chinese.',
);

String? _almanacText(AppLocalizations l10n, Object? value) => switch (value) {
  'language' => l10n.calendarLunarLocale,
  'show' => l10n.calendarLunarAlways,
  'hide' => l10n.calendarLunarNever,
  _ => null,
};

String _modeKey(CalendarLunarMode mode) =>
    _almanacModes.entries.firstWhere((entry) => entry.value == mode).key;

/// 全部 AI 能改的设置；顺序即 schema 里参数的顺序（保持稳定，利于提示缓存）。
final List<AiSettingSpec> aiSettingSpecs = <AiSettingSpec>[
  // 编辑器。
  AiSettingSpec(
    key: 'open_diary_in_editor',
    page: AiSettingPage.editor,
    schema: const AiBooleanSchema(
      description: 'Tapping an entry opens the editor, skipping the preview.',
    ),
    name: (l10n) => l10n.settingsOpenDiaryInEditor,
    read: (settings) => DiaryPreviewSettings.decode(
      settings.diaryPreviewStyleRawNotifier.value,
    ).behavior.openInEditor,
    write: (settings, value) {
      final now = DiaryPreviewSettings.decode(
        settings.diaryPreviewStyleRawNotifier.value,
      );
      return saveDiaryPreviewSettings(
        settings,
        now.withBehavior(now.behavior.copyWith(openInEditor: value! as bool)),
      );
    },
  ),
  AiSettingSpec(
    key: 'publish_on_leave',
    page: AiSettingPage.editor,
    schema: const AiBooleanSchema(
      description:
          'Leaving a new entry publishes it instead of keeping a draft.',
    ),
    name: (l10n) => l10n.settingsPublishOnLeave,
    read: (settings) => DiaryCreatePrefs.decode(
      settings.diaryCreatePrefsRawNotifier.value,
    ).publishOnLeave,
    write: (settings, value) => saveDiaryCreatePrefs(
      settings,
      DiaryCreatePrefs.decode(
        settings.diaryCreatePrefsRawNotifier.value,
      ).copyWith(
        leaveAction: value == true
            ? DiaryCreateLeaveAction.publish
            : DiaryCreateLeaveAction.keepDraft,
      ),
    ),
  ),
  _editorBool(
    'day_photo_suggestions',
    "Writing for an earlier day suggests that day's photos.",
    name: (l10n) => l10n.settingsDayPhotoSuggestions,
    get: (settings) => settings.isDayPhotoSuggestionsEnabled,
    set: (settings, value) => settings.setDayPhotoSuggestionsEnabled(value),
  ),
  _editorBool(
    'toolbar_always_visible',
    'Keep the editor toolbar shown without the on-screen keyboard.',
    name: (l10n) => l10n.settingsToolbarAlwaysVisible,
    get: (settings) => settings.isDiaryToolbarAlwaysVisible,
    set: (settings, value) => settings.setDiaryToolbarAlwaysVisible(value),
    // 桌面没有软键盘，工具栏一直显示（设置页也不显示这个开关）。
    onPlatform: () => !AppPlatform.isDesktop,
  ),
  // 日记预览页。
  _previewBool(
    'preview_swipe_between_entries',
    'Swipe sideways on the preview page to the previous / next entry.',
    name: (l10n) => l10n.diaryPreviewStyleSwipe,
    get: (behavior) => behavior.swipeBetweenDiaries,
    set: (behavior, value) => behavior.copyWith(swipeBetweenDiaries: value),
  ),
  _previewBool(
    'preview_tick_todos',
    'Tick to-do items in the text on the preview page.',
    name: (l10n) => l10n.diaryPreviewStyleTodoToggle,
    get: (behavior) => behavior.todoToggle,
    set: (behavior, value) => behavior.copyWith(todoToggle: value),
  ),
  _previewBool(
    'preview_select_text',
    'Long-press to select text on the preview page.',
    name: (l10n) => l10n.diaryPreviewStyleTextSelection,
    get: (behavior) => behavior.textSelection,
    set: (behavior, value) => behavior.copyWith(textSelection: value),
  ),
  _previewBool(
    'preview_double_tap_to_edit',
    'Double-tap the text on the preview page to edit.',
    name: (l10n) => l10n.diaryPreviewStyleDoubleTapEdit,
    get: (behavior) => behavior.doubleTapToEdit,
    set: (behavior, value) => behavior.copyWith(doubleTapToEdit: value),
    // 桌面双击仍是选词（设置页也只在手机上显示）。
    onPlatform: () => !AppPlatform.isDesktop,
  ),
  // 日历。
  _calendar(
    'calendar_week_start',
    const AiStringSchema(enumValues: <String>['language', 'monday', 'sunday']),
    name: (l10n) => l10n.calendarOptionsWeekStart,
    get: (options) => switch (options.weekStart) {
      CalendarWeekStart.locale => 'language',
      CalendarWeekStart.monday => 'monday',
      CalendarWeekStart.sunday => 'sunday',
    },
    set: (options, value) => options.copyWith(
      weekStart: switch (value) {
        'monday' => CalendarWeekStart.monday,
        'sunday' => CalendarWeekStart.sunday,
        _ => CalendarWeekStart.locale,
      },
    ),
    valueText: (l10n, value) => switch (value) {
      'language' => l10n.calendarWeekStartLocale,
      'monday' => l10n.calendarWeekStartMonday,
      'sunday' => l10n.calendarWeekStartSunday,
      _ => null,
    },
  ),
  _calendar(
    'calendar_highlight_weekends',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarHighlightWeekends,
    get: (options) => options.highlightWeekends,
    set: (options, value) => options.copyWith(highlightWeekends: value as bool),
  ),
  _calendar(
    'calendar_week_numbers',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarShowWeekNumbers,
    get: (options) => options.showWeekNumbers,
    set: (options, value) => options.copyWith(showWeekNumbers: value as bool),
  ),
  _calendar(
    'calendar_lunar',
    _almanacSchema,
    name: (l10n) => l10n.calendarOptionsLunar,
    get: (options) => _modeKey(options.lunarMode),
    set: (options, value) => options.copyWith(lunarMode: _almanacModes[value]),
    valueText: _almanacText,
  ),
  _calendar(
    'calendar_holidays',
    _almanacSchema,
    name: (l10n) => l10n.calendarOptionsHolidays,
    get: (options) => _modeKey(options.holidayMode),
    set: (options, value) =>
        options.copyWith(holidayMode: _almanacModes[value]),
    valueText: _almanacText,
  ),
  _calendar(
    'calendar_month_summary',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarShowMonthSummary,
    get: (options) => options.showMonthSummary,
    set: (options, value) => options.copyWith(showMonthSummary: value as bool),
  ),
  _calendar(
    'calendar_on_this_day',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarShowOnThisDay,
    get: (options) => options.showOnThisDay,
    set: (options, value) => options.copyWith(showOnThisDay: value as bool),
  ),
  _calendar(
    'calendar_day_moods',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarShowDayMoods,
    get: (options) => options.showDayMoods,
    set: (options, value) => options.copyWith(showDayMoods: value as bool),
  ),
  _calendar(
    'calendar_show_todos',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarShowTodos,
    get: (options) => options.showTodos,
    set: (options, value) => options.copyWith(showTodos: value as bool),
    feature: (features) => features.calendar && features.todos,
  ),
  _calendar(
    'calendar_show_anniversaries',
    const AiBooleanSchema(),
    name: (l10n) => l10n.calendarShowAnniversaries,
    get: (options) => options.showAnniversaries,
    set: (options, value) => options.copyWith(showAnniversaries: value as bool),
    feature: (features) => features.anniversariesEnabled,
  ),
  // 待办。
  _todo(
    'todo_show_completed',
    const AiBooleanSchema(
      description: 'Show completed to-dos at the bottom of lists.',
    ),
    name: (l10n) => l10n.todoShowCompleted,
    get: (settings) => settings.showCompleted,
    set: (settings, value) => settings.copyWith(showCompleted: value! as bool),
  ),
  _todo(
    'todo_sort',
    AiStringSchema(enumValues: [for (final m in TodoSortMode.values) m.name]),
    name: (l10n) => l10n.todoSortTitle,
    get: (settings) => settings.sort.name,
    set: (settings, value) =>
        settings.copyWith(sort: TodoSortMode.values.byName(value! as String)),
    valueText: (l10n, value) =>
        switch (TodoSortMode.values.asNameMap()[value]) {
          final mode? => TodoLabels.sortMode(l10n, mode),
          null => null,
        },
  ),
  _todo(
    'todo_default_view',
    AiStringSchema(
      enumValues: [for (final view in TodoSmartView.values) view.name],
      description: 'The view the to-do tab opens on.',
    ),
    name: (l10n) => l10n.todoSettingsDefaultView,
    get: (settings) => settings.defaultViewKey,
    set: (settings, value) =>
        settings.copyWith(defaultViewKey: value! as String),
    valueText: (l10n, value) =>
        switch (TodoSmartView.values.asNameMap()[value]) {
          final view? => TodoLabels.smartView(l10n, view),
          null => null,
        },
  ),
  // 默认清单：参数是清单名称（"" 为收集箱），存储的是清单 id；名称与 id 的
  // 换算在 `change_settings` / `get_settings` 里（要读库）。
  _todo(
    aiDefaultTodoListKey,
    const AiStringSchema(
      allowEmpty: true,
      description: 'List name new to-dos go to ("" = inbox).',
    ),
    name: (l10n) => l10n.todoSettingsDefaultList,
    get: (settings) => settings.defaultListId,
    set: (settings, value) => value is String
        ? settings.copyWith(defaultListId: value)
        : settings.copyWith(clearDefaultList: true),
    valueText: (l10n, value) => value == '' ? l10n.todoViewInbox : null,
  ),
  _todo(
    'todo_smart_parse',
    const AiBooleanSchema(
      description:
          'Recognize dates, times, #list and ! priority when typing a '
          'new to-do.',
    ),
    name: (l10n) => l10n.todoSettingsSmartParse,
    get: (settings) => settings.smartParse,
    set: (settings, value) => settings.copyWith(smartParse: value! as bool),
  ),
  _todo(
    'todo_all_day_reminder_time',
    const AiTimeSchema(
      description: 'Default reminder time for all-day to-dos, HH:MM.',
    ),
    name: (l10n) => l10n.todoSettingsAllDayTime,
    get: (settings) => settings.allDayReminderMinute,
    set: (settings, value) =>
        settings.copyWith(allDayReminderMinute: value! as int),
    onPlatform: () => AppPlatform.supportsReminders,
  ),
  _todo(
    'todo_snooze_minutes',
    AiIntegerSchema(
      minimum: TodoSettings.snoozeChoices.first,
      maximum: TodoSettings.snoozeChoices.last,
      description:
          'Snooze length on reminders: '
          '${TodoSettings.snoozeChoices.join(', ')}.',
    ),
    name: (l10n) => l10n.todoSettingsSnooze,
    get: (settings) => settings.snoozeMinutes,
    set: (settings, value) => settings.copyWith(snoozeMinutes: value! as int),
    check: (value) => TodoSettings.snoozeChoices.contains(value)
        ? null
        : '`todo_snooze_minutes` must be one of '
              '${TodoSettings.snoozeChoices.join(', ')}.',
    onPlatform: () => AppPlatform.supportsReminders,
    valueText: (l10n, value) =>
        value is int ? l10n.todoSettingsSnoozeMinutes(value) : null,
  ),
  _todo(
    'todo_hide_on_lock_screen',
    const AiBooleanSchema(
      description: 'Reminders on the lock screen hide the to-do text.',
    ),
    name: (l10n) => l10n.todoSettingsHideContent,
    get: (settings) => settings.hideContentOnLockScreen,
    set: (settings, value) =>
        settings.copyWith(hideContentOnLockScreen: value! as bool),
    onPlatform: () => AppPlatform.supportsNotificationVisibility,
  ),
];

/// 默认清单这一项的键（名称与 id 要换算）。
const String aiDefaultTodoListKey = 'todo_default_list';
