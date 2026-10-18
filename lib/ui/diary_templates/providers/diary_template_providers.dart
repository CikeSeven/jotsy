import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
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

/// 用户模板（手动排序），实时跟随数据库变化；模板管理页用它。payload 解析
/// 不了的行跳过，不让一行坏数据拖垮整个模板列表。
final userDiaryTemplatesProvider = StreamProvider<List<DiaryTemplate>>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return database.watchDiaryTemplates().map(_parseTemplateRows);
});

/// 用户模板的一次性读取，新建编辑页的建议条与模板面板用它。
///
/// 不挂 drift 的实时查询：编辑页随时会被打开、关闭，实时查询要在页面卸载
/// 时注销，徒增开销；模板只在管理页里改变，管理页每次写入后 invalidate
/// 它（见 `DiaryTemplatesController`），下次读取即是最新列表。
final userDiaryTemplatesSnapshotProvider =
    FutureProvider.autoDispose<List<DiaryTemplate>>((Ref ref) async {
      final rows = await ref.watch(appDatabaseProvider).getDiaryTemplates();
      return _parseTemplateRows(rows);
    });

List<DiaryTemplate> _parseTemplateRows(List<DiaryTemplateRow> rows) {
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
}

/// 当前的模板库。用户模板还在读取时只含内置模板，[loaded] 告诉调用方是否
/// 已经拿到完整列表。[live] 为 true 时实时跟随数据库（管理页），否则用一次性
/// 读取（新建编辑页与模板面板）。
({DiaryTemplateLibrary library, bool loaded}) watchDiaryTemplateLibrary(
  WidgetRef ref,
  AppLocalizations l10n, {
  bool live = false,
}) {
  final user = live
      ? ref.watch(userDiaryTemplatesProvider)
      : ref.watch(userDiaryTemplatesSnapshotProvider);
  return (
    library: DiaryTemplateLibrary(
      builtIns: buildBuiltInDiaryTemplates(l10n),
      userTemplates: user.asData?.value ?? const <DiaryTemplate>[],
      prefs: ref.watch(diaryTemplatePrefsProvider),
    ),
    loaded: user.hasValue,
  );
}

/// 按 id 取一个模板（内置或用户模板），不存在或读不出时为 null。
///
/// 供不在 widget 树里的流程使用（新建页自动套用）：不等用户模板的
/// StreamProvider 首次推送，直接查库。
Future<DiaryTemplate?> loadDiaryTemplate(
  AppDatabase database,
  AppLocalizations l10n,
  String id,
) async {
  if (id.startsWith(builtInDiaryTemplateIdPrefix)) {
    return buildBuiltInDiaryTemplates(
      l10n,
    ).where((template) => template.id == id).firstOrNull;
  }
  final row = await database.getDiaryTemplate(id);
  return row == null
      ? null
      : DiaryTemplateJson.fromPayload(row.payload, id: row.templateId);
}

/// 记一次“最近使用”。从设置里的原文重新解码再写回，不依赖 provider 的
/// 缓存值——页面卸载后也能完成。
Future<void> recordDiaryTemplateUse(SettingsService settings, String id) {
  final prefs = DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);
  return saveDiaryTemplatePrefs(settings, prefs.recordUse(id));
}
