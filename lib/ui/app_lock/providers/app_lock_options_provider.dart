import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/app_lock_options.dart';

/// 当前的应用锁选项（[AppLockOptions]）；设置服务未就绪时为默认值。
///
/// 订阅设置服务里的原文 notifier：设置页保存后应用根部的上锁逻辑立即生效。
final appLockOptionsProvider =
    NotifierProvider<AppLockOptionsNotifier, AppLockOptions>(
      AppLockOptionsNotifier.new,
    );

class AppLockOptionsNotifier extends Notifier<AppLockOptions> {
  @override
  AppLockOptions build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return AppLockOptions.defaults;
    final rawNotifier = settings.appLockOptionsRawNotifier;
    void listener() {
      final next = AppLockOptions.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return AppLockOptions.decode(rawNotifier.value);
  }
}

/// 保存应用锁选项（整份写入）。
Future<void> saveAppLockOptions(
  SettingsService settings,
  AppLockOptions options,
) => settings.setAppLockOptionsRaw(options.encode());
