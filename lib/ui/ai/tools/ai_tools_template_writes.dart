// 日记模板的写工具：新建（从零、复制模板或从日记）、修改（内置模板改后
// 存为改过的版本）、调整“我的模板”的顺序。删除、恢复默认与找回已删除的
// 内置模板见 `ai_tools_template_removals.dart`。
//
// 读写只经 `DiaryTemplatesController`（与管理页同一套：删除时一并撤下指向它
// 的自动套用，内置模板删除只记进偏好）。每个都带撤销数据：修改与新建记下
// 写完时的 payload，撤销前核对之后有没有在别处（管理页、同步）被改过，
// 改过就抛 `AiUndoConflict`，由界面问过再强制。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/publish_metadata_composer.dart';
import '../../diary_templates/controllers/diary_template_save_as.dart';
import '../../diary_templates/models/diary_template.dart';
import '../../diary_templates/providers/diary_template_providers.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../models/ai_tool_subject.dart';
import 'ai_template_markdown.dart';
import 'ai_tool.dart';
import 'ai_tool_template_facts.dart';
import 'ai_tool_template_parts.dart';
import 'ai_tool_writes.dart';

/// 参数 `id` 指向的模板的显示名（找不到时原样用 id），确认面板用。
Future<String> aiTemplateNameArg(
  Map<String, Object?> args,
  AiToolContext context,
) async {
  final id = args['id'];
  if (id is! String) return '';
  try {
    return diaryTemplateDisplayName(
      context.l10n,
      aiFindTemplate(await aiTemplateLibrary(context), id),
    );
  } on AiToolFailure {
    return id;
  }
}

/// 撤销前核对模板在写完之后没被别处改过（[expected] 为写完时的 payload）。
Future<void> aiTemplateCheckUnchanged(
  AppDatabase database,
  String id,
  Object? expected, {
  required bool force,
}) async {
  if (force || expected is! String) return;
  if (await aiTemplatePayloadOf(database, id) != expected) {
    throw const AiUndoConflict();
  }
}

class CreateTemplateTool extends AiTool {
  const CreateTemplateTool();

  @override
  String get name => 'create_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Create a diary template: from scratch, as a copy of a template '
      '(from_template_id), or from a diary entry (from_diary_id: its title, '
      'body, tags, mood and energy; photos and media are dropped). Given '
      'fields override what is copied. Template variables (list_templates '
      '`variables`) are filled in when the template is used. '
      '$aiTemplateMarkdownGuide';

  @override
  Set<String> get diaryIdArgs => const <String>{'from_diary_id'};

  @override
  AiObjectSchema get schema => AiObjectSchema(
    properties: <String, AiSchema>{
      ...aiTemplateFieldSchemas,
      'from_template_id': const AiStringSchema(),
      'from_diary_id': const AiStringSchema(),
    },
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final name = args['name'];
    return name is String && name.trim().isNotEmpty
        ? l10n.aiToolCreateTemplateNamed(name.trim())
        : l10n.aiToolCreateTemplate;
  }

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final created = subjects.where((s) => !s.input).firstOrNull;
    return created == null
        ? label(l10n, args)
        : l10n.aiToolCreateTemplateNamed(created.title);
  }

  @override
  String? argLabel(AppLocalizations l10n, String key) =>
      aiTemplateArgLabel(l10n, key);

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      aiTemplateDescribeArg(l10n, key, value);

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final fromTemplate = args['from_template_id'] as String?;
    final fromDiary = args['from_diary_id'] as String?;
    if (fromTemplate != null && fromDiary != null) {
      throw const AiToolFailure(
        'Give from_template_id or from_diary_id, not both.',
      );
    }
    final inputs = <AiToolSubject>[];
    var base = const DiaryTemplate(id: '', name: '');
    var droppedMedia = false;
    if (fromTemplate != null) {
      final source = aiFindTemplate(library, fromTemplate);
      inputs.add(aiTemplateSubject(context.l10n, source, input: true));
      base = source.copyWith(
        id: '',
        name: normalizeDiaryTemplateLine(
          context.l10n.diaryTemplatesCopyName(source.name),
          DiaryTemplate.maxNameLength,
        ),
      );
    } else if (fromDiary != null) {
      final found = await aiWritableDiary(context, fromDiary);
      inputs.add(aiDiarySubject(found.diary, input: true));
      final meta = PublishMetadataComposer.parse(found.diary.metadata);
      final draft = diaryTemplateFromEntry(
        title: found.diary.title,
        contentDocJson: found.diary.content,
        tags: found.tags,
        mood: meta.moodEmoji,
        energy: meta.energyLevel,
      );
      base = draft.template;
      droppedMedia = draft.droppedMedia;
    }
    final template = await aiTemplateWithFields(context, base, args);
    if (template.name.isEmpty) {
      throw const AiToolFailure('`name` is required.');
    }
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final id = await aiTemplatesController(
      context.container,
      settings,
    ).save(template);
    final saved = template.copyWith(id: id);
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'id': id,
        if (droppedMedia)
          'note': 'Photos and media of the entry were left out.',
      },
      summary: context.l10n.aiToolDone,
      subjects: [...inputs, aiTemplateSubject(context.l10n, saved)],
      undo: <String, Object?>{
        'id': id,
        'payload': await aiTemplatePayloadOf(context.database, id),
      },
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
    await aiTemplateCheckUnchanged(database, id, data['payload'], force: force);
    final settings = await container.read(settingsServiceProvider.future);
    await aiTemplatesController(container, settings).delete(id);
  }
}

class UpdateTemplateTool extends AiTool {
  const UpdateTemplateTool();

  @override
  String get name => 'update_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Change a diary template (by id); only the given fields change. '
      'Built-in templates can be edited too (reset_template brings the '
      'default back). `body` replaces the whole body: start from '
      'get_template\'s body and change only what is asked, so its formatting '
      'stays (format: see create_template). To clear: description "", '
      'title "", tags [], mood "", energy 0, capsule "none", color "theme", '
      'recommend {}.';

  @override
  AiObjectSchema get schema => AiObjectSchema(
    properties: <String, AiSchema>{
      'id': const AiStringSchema(),
      ...aiTemplateFieldSchemas,
    },
    required: const <String>['id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolUpdateTemplate;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) => subjects.isEmpty
      ? label(l10n, args)
      : l10n.aiToolUpdateTemplateNamed(subjects.last.title);

  @override
  String? argLabel(AppLocalizations l10n, String key) =>
      aiTemplateArgLabel(l10n, key);

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      aiTemplateDescribeArg(l10n, key, value);

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async => AiToolPreview(
    title: context.l10n.aiToolUpdateTemplateNamed(
      await aiTemplateNameArg(args, context),
    ),
  );

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final library = await aiTemplateLibrary(context);
    final template = aiFindTemplate(library, args['id']! as String);
    final before = await aiTemplatePayloadOf(database, template.id);
    final next = await aiTemplateWithFields(context, template, args);
    final subject = aiTemplateSubject(context.l10n, next);
    if (next == template) {
      return AiToolOutcome(
        data: const <String, Object?>{'ok': true, 'note': 'Nothing changed.'},
        summary: context.l10n.aiToolDone,
        subjects: [subject],
        undo: <String, Object?>{'id': template.id, 'unchanged': true},
      );
    }
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    await aiTemplatesController(context.container, settings).save(next);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [subject],
      undo: <String, Object?>{
        'id': template.id,
        'before': before,
        'after': await aiTemplatePayloadOf(database, template.id),
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    if (data['unchanged'] == true) return;
    final database = container.read(appDatabaseProvider);
    final id = data['id']! as String;
    await aiTemplateCheckUnchanged(database, id, data['after'], force: force);
    final before = data['before'];
    if (before is String) {
      await aiWriteTemplatePayload(database, id, before);
    } else {
      // 改之前是内置模板的默认内容：删掉改过的那一行即回到默认。
      await database.deleteDiaryTemplates([id]);
    }
    container.invalidate(userDiaryTemplatesSnapshotProvider);
  }
}

class ReorderTemplatesTool extends AiTool {
  const ReorderTemplatesTool();

  @override
  String get name => 'reorder_templates';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Reorder the user\'s own templates: the listed ids come first in this '
      'order, the rest keep their order after them. Built-in templates keep '
      'their fixed order after the user\'s own.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolReorderTemplates;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final picked = <DiaryTemplate>[];
    for (final raw in (args['ids']! as List).cast<String>()) {
      final template = aiFindTemplate(library, raw);
      if (template.isBuiltIn) {
        throw AiToolFailure(
          '${template.id} is built in; built-in templates keep their order.',
        );
      }
      if (!picked.contains(template)) picked.add(template);
    }
    final before = [
      for (final row in await context.database.getDiaryTemplates())
        row.templateId,
    ];
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    await aiTemplatesController(
      context.container,
      settings,
    ).reorder([for (final template in picked) template.id]);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [
        for (final template in picked)
          aiTemplateSubject(context.l10n, template),
      ],
      undo: <String, Object?>{'before': before},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    await aiTemplatesController(
      container,
      settings,
    ).reorder(aiUndoStrings(data['before']));
  }
}
