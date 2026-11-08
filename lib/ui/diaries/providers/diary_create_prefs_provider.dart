import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/diary_create_prefs.dart';

/// 新建日记的偏好（格式见 [DiaryCreatePrefs]）。
///
/// 同步 Notifier：settings 未就绪时给默认值；就绪后 build 立即同步解码。
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重。
final diaryCreatePrefsProvider =
    NotifierProvider<DiaryCreatePrefsNotifier, DiaryCreatePrefs>(
      DiaryCreatePrefsNotifier.new,
    );

class DiaryCreatePrefsNotifier extends Notifier<DiaryCreatePrefs> {
  @override
  DiaryCreatePrefs build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return DiaryCreatePrefs.defaults;
    final rawNotifier = settings.diaryCreatePrefsRawNotifier;
    void listener() {
      final next = DiaryCreatePrefs.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryCreatePrefs.decode(rawNotifier.value);
  }
}

/// 持久化新建日记的偏好；全为默认时移除该键。
Future<void> saveDiaryCreatePrefs(
  SettingsService settings,
  DiaryCreatePrefs value,
) => settings.setDiaryCreatePrefsRaw(value.encode());
