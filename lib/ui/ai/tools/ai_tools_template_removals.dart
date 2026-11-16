// 日记模板的删除类与找回：删除模板（内置模板只记进偏好，可找回）、把改过
// 的内置模板恢复默认（删除类，先确认），以及找回已删除的内置模板。
//
// 都经 `DiaryTemplatesController`（删除时一并撤下指向它的自动套用，撤销
// 时放回）。撤销前若同一个 id 在那之后又有了内容（再次修改、同步、备份
// 恢复），原样写回会盖掉它，先抛 `AiUndoConflict` 由界面问过再强制。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diary_templates/models/diary_template.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_template_parts.dart';
import 'ai_tool_writes.dart';
import 'ai_tools_template_writes.dart';

class DeleteTemplateTool extends AiTool {
  const DeleteTemplateTool();

  @override
  String get name => 'delete_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Delete a diary template. A deleted built-in template can be brought '
      'back with restore_templates. The default template and time-range '
      'rules pointing to it are removed too. The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{'id': AiStringSchema()},
    required: <String>['id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolDeleteTemplate;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) => subjects.isEmpty
      ? label(l10n, args)
      : l10n.aiToolDeleteTemplateNamed(subjects.single.title);

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final template = aiFindTemplate(library, args['id']! as String);
    final prefs = library.prefs;
    final automatic =
        prefs.autoTemplateId == template.id ||
        prefs.autoRulesFor(template.id).isNotEmpty;
    return AiToolPreview(
      title: context.l10n.aiToolDeleteTemplateNamed(
        diaryTemplateDisplayName(context.l10n, template),
      ),
      lines: [
        if (template.description.isNotEmpty) template.description,
        if (automatic) context.l10n.aiToolDeleteTemplateAuto,
      ],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final template = aiFindTemplate(library, args['id']! as String);
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final controller = aiTemplatesController(context.container, settings);
    final Map<String, Object?> undo;
    if (template.isBuiltIn) {
      final removed = await controller.deleteBuiltIn(template.id);
      undo = <String, Object?>{
        'id': template.id,
        'builtIn': true,
        'auto': aiTemplateAutoRemovalJson(removed),
      };
    } else {
      final deletion = await controller.delete(template.id);
      if (deletion == null) {
        throw const AiToolFailure('That template no longer exists.');
      }
      undo = <String, Object?>{
        'id': template.id,
        'row': deletion.row.toJson(),
        'auto': aiTemplateAutoRemovalJson(deletion.auto),
      };
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        if (template.isBuiltIn)
          'note': 'It can be restored with restore_templates.',
      },
      summary: context.l10n.aiToolDone,
      subjects: [aiTemplateSubject(context.l10n, template, input: true)],
      undo: undo,
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    final controller = aiTemplatesController(container, settings);
    final id = data['id']! as String;
    final removed = aiTemplateAutoRemovalFrom(data['auto']);
    if (data['builtIn'] == true) {
      await controller.undoDeleteBuiltIn(id, removed: removed);
      return;
    }
    // 之后又以同一个 id 存进了模板（同步、备份恢复）：原样写回会盖掉它。
    final database = container.read(appDatabaseProvider);
    if (!force && await database.getDiaryTemplate(id) != null) {
      throw const AiUndoConflict();
    }
    await controller.restore((
      row: aiTemplateRowFrom(data['row']),
      auto: removed,
    ));
  }
}

class ResetTemplateTool extends AiTool {
  const ResetTemplateTool();

  @override
  String get name => 'reset_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Bring an edited built-in template back to its default content '
      '(edits are discarded). The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{'id': AiStringSchema()},
    required: <String>['id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolResetTemplate;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) => subjects.isEmpty
      ? label(l10n, args)
      : l10n.aiToolResetTemplateNamed(subjects.single.title);

  Future<String> _edited(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final template = aiFindTemplate(library, args['id']! as String);
    if (!library.editedBuiltIns.contains(template.id)) {
      throw const AiToolFailure(
        'Only an edited built-in template can be reset; this one is not.',
      );
    }
    return template.id;
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    await _edited(context, args);
    return AiToolPreview(
      title: context.l10n.aiToolResetTemplateNamed(
        await aiTemplateNameArg(args, context),
      ),
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final id = await _edited(context, args);
    final library = await aiTemplateLibrary(context);
    final edited = library.byId(id)!;
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final deletion = await aiTemplatesController(
      context.container,
      settings,
    ).resetBuiltIn(id);
    if (deletion == null) {
      throw const AiToolFailure('That template is not edited.');
    }
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [aiTemplateSubject(context.l10n, edited, input: true)],
      undo: <String, Object?>{'id': id, 'row': deletion.row.toJson()},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final id = data['id']! as String;
    // 之后又改过一次（库里又有了这一行）：写回旧的会盖掉新改的。
    if (!force && await database.getDiaryTemplate(id) != null) {
      throw const AiUndoConflict();
    }
    final settings = await container.read(settingsServiceProvider.future);
    await aiTemplatesController(container, settings).restore((
      row: aiTemplateRowFrom(data['row']),
      auto: (wasAuto: false, rules: const []),
    ));
  }
}

class RestoreTemplatesTool extends AiTool {
  const RestoreTemplatesTool();

  @override
  String get name => 'restore_templates';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Bring deleted built-in templates back (ids from list_templates '
      '`deleted_built_ins`), with any edits made before they were deleted.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 20),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolRestoreTemplates(ids is List ? ids.length : 0);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final deleted = library.deletedBuiltIns;
    final picked = <DiaryTemplate>[];
    for (final raw in (args['ids']! as List).cast<String>()) {
      final key = raw.trim();
      final match = deleted
          .where(
            (t) => t.id == key || t.name.toLowerCase() == key.toLowerCase(),
          )
          .firstOrNull;
      if (match == null) {
        throw AiToolFailure(
          '"$key" is not a deleted built-in template. Deleted ones: '
          '${deleted.isEmpty ? 'none' : deleted.map((t) => t.id).join(', ')}.',
        );
      }
      if (!picked.contains(match)) picked.add(match);
    }
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    await aiTemplatesController(
      context.container,
      settings,
    ).restoreBuiltIns([for (final template in picked) template.id]);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [
        for (final template in picked)
          aiTemplateSubject(context.l10n, template),
      ],
      undo: <String, Object?>{
        'ids': [for (final template in picked) template.id],
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    final controller = aiTemplatesController(container, settings);
    for (final id in aiUndoStrings(data['ids'])) {
      await controller.deleteBuiltIn(id);
    }
  }
}
