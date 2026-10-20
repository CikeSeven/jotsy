import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../models/diary_saved_colors.dart';

/// 颜色面板的“我的颜色”（跨日记）。
///
/// 同步 Notifier：设置服务在启动门控里已加载，编辑页第一次展开色板就能看到
/// 保存的颜色。备份恢复与失败回滚会改写 raw notifier，这里监听它并按 `==`
/// 去重，避免同一份记录反复触发编辑页重建。
final diarySavedColorsProvider =
    NotifierProvider<DiarySavedColorsNotifier, DiarySavedColors>(
      DiarySavedColorsNotifier.new,
    );

class DiarySavedColorsNotifier extends Notifier<DiarySavedColors> {
  @override
  DiarySavedColors build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return DiarySavedColors.empty;
    final rawNotifier = settings.diarySavedColorsRawNotifier;
    void listener() {
      final next = DiarySavedColors.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiarySavedColors.decode(rawNotifier.value);
  }

  /// 在最新的记录上执行一次改写（自定义页保存、色板里移除或收藏）。先改内存
  /// 状态，色板立即显示；写盘在后台进行，设置服务未就绪时只记在内存里。
  void edit(DiarySavedColorsEdit change) {
    final next = change(state);
    if (next == state) return;
    state = next;
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings != null) {
      unawaited(settings.setDiarySavedColorsRaw(next.encode()));
    }
  }
}
