// 手动日记本章节的删除与日记分章工具：删除章节（删除类，执行前确认）、调整
// 日记所属章节（含移回未分章）。新增、改名与排序见 `ai_tools_notebook_chapters.dart`。
//
// 输入：手动日记本 id、章节引用（章节 id 或本子内唯一标题，不区分大小写）与
// 日记 id（`move_to_notebook_chapter` 登记 `diaryIdArgs`，支持 `D3` 编号）。
// 输出：改动结果、受影响对象与撤销快照；只写手动、非私密、未被 AI 隐私排除
// 的日记本，不改动手动书序（`position`）。
//
// 副作用：经 `deleteNotebookChaptersWithSnapshot` / `setNotebookEntriesChapter`
// 落库；删除章节的撤销经 `restoreNotebookChaptersDeletion` 恢复原章节与原属
// 日记的章节归属，期间章节列表变过时抛 `AiUndoConflict`。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/viewmodels/notebook_book_layout.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../models/ai_tool_subject.dart';
import '../viewmodels/ai_tool_facts.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';
import 'ai_tools_notebook_chapters.dart';
import 'ai_tools_organize_writes.dart';

class DeleteNotebookChaptersTool extends AiTool {
  const DeleteNotebookChaptersTool();

  @override
  String get name => 'delete_notebook_chapters';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Delete one or more chapters from a manual notebook (by id or unique '
      'title). Entries in those chapters stay in the notebook and move to '
      'No chapter (unassigned). The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'chapters': AiArraySchema(
        items: AiStringSchema(),
        maxItems: 50,
        description: 'Chapter ids or unique titles to delete.',
      ),
    },
    required: <String>['notebook_id', 'chapters'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final chapters = args['chapters'];
    final count = chapters is List && chapters.isNotEmpty ? chapters.length : 1;
    return l10n.aiToolDeleteNotebookChapters(count);
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
    if (notebook == null) return label(l10n, args);
    final chapters = args['chapters'];
    final count = chapters is List && chapters.isNotEmpty ? chapters.length : 1;
    return l10n.aiToolDeleteNotebookChaptersNamed(notebook.title, count);
  }

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      // 原始参数可能是 8 位随机 id；被删章节的名称已记在 summary 里。
      key == 'chapters' ? '' : null;

  Future<_DeleteChaptersPlan> _plan(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final notebook = await aiOpenManualNotebook(
      context,
      args['notebook_id']! as String,
    );
    final refs = (args['chapters']! as List).cast<String>();
    if (refs.isEmpty) {
      throw const AiToolFailure('Give at least one chapter to delete.');
    }
    final row = await context.database.getNotebook(notebook.id);
    if (row == null) {
      throw const AiToolFailure('No such notebook. Call list_notebooks.');
    }
    final chapters = row.parsedPayload.chapters;
    final seen = <String>{};
    final targets = <NotebookChapter>[];
    for (final ref in refs) {
      final chapter = aiResolveNotebookChapter(chapters, ref);
      if (seen.add(chapter.id)) targets.add(chapter);
    }
    // 统计口径与目录页一致（含归档、不含回收站与私密日记），不泄露私密日记。
    final contents = await context.database.getNotebookContents(notebook.id);
    final affected = contents
        .where((entry) => seen.contains(entry.chapterId))
        .length;
    return _DeleteChaptersPlan(
      notebook: notebook,
      targets: targets,
      affected: affected,
    );
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final plan = await _plan(context, args);
    final l10n = context.l10n;
    final single = plan.targets.length == 1;
    return AiToolPreview(
      title: single
          ? l10n.aiToolDeleteNotebookChapterNamed(
              plan.notebook.name,
              plan.targets.single.title,
            )
          : l10n.aiToolDeleteNotebookChaptersNamed(
              plan.notebook.name,
              plan.targets.length,
            ),
      lines: <String>[
        if (!single) ...[
          for (final chapter in plan.targets.take(8)) chapter.title,
          if (plan.targets.length > 8) '…',
        ],
        if (plan.affected > 0)
          l10n.aiToolDeleteNotebookChaptersUnassign(plan.affected),
      ],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final plan = await _plan(context, args);
    final deletion = await context.database.deleteNotebookChaptersWithSnapshot(
      plan.notebook.id,
      [for (final chapter in plan.targets) chapter.id],
    );
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'deleted': plan.targets.length,
        'entries_unassigned': plan.affected,
        'chapters': aiNotebookChaptersJson(deletion.afterChapters),
      },
      summary: aiJoinNames(context.l10n, [
        for (final chapter in plan.targets) chapter.title,
      ]),
      subjects: [AiToolSubject.notebook(plan.notebook.id, plan.notebook.name)],
      undo: <String, Object?>{'deletion': jsonEncode(deletion.toJson())},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final deletion = NotebookChaptersDeletion.fromJson(
      (jsonDecode(data['deletion']! as String) as Map).cast<String, Object?>(),
    );
    try {
      await container
          .read(appDatabaseProvider)
          .restoreNotebookChaptersDeletion(deletion, force: force);
    } on StateError {
      throw const AiUndoConflict();
    }
  }
}

class _DeleteChaptersPlan {
  const _DeleteChaptersPlan({
    required this.notebook,
    required this.targets,
    required this.affected,
  });

  final NotebookView notebook;
  final List<NotebookChapter> targets;
  final int affected;
}

class MoveToNotebookChapterTool extends AiTool {
  const MoveToNotebookChapterTool();

  @override
  String get name => 'move_to_notebook_chapter';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Move entries (by id) that are already in a manual notebook into one of '
      'its chapters (by id or unique title), or pass "" to move them to No '
      'chapter (unassigned). Entries not yet in this notebook are rejected; '
      'use add_to_notebook first. Does not change book order.';

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
      'chapter_id': AiStringSchema(
        allowEmpty: true,
        description:
            'Target chapter id or unique title; "" moves entries to No '
            'chapter (unassigned).',
      ),
    },
    required: <String>['notebook_id', 'ids', 'chapter_id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolMoveToChapter(ids is List ? ids.length : 1);
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
        : l10n.aiToolMoveToChapterIn(
            ids is List ? ids.length : 1,
            notebook.title,
          );
  }

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      key == 'chapter_id' && value == ''
      ? l10n.notebookChapterUnassigned
      : null;

  Future<_MoveToChapterPlan> _plan(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final notebook = await aiOpenManualNotebook(
      context,
      args['notebook_id']! as String,
    );
    final rawChapter = (args['chapter_id']! as String).trim();
    final target = rawChapter.isEmpty
        ? null
        : aiResolveNotebookChapter(notebook.payload.chapters, rawChapter);
    final rawIds = (args['ids']! as List).cast<String>();
    if (rawIds.isEmpty) {
      throw const AiToolFailure('Give at least one entry id.');
    }
    final diaries = await aiWritableDiaries(context, rawIds);
    final ids = [for (final found in diaries) found.diary.diaryId];
    final current = await context.database.getNotebookEntryChapters(
      notebook.id,
      ids,
    );
    final missing = [
      for (final id in ids)
        if (!current.containsKey(id)) id,
    ];
    if (missing.isNotEmpty) {
      throw AiToolFailure(
        'These entries are not in notebook "${notebook.name}": '
        '${missing.join(', ')}. Use add_to_notebook first.',
      );
    }
    return _MoveToChapterPlan(
      notebook: notebook,
      target: target,
      diaries: diaries,
      current: current,
    );
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final plan = await _plan(context, args);
    final l10n = context.l10n;
    final targetTitle = plan.target?.title ?? l10n.notebookChapterUnassigned;
    return AiToolPreview(
      title: l10n.aiToolMoveToChapterIn(
        plan.diaries.length,
        plan.notebook.name,
      ),
      lines: <String>[
        l10n.notebookContentsMoved(targetTitle, plan.diaries.length),
        for (final found in plan.diaries.take(6)) aiDiaryName(found.diary),
        if (plan.diaries.length > 6) '…',
      ],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final plan = await _plan(context, args);
    final chapters = plan.notebook.payload.chapters;
    final targetId = plan.target?.id;
    final before = <String, String?>{};
    for (final found in plan.diaries) {
      final id = found.diary.diaryId;
      final effective = validNotebookChapterId(chapters, plan.current[id]);
      if (effective != targetId) {
        before[id] = effective;
      }
    }
    if (before.isNotEmpty) {
      await context.database.setNotebookEntriesChapter(
        plan.notebook.id,
        before.keys,
        targetId,
      );
    }
    final targetTitle =
        plan.target?.title ?? context.l10n.notebookChapterUnassigned;
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'moved': before.length,
        'already_there': plan.diaries.length - before.length,
        'chapter_id': ?targetId,
      },
      summary: context.l10n.notebookContentsMoved(
        targetTitle,
        plan.diaries.length,
      ),
      subjects: [
        AiToolSubject.notebook(
          plan.notebook.id,
          plan.notebook.name,
          input: true,
        ),
        for (final found in plan.diaries) aiDiarySubject(found.diary),
      ],
      undo: <String, Object?>{
        'notebook_id': plan.notebook.id,
        'before': before,
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final raw = data['before'];
    if (raw is! Map || raw.isEmpty) return;
    final before = <String, String?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value as String?,
    };
    await container
        .read(appDatabaseProvider)
        .restoreNotebookEntryChapters(data['notebook_id']! as String, before);
  }
}

class _MoveToChapterPlan {
  const _MoveToChapterPlan({
    required this.notebook,
    required this.target,
    required this.diaries,
    required this.current,
  });

  final NotebookView notebook;
  final NotebookChapter? target;
  final List<DiaryWithTags> diaries;
  final Map<String, String?> current;
}
