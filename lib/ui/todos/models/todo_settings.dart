import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'todo_view.dart';

/// 清单与智能视图里待办的排序方式。枚举名即持久化值。
enum TodoSortMode {
  /// 拖动顺序（新建的在前）；日期分组的视图里按截止时刻。只有这种排序下
  /// 收集箱与清单能拖动。
  manual,

  /// 截止日期近的在前，没有日期的在最后。
  due,

  /// 优先级高的在前，同级按截止日期与时刻（默认）。
  priority,

  /// 新建的在前。
  created,
}

/// 手机上往行首方向滑（LTR 为左滑）一行待办做什么。枚举名即持久化值。
enum TodoSwipeAction {
  /// 删除（可撤销，默认）。
  delete,

  /// 改期：弹出截止日面板，这一行弹回原位。
  reschedule,
}

/// 待办的偏好。
///
/// 存储：单个 JSON 设置键 `app.settings.todos`（经
/// `SettingsService.setTodoSettingsRaw`），逐字段容错解析，随完整备份导出、
/// 导入失败时随设置快照回滚；局域网同步只在两端都开启“同步设置”时同步。
/// 全部为默认值时移除该键。
///
/// 排序默认为优先级（#256）。排序存在字段 `sortMode`；旧版本存在 `sort`，
/// 且旧版 [encode] 只要有一项不是默认值就把所有字段一起写出，`sort: manual`
/// 分不清是用户选的还是顺带写出的旧默认值。所以读旧字段时只认主动选过的
/// `due / priority / created`，`manual` 当作没选、落到新默认值；之后再选
/// “手动”写进 `sortMode`，会被记住。备份导入与局域网同步来的旧设置同样经此
/// 兼容。
@immutable
class TodoSettings {
  const TodoSettings({
    this.showCompleted = true,
    this.defaultListId,
    this.sort = TodoSortMode.priority,
    this.defaultViewKey = 'today',
    this.allDayReminderMinute = 9 * 60,
    this.snoozeMinutes = 10,
    this.hideContentOnLockScreen = false,
    this.smartParse = true,
    this.swipeLeft = TodoSwipeAction.delete,
  });

  static const TodoSettings defaults = TodoSettings();

  /// 稍后提醒可选的时长（分钟）。
  static const List<int> snoozeChoices = <int>[5, 10, 15, 30, 60];

  /// 清单与收集箱底部是否显示已完成的待办。
  final bool showCompleted;

  /// 在智能视图里新建的待办默认放进哪个清单；null 为收集箱。清单被删掉后
  /// 读取方按收集箱处理。
  final String? defaultListId;

  final TodoSortMode sort;

  /// 打开待办页时停在哪个视图（[TodoView.key]）。
  final String defaultViewKey;

  /// 全天待办“当天提醒”默认的时刻（一天中的分钟数）。
  final int allDayReminderMinute;

  /// 通知上“稍后提醒”的时长（分钟）。
  final int snoozeMinutes;

  /// 锁屏上的提醒只写“你有一个待办”，不写内容。
  final bool hideContentOnLockScreen;

  /// 新建待办时从输入里识别日期、时刻、`#清单` 与 `!` 优先级（见
  /// `parseTodoQuickInput`）。
  final bool smartParse;

  /// 左滑（RTL 为右滑）一行待办的动作。
  final TodoSwipeAction swipeLeft;

  /// 打开时显示的视图；认不出（含清单已删）时由调用方回到“今天”。
  TodoView get defaultView => TodoView.parse(defaultViewKey) ?? TodoView.today;

  static const _keyShowCompleted = 'showCompleted';
  static const _keyDefaultList = 'defaultList';
  static const _keySort = 'sortMode';

  /// 旧版本的排序字段，只读不写（见类注释）。
  static const _keyLegacySort = 'sort';
  static const _keyDefaultView = 'defaultView';
  static const _keyAllDayReminder = 'allDayReminderMinute';
  static const _keySnooze = 'snoozeMinutes';
  static const _keyHideContent = 'hideContentOnLockScreen';
  static const _keySmartParse = 'smartParse';
  static const _keySwipeLeft = 'swipeLeft';

  static TodoSettings decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    final map = node;
    final minute = map[_keyAllDayReminder];
    final snooze = map[_keySnooze];
    final list = map[_keyDefaultList];
    final view = map[_keyDefaultView];
    return TodoSettings(
      showCompleted: map[_keyShowCompleted] is bool
          ? map[_keyShowCompleted] as bool
          : defaults.showCompleted,
      defaultListId: list is String && list.isNotEmpty ? list : null,
      sort: _decodeSort(map),
      defaultViewKey: view is String && TodoView.parse(view) != null
          ? view
          : defaults.defaultViewKey,
      allDayReminderMinute: minute is int && minute >= 0 && minute < 24 * 60
          ? minute
          : defaults.allDayReminderMinute,
      snoozeMinutes: snooze is int && snoozeChoices.contains(snooze)
          ? snooze
          : defaults.snoozeMinutes,
      hideContentOnLockScreen: map[_keyHideContent] is bool
          ? map[_keyHideContent] as bool
          : defaults.hideContentOnLockScreen,
      smartParse: map[_keySmartParse] is bool
          ? map[_keySmartParse] as bool
          : defaults.smartParse,
      swipeLeft:
          TodoSwipeAction.values.asNameMap()[map[_keySwipeLeft]] ??
          defaults.swipeLeft,
    );
  }

  /// 排序：新字段认得出就用它；否则旧字段里主动选过的（非 `manual`）；都
  /// 没有时为默认。
  static TodoSortMode _decodeSort(Map<Object?, Object?> map) {
    final modes = TodoSortMode.values.asNameMap();
    final current = modes[map[_keySort]];
    if (current != null) return current;
    final legacy = modes[map[_keyLegacySort]];
    if (legacy != null && legacy != TodoSortMode.manual) return legacy;
    return defaults.sort;
  }

  /// 编码；全部为默认值时为 null（移除设置键）。
  String? encode() {
    if (this == defaults) return null;
    return jsonEncode(<String, Object?>{
      _keyShowCompleted: showCompleted,
      if (defaultListId != null) _keyDefaultList: defaultListId,
      _keySort: sort.name,
      _keyDefaultView: defaultViewKey,
      _keyAllDayReminder: allDayReminderMinute,
      _keySnooze: snoozeMinutes,
      _keyHideContent: hideContentOnLockScreen,
      _keySmartParse: smartParse,
      _keySwipeLeft: swipeLeft.name,
    });
  }

  TodoSettings copyWith({
    bool? showCompleted,
    String? defaultListId,
    bool clearDefaultList = false,
    TodoSortMode? sort,
    String? defaultViewKey,
    int? allDayReminderMinute,
    int? snoozeMinutes,
    bool? hideContentOnLockScreen,
    bool? smartParse,
    TodoSwipeAction? swipeLeft,
  }) {
    return TodoSettings(
      showCompleted: showCompleted ?? this.showCompleted,
      defaultListId: clearDefaultList
          ? null
          : (defaultListId ?? this.defaultListId),
      sort: sort ?? this.sort,
      defaultViewKey: defaultViewKey ?? this.defaultViewKey,
      allDayReminderMinute: allDayReminderMinute ?? this.allDayReminderMinute,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      hideContentOnLockScreen:
          hideContentOnLockScreen ?? this.hideContentOnLockScreen,
      smartParse: smartParse ?? this.smartParse,
      swipeLeft: swipeLeft ?? this.swipeLeft,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoSettings &&
      other.showCompleted == showCompleted &&
      other.defaultListId == defaultListId &&
      other.sort == sort &&
      other.defaultViewKey == defaultViewKey &&
      other.allDayReminderMinute == allDayReminderMinute &&
      other.snoozeMinutes == snoozeMinutes &&
      other.hideContentOnLockScreen == hideContentOnLockScreen &&
      other.smartParse == smartParse &&
      other.swipeLeft == swipeLeft;

  @override
  int get hashCode => Object.hash(
    showCompleted,
    defaultListId,
    sort,
    defaultViewKey,
    allDayReminderMinute,
    snoozeMinutes,
    hideContentOnLockScreen,
    smartParse,
    swipeLeft,
  );
}
