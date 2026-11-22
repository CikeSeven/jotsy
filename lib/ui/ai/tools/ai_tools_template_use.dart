// 日记模板的“用法”：新建空白日记时自动套用哪个模板（默认模板与按时间段
// 的规则）、日记本的默认模板，以及按模板直接写一篇日记。
//
// - 自动套用只经 `DiaryTemplatePrefs`（与自动套用页同一个设置键），每次在
//   最新的偏好上只改默认模板与规则，撤销同样只写回这两项；
// - 日记本只动非私密、没被 AI 隐私排除的（与其他日记本工具同一口径），只改
//   payload 的 `templateId`；
// - 按模板写日记与新建编辑页套用同一套展开（`DiaryTemplateVariableValues`：
//   变量按日记日期替换，预设只用本机认得的心情，胶囊在功能开着时才设），
//   写库与撤销同 `create_diary`（`publishNewDiaryDirectly`）。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/controllers/publish_new_diary_directly.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diary_templates/models/diary_template.dart';
import '../../diary_templates/models/diary_template_auto_rule.dart';
import '../../diary_templates/models/diary_template_blocks.dart';
import '../../diary_templates/models/diary_template_prefs.dart';
import '../../diary_templates/providers/diary_template_providers.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../../diary_templates/viewmodels/diary_template_variable_values.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../models/ai_tool_subject.dart';
import 'ai_template_markdown_parse.dart';
import 'ai_tool.dart';
import 'ai_tool_template_facts.dart';
import 'ai_tool_template_parts.dart';
import 'ai_tool_writes.dart';
import 'ai_tools_diary_writes.dart';
import 'ai_tools_notebook_chapters.dart';
import 'ai_tools_organize_writes.dart';

const AiObjectSchema _ruleSchema = AiObjectSchema(
  properties: <String, AiSchema>{
    'from': AiTimeSchema(),
    'to': AiTimeSchema(),
    'weekdays': AiArraySchema(
      items: AiIntegerSchema(minimum: 1, maximum: 7),
      description: '1 = Monday … 7 = Sunday; empty = every day.',
    ),
    'template_id': AiStringSchema(),
  },
  required: <String>['from', 'to', 'template_id'],
);

class SetTemplateAutoApplyTool extends AiTool {
  const SetTemplateAutoApplyTool();

  @override
  String get name => 'set_template_auto_apply';

  /// 是模板的偏好（与设置同一类卡片）；涉及的模板仍记作对象。
  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Choose which template a new blank entry starts with. Time-range rules '
      'apply only when writing today\'s entry: from–to (to earlier than from '
      'runs past midnight), optional weekdays (by the day the range starts). '
      'When several match, rules with weekdays win, then the shorter range. '
      'The default template covers all other times and other days ("" turns '
      'it off). At most ${DiaryTemplatePrefs.maxAutoRules} rules. Remove a '
      'rule by repeating it as list_templates shows it, or clear them all.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'default_template_id': AiStringSchema(allowEmpty: true),
      'add_rules': AiArraySchema(
        items: _ruleSchema,
        maxItems: DiaryTemplatePrefs.maxAutoRules,
      ),
      'remove_rules': AiArraySchema(
        items: _ruleSchema,
        maxItems: DiaryTemplatePrefs.maxAutoRules,
      ),
      'clear_rules': AiBooleanSchema(),
    },
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolSetTemplateAutoApply;

  @override
  String? argLabel(AppLocalizations l10n, String key) =>
      aiTemplateArgLabel(l10n, key);

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      key == 'default_template_id' && value == ''
      ? l10n.diaryTemplatesAutoApplyNone
      : aiTemplateDescribeArg(l10n, key, value);

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final before = DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);
    final subjects = <AiToolSubject>[];
    void touched(DiaryTemplate template) {
      final subject = aiTemplateSubject(context.l10n, template);
      if (!subjects.contains(subject)) subjects.add(subject);
    }

    var next = before;
    if (args['default_template_id'] case final String id) {
      if (id.trim().isEmpty) {
        next = next.withAuto(null);
      } else {
        final template = aiFindTemplate(library, id);
        touched(template);
        next = next.withAuto(template.id);
      }
    }

    DiaryTemplateAutoRule rule(Object? raw, {required bool adding}) {
      final map = (raw! as Map).cast<String, Object?>();
      final key = map['template_id']! as String;
      // 删除时也认指向已删除模板的规则：找不到模板就按原样的 id 比对。
      DiaryTemplate? template;
      try {
        template = aiFindTemplate(library, key);
      } on AiToolFailure {
        if (adding) rethrow;
      }
      if (template != null) touched(template);
      final result = DiaryTemplateAutoRule(
        startMinute: map['from']! as int,
        endMinute: map['to']! as int,
        weekdays: Set<int>.unmodifiable(<int>{
          for (final day in map['weekdays'] as List? ?? const []) day as int,
        }),
        templateId: template?.id ?? key,
      );
      if (!result.isValid) {
        throw const AiToolFailure(
          'A rule cannot start and end at the same time.',
        );
      }
      return result;
    }

    final rules = <DiaryTemplateAutoRule>[
      if (args['clear_rules'] != true) ...before.autoRules,
    ];
    for (final raw in args['remove_rules'] as List? ?? const []) {
      final target = rule(raw, adding: false);
      if (!rules.remove(target)) {
        throw AiToolFailure(
          'No such rule. Current rules: ${jsonEncode([for (final r in before.autoRules) aiTemplateRuleJson(r)])}',
        );
      }
    }
    for (final raw in args['add_rules'] as List? ?? const []) {
      final added = rule(raw, adding: true);
      if (!rules.contains(added)) rules.add(added);
    }
    if (rules.length > DiaryTemplatePrefs.maxAutoRules) {
      throw const AiToolFailure(
        'At most ${DiaryTemplatePrefs.maxAutoRules} rules; remove some first.',
      );
    }
    next = next.withAutoRules(rules);
    await saveDiaryTemplatePrefs(settings, next);
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'default_template_id': ?next.autoTemplateId,
        'rules': [for (final r in next.autoRules) aiTemplateRuleJson(r)],
      },
      summary: context.l10n.aiToolDone,
      subjects: subjects,
      undo: <String, Object?>{
        'auto': before.autoTemplateId,
        'rules': [for (final r in before.autoRules) r.toJson()],
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
    final current = DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);
    final rules = data['rules'];
    await saveDiaryTemplatePrefs(
      settings,
      current.withAuto(data['auto'] as String?).withAutoRules([
        if (rules is List)
          for (final rule in rules) ?DiaryTemplateAutoRule.fromJson(rule),
      ]),
    );
  }
}

class SetNotebookTemplateTool extends AiTool {
  const SetNotebookTemplateTool();

  @override
  String get name => 'set_notebook_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Set the template a new blank entry starts with inside a notebook '
      '(it wins over the auto-apply settings); "" removes it.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'template_id': AiStringSchema(allowEmpty: true),
    },
    required: <String>['notebook_id', 'template_id'],
  );

  @override
  bool isAvailable(AiToolEnv env) =>
      env.features.templates && env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolSetNotebookTemplate;

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      key == 'template_id' && value == '' ? l10n.notebookTemplateNone : null;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final id = args['notebook_id']! as String;
    final notebook = (await context.notebookTree())[id];
    if (notebook == null ||
        notebook.isPrivate ||
        context.prefs.privacy.excludedNotebookIds.contains(id)) {
      throw const AiToolFailure(
        'No such notebook, or it is private (private notebooks must be '
        'changed by the user). Call list_notebooks.',
      );
    }
    final key = (args['template_id']! as String).trim();
    final template = key.isEmpty
        ? null
        : aiFindTemplate(await aiTemplateLibrary(context), key);
    final before = notebook.payload.templateId;
    await context.database.updateNotebook(
      id,
      payload: template == null
          ? notebook.payload.copyWith(clearTemplateId: true)
          : notebook.payload.copyWith(templateId: template.id),
    );
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [
        AiToolSubject.notebook(id, notebook.name),
        if (template != null) aiTemplateSubject(context.l10n, template),
      ],
      undo: <String, Object?>{'id': id, 'before': before},
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
    final row = await database.getNotebook(id);
    if (row == null) return;
    final before = data['before'] as String?;
    await database.updateNotebook(
      id,
      payload: before == null
          ? row.parsedPayload.copyWith(clearTemplateId: true)
          : row.parsedPayload.copyWith(templateId: before),
    );
  }
}

class CreateDiaryFromTemplateTool extends AiTool {
  const CreateDiaryFromTemplateTool();

  @override
  String get name => 'create_diary_from_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Write a new diary entry from a template, as if the user picked it in '
      'the editor: variables are filled in for the entry\'s date and the '
      'template\'s tags, mood, energy and time capsule are set. Pass `body` '
      'with the template filled in (start from get_template\'s body, keep '
      'its format; template Markdown). `title` overrides the title pattern, '
      '`tags` are added, `mood` overrides. Dates work as in create_diary. To '
      'let the user fill a template in, use open_page new_diary instead.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'template_id': AiStringSchema(),
      'body': AiStringSchema(allowEmpty: true),
      'title': AiStringSchema(maxLength: 200, allowEmpty: true),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'tags': AiArraySchema(items: AiStringSchema(maxLength: 40), maxItems: 20),
      'mood': AiStringSchema(),
      'notebook_id': AiStringSchema(),
      'chapter_id': AiStringSchema(
        description:
            'Optional chapter (id or unique title) inside `notebook_id`.',
      ),
    },
    required: <String>['template_id', 'body'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateDiary;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final template = subjects
        .where((s) => s.kind == AiSubjectKind.template)
        .firstOrNull;
    return template == null
        ? label(l10n, args)
        : l10n.aiToolWriteWithTemplate(template.title);
  }

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      aiTemplateDescribeArg(l10n, key, value);

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final template = aiFindTemplate(
      await aiTemplateLibrary(context),
      args['template_id']! as String,
    );
    return AiToolPreview(
      title: context.l10n.aiToolWriteWithTemplate(
        diaryTemplateDisplayName(context.l10n, template),
      ),
      lines: [
        if (args['date'] case final DateTime date) aiToolDate(date),
        if (aiTemplateDescribeArg(context.l10n, 'body', args['body'])
            case final String text when text.isNotEmpty)
          text.split('\n').first,
      ],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final features = context.env.features;
    final template = aiFindTemplate(
      await aiTemplateLibrary(context),
      args['template_id']! as String,
    );
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    final DateTime? requested = date == null
        ? null
        : minute == null
        ? date
        : DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
    // 将来的日期发表时回落到现在，变量也按现在算。
    final diaryDate = requested == null || requested.isAfter(context.now)
        ? context.now
        : requested;
    final values = DiaryTemplateVariableValues.compute(
      l10n: context.l10n,
      diaryDate: diaryDate,
      now: context.now,
    );
    final document = resolveDiaryTemplateBlockText(
      aiTemplateBodyFromMarkdown(args['body']! as String),
      values.resolve,
    );
    final title = values.resolve(
      (args['title'] as String?)?.trim() ?? template.titlePattern,
    );

    final mood = await _mood(context, settings, args['mood'], template);
    final notebookId = args['notebook_id'] as String?;
    final chapterRef = args['chapter_id'] as String?;
    if (chapterRef != null && notebookId == null) {
      throw const AiToolFailure('`chapter_id` requires `notebook_id`.');
    }
    NotebookView? notebook;
    NotebookChapter? chapter;
    if (notebookId != null) {
      notebook = await aiOpenManualNotebook(context, notebookId);
      if (chapterRef != null) {
        chapter = aiResolveNotebookChapter(
          notebook.payload.chapters,
          chapterRef,
        );
      }
    }
    final tags = await database.ensureTagsByName([
      for (final tag in template.tags) (name: tag.name, color: tag.color),
      for (final name in (args['tags'] as List?)?.cast<String>() ?? const [])
        (name: name, color: aiDefaultTagColor),
    ]);
    final capsule = features.timeCapsules ? template.capsule : null;
    final id = await publishNewDiaryDirectly(
      database: database,
      draft: NewDiaryDraft(
        title: title,
        contentDocJson: encodeDiaryBlocks(document),
        contentText: diaryBlocksPlainText(document),
        createdAtOverride: requested,
        selectedTagIds: tags.ids.values.toSet(),
        notebookIds: [?notebookId],
        notebookChapterIds: chapter == null
            ? const <String, String>{}
            : <String, String>{notebookId!: chapter.id},
        moodEmoji: mood,
        energyLevel: template.energy?.toDouble(),
        capsuleUnlockAt: capsule == null
            ? null
            : TimeCapsuleSchedule.normalizeUnlockAt(
                TimeCapsuleSchedule.presetUnlockAt(capsule, context.now),
                precision: TimeCapsulePrecision.date,
              ),
        capsulePrecision: capsule == null
            ? null
            : TimeCapsuleSchedule.encodePrecision(TimeCapsulePrecision.date),
      ),
      timeCapsulesEnabled: features.timeCapsules,
      notebooksEnabled: features.notebooks,
    );
    await recordDiaryTemplateUse(settings, template.id);
    final created = (await database.getDiaryWithTagsByDiaryId(id))!.diary;
    if (tags.created.isNotEmpty) aiRefreshTags(context.container);
    final ref = context.citations.refFor(
      id,
      title: created.title,
      date: created.createdAt,
    );
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'id': id,
        'ref': ref,
        'date': aiToolDateTime(created.createdAt),
        'chapter_id': ?chapter?.id,
        if (capsule != null)
          'note': 'Sealed as a time capsule (${capsule.name}) by the template.',
      },
      summary: context.l10n.aiToolDiaryCreated(
        created.title.trim().isEmpty
            ? aiToolDate(created.createdAt)
            : created.title.trim(),
      ),
      subjects: [
        aiTemplateSubject(context.l10n, template, input: true),
        if (notebook != null)
          AiToolSubject.notebook(notebook.id, notebook.name, input: true),
        aiDiarySubject(created),
      ],
      // 与 create_diary 同一份撤销数据，撤销也交给它。
      undo: <String, Object?>{
        'id': id,
        'fingerprint': aiDiaryFingerprint(created),
        'createdTags': tags.created.toList(),
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => const CreateDiaryTool().undo(container, data, force: force);

  /// 心情：给了就必须是用户的心情选项；没给时用模板的（不在选项里就不设，
  /// 与编辑页套用同一口径）。
  static Future<String?> _mood(
    AiToolContext context,
    SettingsService settings,
    Object? raw,
    DiaryTemplate template,
  ) async {
    final options = settings.moodOptions;
    if (raw is String && raw.trim().isNotEmpty) {
      if (!options.contains(raw.trim())) {
        throw AiToolFailure(
          "`mood` must be one of the user's mood options: ${options.join(' ')}",
        );
      }
      return raw.trim();
    }
    final preset = template.mood;
    return preset != null && options.contains(preset) ? preset : null;
  }
}
