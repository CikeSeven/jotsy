import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/style_library/style_code.dart';
import '../models/diary_template.dart';
import '../models/diary_template_auto_rule.dart';
import '../models/diary_template_code.dart';
import '../models/diary_template_json.dart';
import '../models/diary_template_prefs.dart';
import '../providers/diary_template_providers.dart';

/// 删除或隐藏一个模板时一并撤下的自动套用设置：它是否是默认模板，以及
/// 指向它的时间段规则。撤销时据此放回。
typedef DiaryTemplateAutoRemoval = ({
  bool wasAuto,
  List<DiaryTemplateAutoRule> rules,
});

/// 删除一个模板（或内置模板恢复默认）留下的记录：撤销时原样写回这一行，
/// 并放回撤下的自动套用设置（见 [DiaryTemplateAutoRemoval]）。
typedef DiaryTemplateDeletion = ({
  DiaryTemplateRow row,
  DiaryTemplateAutoRemoval auto,
});

/// 导入模板码的结果：[templateId] 为新存下的模板（导入失败时为 null）。
typedef DiaryTemplateImport = ({
  StyleCodeStatus status,
  String? templateId,
  String name,
});

/// 模板管理的读写：保存、复制、删除与撤销、排序、内置模板的编辑 / 恢复
/// 默认 / 删除与恢复、偏好与模板码。不构建 UI，确认与提示由页面负责。
///
/// 内置模板：编辑后以同一个 id 存进数据库（替换默认内容，自动套用与最近
/// 使用的指向不变），恢复默认即删掉这一行；删除只记进偏好的 `hidden`
/// （默认内容不在库里，删无可删），恢复时移出即可，改过的内容一直留在库里。
///
/// 每次写入模板行后调用 [onTemplatesChanged]：新建编辑页的建议条读的是
/// 一次性快照（见 `userDiaryTemplatesSnapshotProvider`），需要据此刷新。
///
/// 偏好每次都从设置原文重新解码再写回，不依赖页面手里可能过时的值。删除
/// 一个模板（含内置模板）时，一并清空指向它的默认模板与时间段规则——否则
/// 新建日记会套用一个已经不在列表里的模板；撤销时只放回仍空着的默认模板与
/// 本机还没有的规则（撤销前用户可能已经重新设置过）。
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

  /// 保存 [template]；id 为空时另存为新的用户模板，内置模板以原 id 保存为
  /// 改过的版本。返回模板 id。正文在写入前再清洗一次，名称按长度上限截断。
  Future<String> save(DiaryTemplate template) async {
    final isNew = template.id.isEmpty;
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

  /// 复制为一个新的用户模板（内置模板的“复制”也走这里）。
  Future<String> duplicate(DiaryTemplate template, {required String name}) =>
      save(template.copyWith(id: '', name: name));

  /// 删除 [templateId]；它已不存在时返回 null。
  Future<DiaryTemplateDeletion?> delete(String templateId) async {
    final row = await database.getDiaryTemplate(templateId);
    if (row == null) return null;
    await database.deleteDiaryTemplates([templateId]);
    final (prefs, removed) = _withoutAuto(_prefs, templateId);
    if (removed.wasAuto || removed.rules.isNotEmpty) await _savePrefs(prefs);
    onTemplatesChanged();
    return (row: row, auto: removed);
  }

  /// 改过的内置模板恢复默认：删掉它在库里的行；没改过时返回 null。自动套用
  /// 设置不动——id 没变，指向的仍是这个模板。
  Future<DiaryTemplateDeletion?> resetBuiltIn(String templateId) async {
    if (!templateId.startsWith(builtInDiaryTemplateIdPrefix)) return null;
    final row = await database.getDiaryTemplate(templateId);
    if (row == null) return null;
    await database.deleteDiaryTemplates([templateId]);
    onTemplatesChanged();
    return (
      row: row,
      auto: (wasAuto: false, rules: const <DiaryTemplateAutoRule>[]),
    );
  }

  /// 撤销删除或恢复默认：原样写回那一行。
  Future<void> restore(DiaryTemplateDeletion deletion) async {
    await database.restoreDiaryTemplates([deletion.row]);
    final prefs = _prefs;
    final restored = _withAutoRestored(
      prefs,
      deletion.row.templateId,
      deletion.auto,
    );
    if (restored != prefs) await _savePrefs(restored);
    onTemplatesChanged();
  }

  Future<void> reorder(List<String> orderedIds) async {
    await database.reorderDiaryTemplates(orderedIds);
    onTemplatesChanged();
  }

  /// 删除内置模板（记进偏好的 `hidden`），返回一并撤下的自动套用设置，
  /// 撤销时交给 [undoDeleteBuiltIn]。
  Future<DiaryTemplateAutoRemoval> deleteBuiltIn(String templateId) async {
    final (prefs, removed) = _withoutAuto(
      _prefs.withHidden(templateId, true),
      templateId,
    );
    await _savePrefs(prefs);
    return removed;
  }

  /// 撤销删除内置模板，并放回删除时撤下的自动套用设置。
  Future<void> undoDeleteBuiltIn(
    String templateId, {
    required DiaryTemplateAutoRemoval removed,
  }) async {
    final prefs = _prefs.withHidden(templateId, false);
    await _savePrefs(_withAutoRestored(prefs, templateId, removed));
  }

  /// 从“已删除的内置模板”里恢复：移出 `hidden`，不放回任何自动套用设置
  /// （删除时撤下的设置只随撤销放回）。
  Future<void> restoreBuiltIns(Iterable<String> templateIds) async {
    final prefs = _prefs;
    final next = templateIds.fold(prefs, (p, id) => p.withHidden(id, false));
    if (next != prefs) await _savePrefs(next);
  }

  /// 去掉指向 [templateId] 的默认模板与时间段规则。
  (DiaryTemplatePrefs, DiaryTemplateAutoRemoval) _withoutAuto(
    DiaryTemplatePrefs prefs,
    String templateId,
  ) {
    final wasAuto = prefs.autoTemplateId == templateId;
    final rules = prefs.autoRulesFor(templateId);
    var next = prefs;
    if (wasAuto) next = next.withAuto(null);
    if (rules.isNotEmpty) {
      next = next.withAutoRules(
        prefs.autoRules.where((rule) => rule.templateId != templateId),
      );
    }
    return (next, (wasAuto: wasAuto, rules: rules));
  }

  /// 放回 [removed]：默认模板只在仍空着时放回，规则只放回本机还没有的
  /// （上限内）。
  DiaryTemplatePrefs _withAutoRestored(
    DiaryTemplatePrefs prefs,
    String templateId,
    DiaryTemplateAutoRemoval removed,
  ) {
    var next = prefs;
    if (removed.wasAuto && next.autoTemplateId == null) {
      next = next.withAuto(templateId);
    }
    if (removed.rules.isNotEmpty) {
      next = next.withAutoRules(<DiaryTemplateAutoRule>[
        ...next.autoRules,
        ...removed.rules,
      ]);
    }
    return next;
  }

  Future<void> setStripEnabled(bool enabled) =>
      _savePrefs(_prefs.withStrip(enabled));

  Future<void> setAutoTemplate(String? templateId) =>
      _savePrefs(_prefs.withAuto(templateId));

  /// 保存一条时间段规则；[replacing] 为正在编辑的原规则（新增时为 null）。
  /// 已有一模一样的规则时不重复添加；新增时已满 [DiaryTemplatePrefs.maxAutoRules]
  /// 条则不保存，返回 false。
  Future<bool> saveAutoRule(
    DiaryTemplateAutoRule rule, {
    DiaryTemplateAutoRule? replacing,
  }) async {
    if (!rule.isValid) return false;
    final prefs = _prefs;
    final rest = prefs.autoRules.where((item) => item != replacing).toList();
    if (!rest.contains(rule) &&
        rest.length >= DiaryTemplatePrefs.maxAutoRules) {
      return false;
    }
    await _savePrefs(
      prefs.withAutoRules(<DiaryTemplateAutoRule>[...rest, rule]),
    );
    return true;
  }

  /// 删除一条时间段规则；返回被删的规则（撤销用），它已不存在时为 null。
  Future<DiaryTemplateAutoRule?> deleteAutoRule(
    DiaryTemplateAutoRule rule,
  ) async {
    final prefs = _prefs;
    if (!prefs.autoRules.contains(rule)) return null;
    await _savePrefs(
      prefs.withAutoRules(prefs.autoRules.where((item) => item != rule)),
    );
    return rule;
  }

  /// 撤销删除：本机已有同样的规则或已满时什么也不做。
  Future<void> restoreAutoRule(DiaryTemplateAutoRule rule) async {
    final prefs = _prefs;
    if (prefs.autoRules.contains(rule) ||
        prefs.autoRules.length >= DiaryTemplatePrefs.maxAutoRules) {
      return;
    }
    await _savePrefs(
      prefs.withAutoRules(<DiaryTemplateAutoRule>[...prefs.autoRules, rule]),
    );
  }

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
