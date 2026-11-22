// 手动日记本章节的编辑工具（新增、改名、排序）与章节工具共用辅助；删除章节
// 与调整日记所属章节见 `ai_tools_notebook_chapter_actions.dart`。
//
// 输入：手动日记本 id、要新增 / 重命名 / 重排的章节参数（章节支持按 id 或本子
// 内唯一标题匹配，不区分大小写）。
// 输出：最新章节列表与撤销快照；只写手动、非私密、未被 AI 隐私排除的日记本。
//
// 副作用：经 `AppDatabase.updateNotebook` 只改 payload 的 `chapters`，保留其他
// 字段；撤销前核对章节列表是否被别处改过以及新建章节内是否已有日记，有冲突时
// 抛 `AiUndoConflict`。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/viewmodels/notebook_book_layout.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';
import 'ai_tools_organize_writes.dart';

/// 按章节 id 或本子内唯一标题（不区分大小写）查找章节；找不到或重名歧义时
/// 抛 [AiToolFailure]，并列出现有章节供模型改用 id。
NotebookChapter aiResolveNotebookChapter(
  List<NotebookChapter> chapters,
  String ref,
) {
  final wanted = ref.trim();
  for (final chapter in chapters) {
    if (chapter.id == wanted) return chapter;
  }
  final lower = wanted.toLowerCase();
  final named = <NotebookChapter>[
    for (final chapter in chapters)
      if (chapter.title.toLowerCase() == lower) chapter,
  ];
  if (named.length == 1) return named.single;
  final catalog = _describeChapters(chapters);
  if (named.length > 1) {
    throw AiToolFailure(
      'More than one chapter is titled "$ref". Pass the chapter id instead. '
      'Chapters: $catalog.',
    );
  }
  throw AiToolFailure('No chapter "$ref". Chapters: $catalog.');
}

/// 发给模型与存撤销数据用的章节列表 JSON。
List<Map<String, Object?>> aiNotebookChaptersJson(
  List<NotebookChapter> chapters,
) => [
  for (final chapter in chapters)
    <String, Object?>{'id': chapter.id, 'title': chapter.title},
];

String _describeChapters(List<NotebookChapter> chapters) => chapters.isEmpty
    ? '(none)'
    : chapters.map((c) => '${c.id}: ${c.title}').join('; ');

String _validateChapterTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const AiToolFailure('Chapter title cannot be empty.');
  }
  if (trimmed.runes.length > NotebookChapter.maxTitleLength) {
    throw const AiToolFailure(
      'Chapter title must be at most ${NotebookChapter.maxTitleLength} '
      'characters.',
    );
  }
  return trimmed;
}

List<NotebookChapter> _decodeChapterList(Object? raw) {
  if (raw is! List) return const <NotebookChapter>[];
  return <NotebookChapter>[
    for (final item in raw)
      if (item is Map && item['id'] is String && item['title'] is String)
        ?NotebookChapter.tryCreate(
          id: item['id'] as String,
          title: item['title'] as String,
        ),
  ];
}

bool _chaptersEqual(List<NotebookChapter> a, List<NotebookChapter> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class EditNotebookChaptersTool extends AiTool {
  const EditNotebookChaptersTool();

  @override
  String get name => 'edit_notebook_chapters';

  @override
  AiToolGroup get group => AiToolGroup.organize;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Edit chapters of a manual notebook: add new chapters, rename existing '
      'ones, or reorder them (in one call or separately). Chapters are '
      'one-level and belong to manual, non-private notebooks only. Existing '
      'chapters can be named by id or unique title; if two share a title, pass '
      'the id. Operations run as rename, then add, then order. To delete '
      'chapters, use delete_notebook_chapters; to assign entries to a chapter, '
      'use move_to_notebook_chapter.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'notebook_id': AiStringSchema(),
      'add': AiArraySchema(
        items: AiStringSchema(maxLength: NotebookChapter.maxTitleLength),
        maxItems: 50,
        description: 'New chapter titles to add at the end.',
      ),
      'rename': AiArraySchema(
        items: AiObjectSchema(
          properties: <String, AiSchema>{
            'chapter': AiStringSchema(
              description: 'Existing chapter id or unique title.',
            ),
            'title': AiStringSchema(maxLength: NotebookChapter.maxTitleLength),
          },
          required: <String>['chapter', 'title'],
        ),
        maxItems: 50,
        description: 'Rename existing chapters.',
      ),
      'order': AiArraySchema(
        items: AiStringSchema(),
        maxItems: 100,
        description:
            'Chapter ids (or unique titles, including newly added ones) in '
            'the desired order; unlisted chapters keep their relative order '
            'after them.',
      ),
    },
    required: <String>['notebook_id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.notebooks;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolEditNotebookChapters;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final notebook = subjects
        .where((subject) => subject.kind == AiSubjectKind.notebook)
        .firstOrNull;
    return notebook == null
        ? label(l10n, args)
        : l10n.aiToolEditNotebookChaptersOf(notebook.title);
  }

  @override
  String? argLabel(AppLocalizations l10n, String key) => switch (key) {
    'add' => l10n.aiToolArgAddChapters,
    'rename' => l10n.aiToolArgRenameChapters,
    'order' => l10n.aiToolArgChapterOrder,
    _ => null,
  };

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) {
    switch (key) {
      case 'rename' when value is List:
        // 只展示新标题，绝不把对象 JSON 或 8 位章节 id 暴露给用户。
        return [
          for (final item in value)
            if (item is Map && item['title'] is String)
              (item['title']! as String).trim(),
        ].where((title) => title.isNotEmpty).join(l10n.aiListSeparator);
      case 'order':
        return '';
      default:
        return null;
    }
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final plan = await _plan(context, args);
    final l10n = context.l10n;
    return AiToolPreview(
      title: l10n.aiToolEditNotebookChaptersOf(plan.notebook.name),
      lines: <String>[
        if (plan.added.isNotEmpty)
          '${l10n.aiToolArgAddChapters}: '
              '${plan.added.map((c) => c.title).join(l10n.aiListSeparator)}',
        for (final rename in plan.renames)
          l10n.aiToolEditReplace(rename.from, rename.to),
        if (plan.reordered) l10n.aiToolReorderChaptersPreview,
      ],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final plan = await _plan(context, args);
    await context.database.updateNotebook(
      plan.notebook.id,
      payload: plan.payload.copyWith(chapters: plan.next),
    );
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'chapters': aiNotebookChaptersJson(plan.next),
        if (plan.added.isNotEmpty) 'added': aiNotebookChaptersJson(plan.added),
      },
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.notebook(plan.notebook.id, plan.notebook.name)],
      undo: <String, Object?>{
        'notebook_id': plan.notebook.id,
        'before': aiNotebookChaptersJson(plan.before),
        'after': aiNotebookChaptersJson(plan.next),
        if (plan.added.isNotEmpty)
          'added_ids': [for (final c in plan.added) c.id],
      },
    );
  }

  Future<_EditChaptersPlan> _plan(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final notebook = await aiOpenManualNotebook(
      context,
      args['notebook_id']! as String,
    );
    final addTitles = (args['add'] as List?)?.cast<String>() ?? const [];
    final renameItems =
        (args['rename'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final orderRefs = (args['order'] as List?)?.cast<String>() ?? const [];
    if (addTitles.isEmpty && renameItems.isEmpty && orderRefs.isEmpty) {
      throw const AiToolFailure('Give `add`, `rename` or `order`.');
    }
    // 重读库里最新的 payload，避免把别处刚改的封面、模板等字段覆盖掉。
    final row = await context.database.getNotebook(notebook.id);
    if (row == null) {
      throw const AiToolFailure('No such notebook. Call list_notebooks.');
    }
    final payload = row.parsedPayload;
    final before = payload.chapters;

    // 1. 重命名（按改动前的列表匹配，避免链式改名引起歧义）。
    final renamedById = <String, String>{};
    final renames = <({String from, String to})>[];
    for (final item in renameItems) {
      final target = aiResolveNotebookChapter(
        before,
        item['chapter']! as String,
      );
      if (renamedById.containsKey(target.id)) {
        throw AiToolFailure(
          'Chapter "${target.title}" is renamed more than once.',
        );
      }
      final title = _validateChapterTitle(item['title']! as String);
      renamedById[target.id] = title;
      if (title != target.title) {
        renames.add((from: target.title, to: title));
      }
    }
    final working = <NotebookChapter>[
      for (final chapter in before)
        if (renamedById[chapter.id] case final title?)
          chapter.withTitle(title)
        else
          chapter,
    ];

    // 2. 新增章节（生成本子内不冲突的 8 位 id）。
    final usedIds = <String>{for (final chapter in working) chapter.id};
    final added = <NotebookChapter>[];
    for (final rawTitle in addTitles) {
      final title = _validateChapterTitle(rawTitle);
      String id;
      do {
        id = NotebookChapter.newId();
      } while (!usedIds.add(id));
      final created = NotebookChapter(id: id, title: title);
      added.add(created);
      working.add(created);
    }

    // 3. 排序（可引用已有 id、改名后的标题或刚新增的标题）。
    var next = working;
    var reordered = false;
    if (orderRefs.isNotEmpty) {
      final seenOrder = <String>{};
      final orderedIds = <String>[];
      for (final ref in orderRefs) {
        final chapter = aiResolveNotebookChapter(working, ref);
        if (!seenOrder.add(chapter.id)) {
          throw AiToolFailure(
            'Duplicate chapter in `order`: "${chapter.title}".',
          );
        }
        orderedIds.add(chapter.id);
      }
      next = orderNotebookChapters(working, orderedIds);
      reordered = !_chaptersEqual(working, next);
    }

    if (_chaptersEqual(before, next)) {
      throw const AiToolFailure('Nothing to change.');
    }
    return _EditChaptersPlan(
      notebook: notebook,
      payload: payload,
      before: before,
      next: next,
      added: added,
      renames: renames,
      reordered: reordered,
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final notebookId = data['notebook_id']! as String;
    final row = await database.getNotebook(notebookId);
    if (row == null || !row.acceptsManualEntries) return;
    final before = _decodeChapterList(data['before']);
    final after = _decodeChapterList(data['after']);
    final addedIds = aiUndoStrings(data['added_ids']);
    if (!force) {
      // 之后章节又被改过，或者新建的章节里已经放进了日记：先问用户再强制。
      if (!_chaptersEqual(row.parsedPayload.chapters, after)) {
        throw const AiUndoConflict();
      }
      if (addedIds.isNotEmpty &&
          await database.countNotebookEntriesInChapters(notebookId, addedIds) >
              0) {
        throw const AiUndoConflict();
      }
    }
    await database.updateNotebook(
      notebookId,
      payload: row.parsedPayload.copyWith(chapters: before),
    );
  }
}

class _EditChaptersPlan {
  const _EditChaptersPlan({
    required this.notebook,
    required this.payload,
    required this.before,
    required this.next,
    required this.added,
    required this.renames,
    required this.reordered,
  });

  final NotebookView notebook;
  final NotebookPayload payload;
  final List<NotebookChapter> before;
  final List<NotebookChapter> next;
  final List<NotebookChapter> added;
  final List<({String from, String to})> renames;
  final bool reordered;
}
