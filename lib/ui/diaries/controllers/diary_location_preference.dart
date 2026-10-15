import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';

/// 发布页与编辑页共用的地址层级偏好：新建日记沿用最近一次的选择，
/// 已有日记仍以各自 metadata 中保存的层级为准。
class DiaryLocationPreference {
  const DiaryLocationPreference._();

  /// 新建日记的初始层级；未保存过或无法识别时为默认层级。
  static Future<DiaryLocationPrecision> load(WidgetRef ref) async {
    final settings = await ref.read(settingsServiceProvider.future);
    return DiaryLocationPrecision.parse(settings.diaryLocationPrecisionRaw);
  }

  /// 必须在用户操作的同步阶段调用（读取 ref 不能晚于页面销毁）。写入失败
  /// 只影响下一篇日记的默认值，不打断当前编辑，因此不向上抛出。
  static Future<void> remember(
    WidgetRef ref,
    DiaryLocationPrecision precision,
  ) async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    try {
      final settings = await settingsFuture;
      await settings.setDiaryLocationPrecisionRaw(precision.name);
    } catch (_) {
      // 偏好写入失败时保持上一次的默认层级。
    }
  }
}
