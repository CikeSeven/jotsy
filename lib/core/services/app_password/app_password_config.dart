// 应用密码的本机配置（docs/rules/app_lock.md）。纯数据，无副作用。
//
// 存储：单个 JSON 键 `app.security.app_password`（见 `AppPasswordStore`），
// 只在本机：不随备份导出，也不参与局域网同步——密码是这台设备的安全设置，
// 换到另一台设备上应当由那台设备的主人自己设定。
//
// 验证方式不单独存一个字段：存着有效的密码摘要即为“应用密码”，没有即为
// “系统验证”。这样不会出现“方式是应用密码却没有密码”的状态（那会让应用锁
// 与上锁日记本打不开），清除密码就是切回系统验证。

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 验证身份的方式：系统验证（指纹、面容或锁屏密码）或应用自己的密码。
enum AppVerificationMethod { system, password }

/// 密码摘要：PBKDF2-HMAC-SHA256 的派生结果与参数（见 `AppPasswordHasher`）。
@immutable
class AppPasswordSecret {
  const AppPasswordSecret({
    required this.hash,
    required this.salt,
    required this.iterations,
  });

  final List<int> hash;
  final List<int> salt;

  /// 派生时的迭代次数；随记录保存，以后提高默认值时旧密码照样能验证。
  final int iterations;

  @override
  bool operator ==(Object other) =>
      other is AppPasswordSecret &&
      listEquals(other.hash, hash) &&
      listEquals(other.salt, salt) &&
      other.iterations == iterations;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(hash), Object.hashAll(salt), iterations);
}

/// 密码规则不满足的原因。
enum AppPasswordProblem { tooShort, tooLong, whitespace }

/// 应用密码的长度与字符规则：4–16 个字符、区分大小写、不含空白。
abstract final class AppPasswordRules {
  static const int minLength = 4;
  static const int maxLength = 16;

  static final RegExp _whitespace = RegExp(r'\s');

  /// 按字符（Unicode 码点）计长度；满足规则时返回 null。
  static AppPasswordProblem? check(String password) {
    if (_whitespace.hasMatch(password)) {
      return AppPasswordProblem.whitespace;
    }
    final length = password.runes.length;
    if (length < minLength) {
      return AppPasswordProblem.tooShort;
    }
    if (length > maxLength) {
      return AppPasswordProblem.tooLong;
    }
    return null;
  }
}

/// 输错限流：前几次不用等，之后每次输错都要等待，越来越久。
///
/// 次数与等待时间都记在配置里，杀掉进程重开不会清零；输对（或指纹 / 面容
/// 验证通过）后清零。
abstract final class AppPasswordLockout {
  /// 第几次输错开始要等待。
  static const int firstLockedAttempt = 5;

  /// 第 [failedCount] 次输错之后要等多久；null 为不用等。
  static Duration? durationAfter(int failedCount) {
    if (failedCount < firstLockedAttempt) {
      return null;
    }
    return switch (failedCount - firstLockedAttempt) {
      0 => const Duration(seconds: 30),
      1 => const Duration(minutes: 1),
      2 => const Duration(minutes: 5),
      _ => const Duration(minutes: 15),
    };
  }

  /// 已经输错 [failedCount] 次，还能再试几次才开始等待（已在等待档位时为 0）。
  static int attemptsBeforeLockout(int failedCount) =>
      failedCount >= firstLockedAttempt ? 0 : firstLockedAttempt - failedCount;
}

/// 应用密码的本机配置。
@immutable
class AppPasswordConfig {
  const AppPasswordConfig({
    this.secret,
    this.biometric = false,
    this.failedCount = 0,
    this.lockedUntil,
  });

  /// 没设过密码：系统验证。
  static const AppPasswordConfig initial = AppPasswordConfig();

  /// 密码摘要；null 表示没有设置应用密码（即系统验证）。
  final AppPasswordSecret? secret;

  /// 应用密码之外是否允许用指纹 / 面容快捷解锁（只认生物识别，不回落到
  /// 系统锁屏密码）。设备或平台不支持时即使为 true 也不出现。
  final bool biometric;

  /// 连续输错的次数（输对后清零）。
  final int failedCount;

  /// 输错太多次后，在这个时刻之前不再接受输入。
  final DateTime? lockedUntil;

  bool get hasPassword => secret != null;

  AppVerificationMethod get method => hasPassword
      ? AppVerificationMethod.password
      : AppVerificationMethod.system;

  AppPasswordConfig copyWith({
    bool? biometric,
    int? failedCount,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return AppPasswordConfig(
      secret: secret,
      biometric: biometric ?? this.biometric,
      failedCount: failedCount ?? this.failedCount,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    );
  }

  /// 逐字段容错解析：摘要任一部分无效即视为没有密码（回到系统验证），
  /// 其余字段无效时取默认值。
  static AppPasswordConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return initial;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return initial;
    }
    if (decoded is! Map) {
      return initial;
    }
    final secret = _decodeSecret(decoded);
    if (secret == null) {
      return initial;
    }
    final biometric = decoded['biometric'];
    final failed = decoded['failed'];
    final lockedUntil = decoded['lockedUntil'];
    return AppPasswordConfig(
      secret: secret,
      biometric: biometric is bool && biometric,
      failedCount: failed is int && failed > 0 ? failed : 0,
      lockedUntil: lockedUntil is int && lockedUntil > 0
          ? DateTime.fromMillisecondsSinceEpoch(lockedUntil)
          : null,
    );
  }

  static AppPasswordSecret? _decodeSecret(Map<dynamic, dynamic> node) {
    final hash = _decodeBytes(node['hash']);
    final salt = _decodeBytes(node['salt']);
    final iterations = node['iter'];
    if (hash == null || salt == null || iterations is! int || iterations < 1) {
      return null;
    }
    return AppPasswordSecret(hash: hash, salt: salt, iterations: iterations);
  }

  static List<int>? _decodeBytes(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  /// 没有密码时返回 null（调用方删除这个键）。
  String? encode() {
    final secret = this.secret;
    if (secret == null) {
      return null;
    }
    return jsonEncode(<String, Object?>{
      'v': 1,
      'hash': base64Encode(secret.hash),
      'salt': base64Encode(secret.salt),
      'iter': secret.iterations,
      'biometric': biometric,
      if (failedCount > 0) 'failed': failedCount,
      if (lockedUntil != null)
        'lockedUntil': lockedUntil!.millisecondsSinceEpoch,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is AppPasswordConfig &&
      other.secret == secret &&
      other.biometric == biometric &&
      other.failedCount == failedCount &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(secret, biometric, failedCount, lockedUntil);
}
