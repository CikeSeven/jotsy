// 整理类的只读工具：标签与日记本。
//
// AI 隐私里排除的标签与日记本、以及私密 / 上锁的日记本（含子本）不出现在
// 列表里：连名字都可能是隐私。

import '../../../core/database/notebook_payload.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../l10n/app_localizations.dart';
import 'ai_tool.dart';

class ListTagsTool extends AiTool {
  const ListTagsTool();

  @override
  String get name => 'list_tags';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      "List the user's tags with how many entries use each, most used first.";

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolListTags;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final excluded = context.prefs.privacy.excludedTagNames;
    final tags = await database.watchAllTags().first;
    final uses = <int, int>{
      for (final count in await database.watchTagUsageCounts().first)
        count.tagId: count.uses,
    };
    final visible = [
      for (final tag in tags)
        if (!excluded.contains(tag.name)) tag,
    ]..sort((a, b) => (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0));
    return AiToolOutcome(
      data: <String, Object?>{
        'tags': [
          for (final tag in visible)
            <String, Object?>{'name': tag.name, 'entries': uses[tag.id] ?? 0},
        ],
      },
      summary: context.l10n.aiToolTagCount(visible.length),
    );
  }
}

class ListNotebooksTool extends AiTool {
  const ListNotebooksTool();

  @override
  String get name => 'list_notebooks';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      "List the user's notebooks (tree order) with id, kind, parent and "
      'entry count. Manual notebooks hold chosen entries; smart notebooks '
      'gather entries by rules. Private notebooks are not listed.';

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolListNotebooks;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final tree = await context.notebookTree();
    final excluded = context.prefs.privacy.excludedNotebookIds;
    final counts = await context.database
        .watchManualNotebookEntryCounts()
        .first;
    final visible = [
      for (final notebook in tree.depthFirst)
        if (!notebook.isPrivate && !excluded.contains(notebook.id)) notebook,
    ];
    return AiToolOutcome(
      data: <String, Object?>{
        'notebooks': [
          for (final notebook in visible)
            <String, Object?>{
              'id': notebook.id,
              'name': notebook.name,
              'kind': notebook.kind == NotebookKind.smart ? 'smart' : 'manual',
              'parent_id': ?notebook.parentId,
              if (notebook.isManual) 'entries': counts[notebook.id] ?? 0,
              if (notebook.isClosed) 'closed': true,
            },
        ],
      },
      summary: context.l10n.aiToolNotebookCount(visible.length),
    );
  }
}
