// 应用密码的本机配置（docs/rules/app_lock.md）。纯数据，无副作用。
//
// 存储：单个 JSON 键 `app.security.passcode`（见 `AppPasscodeStore`），只在
// 本机：不随备份导出，也不参与局域网同步——密码是这台设备的安全设置，换到
// 另一台设备上应当由那台设备的主人自己设定。
//
// 验证方式不单独存一个字段：存着有效的密码摘要即为“应用密码”，没有即为
// “系统验证”。这样不会出现“方式是应用密码却没有密码”的状态（那会让应用锁
// 与上锁日记本打不开），清除密码就是切回系统验证。
//
// 应用密码有两种形式（[AppPasscodeKind]）：4 / 6 位数字，或 3×3 图案。形式
// 与数字位数明文保存——解锁界面要据此画出圆点个数或九宫格，这只透露“密码
// 有几位”，与系统锁屏一样。

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 验证身份的方式：系统验证（指纹、面容或锁屏密码）或应用自己的密码。
enum AppVerificationMethod { system, passcode }

/// 应用密码的形式。
enum AppPasscodeKind {
  /// 4 或 6 位数字，在应用内的数字键盘上输入。
  pin,

  /// 3×3 九宫格图案，至少连 [AppPasscodeRules.patternMinNodes] 个点。
  pattern,
}

/// 密码摘要：PBKDF2-HMAC-SHA256 的派生结果与参数（见 `AppPasscodeHasher`）。
@immutable
class AppPasscodeSecret {
  const AppPasscodeSecret({
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
      other is AppPasscodeSecret &&
      listEquals(other.hash, hash) &&
      listEquals(other.salt, salt) &&
      other.iterations == iterations;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(hash), Object.hashAll(salt), iterations);
}

/// 两种形式的输入规则与串化。
///
/// 输入一律串化成字符串再计算摘要：数字为数字本身（“0428”），图案为经过的
/// 格子序号（0–8，行优先）以“-”连接（“0-4-8-5”）。摘要的原文再带上形式前缀
/// （[material]），同一串字符在两种形式下得到不同的摘要。
abstract final class AppPasscodeRules {
  /// 可选的数字位数，第一个为默认。
  static const List<int> pinLengths = <int>[6, 4];

  /// 图案至少连几个点（与系统图案锁一致）。
  static const int patternMinNodes = 4;

  /// 九宫格的格子数。
  static const int patternNodeCount = 9;

  static bool validPinLength(int length) => pinLengths.contains(length);

  /// [value] 是否为一串 [length] 位的数字。
  static bool validPin(String value, int length) =>
      validPinLength(length) &&
      value.length == length &&
      value.codeUnits.every((int c) => c >= 0x30 && c <= 0x39);

  /// 图案的格子序号：不重复、都在 0–8、至少 [patternMinNodes] 个。
  static bool validPattern(List<int> nodes) =>
      nodes.length >= patternMinNodes &&
      nodes.toSet().length == nodes.length &&
      nodes.every((int n) => n >= 0 && n < patternNodeCount);

  static String encodePattern(List<int> nodes) => nodes.join('-');

  /// 计算摘要用的原文。
  static String material(AppPasscodeKind kind, String value) =>
      '${kind.name}:$value';
}

/// 输错限流：前几次不用等，之后每次输错都要等待，越来越久。
///
/// 次数与等待时间都记在配置里，杀掉进程重开不会清零；输对（或指纹 / 面容
/// 验证通过）后清零。
abstract final class AppPasscodeLockout {
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
class AppPasscodeConfig {
  const AppPasscodeConfig({
    this.secret,
    this.kind = AppPasscodeKind.pin,
    this.pinLength = 6,
    this.biometric = false,
    this.failedCount = 0,
    this.lockedUntil,
  });

  /// 没设过密码：系统验证。
  static const AppPasscodeConfig initial = AppPasscodeConfig();

  /// 密码摘要；null 表示没有设置应用密码（即系统验证）。
  final AppPasscodeSecret? secret;

  final AppPasscodeKind kind;

  /// 数字密码的位数（4 或 6）；图案时无意义。
  final int pinLength;

  /// 应用密码之外是否允许用指纹 / 面容快捷解锁（只认生物识别，不回落到
  /// 系统锁屏密码）。设备或平台不支持时即使为 true 也不出现。
  final bool biometric;

  /// 连续输错的次数（输对后清零）。
  final int failedCount;

  /// 输错太多次后，在这个时刻之前不再接受输入。
  final DateTime? lockedUntil;

  bool get hasPasscode => secret != null;

  AppVerificationMethod get method => hasPasscode
      ? AppVerificationMethod.passcode
      : AppVerificationMethod.system;

  AppPasscodeConfig copyWith({
    bool? biometric,
    int? failedCount,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return AppPasscodeConfig(
      secret: secret,
      kind: kind,
      pinLength: pinLength,
      biometric: biometric ?? this.biometric,
      failedCount: failedCount ?? this.failedCount,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    );
  }

  /// 逐字段容错解析：摘要或形式无效即视为没有密码（回到系统验证，而不是
  /// 画出一个对不上的输入界面），其余字段无效时取默认值。
  static AppPasscodeConfig decode(String? raw) {
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
    final kind = switch (decoded['kind']) {
      'pin' => AppPasscodeKind.pin,
      'pattern' => AppPasscodeKind.pattern,
      _ => null,
    };
    final length = decoded['length'];
    if (secret == null || kind == null) {
      return initial;
    }
    if (kind == AppPasscodeKind.pin &&
        (length is! int || !AppPasscodeRules.validPinLength(length))) {
      return initial;
    }
    final biometric = decoded['biometric'];
    final failed = decoded['failed'];
    final lockedUntil = decoded['lockedUntil'];
    return AppPasscodeConfig(
      secret: secret,
      kind: kind,
      pinLength: kind == AppPasscodeKind.pin ? length as int : 6,
      biometric: biometric is bool && biometric,
      failedCount: failed is int && failed > 0 ? failed : 0,
      lockedUntil: lockedUntil is int && lockedUntil > 0
          ? DateTime.fromMillisecondsSinceEpoch(lockedUntil)
          : null,
    );
  }

  static AppPasscodeSecret? _decodeSecret(Map<dynamic, dynamic> node) {
    final hash = _decodeBytes(node['hash']);
    final salt = _decodeBytes(node['salt']);
    final iterations = node['iter'];
    if (hash == null || salt == null || iterations is! int || iterations < 1) {
      return null;
    }
    return AppPasscodeSecret(hash: hash, salt: salt, iterations: iterations);
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
      'kind': kind.name,
      if (kind == AppPasscodeKind.pin) 'length': pinLength,
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
      other is AppPasscodeConfig &&
      other.secret == secret &&
      other.kind == kind &&
      other.pinLength == pinLength &&
      other.biometric == biometric &&
      other.failedCount == failedCount &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode =>
      Object.hash(secret, kind, pinLength, biometric, failedCount, lockedUntil);
}
