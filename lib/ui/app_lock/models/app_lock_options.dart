// 应用锁的上锁时机与隐私选项（设置 → 应用锁与密码，docs/rules/app_lock.md）。
//
// 存储：单个 JSON 设置键 `app.settings.app_lock_options`（经
// `SettingsService.setAppLockOptionsRaw`），逐字段容错解析。本机偏好：熄屏、
// 闲置与防截屏都是按平台提供的能力，上锁有多严也是这台设备自己的安全设置，
// 所以不随备份导出、不参与局域网同步（应用锁开关 `appLockEnabled` 仍随备份）。
//
// 冷启动总是上锁（应用锁开着时），这里的选项只增加“运行中”的上锁时机：
// - [AppLockOptions.afterLeaving]：离开应用（切到其他应用、回到桌面、窗口
//   最小化）多久后再回来需要验证；
// - [AppLockOptions.onScreenOff]：手机熄屏 / 锁屏后回来需要验证（Android）；
// - [AppLockOptions.whenIdle]：窗口开着但多久没有操作就上锁（桌面）；
// 以及：
// - [AppLockOptions.autoPrompt]：锁屏出现时自动弹出系统验证或指纹；
// - [AppLockOptions.secureScreen]：防截屏（Android，与应用锁开关无关）。

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 离开应用多久后重新上锁。按从严到宽排列（[index] 越大越宽松）。
enum AppLockAfterLeaving {
  immediately(Duration.zero),
  minutes1(Duration(minutes: 1)),
  minutes5(Duration(minutes: 5)),
  minutes15(Duration(minutes: 15)),
  minutes30(Duration(minutes: 30)),
  hour1(Duration(hours: 1)),

  /// 运行中不因离开而上锁，只在重新打开应用时（改版前的行为，默认）。
  never(null);

  const AppLockAfterLeaving(this.after);

  /// 离开多久后上锁；[never] 为 null。
  final Duration? after;

  static AppLockAfterLeaving? fromName(Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// 闲置多久后上锁（桌面）。按从严到宽排列，[off] 最宽松。
enum AppLockWhenIdle {
  minutes1(Duration(minutes: 1)),
  minutes5(Duration(minutes: 5)),
  minutes15(Duration(minutes: 15)),
  minutes30(Duration(minutes: 30)),
  off(null);

  const AppLockWhenIdle(this.after);

  final Duration? after;

  static AppLockWhenIdle? fromName(Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

@immutable
class AppLockOptions {
  const AppLockOptions({
    this.afterLeaving = AppLockAfterLeaving.never,
    this.onScreenOff = false,
    this.whenIdle = AppLockWhenIdle.off,
    this.autoPrompt = true,
    this.secureScreen = false,
  });

  /// 默认：只在打开应用时上锁、自动弹出验证、不防截屏（与改版前一致）。
  static const AppLockOptions defaults = AppLockOptions();

  final AppLockAfterLeaving afterLeaving;
  final bool onScreenOff;
  final AppLockWhenIdle whenIdle;

  /// 锁屏出现时自动弹出系统验证（系统验证方式）或指纹 / 面容（应用密码方式，
  /// 开着快捷解锁时）。关掉后停在锁屏上，由用户点“立即解锁”或直接输密码。
  final bool autoPrompt;

  final bool secureScreen;

  static const _keyAfterLeaving = 'afterLeaving';
  static const _keyOnScreenOff = 'onScreenOff';
  static const _keyWhenIdle = 'whenIdle';
  static const _keyAutoPrompt = 'autoPrompt';
  static const _keySecureScreen = 'secureScreen';

  /// 解析设置原文。空值、坏 JSON 或不是对象时回到 [defaults]；每个字段单独
  /// 读取，类型不对或认不出的取值只让这一项回到默认。
  static AppLockOptions decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map) return defaults;
    final map = decoded;
    bool readBool(String key, bool fallback) {
      final value = map[key];
      return value is bool ? value : fallback;
    }

    return AppLockOptions(
      afterLeaving:
          AppLockAfterLeaving.fromName(map[_keyAfterLeaving]) ??
          defaults.afterLeaving,
      onScreenOff: readBool(_keyOnScreenOff, defaults.onScreenOff),
      whenIdle:
          AppLockWhenIdle.fromName(map[_keyWhenIdle]) ?? defaults.whenIdle,
      autoPrompt: readBool(_keyAutoPrompt, defaults.autoPrompt),
      secureScreen: readBool(_keySecureScreen, defaults.secureScreen),
    );
  }

  String encode() => jsonEncode(<String, Object>{
    _keyAfterLeaving: afterLeaving.name,
    _keyOnScreenOff: onScreenOff,
    _keyWhenIdle: whenIdle.name,
    _keyAutoPrompt: autoPrompt,
    _keySecureScreen: secureScreen,
  });

  /// 从这份改成 [next] 是否放宽了保护：离开后更晚上锁、关掉锁屏上锁、闲置
  /// 更久才锁或不再按闲置上锁、关掉防截屏。应用锁开着时这类改动要先验证
  /// （与关闭应用锁同一口径）；收紧与“自动弹出验证”不用。
  bool loosenedBy(AppLockOptions next) =>
      next.afterLeaving.index > afterLeaving.index ||
      (onScreenOff && !next.onScreenOff) ||
      next.whenIdle.index > whenIdle.index ||
      (secureScreen && !next.secureScreen);

  AppLockOptions copyWith({
    AppLockAfterLeaving? afterLeaving,
    bool? onScreenOff,
    AppLockWhenIdle? whenIdle,
    bool? autoPrompt,
    bool? secureScreen,
  }) {
    return AppLockOptions(
      afterLeaving: afterLeaving ?? this.afterLeaving,
      onScreenOff: onScreenOff ?? this.onScreenOff,
      whenIdle: whenIdle ?? this.whenIdle,
      autoPrompt: autoPrompt ?? this.autoPrompt,
      secureScreen: secureScreen ?? this.secureScreen,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppLockOptions &&
      other.afterLeaving == afterLeaving &&
      other.onScreenOff == onScreenOff &&
      other.whenIdle == whenIdle &&
      other.autoPrompt == autoPrompt &&
      other.secureScreen == secureScreen;

  @override
  int get hashCode => Object.hash(
    afterLeaving,
    onScreenOff,
    whenIdle,
    autoPrompt,
    secureScreen,
  );
}
