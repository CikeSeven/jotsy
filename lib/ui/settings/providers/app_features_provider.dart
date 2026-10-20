import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_features.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';

/// 功能管理开关 provider。
///
/// 是同步 Notifier：首页底栏与各处入口在首帧就要知道哪些功能开启，否则
/// 被关掉的 Tab 会先出现再消失；settings 在 HomePage 构建前已就绪，未就绪时
/// 给 [AppFeatures.defaults]。设置页写入、备份恢复与失败回滚都会改写 raw
/// notifier；监听它并按 `==` 去重，避免无变化的重建。
final appFeaturesProvider = NotifierProvider<AppFeaturesNotifier, AppFeatures>(
  AppFeaturesNotifier.new,
);

class AppFeaturesNotifier extends Notifier<AppFeatures> {
  @override
  AppFeatures build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return AppFeatures.defaults;
    final rawNotifier = settings.appFeaturesRawNotifier;
    void listener() {
      final next = AppFeatures.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return AppFeatures.decode(rawNotifier.value);
  }
}

/// 保存功能开关；全部开启时移除设置键（[AppFeatures.encode] 返回 null）。
Future<void> saveAppFeatures(SettingsService settings, AppFeatures features) =>
    settings.setAppFeaturesRaw(features.encode());
