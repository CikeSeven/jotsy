import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/diary_preview_style/diary_preview_behavior.dart';
import '../models/diary_preview_style/diary_preview_settings.dart';
import '../models/diary_preview_style/diary_preview_style.dart';

/// 日记预览页设置（当前样式 + 我的样式 + 阅读行为）provider。
///
/// 与卡片样式一样是同步 Notifier：settings 未就绪时给默认值；就绪后 build
/// 立即同步解码存储值，预览页首帧就是用户样式，不会先画一帧默认外观再跳。
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重。
final diaryPreviewSettingsProvider =
    NotifierProvider<DiaryPreviewSettingsNotifier, DiaryPreviewSettings>(
      DiaryPreviewSettingsNotifier.new,
    );

class DiaryPreviewSettingsNotifier extends Notifier<DiaryPreviewSettings> {
  @override
  DiaryPreviewSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return DiaryPreviewSettings.defaults;
    }
    final rawNotifier = settings.diaryPreviewStyleRawNotifier;
    void listener() {
      final next = DiaryPreviewSettings.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryPreviewSettings.decode(rawNotifier.value);
  }
}

/// 预览页实际使用的外观；只在外观变化时通知（保存“我的样式”、改阅读行为
/// 不会让已打开的预览页重建）。
final diaryPreviewStyleProvider = Provider<DiaryPreviewStyle>((Ref ref) {
  return ref.watch(
    diaryPreviewSettingsProvider.select((settings) => settings.current),
  );
});

/// 预览页的阅读行为（翻页、勾选待办、选择文字等）。
final diaryPreviewBehaviorProvider = Provider<DiaryPreviewBehavior>((Ref ref) {
  return ref.watch(
    diaryPreviewSettingsProvider.select((settings) => settings.behavior),
  );
});

/// 应用主题的种子色：预览页按纸张换成另一种明暗时，用它重建同一配色。跟随
/// 设置变化（换主题色、恢复备份）。
final appThemeSeedColorProvider = Provider<Color>((Ref ref) {
  final settings = ref.watch(settingsServiceProvider).asData?.value;
  if (settings == null) {
    return const Color(SettingsService.defaultThemeSeedColorValue);
  }
  final notifier = settings.themeSeedColorNotifier;
  void listener() => ref.invalidateSelf();
  notifier.addListener(listener);
  ref.onDispose(() => notifier.removeListener(listener));
  return notifier.value;
});

/// 持久化预览页设置；与默认完全相同时移除该键，备份里不留冗余配置。
Future<void> saveDiaryPreviewSettings(
  SettingsService settings,
  DiaryPreviewSettings value,
) {
  return settings.setDiaryPreviewStyleRaw(value.encode());
}
