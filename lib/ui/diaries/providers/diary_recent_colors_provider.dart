import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../models/diary_recent_colors.dart';
import '../models/diary_text_colors.dart';

/// 颜色面板最近用过的自定义颜色（跨日记）。
///
/// 同步 Notifier：设置服务在启动门控里已加载，编辑页第一次展开色板就能看到
/// 记录。备份恢复与失败回滚会改写 raw notifier，这里监听它并按 `==` 去重，
/// 避免同一份记录反复触发编辑页重建。
final diaryRecentColorsProvider =
    NotifierProvider<DiaryRecentColorsNotifier, DiaryRecentColors>(
      DiaryRecentColorsNotifier.new,
    );

class DiaryRecentColorsNotifier extends Notifier<DiaryRecentColors> {
  @override
  DiaryRecentColors build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return DiaryRecentColors.empty;
    final rawNotifier = settings.diaryRecentColorsRawNotifier;
    void listener() {
      final next = DiaryRecentColors.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryRecentColors.decode(rawNotifier.value);
  }

  /// 记下一次自定义取色（色谱松手或应用颜色代码）。先改内存状态，色板立即
  /// 显示；写盘在后台进行，设置服务未就绪时只记在内存里。
  void record(DiaryColorTarget target, Color color) {
    final next = state.record(target, color);
    if (next == state) return;
    state = next;
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings != null) {
      unawaited(settings.setDiaryRecentColorsRaw(next.encode()));
    }
  }
}
