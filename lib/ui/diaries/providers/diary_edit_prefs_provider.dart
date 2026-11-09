import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/diary_edit_prefs.dart';

/// 编辑已有日记的偏好（格式见 [DiaryEditPrefs]）。
///
/// 同步 Notifier：settings 未就绪时给默认值；就绪后 build 立即同步解码。
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重。
final diaryEditPrefsProvider =
    NotifierProvider<DiaryEditPrefsNotifier, DiaryEditPrefs>(
      DiaryEditPrefsNotifier.new,
    );

class DiaryEditPrefsNotifier extends Notifier<DiaryEditPrefs> {
  @override
  DiaryEditPrefs build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return DiaryEditPrefs.defaults;
    final rawNotifier = settings.diaryEditPrefsRawNotifier;
    void listener() {
      final next = DiaryEditPrefs.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryEditPrefs.decode(rawNotifier.value);
  }
}

/// 持久化编辑已有日记的偏好；全为默认时移除该键。
Future<void> saveDiaryEditPrefs(
  SettingsService settings,
  DiaryEditPrefs value,
) => settings.setDiaryEditPrefsRaw(value.encode());
