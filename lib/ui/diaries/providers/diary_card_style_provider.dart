import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/diary_card_style/diary_card_style.dart';
import '../models/diary_card_style/diary_card_style_settings.dart';

/// 日记卡片样式设置（当前样式 + 我的样式）provider。
///
/// 为什么是同步 Notifier 而不是 `async*` StreamProvider：StreamProvider 在
/// settings 就绪后的第一帧必然处于 loading，页面只能先用默认样式画一帧，
/// 随后再跳成用户样式——启动时整列卡片会闪一下。这里 settings 未就绪时给
/// 默认值；就绪后 build 立即同步解码存储值，日记页在 settings 的 data 分支
/// 首帧读到的就是用户样式。
///
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重，相同样式不触发列表重建。
final diaryCardStyleSettingsProvider =
    NotifierProvider<DiaryCardStyleSettingsNotifier, DiaryCardStyleSettings>(
      DiaryCardStyleSettingsNotifier.new,
    );

class DiaryCardStyleSettingsNotifier extends Notifier<DiaryCardStyleSettings> {
  @override
  DiaryCardStyleSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return DiaryCardStyleSettings.defaults;
    }
    final rawNotifier = settings.diaryCardStyleRawNotifier;
    void listener() {
      final next = DiaryCardStyleSettings.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryCardStyleSettings.decode(rawNotifier.value);
  }
}

/// 列表实际使用的当前卡片样式；只在当前样式变化时通知（保存/删除“我的
/// 样式”不会让日记列表重建）。
final diaryCardStyleProvider = Provider<DiaryCardStyle>((Ref ref) {
  return ref.watch(
    diaryCardStyleSettingsProvider.select((settings) => settings.current),
  );
});

/// 卡片按“心情色”着色时换算心情档位所需的心情配置。
///
/// 心情配置的 StreamProvider 首帧处于 loading，这里同步回退到设置服务里的
/// 当前配置（settings 已就绪时），与 [diaryCardStyleSettingsProvider] 一样
/// 避免首帧先按默认配置着色。
final diaryCardMoodOptionsProvider = Provider<List<String>>((Ref ref) {
  final streamed = ref.watch(moodOptionsProvider).asData?.value;
  if (streamed != null) {
    return streamed;
  }
  return ref.watch(settingsServiceProvider).asData?.value.moodOptions ??
      SettingsService.defaultMoodOptions;
});

/// 持久化卡片样式设置；与默认完全相同时移除该键，备份里不留冗余配置。
Future<void> saveDiaryCardStyleSettings(
  SettingsService settings,
  DiaryCardStyleSettings value,
) {
  return settings.setDiaryCardStyleRaw(value.encode());
}
