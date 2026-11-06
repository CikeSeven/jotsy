// 应用密码的本机存储（docs/rules/app_lock.md）。
//
// - 输入：SharedPreferences、摘要计算器 [AppPasscodeHasher]、时钟；
// - 输出：[AppPasscodeStore.configNotifier]（当前配置）与每次核对的结果
//   [AppPasscodeCheck]；
// - 副作用：读写单个键 [AppPasscodeStore.key]。
//
// 所有写入串行执行（同 `AiProviderStore`）：快速连输两次的两次核对不会读到
// 同一份输错次数、各自只加一次。
//
// 输错限流见 [AppPasscodeLockout]。等待截止时刻按墙上时钟存；系统时钟被往回
// 调时，剩余等待会远超当前档位应有的时长，此时把截止时刻收回到“现在 +
// 当前档位”并写回，不会因为改了时间而被锁上几天。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_passcode_config.dart';
import 'app_passcode_hasher.dart';

export 'app_passcode_config.dart';

/// 一次核对的结论。
enum AppPasscodeCheckStatus {
  /// 密码正确。
  accepted,

  /// 密码不对，还能接着试（见 [AppPasscodeCheck.attemptsLeft]）。
  wrong,

  /// 输错太多次，等到 [AppPasscodeCheck.lockedUntil] 才能再试；这次输入
  /// 没有被核对（或刚好是让它进入等待的那一次）。
  lockedOut,

  /// 没有设置应用密码。
  noPasscode,
}

/// 核对结果：结论、还能试几次、等待截止时刻。
@immutable
class AppPasscodeCheck {
  const AppPasscodeCheck(
    this.status, {
    this.attemptsLeft = 0,
    this.lockedUntil,
  });

  final AppPasscodeCheckStatus status;

  /// 再输错几次就要开始等待（只在 [AppPasscodeCheckStatus.wrong] 时有意义）。
  final int attemptsLeft;

  final DateTime? lockedUntil;
}

class AppPasscodeStore {
  AppPasscodeStore._(
    this._prefs,
    AppPasscodeConfig config,
    this._hasher,
    this._clock,
  ) : configNotifier = ValueNotifier<AppPasscodeConfig>(config);

  static const String key = 'app.security.passcode';

  final SharedPreferences _prefs;
  final AppPasscodeHasher _hasher;
  final DateTime Function() _clock;
  final ValueNotifier<AppPasscodeConfig> configNotifier;
  Future<void> _pending = Future<void>.value();

  static Future<AppPasscodeStore> create({
    AppPasscodeHasher hasher = const AppPasscodeHasher(),
    DateTime Function() clock = DateTime.now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return AppPasscodeStore._(
      prefs,
      AppPasscodeConfig.decode(prefs.getString(key)),
      hasher,
      clock,
    );
  }

  AppPasscodeConfig get config => configNotifier.value;

  /// 设置（或修改）数字密码：重新生成盐与摘要，输错记录清零。
  ///
  /// [biometric] 为 null 时保留原来的指纹开关（修改密码），首次设置由调用方
  /// 按设备是否支持传入默认值。
  Future<void> setPin(String digits, {bool? biometric}) {
    assert(AppPasscodeRules.validPin(digits, digits.length));
    return _set(
      AppPasscodeKind.pin,
      digits,
      pinLength: digits.length,
      biometric: biometric,
    );
  }

  /// 设置（或修改）图案密码，其余同 [setPin]。
  Future<void> setPattern(List<int> nodes, {bool? biometric}) {
    assert(AppPasscodeRules.validPattern(nodes));
    return _set(
      AppPasscodeKind.pattern,
      AppPasscodeRules.encodePattern(nodes),
      biometric: biometric,
    );
  }

  Future<void> _set(
    AppPasscodeKind kind,
    String value, {
    int pinLength = 6,
    bool? biometric,
  }) async {
    final secret = await _hasher.create(AppPasscodeRules.material(kind, value));
    await _serialized(() async {
      await _write(
        AppPasscodeConfig(
          secret: secret,
          kind: kind,
          pinLength: pinLength,
          biometric: biometric ?? config.biometric,
        ),
      );
    });
  }

  /// 清除应用密码，回到系统验证。
  Future<void> clear() => _serialized(() => _write(AppPasscodeConfig.initial));

  Future<void> setBiometric(bool enabled) => _serialized(() async {
    if (!config.hasPasscode) return;
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

  /// 核对一次输入并记录结果。[value] 为数字串，或 [AppPasscodeRules.encodePattern]
  /// 串化后的图案；形式取当前配置。
  Future<AppPasscodeCheck> verify(String value) async {
    late AppPasscodeCheck result;
    await _serialized(() async {
      final secret = config.secret;
      if (secret == null) {
        result = const AppPasscodeCheck(AppPasscodeCheckStatus.noPasscode);
        return;
      }
      final waiting = await _normalizedLockout(_clock());
      if (waiting != null) {
        result = AppPasscodeCheck(
          AppPasscodeCheckStatus.lockedOut,
          lockedUntil: waiting,
        );
        return;
      }
      final material = AppPasscodeRules.material(config.kind, value);
      if (await _hasher.matches(material, secret)) {
        if (config.failedCount > 0 || config.lockedUntil != null) {
          await _write(config.copyWith(failedCount: 0, clearLockedUntil: true));
        }
        result = const AppPasscodeCheck(AppPasscodeCheckStatus.accepted);
        return;
      }
      final failed = config.failedCount + 1;
      final wait = AppPasscodeLockout.durationAfter(failed);
      final until = wait == null ? null : _clock().add(wait);
      await _write(
        config.copyWith(
          failedCount: failed,
          lockedUntil: until,
          clearLockedUntil: until == null,
        ),
      );
      result = until == null
          ? AppPasscodeCheck(
              AppPasscodeCheckStatus.wrong,
              attemptsLeft: AppPasscodeLockout.attemptsBeforeLockout(failed),
            )
          : AppPasscodeCheck(
              AppPasscodeCheckStatus.lockedOut,
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
    final tier = AppPasscodeLockout.durationAfter(config.failedCount);
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

  Future<void> _write(AppPasscodeConfig next) async {
    if (next == config) return;
    final raw = next.encode();
    final ok = raw == null
        ? await _prefs.remove(key)
        : await _prefs.setString(key, raw);
    if (!ok) throw StateError('failed to persist app passcode');
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
final appPasscodeHasherProvider = Provider<AppPasscodeHasher>(
  (Ref ref) => const AppPasscodeHasher(),
);

/// 输错限流用的时钟；界面倒数与存储共用同一个，测试覆盖为假时钟。
final appPasscodeClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

/// 应用密码存储。与 SettingsService 分离：内容不进备份、不同步。
final appPasscodeStoreProvider = FutureProvider<AppPasscodeStore>((
  Ref ref,
) async {
  final store = await AppPasscodeStore.create(
    hasher: ref.read(appPasscodeHasherProvider),
    clock: ref.read(appPasscodeClockProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

/// 当前的应用密码配置。同步 Notifier：存储未就绪（或加载失败）时为
/// [AppPasscodeConfig.initial]（系统验证），就绪后跟随存储变化。
final appPasscodeConfigProvider =
    NotifierProvider<AppPasscodeConfigNotifier, AppPasscodeConfig>(
      AppPasscodeConfigNotifier.new,
    );

class AppPasscodeConfigNotifier extends Notifier<AppPasscodeConfig> {
  @override
  AppPasscodeConfig build() {
    final store = ref.watch(appPasscodeStoreProvider).asData?.value;
    if (store == null) return AppPasscodeConfig.initial;
    final notifier = store.configNotifier;
    void listener() => state = notifier.value;
    notifier.addListener(listener);
    ref.onDispose(() => notifier.removeListener(listener));
    return notifier.value;
  }
}
