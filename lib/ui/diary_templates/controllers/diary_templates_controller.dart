import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/style_library/style_code.dart';
import '../models/diary_template.dart';
import '../models/diary_template_code.dart';
import '../models/diary_template_json.dart';
import '../models/diary_template_prefs.dart';
import '../providers/diary_template_providers.dart';

/// 删除一个模板留下的记录：撤销时原样写回这一行，并在自动套用仍空着时
/// 恢复成它。
typedef DiaryTemplateDeletion = ({DiaryTemplateRow row, bool wasAuto});

/// 导入模板码的结果：[templateId] 为新存下的模板（导入失败时为 null）。
typedef DiaryTemplateImport = ({
  StyleCodeStatus status,
  String? templateId,
  String name,
});

/// 模板管理的读写：保存、复制、删除与撤销、排序、隐藏内置模板、偏好与
/// 模板码。不构建 UI，确认与提示由页面负责。
///
/// 每次写入用户模板后调用 [onTemplatesChanged]：新建编辑页的建议条读的是
/// 一次性快照（见 `userDiaryTemplatesSnapshotProvider`），需要据此刷新。
///
/// 偏好每次都从设置原文重新解码再写回，不依赖页面手里可能过时的值。删除
/// 或隐藏的正是自动套用的模板时一并清空自动套用——否则新建日记会套用一个
/// 已经不在列表里的模板；撤销时再恢复。
class DiaryTemplatesController {
  DiaryTemplatesController({
    required this.database,
    required this.settings,
    required this.onTemplatesChanged,
  });

  final AppDatabase database;
  final SettingsService settings;
  final VoidCallback onTemplatesChanged;

  DiaryTemplatePrefs get _prefs =>
      DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);

  Future<void> _savePrefs(DiaryTemplatePrefs prefs) =>
      saveDiaryTemplatePrefs(settings, prefs);

  /// 保存 [template]；内置模板或 id 为空时另存为新的用户模板。返回模板 id。
  /// 正文在写入前再清洗一次，名称按长度上限截断。
  Future<String> save(DiaryTemplate template) async {
    final isNew = template.id.isEmpty || template.isBuiltIn;
    final normalized = template.copyWith(
      name: normalizeDiaryTemplateLine(
        template.name,
        DiaryTemplate.maxNameLength,
      ),
      bodyJson: encodeDiaryTemplateBody(
        decodeDiaryTemplateBody(template.bodyJson),
      ),
    );
    final id = await database.saveDiaryTemplate(
      templateId: isNew ? null : template.id,
      name: normalized.name,
      payload: DiaryTemplateJson.toPayload(normalized),
    );
    onTemplatesChanged();
    return id;
  }

  /// 复制为一个新的用户模板（内置模板“复制为我的模板”也走这里）。
  Future<String> duplicate(DiaryTemplate template, {required String name}) =>
      save(template.copyWith(id: '', name: name));

  /// 删除 [templateId]；它已不存在时返回 null。
  Future<DiaryTemplateDeletion?> delete(String templateId) async {
    final row = await database.getDiaryTemplate(templateId);
    if (row == null) return null;
    await database.deleteDiaryTemplates([templateId]);
    final prefs = _prefs;
    final wasAuto = prefs.autoTemplateId == templateId;
    if (wasAuto) await _savePrefs(prefs.withAuto(null));
    onTemplatesChanged();
    return (row: row, wasAuto: wasAuto);
  }

  Future<void> restore(DiaryTemplateDeletion deletion) async {
    await database.restoreDiaryTemplates([deletion.row]);
    final prefs = _prefs;
    if (deletion.wasAuto && prefs.autoTemplateId == null) {
      await _savePrefs(prefs.withAuto(deletion.row.templateId));
    }
    onTemplatesChanged();
  }

  Future<void> reorder(List<String> orderedIds) async {
    await database.reorderDiaryTemplates(orderedIds);
    onTemplatesChanged();
  }

  /// 隐藏或重新显示内置模板；返回隐藏前它是否是自动套用的模板（撤销用）。
  Future<bool> setHidden(String templateId, bool hidden) async {
    var prefs = _prefs;
    final wasAuto = hidden && prefs.autoTemplateId == templateId;
    prefs = prefs.withHidden(templateId, hidden);
    if (wasAuto) prefs = prefs.withAuto(null);
    await _savePrefs(prefs);
    return wasAuto;
  }

  /// 撤销隐藏。
  Future<void> unhide(String templateId, {required bool wasAuto}) async {
    var prefs = _prefs.withHidden(templateId, false);
    if (wasAuto && prefs.autoTemplateId == null) {
      prefs = prefs.withAuto(templateId);
    }
    await _savePrefs(prefs);
  }

  Future<void> setStripEnabled(bool enabled) =>
      _savePrefs(_prefs.withStrip(enabled));

  Future<void> setAutoTemplate(String? templateId) =>
      _savePrefs(_prefs.withAuto(templateId));

  /// 导入剪贴板里的模板码：解析成功即存为新的用户模板。
  Future<DiaryTemplateImport> importCode(String? text) async {
    final result = diaryTemplateCodeFormat.decode(text);
    final template = result.style;
    if (template == null ||
        (result.status != StyleCodeStatus.ok &&
            result.status != StyleCodeStatus.newerVersion)) {
      return (status: result.status, templateId: null, name: '');
    }
    final id = await save(template);
    return (status: result.status, templateId: id, name: template.name);
  }

  /// 撤销导入：删掉刚导入的模板。
  Future<void> removeImported(String templateId) async {
    await database.deleteDiaryTemplates([templateId]);
    onTemplatesChanged();
  }

  /// 模板码；正文太长、导入时会被拒绝的返回 null。
  String? exportCode(DiaryTemplate template) =>
      encodeDiaryTemplateCode(template);
}

/// 页面用的控制器：写入用户模板后让新建编辑页的模板快照失效。
DiaryTemplatesController createDiaryTemplatesController(
  WidgetRef ref,
  SettingsService settings,
) {
  return DiaryTemplatesController(
    database: ref.read(appDatabaseProvider),
    settings: settings,
    onTemplatesChanged: () =>
        ref.invalidate(userDiaryTemplatesSnapshotProvider),
  );
}
