import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/home_bar_style/home_bar_behavior.dart';
import '../models/home_bar_style/home_bar_settings.dart';
import '../models/home_bar_style/home_bar_style.dart';

/// 首页栏设置（当前样式 + 我的样式 + 栏的行为）provider。
///
/// 与日记卡片样式一样是同步 Notifier 而不是 `async*` StreamProvider：
/// StreamProvider 在 settings 就绪后的第一帧必然处于 loading，首页只能先用
/// 默认的实色栏画一帧，随后再跳成玻璃栏——启动时底栏会闪一下。这里 settings
/// 未就绪时给默认值；就绪后 build 立即同步解码存储值，首页首帧读到的就是
/// 用户样式。
///
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重，相同设置不触发首页重建。
final homeBarSettingsProvider =
    NotifierProvider<HomeBarSettingsNotifier, HomeBarSettings>(
      HomeBarSettingsNotifier.new,
    );

class HomeBarSettingsNotifier extends Notifier<HomeBarSettings> {
  @override
  HomeBarSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return HomeBarSettings.defaults;
    }
    final rawNotifier = settings.homeBarStyleRawNotifier;
    void listener() {
      final next = HomeBarSettings.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return HomeBarSettings.decode(rawNotifier.value);
  }
}

/// 首页栏实际使用的外观；只在外观变化时通知（保存“我的样式”、改栏的行为
/// 不会让底栏与顶栏重建）。
final homeBarStyleProvider = Provider<HomeBarStyle>((Ref ref) {
  return ref.watch(homeBarSettingsProvider.select((value) => value.current));
});

/// 首页栏的行为（滚动隐藏底栏、指示器跟随滑动）。
final homeBarBehaviorProvider = Provider<HomeBarBehavior>((Ref ref) {
  return ref.watch(homeBarSettingsProvider.select((value) => value.behavior));
});

/// 持久化首页栏设置；与默认完全相同时移除该键，备份里不留冗余配置。
Future<void> saveHomeBarSettings(
  SettingsService settings,
  HomeBarSettings value,
) {
  return settings.setHomeBarStyleRaw(value.encode());
}
