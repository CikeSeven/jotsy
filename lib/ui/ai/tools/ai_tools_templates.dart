// 日记模板的查询工具：模板列表（含自动套用、建议条、变量写法与日记本的
// 默认模板）与单个模板的全部设置和正文。改动类见
// `ai_tools_template_writes.dart` 与 `ai_tools_template_use.dart`。

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../l10n/app_localizations.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_template_parts.dart';

class ListTemplatesTool extends AiTool {
  const ListTemplatesTool();

  @override
  String get name => 'list_templates';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'List diary templates (the user\'s own first, then built-in ones; '
      'bodies via get_template), deleted built-in templates, the auto-apply '
      'settings (default template and time-range rules for new blank '
      'entries), notebooks\' default templates, and how to write each '
      'template variable in the app language.';

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolListTemplates;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final prefs = library.prefs;
    final notebooks = <Map<String, Object?>>[];
    if (context.env.features.notebooks) {
      final tree = await context.notebookTree();
      for (final notebook in tree.depthFirst) {
        final templateId = notebook.payload.templateId;
        if (templateId == null ||
            notebook.isPrivate ||
            context.prefs.privacy.excludedNotebookIds.contains(notebook.id)) {
          continue;
        }
        notebooks.add(<String, Object?>{
          'notebook_id': notebook.id,
          'notebook': notebook.name,
          'template_id': templateId,
          if (library.byId(templateId) == null) 'template_missing': true,
        });
      }
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'templates': [
          for (final template in library.visible)
            aiTemplateJson(template, library),
        ],
        if (library.deletedBuiltIns.isNotEmpty)
          'deleted_built_ins': [
            for (final template in library.deletedBuiltIns)
              <String, Object?>{'id': template.id, 'name': template.name},
          ],
        'auto_apply': <String, Object?>{
          'default_template_id': ?library.autoTemplate?.id,
          'rules': [
            for (final rule in prefs.autoRules) aiTemplateRuleJson(rule),
          ],
        },
        'suggestions_on_new_entry': prefs.showStrip,
        if (notebooks.isNotEmpty) 'notebook_defaults': notebooks,
        'variables': aiTemplateVariables(context.l10n),
      },
      summary: context.l10n.aiToolTemplateCount(library.visible.length),
    );
  }
}

class GetTemplateTool extends AiTool {
  const GetTemplateTool();

  @override
  String get name => 'get_template';

  @override
  AiToolGroup get group => AiToolGroup.templates;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Read diary templates in full (by id): every setting and the body in '
      'template Markdown, exactly as update_template takes it back.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 10),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.templates;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolGetTemplates;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) => subjects.length == 1
      ? l10n.aiToolGetTemplate(subjects.single.title)
      : label(l10n, args);

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final library = await aiTemplateLibrary(context);
    final templates = [
      for (final id in (args['ids']! as List).cast<String>())
        aiFindTemplate(library, id),
    ];
    return AiToolOutcome(
      data: <String, Object?>{
        'templates': [
          for (final template in templates)
            aiTemplateJson(template, library, body: true),
        ],
      },
      subjects: [
        for (final template in templates)
          aiTemplateSubject(context.l10n, template, input: true),
      ],
      summary: templates.length == 1
          ? diaryTemplateDisplayName(context.l10n, templates.single)
          : null,
    );
  }
}
