import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../models/diary_mood_palette.dart';
import 'diary_card_style_provider.dart';

/// 用户改过的心情颜色（设置键 `app.settings.mood_colors`）。
///
/// 与 `diaryCardStyleSettingsProvider` 同理用同步 Notifier：settings 就绪的
/// 第一帧就读到用户的颜色，卡片与预览页不会先按内置色画一帧再跳色。心情
/// 符号页保存时改写 raw notifier，这里按 `==` 去重后更新。
final diaryMoodColorsProvider =
    NotifierProvider<DiaryMoodColorsNotifier, DiaryMoodColors>(
      DiaryMoodColorsNotifier.new,
    );

class DiaryMoodColorsNotifier extends Notifier<DiaryMoodColors> {
  @override
  DiaryMoodColors build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return DiaryMoodColors.defaults;
    }
    final rawNotifier = settings.moodColorsRawNotifier;
    void listener() {
      final next = DiaryMoodColors.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryMoodColors.decode(rawNotifier.value);
  }
}

/// 当前的心情色板（心情符号 + 心情颜色），预览页配色基调与卡片心情色共用。
///
/// 只在心情符号或颜色变化时重建：实例里记着换算好的强调色，平时一直沿用
/// 同一个；下游按 `==` 做的缓存（`DiaryCardResolvedStyle.cached`）照常命中。
final diaryMoodPaletteProvider = Provider<DiaryMoodPalette>((Ref ref) {
  return DiaryMoodPalette(
    moodOptions: ref.watch(diaryCardMoodOptionsProvider),
    colors: ref.watch(diaryMoodColorsProvider),
  );
});
