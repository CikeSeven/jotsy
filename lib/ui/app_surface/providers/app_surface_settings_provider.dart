import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/app_surface_settings.dart';

/// “背景与材质”设置（全局 / 各区域背景 + 组件材质）provider。
///
/// 与首页栏样式一样是同步 Notifier 而不是 `async*` StreamProvider：
/// StreamProvider 在 settings 就绪后的第一帧必然处于 loading，各页只能先按
/// 无背景、经典材质画一帧，随后再跳成用户的背景——启动时整屏会闪一下。这里
/// settings 未就绪时给默认值；就绪后 build 立即同步解码存储值，首帧读到的
/// 就是用户设置。
///
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重，相同设置不触发重建。
final appSurfaceSettingsProvider =
    NotifierProvider<AppSurfaceSettingsNotifier, AppSurfaceSettings>(
      AppSurfaceSettingsNotifier.new,
    );

class AppSurfaceSettingsNotifier extends Notifier<AppSurfaceSettings> {
  @override
  AppSurfaceSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return AppSurfaceSettings.defaults;
    }
    final rawNotifier = settings.appSurfaceRawNotifier;
    void listener() {
      final next = AppSurfaceSettings.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return AppSurfaceSettings.decode(rawNotifier.value);
  }
}

/// 组件材质；只在材质设置变化时通知（改背景不会让玻璃组件重建）。
final appGlassStyleProvider = Provider<AppGlassStyle>((Ref ref) {
  return ref.watch(appSurfaceSettingsProvider.select((value) => value.glass));
});

/// 某个区域实际使用的背景（已按 follow / off / custom 解析）；只在这个区域
/// 的结果变化时通知，改别的区域不会让本区域重建。
final appAreaBackgroundProvider =
    Provider.family<AppBackground, AppBackgroundArea>((
      Ref ref,
      AppBackgroundArea area,
    ) {
      return ref.watch(
        appSurfaceSettingsProvider.select((value) => value.backgroundFor(area)),
      );
    });

/// 持久化背景与材质设置；与默认完全相同时移除该键，备份里不留冗余配置。
Future<void> saveAppSurfaceSettings(
  SettingsService settings,
  AppSurfaceSettings value,
) {
  return settings.setAppSurfaceRaw(value.encode());
}
