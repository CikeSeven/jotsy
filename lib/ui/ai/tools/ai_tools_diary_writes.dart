// 日记的写工具：新建、追加正文、改信息、加减标签、置顶、归档、移入回收站。
//
// 都复用现有的写库路径：新建与“返回时直接发表”同一条
// `publishNewDiaryDirectly`（组元数据、未来的日期回落到现在、功能关闭时去掉
// 日记本）；只改正文用 `updateDiaryContent`、只改信息用 `patchDiaryFields`
// （都不碰归档与删除标记）；批量的置顶 / 归档 / 删除用 batch writes。每个都
// 带撤销数据；撤销前按内容指纹核对这篇之后有没有被改过。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/controllers/publish_new_diary_directly.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/models/publish_metadata_composer.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';

String _firstLine(String text, [int max = 40]) {
  final line = text.trim().split('\n').first.trim();
  return line.length > max ? '${line.substring(0, max)}…' : line;
}

/// 日记在卡片上的称呼：标题，没有标题时为日期。
String _diaryName(Diary diary) => diary.title.trim().isNotEmpty
    ? diary.title.trim()
    : aiToolDate(diary.createdAt);

/// 心情只能取用户自己的心情选项。
Future<String?> _checkedMood(AiToolContext context, Object? raw) async {
  if (raw is! String || raw.trim().isEmpty) return null;
  final settings = await context.container.read(settingsServiceProvider.future);
  final options = settings.moodOptions;
  if (!options.contains(raw.trim())) {
    throw AiToolFailure(
      'Mood must be one of the user\'s mood options: ${options.join(' ')}',
    );
  }
  return raw.trim();
}

class CreateDiaryTool extends AiTool {
  const CreateDiaryTool();

  @override
  String get name => 'create_diary';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Write a new diary entry. `body` is Markdown. Without `date` it is '
      'dated now; a date alone keeps the current time of day; future dates '
      'fall back to now. Tags that do not exist are created. `mood` must be '
      'one of the mood options from get_app_context. Only manual, '
      'non-private notebooks can be chosen.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'title': AiStringSchema(maxLength: 200, allowEmpty: true),
      'body': AiStringSchema(description: 'Markdown body.'),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'tags': AiArraySchema(items: AiStringSchema(maxLength: 40), maxItems: 20),
      'mood': AiStringSchema(),
      'weather': AiStringSchema(maxLength: 40),
      'location': AiStringSchema(maxLength: 100),
      'notebook_id': AiStringSchema(),
    },
    required: <String>['body'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final title = args['title'];
    return title is String && title.trim().isNotEmpty
        ? l10n.aiToolCreateDiaryNamed(_firstLine(title))
        : l10n.aiToolCreateDiary;
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async => AiToolPreview(
    title: label(context.l10n, args),
    lines: [
      _firstLine(args['body']! as String, 80),
      if (args['date'] case final DateTime date) aiToolDate(date),
      if (args['tags'] case final List tags when tags.isNotEmpty)
        tags.map((tag) => '#$tag').join(' '),
    ],
  );

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final features = context.env.features;
    final mood = await _checkedMood(context, args['mood']);
    final notebookId = args['notebook_id'] as String?;
    if (notebookId != null) {
      final notebook = (await context.notebookTree())[notebookId];
      if (!features.notebooks ||
          notebook == null ||
          !notebook.isManual ||
          notebook.isPrivate ||
          context.prefs.privacy.excludedNotebookIds.contains(notebookId)) {
        throw const AiToolFailure(
          'That notebook cannot take entries here (it must be a manual, '
          'non-private notebook). Call list_notebooks.',
        );
      }
    }
    final tagNames = (args['tags'] as List?)?.cast<String>() ?? const [];
    final tags = await database.ensureTagsByName([
      for (final name in tagNames) (name: name, color: aiDefaultTagColor),
    ]);
    final date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    final DateTime? requested = date == null
        ? null
        : minute == null
        ? date
        : DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
    final document = aiMarkdownDiaryDocument(args['body']! as String);
    final id = await publishNewDiaryDirectly(
      database: database,
      draft: NewDiaryDraft(
        title: (args['title'] as String?)?.trim() ?? '',
        contentDocJson: encodeDiaryBlocks(document),
        contentText: diaryBlocksPlainText(document),
        createdAtOverride: requested,
        selectedTagIds: tags.ids.values.toSet(),
        notebookIds: [?notebookId],
        moodEmoji: mood,
        weather: (args['weather'] as String?)?.trim(),
        location: (args['location'] as String?)?.trim(),
      ),
      timeCapsulesEnabled: features.timeCapsules,
      notebooksEnabled: features.notebooks,
    );
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
        if (requested != null && requested.isAfter(context.now))
          'note': 'The date was in the future, so it is dated now.',
      },
      summary: context.l10n.aiToolDiaryCreated(_diaryName(created)),
      subjects: [aiDiarySubject(created)],
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
  }) async {
    final database = container.read(appDatabaseProvider);
    final id = data['id']! as String;
    await aiCheckUnchanged(database, id, data['fingerprint'], force: force);
    // 先摘掉顺带新建的标签：进了回收站的日记仍挂着它们，否则删不掉。
    final createdTags = aiUndoInts(data['createdTags']).toSet();
    if (createdTags.isNotEmpty) {
      await database.applyDiaryTagBatch([id], remove: createdTags);
    }
    await database.softDeleteDiary(id);
    await database.deleteTagsIfUnused(createdTags);
    aiRefreshDiaries(container, [id]);
    aiRefreshTags(container);
  }
}

class AppendToDiaryTool extends AiTool {
  const AppendToDiaryTool();

  @override
  String get name => 'append_to_diary';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add Markdown text to the end of an existing entry (by id). The rest '
      'of the entry is left as it is.';

  @override
  Set<String> get diaryIdArgs => const <String>{'id'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'id': AiStringSchema(),
      'text': AiStringSchema(description: 'Markdown to append.'),
    },
    required: <String>['id', 'text'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolAppendDiary;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final found = await aiWritableDiary(context, args['id']! as String);
    final diary = found.diary;
    final document = decodeStoredDiaryBlocks(diary.content);
    final page = (document['document']! as Map).cast<String, Object?>();
    final added =
        (aiMarkdownDiaryDocument(args['text']! as String)['document']!
                as Map)['children']!
            as List;
    final next = <String, Object?>{
      ...document,
      'document': <String, Object?>{
        ...page,
        'children': [...(page['children'] as List? ?? const []), ...added],
      },
    };
    await context.database.updateDiaryContent(
      diaryId: diary.diaryId,
      contentDocJson: encodeDiaryBlocks(next),
      contentText: diaryBlocksPlainText(next),
    );
    aiRefreshDiaries(context.container, [diary.diaryId]);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDiaryChanged(_diaryName(diary)),
      subjects: [aiDiarySubject(diary)],
      undo: <String, Object?>{
        'id': diary.diaryId,
        'content': diary.content,
        'text': diary.contentText,
        'fingerprint': await aiDiaryFingerprintOf(
          context.database,
          diary.diaryId,
        ),
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
    await aiCheckUnchanged(database, id, data['fingerprint'], force: force);
    await database.updateDiaryContent(
      diaryId: id,
      contentDocJson: data['content']! as String,
      contentText: data['text']! as String,
    );
    aiRefreshDiaries(container, [id]);
  }
}

class UpdateDiaryTool extends AiTool {
  const UpdateDiaryTool();

  @override
  String get name => 'update_diary';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      "Change an entry's title, date, time, mood, weather or location (by "
      'id). Pass only what changes; an empty string clears mood, weather or '
      'location. The body is not touched (use append_to_diary to add text).';

  @override
  Set<String> get diaryIdArgs => const <String>{'id'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'id': AiStringSchema(),
      'title': AiStringSchema(maxLength: 200, allowEmpty: true),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'mood': AiStringSchema(allowEmpty: true),
      'weather': AiStringSchema(maxLength: 40, allowEmpty: true),
      'location': AiStringSchema(maxLength: 100, allowEmpty: true),
    },
    required: <String>['id'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolUpdateDiary;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final found = await aiWritableDiary(context, args['id']! as String);
    final diary = found.diary;
    String? clean(Object? raw) =>
        raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    String? metadataJson;
    if (args.containsKey('mood') ||
        args.containsKey('weather') ||
        args.containsKey('location')) {
      final mood = args.containsKey('mood')
          ? await _checkedMood(context, args['mood'])
          : null;
      var meta = PublishMetadataComposer.parse(
        diary.metadata,
      ).copyWith(tagIds: {for (final tag in found.tags) tag.id});
      if (args.containsKey('mood')) meta = meta.copyWith(moodEmoji: mood);
      if (args.containsKey('weather')) {
        meta = meta.copyWith(
          weather: clean(args['weather']),
          weatherIconCode: null,
        );
      }
      if (args.containsKey('location')) {
        meta = meta.copyWith(location: clean(args['location']));
      }
      final previous = jsonDecode(diary.metadata);
      metadataJson = PublishMetadataComposer.composeDraft(
        draft: meta,
        contentText: diary.contentText,
        generatedAt: context.now,
        preserve: previous is Map ? previous.cast<String, Object?>() : null,
      );
    }
    DateTime? createdAt;
    final date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    if (date != null || minute != null) {
      final day = date ?? diary.createdAt;
      createdAt = DateTime(
        day.year,
        day.month,
        day.day,
        minute == null ? diary.createdAt.hour : minute ~/ 60,
        minute == null ? diary.createdAt.minute : minute % 60,
      );
      if (createdAt.isAfter(context.now)) {
        throw const AiToolFailure('An entry cannot be dated in the future.');
      }
    }
    final title = args['title'] as String?;
    if (title == null && metadataJson == null && createdAt == null) {
      throw const AiToolFailure('Nothing to change.');
    }
    await context.database.patchDiaryFields(
      diaryId: diary.diaryId,
      title: title,
      metadataJson: metadataJson,
      createdAt: createdAt,
    );
    aiRefreshDiaries(context.container, [diary.diaryId]);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDiaryChanged(_diaryName(diary)),
      subjects: [aiDiarySubject(diary)],
      undo: <String, Object?>{
        'id': diary.diaryId,
        if (title != null) 'title': diary.title,
        if (metadataJson != null) 'metadata': diary.metadata,
        if (createdAt != null)
          'createdAt': diary.createdAt.millisecondsSinceEpoch,
        'fingerprint': await aiDiaryFingerprintOf(
          context.database,
          diary.diaryId,
        ),
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
    await aiCheckUnchanged(database, id, data['fingerprint'], force: force);
    final createdAt = data['createdAt'];
    await database.patchDiaryFields(
      diaryId: id,
      title: data['title'] as String?,
      metadataJson: data['metadata'] as String?,
      createdAt: createdAt is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : null,
    );
    aiRefreshDiaries(container, [id]);
  }
}

class TagDiariesTool extends AiTool {
  const TagDiariesTool();

  @override
  String get name => 'tag_diaries';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add and/or remove tags on entries (by id). Tags to add that do not '
      'exist are created; tags to remove must exist.';

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 50),
      'add': AiArraySchema(items: AiStringSchema(maxLength: 40), maxItems: 20),
      'remove': AiArraySchema(items: AiStringSchema(), maxItems: 20),
    },
    required: <String>['ids'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolTagDiaries(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final diaries = await aiWritableDiaries(
      context,
      (args['ids']! as List).cast<String>(),
    );
    final addNames = (args['add'] as List?)?.cast<String>() ?? const [];
    final removeNames = (args['remove'] as List?)?.cast<String>() ?? const [];
    if (addNames.isEmpty && removeNames.isEmpty) {
      throw const AiToolFailure('Give tags to add or remove.');
    }
    final all = await database.watchAllTags().first;
    final remove = <int>{};
    for (final name in removeNames) {
      final match = all.where((tag) => tag.name == name.trim());
      if (match.isEmpty) throw AiToolFailure('No tag named "$name".');
      remove.add(match.first.id);
    }
    final added = await database.ensureTagsByName([
      for (final name in addNames) (name: name, color: aiDefaultTagColor),
    ]);
    final ids = [for (final found in diaries) found.diary.diaryId];
    final batch = await database.applyDiaryTagBatch(
      ids,
      add: added.ids.values.toSet(),
      remove: remove,
    );
    aiRefreshDiaries(context.container, ids);
    aiRefreshTags(context.container);
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'entries': ids.length},
      summary: context.l10n.aiToolEntriesChanged(ids.length),
      subjects: [
        for (final name in addNames)
          AiToolSubject.tag(name.trim(), input: true),
        for (final name in removeNames)
          AiToolSubject.tag(name.trim(), input: true),
        for (final found in diaries) aiDiarySubject(found.diary),
      ],
      undo: <String, Object?>{
        'batch': batch.toJson(),
        'createdTags': added.created.toList(),
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
    final database = container.read(appDatabaseProvider);
    await database.restoreDiaryTagBatch(
      DiaryTagBatchUndo.fromJson(
        (data['batch']! as Map).cast<String, Object?>(),
      ),
    );
    await database.deleteTagsIfUnused(aiUndoInts(data['createdTags']).toSet());
    aiRefreshDiaries(container, aiUndoStrings(data['ids']));
    aiRefreshTags(container);
  }
}

/// 置顶 / 归档共用：按每篇原来的状态撤销。
abstract class _FlagDiariesTool extends AiTool {
  const _FlagDiariesTool();

  String get flag;

  bool current(Diary diary);

  Future<void> write(AppDatabase database, List<String> ids, bool value);

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': const AiArraySchema(items: AiStringSchema(), maxItems: 50),
      flag: const AiBooleanSchema(),
    },
    required: <String>['ids', flag],
  );

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final diaries = await aiWritableDiaries(
      context,
      (args['ids']! as List).cast<String>(),
    );
    final value = args[flag]! as bool;
    final ids = [for (final found in diaries) found.diary.diaryId];
    final before = <String, bool>{
      for (final found in diaries) found.diary.diaryId: current(found.diary),
    };
    await write(context.database, ids, value);
    aiRefreshDiaries(context.container, ids);
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'entries': ids.length},
      summary: context.l10n.aiToolEntriesChanged(ids.length),
      subjects: [for (final found in diaries) aiDiarySubject(found.diary)],
      undo: <String, Object?>{'before': before},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final before = (data['before']! as Map).cast<String, Object?>();
    for (final value in const [true, false]) {
      final ids = [
        for (final entry in before.entries)
          if (entry.value == value) entry.key,
      ];
      if (ids.isNotEmpty) await write(database, ids, value);
    }
    aiRefreshDiaries(container, before.keys);
  }
}

class PinDiariesTool extends _FlagDiariesTool {
  const PinDiariesTool();

  @override
  String get name => 'pin_diaries';

  @override
  String get flag => 'pinned';

  @override
  String get description =>
      'Pin entries to the top of the list, or unpin them (by id).';

  @override
  bool current(Diary diary) => diary.isPinned;

  @override
  Future<void> write(AppDatabase database, List<String> ids, bool value) =>
      database.setDiariesPinned(ids, pinned: value);

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      args['pinned'] == false ? l10n.aiToolUnpinDiaries : l10n.aiToolPinDiaries;
}

class ArchiveDiariesTool extends _FlagDiariesTool {
  const ArchiveDiariesTool();

  @override
  String get name => 'archive_diaries';

  @override
  String get flag => 'archived';

  @override
  String get description =>
      'Archive entries (hidden from the main list, still searchable) or '
      'bring them back from the archive (by id).';

  @override
  bool current(Diary diary) => diary.isArchived;

  @override
  Future<void> write(AppDatabase database, List<String> ids, bool value) =>
      database.setDiariesArchived(ids, archived: value);

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      args['archived'] == false
      ? l10n.aiToolUnarchiveDiaries
      : l10n.aiToolArchiveDiaries;
}

class TrashDiariesTool extends AiTool {
  const TrashDiariesTool();

  @override
  String get name => 'trash_diaries';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Move entries to the recycle bin (by id). The user confirms first; '
      'they can be restored from the recycle bin.';

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 50),
    },
    required: <String>['ids'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolTrashDiaries(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final diaries = await aiWritableDiaries(
      context,
      (args['ids']! as List).cast<String>(),
    );
    return AiToolPreview(
      title: label(context.l10n, args),
      lines: [
        for (final found in diaries.take(8))
          '${aiToolDate(found.diary.createdAt)}  ${_diaryName(found.diary)}',
        if (diaries.length > 8) '…',
      ],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final diaries = await aiWritableDiaries(
      context,
      (args['ids']! as List).cast<String>(),
    );
    final ids = [for (final found in diaries) found.diary.diaryId];
    await context.database.softDeleteDiaries(ids);
    aiRefreshDiaries(context.container, ids);
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'entries': ids.length},
      summary: context.l10n.aiToolEntriesTrashed(ids.length),
      subjects: [for (final found in diaries) aiDiarySubject(found.diary)],
      undo: <String, Object?>{'ids': ids},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final ids = aiUndoStrings(data['ids']);
    await container.read(appDatabaseProvider).restoreDiaries(ids);
    aiRefreshDiaries(container, ids);
  }
}
