// 应用密码的本机存储（docs/rules/app_lock.md）。
//
// - 输入：SharedPreferences、摘要计算器 [AppPasswordHasher]、时钟；
// - 输出：[configNotifier]（当前配置）与每次核对的结果 [AppPasswordCheck]；
// - 副作用：读写单个键 [AppPasswordStore.key]。
//
// 所有写入串行执行（同 `AiProviderStore`）：连按两次“解锁”的两次核对不会
// 读到同一份输错次数、各自只加一次。
//
// 输错限流见 [AppPasswordLockout]。等待截止时刻按墙上时钟存；系统时钟被往回
// 调时，剩余等待会远超当前档位应有的时长，此时把截止时刻收回到“现在 +
// 当前档位”并写回，不会因为改了时间而被锁上几天。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_password_config.dart';
import 'app_password_hasher.dart';

export 'app_password_config.dart';

/// 一次核对的结论。
enum AppPasswordCheckStatus {
  /// 密码正确。
  accepted,

  /// 密码不对，还能接着试（见 [AppPasswordCheck.attemptsLeft]）。
  wrong,

  /// 输错太多次，等到 [AppPasswordCheck.lockedUntil] 才能再试；这次输入
  /// 没有被核对（或刚好是让它进入等待的那一次）。
  lockedOut,

  /// 没有设置应用密码。
  noPassword,
}

/// 核对结果：结论、还能试几次、等待截止时刻。
@immutable
class AppPasswordCheck {
  const AppPasswordCheck(
    this.status, {
    this.attemptsLeft = 0,
    this.lockedUntil,
  });

  final AppPasswordCheckStatus status;

  /// 再输错几次就要开始等待（只在 [AppPasswordCheckStatus.wrong] 时有意义）。
  final int attemptsLeft;

  final DateTime? lockedUntil;
}

class AppPasswordStore {
  AppPasswordStore._(
    this._prefs,
    AppPasswordConfig config,
    this._hasher,
    this._clock,
  ) : configNotifier = ValueNotifier<AppPasswordConfig>(config);

  static const String key = 'app.security.app_password';

  final SharedPreferences _prefs;
  final AppPasswordHasher _hasher;
  final DateTime Function() _clock;
  final ValueNotifier<AppPasswordConfig> configNotifier;
  Future<void> _pending = Future<void>.value();

  static Future<AppPasswordStore> create({
    AppPasswordHasher hasher = const AppPasswordHasher(),
    DateTime Function() clock = DateTime.now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return AppPasswordStore._(
      prefs,
      AppPasswordConfig.decode(prefs.getString(key)),
      hasher,
      clock,
    );
  }

  AppPasswordConfig get config => configNotifier.value;

  /// 设置（或修改）应用密码：重新生成盐与摘要，输错记录清零。
  ///
  /// [biometric] 为 null 时保留原来的指纹开关（修改密码），首次设置由调用方
  /// 按设备是否支持传入默认值。
  Future<void> setPassword(String password, {bool? biometric}) async {
    assert(AppPasswordRules.check(password) == null);
    final secret = await _hasher.create(password);
    await _serialized(() async {
      await _write(
        AppPasswordConfig(
          secret: secret,
          biometric: biometric ?? config.biometric,
        ),
      );
    });
  }

  /// 清除应用密码，回到系统验证。
  Future<void> clearPassword() =>
      _serialized(() => _write(AppPasswordConfig.initial));

  Future<void> setBiometric(bool enabled) => _serialized(() async {
    if (!config.hasPassword) return;
    await _write(config.copyWith(biometric: enabled));
  });

  /// 用其他方式（指纹 / 面容）证明了身份：输错记录清零。
  Future<void> resetFailures() => _serialized(() async {
    if (config.failedCount == 0 && config.lockedUntil == null) return;
    await _write(config.copyWith(failedCount: 0, clearLockedUntil: true));
  });

  /// 当前是否在等待中：返回截止时刻，不在等待时为 null。顺带修正被时钟回拨
  /// 拉长的截止时刻（见文件头）。
  Future<DateTime?> currentLockout() async {
    DateTime? result;
    await _serialized(() async {
      result = await _normalizedLockout(_clock());
    });
    return result;
  }

  /// 核对一次密码并记录结果。
  Future<AppPasswordCheck> verify(String password) async {
    late AppPasswordCheck result;
    await _serialized(() async {
      final secret = config.secret;
      if (secret == null) {
        result = const AppPasswordCheck(AppPasswordCheckStatus.noPassword);
        return;
      }
      final waiting = await _normalizedLockout(_clock());
      if (waiting != null) {
        result = AppPasswordCheck(
          AppPasswordCheckStatus.lockedOut,
          lockedUntil: waiting,
        );
        return;
      }
      if (await _hasher.matches(password, secret)) {
        if (config.failedCount > 0 || config.lockedUntil != null) {
          await _write(config.copyWith(failedCount: 0, clearLockedUntil: true));
        }
        result = const AppPasswordCheck(AppPasswordCheckStatus.accepted);
        return;
      }
      final failed = config.failedCount + 1;
      final wait = AppPasswordLockout.durationAfter(failed);
      final until = wait == null ? null : _clock().add(wait);
      await _write(
        config.copyWith(
          failedCount: failed,
          lockedUntil: until,
          clearLockedUntil: until == null,
        ),
      );
      result = until == null
          ? AppPasswordCheck(
              AppPasswordCheckStatus.wrong,
              attemptsLeft: AppPasswordLockout.attemptsBeforeLockout(failed),
            )
          : AppPasswordCheck(
              AppPasswordCheckStatus.lockedOut,
              lockedUntil: until,
            );
    });
    return result;
  }

  /// 在串行队列里调用：仍在等待时返回截止时刻（必要时修正并写回）。
  Future<DateTime?> _normalizedLockout(DateTime now) async {
    final until = config.lockedUntil;
    if (until == null || !now.isBefore(until)) {
      return null;
    }
    final tier = AppPasswordLockout.durationAfter(config.failedCount);
    if (tier == null) {
      // 输错次数与截止时刻对不上（不应出现）：不让人白等。
      await _write(config.copyWith(clearLockedUntil: true));
      return null;
    }
    final latest = now.add(tier);
    if (until.isAfter(latest)) {
      await _write(config.copyWith(lockedUntil: latest));
      return latest;
    }
    return until;
  }

  Future<void> _write(AppPasswordConfig next) async {
    if (next == config) return;
    final raw = next.encode();
    final ok = raw == null
        ? await _prefs.remove(key)
        : await _prefs.setString(key, raw);
    if (!ok) throw StateError('failed to persist app password');
    configNotifier.value = next;
  }

  void dispose() => configNotifier.dispose();

  Future<void> _serialized(Future<void> Function() action) {
    final run = _pending.then((_) => action());
    _pending = run.catchError((Object _) {});
    return run;
  }
}

/// 摘要计算器；测试覆盖为不进 isolate、低迭代次数的实例。
final appPasswordHasherProvider = Provider<AppPasswordHasher>(
  (Ref ref) => const AppPasswordHasher(),
);

/// 应用密码存储。与 SettingsService 分离：内容不进备份、不同步。
final appPasswordStoreProvider = FutureProvider<AppPasswordStore>((
  Ref ref,
) async {
  final store = await AppPasswordStore.create(
    hasher: ref.read(appPasswordHasherProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

/// 当前的应用密码配置。同步 Notifier：存储未就绪（或加载失败）时为
/// [AppPasswordConfig.initial]（系统验证），就绪后跟随存储变化。
final appPasswordConfigProvider =
    NotifierProvider<AppPasswordConfigNotifier, AppPasswordConfig>(
      AppPasswordConfigNotifier.new,
    );

class AppPasswordConfigNotifier extends Notifier<AppPasswordConfig> {
  @override
  AppPasswordConfig build() {
    final store = ref.watch(appPasswordStoreProvider).asData?.value;
    if (store == null) return AppPasswordConfig.initial;
    final notifier = store.configNotifier;
    void listener() => state = notifier.value;
    notifier.addListener(listener);
    ref.onDispose(() => notifier.removeListener(listener));
    return notifier.value;
  }
}
