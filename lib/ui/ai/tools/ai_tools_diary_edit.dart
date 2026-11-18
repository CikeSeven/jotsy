// 改日记正文（`edit_diary`）：按 `read_diaries` 给出的正文 Markdown 做精确
// 替换（借鉴编码智能体的文件编辑），或整段替换。
//
// - 输入：日记 id 与 `edits[]`（old_text → new_text）或 `body`，二者给一个；
// - 改法与写法见 `ai_diary_markdown_edit.dart`（纯函数，全部校验在写库之前，
//   有一处不对就整次不写）；
// - 写库只经 `updateDiaryContent`（不碰标题、元数据、归档与删除标记），一次
//   写入；撤销写回原正文，之前按内容指纹核对之后有没有被改过（与其他改日记
//   的工具同一口径）；
// - 导图日记（整篇就是一张导图）的正文不在这里改：导图的主题只能在导图里
//   编辑，往里加段落会让它变成普通日记。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/mind_map/mind_map_blocks.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_tool_subject.dart';
import 'ai_diary_markdown.dart';
import 'ai_diary_markdown_edit.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';

class EditDiaryTool extends AiTool {
  const EditDiaryTool();

  @override
  String get name => 'edit_diary';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      "Change an entry's body (by id) by exact text replacement, like editing "
      'a file. read_diaries shows the body as Markdown: one line per block '
      '(# headings, - bullets, 1. numbers, - [ ] to-dos, > quotes, '
      '<callout>, <toggle>, ``` code, | tables |), children indented by 2 '
      'spaces, inline **bold** *italic* ~~strike~~ `code` [links](url) <u> '
      '<span style>, a trailing {align=…} for block options, and photos, '
      'files, link cards and mind maps as their own lines like [Photo 1]. '
      'Each edits[].old_text must match that text exactly (copy it, '
      'including marks) and occur exactly once; all are matched against the '
      'current body, not one after another, and must not overlap. Keep '
      'old_text short but unique; merge nearby changes into one edit. '
      'new_text is written the same way: an empty line is an empty '
      'paragraph; drop a [Photo n] line to remove that photo, move the line '
      'to move it; ![](P1) on its own line adds a photo the user sent in '
      'this chat. To add text at the end, include the last line in old_text. '
      'To rewrite the whole entry, pass `body` (the complete new body) '
      'instead of `edits`. Formatting you do not touch is kept.';

  @override
  Set<String> get diaryIdArgs => const <String>{'id'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'id': AiStringSchema(),
      'edits': AiArraySchema(
        items: AiObjectSchema(
          properties: <String, AiSchema>{
            'old_text': AiStringSchema(
              description: 'Exact text from the body, occurring once.',
            ),
            'new_text': AiStringSchema(
              description: 'Replacement; empty to delete old_text.',
              allowEmpty: true,
            ),
          },
          required: <String>['old_text', 'new_text'],
        ),
        maxItems: 50,
        description:
            'Replacements, each matched against the body before any edit.',
      ),
      'body': AiStringSchema(
        description: 'The whole new body, instead of edits.',
        allowEmpty: true,
      ),
    },
    required: <String>['id'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolEditDiary;

  @override
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) {
    final diary = subjects
        .where((subject) => subject.kind == AiSubjectKind.diary)
        .firstOrNull;
    if (diary == null) return label(l10n, args);
    final title = diary.title.trim();
    final date = diary.date;
    final name = title.isNotEmpty || date == null
        ? title
        : DateFormat.yMMMd(l10n.localeName).format(date);
    return name.isEmpty ? label(l10n, args) : l10n.aiToolEditDiaryNamed(name);
  }

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) {
    if (key != 'edits') return null;
    if (value is! List) return '';
    return [
      for (final edit in value)
        if (edit is Map && edit['old_text'] is String)
          switch (edit['new_text']) {
            final String text when text.isNotEmpty => l10n.aiToolEditReplace(
              _clip(edit['old_text']! as String),
              _clip(text),
            ),
            _ => l10n.aiToolEditRemove(_clip(edit['old_text']! as String)),
          },
    ].join('\n');
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final (_, result) = await _plan(context, args);
    return AiToolPreview(
      title: label(context.l10n, args),
      lines: [...result.changes.take(12), if (result.changes.length > 12) '…'],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final (diary, result) = await _plan(context, args);
    final document = result.document;
    await context.database.updateDiaryContent(
      diaryId: diary.diaryId,
      contentDocJson: encodeDiaryBlocks(document),
      contentText: diaryBlocksPlainText(document),
    );
    aiRefreshDiaries(context.container, [diary.diaryId]);
    final notes = <String>[
      if (result.removedMarks.isNotEmpty || result.photosAdded > 0)
        'Photo and attachment numbers may have changed; read the entry '
            'again before referring to them.',
      if (result.droppedLinks.isNotEmpty)
        aiDroppedLinksNote(result.droppedLinks),
    ];
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        if (result.removedMarks.isNotEmpty) 'removed': result.removedMarks,
        if (result.photosAdded > 0) 'photos_added': result.photosAdded,
        if (notes.isNotEmpty) 'note': notes.join(' '),
      },
      summary: context.l10n.aiToolDiaryChanged(aiDiaryName(diary)),
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

  /// 找到能改的那篇并算出改后的正文（预览与执行共用，都不写库）。
  Future<(Diary, AiDiaryEditResult)> _plan(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final found = await aiWritableDiary(context, args['id']! as String);
    final diary = found.diary;
    final rawEdits = args['edits'] as List?;
    final body = args['body'] as String?;
    if ((rawEdits == null) == (body == null)) {
      throw const AiToolFailure('Give either `edits` or `body`, not both.');
    }
    final document = aiDiaryDocument(diary.content, diary.contentText);
    if (diaryMindMapPage(document) != null) {
      throw const AiToolFailure(
        'This entry is a mind map; its topics can only be edited in the mind '
        'map itself. Offer open_page for the entry instead.',
      );
    }
    final result = aiEditDiaryMarkdown(
      document,
      l10n: context.kit.l10n,
      chatImages: context.chatImages,
      body: body,
      edits: rawEdits == null
          ? null
          : [
              for (final edit in rawEdits.cast<Map<String, Object?>>())
                (
                  oldText: edit['old_text']! as String,
                  newText: edit['new_text']! as String,
                ),
            ],
    );
    return (diary, result);
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

/// 详情里一段文字的简写：换行写成 ↵，过长截断。
String _clip(String text) {
  final line = text.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ↵ ');
  return line.length > 40 ? '${line.substring(0, 40)}…' : line;
}
