import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/diary_code_block/diary_code_block_style.dart';
import 'diary_typography_provider.dart';

/// 正文代码块样式 provider。
///
/// 与预览页样式一样是同步 Notifier：settings 未就绪时给默认值；就绪后 build
/// 立即同步解码存储值，打开日记的首帧就是用户样式，不会先画默认外观再跳。
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重，原文变了但解析结果相同时不触发重建。
final diaryCodeBlockStyleProvider =
    NotifierProvider<DiaryCodeBlockStyleNotifier, DiaryCodeBlockStyle>(
      DiaryCodeBlockStyleNotifier.new,
    );

class DiaryCodeBlockStyleNotifier extends Notifier<DiaryCodeBlockStyle> {
  @override
  DiaryCodeBlockStyle build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return DiaryCodeBlockStyle.defaults;
    }
    final rawNotifier = settings.diaryCodeBlockStyleRawNotifier;
    void listener() {
      final next = DiaryCodeBlockStyle.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryCodeBlockStyle.decode(rawNotifier.value);
  }
}

/// 代码块选了导入字体时，该字体在引擎中的字族名；选系统等宽 / 正文字体、
/// 字体缺失、注册失败或仍在加载时为 null（渲染层回落等宽字体）。
///
/// 复用正文导入字体的加载 provider，同一字体只注册一次。
final diaryCodeBlockFontFamilyProvider = Provider<String?>((Ref ref) {
  final style = ref.watch(diaryCodeBlockStyleProvider);
  if (!style.usesImportedFont) {
    return null;
  }
  return ref.watch(diaryImportedFontFamilyProvider(style.fontId)).asData?.value;
});

/// 持久化代码块样式；与默认完全相同时移除该键，备份里不留冗余配置。
Future<void> saveDiaryCodeBlockStyle(
  SettingsService settings,
  DiaryCodeBlockStyle style,
) {
  return settings.setDiaryCodeBlockStyleRaw(style.encode());
}
