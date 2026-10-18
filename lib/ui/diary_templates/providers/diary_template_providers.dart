import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations_gen.dart';
import '../models/built_in/diary_template_built_ins.dart';
import '../models/diary_template.dart';
import '../models/diary_template_json.dart';
import '../models/diary_template_prefs.dart';
import '../viewmodels/diary_template_library.dart';

/// 模板偏好 provider。
///
/// 与卡片样式一样是同步 Notifier：settings 未就绪时给默认值，就绪后立即
/// 同步解码，新建编辑页首帧就能按偏好决定是否显示建议条，不会先出现再消失。
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重。
final diaryTemplatePrefsProvider =
    NotifierProvider<DiaryTemplatePrefsNotifier, DiaryTemplatePrefs>(
      DiaryTemplatePrefsNotifier.new,
    );

class DiaryTemplatePrefsNotifier extends Notifier<DiaryTemplatePrefs> {
  @override
  DiaryTemplatePrefs build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return DiaryTemplatePrefs.defaults;
    final rawNotifier = settings.diaryTemplatePrefsRawNotifier;
    void listener() {
      final next = DiaryTemplatePrefs.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return DiaryTemplatePrefs.decode(rawNotifier.value);
  }
}

/// 持久化模板偏好；与默认完全相同时移除设置键。
Future<void> saveDiaryTemplatePrefs(
  SettingsService settings,
  DiaryTemplatePrefs prefs,
) {
  return settings.setDiaryTemplatePrefsRaw(prefs.encode());
}

/// 用户模板（手动排序）。payload 解析不了的行跳过，不让一行坏数据拖垮
/// 整个模板列表。
final userDiaryTemplatesProvider = StreamProvider<List<DiaryTemplate>>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return database.watchDiaryTemplates().map((rows) {
    final templates = <DiaryTemplate>[];
    for (final row in rows) {
      final template = DiaryTemplateJson.fromPayload(
        row.payload,
        id: row.templateId,
      );
      if (template == null) {
        debugPrint('Skipped unreadable diary template ${row.templateId}');
        continue;
      }
      templates.add(template);
    }
    return List<DiaryTemplate>.unmodifiable(templates);
  });
});

/// 当前的模板库。用户模板还在读取时只含内置模板，[loaded] 告诉调用方是否
/// 已经拿到完整列表（自动套用要等它，免得把用户模板当成“不存在”）。
({DiaryTemplateLibrary library, bool loaded}) watchDiaryTemplateLibrary(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final user = ref.watch(userDiaryTemplatesProvider);
  return (
    library: DiaryTemplateLibrary(
      builtIns: buildBuiltInDiaryTemplates(l10n),
      userTemplates: user.asData?.value ?? const <DiaryTemplate>[],
      prefs: ref.watch(diaryTemplatePrefsProvider),
    ),
    loaded: user.hasValue,
  );
}
