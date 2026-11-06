// 应用密码的摘要：PBKDF2-HMAC-SHA256（package:cryptography 的纯 Dart 实现）。
//
// - 输入：明文密码；输出：`AppPasswordSecret`（摘要、随机盐、迭代次数），或
//   某个明文与已存摘要是否一致；无副作用。
// - 为什么是 PBKDF2 + 每台设备随机盐：摘要存在 SharedPreferences 里，拿到这份
//   文件的人只能逐个猜，不能查表；迭代次数让每猜一次都要付出几百毫秒。
// - 迭代次数取 6 万：桌面 AOT 约 180ms，中端手机约 0.5s。解锁时按钮里转圈，
//   不会长到让人以为卡住。次数随摘要保存，以后调高只影响新设的密码。
// - 计算放进 `Isolate.run`，不卡 UI 线程（解锁遮罩上的指示器照常转）。测试里
//   `useIsolate: false` 并调低次数，避免在 testWidgets 的假时钟里等后台 isolate。

import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/dart.dart';

import 'app_password_config.dart';

class AppPasswordHasher {
  const AppPasswordHasher({
    this.iterations = defaultIterations,
    this.useIsolate = true,
  });

  static const int defaultIterations = 60000;
  static const int saltBytes = 16;
  static const int hashBits = 256;

  /// 新设密码时使用的迭代次数。
  final int iterations;

  /// 是否在后台 isolate 里计算。
  final bool useIsolate;

  /// 为新密码生成随机盐并计算摘要。
  Future<AppPasswordSecret> create(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(saltBytes, (_) => random.nextInt(256));
    final hash = await _run(password, salt, iterations);
    return AppPasswordSecret(hash: hash, salt: salt, iterations: iterations);
  }

  /// [password] 是否与 [secret] 一致。按已存的盐与迭代次数重新计算，常数时间
  /// 比较（不因前几个字节不同就提前返回）。
  Future<bool> matches(String password, AppPasswordSecret secret) async {
    final hash = await _run(password, secret.salt, secret.iterations);
    if (hash.length != secret.hash.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < hash.length; i++) {
      diff |= hash[i] ^ secret.hash[i];
    }
    return diff == 0;
  }

  Future<List<int>> _run(String password, List<int> salt, int iterations) {
    if (!useIsolate) {
      return _derive(password, salt, iterations);
    }
    return Isolate.run(() => _derive(password, salt, iterations));
  }

  static Future<List<int>> _derive(
    String password,
    List<int> salt,
    int iterations,
  ) async {
    final algorithm = DartPbkdf2(
      macAlgorithm: DartHmac.sha256(),
      iterations: iterations,
      bits: hashBits,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return key.extractBytes();
  }
}
