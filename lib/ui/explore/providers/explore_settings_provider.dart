import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/explore_layout.dart';
import '../models/explore_period.dart';
import '../models/explore_settings.dart';

/// 探索页设置 provider（布局、我的布局与统计范围）。
///
/// 同步 Notifier：settings 未就绪时给默认设置；就绪后 build 立即同步解码，
/// 探索页首帧就是用户的布局，不会先画默认卡片再跳。编辑页写入、范围条切换、
/// 备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==` 去重。
final exploreSettingsProvider =
    NotifierProvider<ExploreSettingsNotifier, ExploreSettings>(
      ExploreSettingsNotifier.new,
    );

class ExploreSettingsNotifier extends Notifier<ExploreSettings> {
  @override
  ExploreSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return ExploreSettings.defaults;
    final rawNotifier = settings.exploreLayoutRawNotifier;
    void listener() {
      final next = ExploreSettings.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return ExploreSettings.decode(rawNotifier.value);
  }
}

/// 当前布局（探索页只关心它，我的布局变化不触发重建）。
final exploreLayoutProvider = Provider<ExploreLayout>(
  (Ref ref) => ref.watch(exploreSettingsProvider.select((s) => s.current)),
);

/// 当前统计范围。
final explorePeriodProvider = Provider<ExplorePeriod>(
  (Ref ref) =>
      ref.watch(exploreSettingsProvider.select((s) => s.behavior.period)),
);

/// 持久化探索页设置；全为默认时移除该键，备份里不留冗余配置。
Future<void> saveExploreSettings(
  SettingsService settings,
  ExploreSettings value,
) => settings.setExploreLayoutRaw(value.encode());
