import 'package:flutter/foundation.dart';

/// 专注计时的节奏：专注多久、短休 / 长休多久、几轮专注后长休一次。
///
/// 存在待办偏好 `app.settings.todos` 的 `focus` 对象里（随备份、随“同步
/// 设置”），逐字段容错：不在可选值里的回到默认。全部为默认值时不写出。
@immutable
class TodoFocusSettings {
  const TodoFocusSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakEvery = 4,
  });

  static const TodoFocusSettings defaults = TodoFocusSettings();

  static const List<int> focusChoices = <int>[15, 20, 25, 30, 45, 50, 60, 90];
  static const List<int> shortBreakChoices = <int>[3, 5, 10, 15];
  static const List<int> longBreakChoices = <int>[10, 15, 20, 30];
  static const List<int> longBreakEveryChoices = <int>[2, 3, 4, 5, 6];

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  /// 每专注几轮后长休一次。
  final int longBreakEvery;

  static const _keyFocus = 'focusMinutes';
  static const _keyShort = 'shortBreakMinutes';
  static const _keyLong = 'longBreakMinutes';
  static const _keyEvery = 'longBreakEvery';

  static TodoFocusSettings fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    int read(String key, List<int> choices, int fallback) {
      final value = raw[key];
      return value is int && choices.contains(value) ? value : fallback;
    }

    return TodoFocusSettings(
      focusMinutes: read(_keyFocus, focusChoices, defaults.focusMinutes),
      shortBreakMinutes: read(
        _keyShort,
        shortBreakChoices,
        defaults.shortBreakMinutes,
      ),
      longBreakMinutes: read(
        _keyLong,
        longBreakChoices,
        defaults.longBreakMinutes,
      ),
      longBreakEvery: read(
        _keyEvery,
        longBreakEveryChoices,
        defaults.longBreakEvery,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    _keyFocus: focusMinutes,
    _keyShort: shortBreakMinutes,
    _keyLong: longBreakMinutes,
    _keyEvery: longBreakEvery,
  };

  TodoFocusSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakEvery,
  }) => TodoFocusSettings(
    focusMinutes: focusMinutes ?? this.focusMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    longBreakEvery: longBreakEvery ?? this.longBreakEvery,
  );

  @override
  bool operator ==(Object other) =>
      other is TodoFocusSettings &&
      other.focusMinutes == focusMinutes &&
      other.shortBreakMinutes == shortBreakMinutes &&
      other.longBreakMinutes == longBreakMinutes &&
      other.longBreakEvery == longBreakEvery;

  @override
  int get hashCode => Object.hash(
    focusMinutes,
    shortBreakMinutes,
    longBreakMinutes,
    longBreakEvery,
  );
}
