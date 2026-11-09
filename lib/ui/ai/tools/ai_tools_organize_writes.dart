// 整理类的写工具：标签与日记本。
//
// - 标签：新建、改名 / 改色、合并（删除类，先确认）、删除（删除类，先确认）。
//   合并与删除都覆盖私密与回收站里的日记（只改关联，不读内容），并与标签
//   管理页一样清理设置里记着它的地方；撤销按快照原样放回；
// - 日记本：新建手动本（可选上级）、改名、收录 / 移出日记。私密或上锁的本子
//   （含子本）一律不碰：收进去的日记会变私密，这类改动要用户在界面里做。

import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/controllers/tag_cleanup.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';
import '../models/ai_tool_subject.dart';

/// 按名称找标签（不区分大小写）；没有时抛 [AiToolFailure]。
Future<Tag> _tagNamed(AppDatabase database, String name) async {
  final wanted = name.trim().toLowerCase();
  final tags = await database.watchAllTags().first;
  for (final tag in tags) {
    if (tag.name.toLowerCase() == wanted) return tag;
  }
  throw AiToolFailure('No tag named "$name". Call list_tags.');
}

/// `#RRGGBB` 转成颜色值；格式不对时抛 [AiToolFailure]。
int? _color(Object? raw) {
  if (raw is! String) return null;
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(raw.trim());
  if (match == null) {
    throw const AiToolFailure('Colors are written as #RRGGBB.');
  }
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16)).toARGB32();
}

class CreateTagTool extends AiTool {
  const CreateTagTool();

  @override
  String get name => 'create_tag';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description => 'Create a tag (color as #RRGGBB, optional).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'name': AiStringSchema(maxLength: 40),
      'color': AiStringSchema(description: '#RRGGBB'),
    },
    required: <String>['name'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateTag('${args['name'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final name = (args['name']! as String).trim();
    final result = await context.database.ensureTagsByName([
      (name: name, color: _color(args['color']) ?? aiDefaultTagColor),
    ]);
    if (result.created.isEmpty) {
      throw AiToolFailure('A tag named "$name" already exists.');
    }
    aiRefreshTags(context.container);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.tag(name)],
      undo: <String, Object?>{'created': result.created.toList()},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    // 已经被日记用上的标签留着（deleteTagsIfUnused 只删没人用的）。
    await container
        .read(appDatabaseProvider)
        .deleteTagsIfUnused(aiUndoInts(data['created']).toSet());
    aiRefreshTags(container);
  }
}

class RenameTagTool extends AiTool {
  const RenameTagTool();

  @override
  String get name => 'rename_tag';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Rename a tag and/or change its color (#RRGGBB). Entries keep it.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'name': AiStringSchema(),
      'new_name': AiStringSchema(maxLength: 40),
      'color': AiStringSchema(description: '#RRGGBB'),
    },
    required: <String>['name'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolRenameTag('${args['name'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final tag = await _tagNamed(database, args['name']! as String);
    final newName = (args['new_name'] as String?)?.trim() ?? tag.name;
    final color = _color(args['color']) ?? tag.color;
    try {
      await database.updateTag(tagId: tag.id, name: newName, color: color);
    } on FormatException catch (error) {
      throw AiToolFailure(error.message);
    }
    aiRefreshTags(context.container);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.tag(newName)],
      undo: <String, Object?>{
        'id': tag.id,
        'name': tag.name,
        'color': tag.color,
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container
        .read(appDatabaseProvider)
        .updateTag(
          tagId: data['id']! as int,
          name: data['name']! as String,
          color: data['color']! as int,
        );
    aiRefreshTags(container);
  }
}

class MergeTagsTool extends AiTool {
  const MergeTagsTool();

  @override
  String get name => 'merge_tags';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Merge tags into one: entries with any of `from` get `into`, then the '
      '`from` tags are deleted. The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'from': AiArraySchema(items: AiStringSchema(), maxItems: 20),
      'into': AiStringSchema(),
    },
    required: <String>['from', 'into'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final from = args['from'];
    return l10n.aiToolMergeTags(
      from is List ? from.map((name) => '#$name').join(' ') : '',
      '#${args['into'] ?? ''}',
    );
  }

  Future<({List<Tag> from, Tag into})> _resolve(
    AppDatabase database,
    Map<String, Object?> args,
  ) async {
    final into = await _tagNamed(database, args['into']! as String);
    final from = <Tag>[
      for (final name in (args['from']! as List).cast<String>())
        await _tagNamed(database, name),
    ]..removeWhere((tag) => tag.id == into.id);
    if (from.isEmpty) throw const AiToolFailure('Nothing to merge.');
    return (from: from, into: into);
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    await _resolve(context.database, args);
    return AiToolPreview(title: label(context.l10n, args));
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final tags = await _resolve(database, args);
    final merge = await database.mergeTags([
      for (final tag in tags.from) tag.id,
    ], tags.into.id);
    await forgetDeletedTags(context.container, {
      for (final tag in tags.from) tag.id,
    });
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'entries_tagged': merge.addedTargetDiaryIds.length,
      },
      summary: context.l10n.aiToolDone,
      subjects: [
        for (final tag in tags.from) AiToolSubject.tag(tag.name, input: true),
        AiToolSubject.tag(tags.into.name),
      ],
      undo: <String, Object?>{'merge': jsonEncode(merge.toJson())},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final merge = TagMerge.fromJson(
      (jsonDecode(data['merge']! as String) as Map).cast<String, Object?>(),
    );
    try {
      await container.read(appDatabaseProvider).restoreTagMerge(merge);
    } on StateError {
      // 期间又建了同名标签：放不回原样。
      throw const AiUndoConflict();
    }
    aiRefreshTags(container);
  }
}

class DeleteTagTool extends AiTool {
  const DeleteTagTool();

  @override
  String get name => 'delete_tag';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Delete a tag; entries stay but lose the tag. The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{'name': AiStringSchema()},
    required: <String>['name'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolDeleteTag('#${args['name'] ?? ''}');

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    await _tagNamed(context.database, args['name']! as String);
    return AiToolPreview(title: label(context.l10n, args));
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final tag = await _tagNamed(database, args['name']! as String);
    final deletion = await database.deleteTagWithSnapshot(tag.id);
    if (deletion == null) throw AiToolFailure('No tag named "${tag.name}".');
    await forgetDeletedTags(context.container, {tag.id});
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'entries_untagged': deletion.diaryIds.length,
      },
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.tag(tag.name, input: true)],
      undo: <String, Object?>{'deletion': jsonEncode(deletion.toJson())},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final deletion = TagDeletion.fromJson(
      (jsonDecode(data['deletion']! as String) as Map).cast<String, Object?>(),
    );
    try {
      await container.read(appDatabaseProvider).restoreTagDeletion(deletion);
    } on StateError {
      throw const AiUndoConflict();
    }
    aiRefreshTags(container);
  }
}

/// AI 能动的日记本：存在、手动本、不私密（含继承）、没被 AI 隐私排除。
Future<NotebookView> _openNotebook(AiToolContext context, String id) async {
  if (!context.env.features.notebooks) {
    throw const AiToolFailure('Notebooks are turned off.');
  }
  final notebook = (await context.notebookTree())[id];
  if (notebook == null ||
      notebook.isPrivate ||
      context.prefs.privacy.excludedNotebookIds.contains(id)) {
    throw const AiToolFailure(
      'No such notebook, or it is private (private and locked notebooks '
      'must be changed by the user). Call list_notebooks.',
    );
  }
  if (!notebook.isManual) {
    throw const AiToolFailure(
      'This is a smart notebook: it gathers entries by rules and cannot '
      'take entries by hand.',
    );
  }
  return notebook;
}

class CreateNotebookTool extends AiTool {
  const CreateNotebookTool();

  @override
  String get name => 'create_notebook';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Create a manual notebook, optionally inside another manual notebook '
      '(at most 3 levels deep).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'name': AiStringSchema(maxLength: 60),
      'parent_id': AiStringSchema(),
    },
    required: <String>['name'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateNotebook('${args['name'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final parentId = args['parent_id'] as String?;
    if (parentId != null) {
      final parent = await _openNotebook(context, parentId);
      if (!parent.canHaveChildren) {
        throw const AiToolFailure(
          'That notebook cannot have sub-notebooks (too deep).',
        );
      }
    }
    final String id;
    try {
      id = await context.database.createNotebook(
        name: (args['name']! as String).trim(),
        parentId: parentId,
      );
    } on ArgumentError catch (error) {
      throw AiToolFailure('${error.message}');
    }
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'id': id},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.notebook(id, (args['name']! as String).trim())],
      undo: <String, Object?>{'id': id},
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
    // 之后已经往里收了日记：删本子会丢掉这些归属，先问。
    final counts = await database.watchManualNotebookEntryCounts().first;
    if (!force && (counts[id] ?? 0) > 0) throw const AiUndoConflict();
    await database.deleteNotebook(id);
  }
}

class RenameNotebookTool extends AiTool {
  const RenameNotebookTool();

  @override
  String get name => 'rename_notebook';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description => 'Rename a notebook.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'name': AiStringSchema(maxLength: 60),
    },
    required: <String>['notebook_id', 'name'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolRenameNotebook('${args['name'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final id = args['notebook_id']! as String;
    if (!context.env.features.notebooks) {
      throw const AiToolFailure('Notebooks are turned off.');
    }
    final notebook = (await context.notebookTree())[id];
    if (notebook == null || notebook.isPrivate) {
      throw const AiToolFailure('No such notebook. Call list_notebooks.');
    }
    try {
      await context.database.updateNotebook(
        id,
        name: (args['name']! as String).trim(),
      );
    } on ArgumentError catch (error) {
      throw AiToolFailure('${error.message}');
    }
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.notebook(id, (args['name']! as String).trim())],
      undo: <String, Object?>{'id': id, 'name': notebook.name},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => container
      .read(appDatabaseProvider)
      .updateNotebook(data['id']! as String, name: data['name']! as String);
}

class AddToNotebookTool extends AiTool {
  const AddToNotebookTool();

  @override
  String get name => 'add_to_notebook';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Put entries (by id) into a manual notebook. An entry can be in '
      'several notebooks.';

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['notebook_id', 'ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolAddToNotebook(ids is List ? ids.length : 1);
  }

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final notebook = subjects
        .where((subject) => subject.kind == AiSubjectKind.notebook)
        .firstOrNull;
    final ids = args['ids'];
    return notebook == null
        ? label(l10n, args)
        : l10n.aiToolAddToNotebookNamed(
            ids is List ? ids.length : 1,
            notebook.title,
          );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final notebook = await _openNotebook(
      context,
      args['notebook_id']! as String,
    );
    final diaries = await aiWritableDiaries(
      context,
      (args['ids']! as List).cast<String>(),
    );
    final ids = [for (final found in diaries) found.diary.diaryId];
    final memberships = await database.getNotebookIdsForDiaries(ids);
    final added = [
      for (final id in ids)
        if (!(memberships[id]?.contains(notebook.id) ?? false)) id,
    ];
    await database.addDiariesToNotebook(notebook.id, added);
    aiRefreshDiaries(context.container, added);
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'added': added.length,
        'already_there': ids.length - added.length,
      },
      summary: context.l10n.aiToolEntriesChanged(added.length),
      subjects: [
        AiToolSubject.notebook(notebook.id, notebook.name, input: true),
        for (final found in diaries) aiDiarySubject(found.diary),
      ],
      undo: <String, Object?>{'notebook': notebook.id, 'ids': added},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final ids = aiUndoStrings(data['ids']);
    await container
        .read(appDatabaseProvider)
        .removeDiariesFromNotebook(data['notebook']! as String, ids);
    aiRefreshDiaries(container, ids);
  }
}

class RemoveFromNotebookTool extends AiTool {
  const RemoveFromNotebookTool();

  @override
  String get name => 'remove_from_notebook';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Take entries (by id) out of a manual notebook. The entries are kept.';

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['notebook_id', 'ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolRemoveFromNotebook(ids is List ? ids.length : 1);
  }

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final notebook = subjects
        .where((subject) => subject.kind == AiSubjectKind.notebook)
        .firstOrNull;
    final ids = args['ids'];
    return notebook == null
        ? label(l10n, args)
        : l10n.aiToolRemoveFromNotebookNamed(
            ids is List ? ids.length : 1,
            notebook.title,
          );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final notebook = await _openNotebook(
      context,
      args['notebook_id']! as String,
    );
    final diaries = await aiWritableDiaries(
      context,
      (args['ids']! as List).cast<String>(),
    );
    final ids = [for (final found in diaries) found.diary.diaryId];
    final removed = await context.database.removeDiariesFromNotebook(
      notebook.id,
      ids,
    );
    aiRefreshDiaries(context.container, ids);
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'removed': removed.length},
      summary: context.l10n.aiToolEntriesChanged(removed.length),
      subjects: [
        AiToolSubject.notebook(notebook.id, notebook.name, input: true),
        for (final found in diaries) aiDiarySubject(found.diary),
      ],
      undo: <String, Object?>{
        'rows': [for (final row in removed) row.toJson()],
        'ids': ids,
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container.read(appDatabaseProvider).restoreNotebookMemberships([
      for (final row in data['rows']! as List)
        DiaryNotebookRow.fromJson((row as Map).cast<String, dynamic>()),
    ]);
    aiRefreshDiaries(container, aiUndoStrings(data['ids']));
  }
}
