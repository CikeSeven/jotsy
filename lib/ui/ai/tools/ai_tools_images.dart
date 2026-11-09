// 智能体看图：日记里的图片与对话里用户附的图片。
//
// - 读日记的口径与 `read_diaries` 相同（[aiAgentReadDiary]）：回收站、
//   未解封胶囊、不存在当作找不到；私密日记一律不给（比单篇功能更严）；
//   AI 隐私里排除的日记本与标签不给。回放旧图片时也按它重新检查；
// - 日记里的图片按正文顺序编号（去重，`AiVisionImages.sourcesOf`），
//   `read_diaries` 在正文的图片位置写“[图片 n]”（[aiDiaryTextWithImageMarks]），
//   `view_images` 按同样的编号取图：可以指定任意几张（如 4、5、6），日记有
//   十张、一次只发三张时也看得到后面的；
// - 一次最多发 AI 设置里“每次最多发送”那么多张（1–20），多要的在结果里
//   列出来让模型下次再要；整次请求的图片另有上限（`AiImageBudget`），满了
//   就请模型先就已看的作答；
// - 图片附在工具结果之后，结果 JSON 按顺序写明附上的是哪几张（Anthropic
//   会把图片挪到文字前面，图与说明不能靠相邻对应）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_media.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/ai/ai_vision.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/ai_privacy_gate.dart';
import '../models/ai_preferences.dart';
import '../models/ai_tool_subject.dart';
import '../viewmodels/ai_chat_images.dart';
import 'ai_tool.dart';

/// 读不到时回传模型的说明。
const String _notFound =
    'No readable entry with this id. Use an id or reference returned by '
    'search_diaries; if it came from there, the entry was deleted, moved to '
    'the recycle bin or is a sealed time capsule.';
const String _excluded =
    'This entry is private or excluded from AI by the user.';

/// 智能体读一篇日记（正文或图片）：读得到时返回日记（带块文档原文），
/// 否则返回给模型的说明（见文件头的口径）。
Future<({AiContextDiary? diary, String? refusal})> aiAgentReadDiary(
  ProviderContainer container, {
  required AiPreferences prefs,
  required String id,
  DateTime? now,
}) async {
  final database = container.read(appDatabaseProvider);
  final diary = await database.getAiDiary(id, now: now);
  if (diary == null) return (diary: null, refusal: _notFound);
  final privacy = prefs.privacy;
  final excluded =
      await database.isDiaryPrivate(id) ||
      diary.tags.any(privacy.excludedTagNames.contains) ||
      (await database.getDiaryNotebookIds(
        id,
      )).any(privacy.excludedNotebookIds.contains) ||
      !(await aiDiaryAllowedIn(container, id));
  if (excluded) return (diary: null, refusal: _excluded);
  return (diary: diary, refusal: null);
}

/// 发给 AI 的正文：与纯文本镜像相同，只是图片的位置写“[图片 n]”（编号同
/// `AiVisionImages.sourcesOf`）。没有图片时就是原来的镜像。
String aiDiaryTextWithImageMarks(AppLocalizations l10n, AiContextDiary diary) {
  final content = diary.contentJson;
  if (content == null) return diary.contentText;
  final sources = AiVisionImages.sourcesOf(content);
  if (sources.isEmpty) return diary.contentText;
  final numbers = <String, int>{
    for (final (index, source) in sources.indexed) source: index + 1,
  };
  final Map<String, Object?> document;
  try {
    document = decodeStoredDiaryBlocks(content);
  } catch (_) {
    return diary.contentText;
  }
  return diaryBlocksPlainText(
    document,
    embedText: (node) {
      final marks = [
        for (final media in diaryNodeMedia(node))
          if (media.kind == DiaryBlockMediaKind.image)
            if (numbers[media.path] case final number?)
              l10n.aiPromptDiaryImage(number),
      ];
      return marks.isEmpty ? null : marks.join(' ');
    },
  );
}

/// 同一篇日记换一份正文文字（其余原样）。
AiContextDiary aiDiaryWithText(AiContextDiary diary, String text) =>
    AiContextDiary(
      diaryId: diary.diaryId,
      title: diary.title,
      contentText: text,
      createdAt: diary.createdAt,
      isArchived: diary.isArchived,
      mood: diary.mood,
      weather: diary.weather,
      location: diary.location,
      tags: diary.tags,
      contentJson: diary.contentJson,
    );

/// 要看的一张图。
typedef _Wanted = ({String label, String source, String? diaryId});

/// 看图：日记里的（按编号）与对话里用户附的（按 P 编号）。
class ViewImagesTool extends AiTool {
  const ViewImagesTool();

  @override
  String get name => 'view_images';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Look at photos. Entry photos: `diary_id` (id or reference like D3) '
      'and `images`, the photo numbers that read_diaries marks in the text '
      'as [Photo n]; any numbers, e.g. [4, 5, 6]; without `images` it starts '
      'from the first. Chat photos: `attachments`, references like P1 from '
      "the user's messages. Only a few photos are sent per call (the user's "
      'limit); the result lists the ones left for another call. The photos '
      'follow the tool results in the order given by `attached`.';

  @override
  Set<String> get diaryIdArgs => const <String>{'diary_id'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'diary_id': AiStringSchema(),
      'images': AiArraySchema(items: AiIntegerSchema(minimum: 1), maxItems: 50),
      'attachments': AiArraySchema(items: AiStringSchema(), maxItems: 50),
    },
  );

  @override
  bool isAvailable(AiToolEnv env) => env.vision;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolViewImages;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final diaryId = args['diary_id'] as String?;
    final numbers = (args['images'] as List?)?.cast<int>() ?? const <int>[];
    final refs =
        (args['attachments'] as List?)?.cast<String>() ?? const <String>[];
    if (diaryId == null && refs.isEmpty) {
      throw const AiToolFailure(
        'Give `diary_id` (with optional `images`) or `attachments`.',
      );
    }
    final wanted = <_Wanted>[];
    final problems = <Map<String, Object?>>[];
    final subjects = <AiToolSubject>[];
    var diaryPhotos = 0;
    if (diaryId != null) {
      final read = await aiAgentReadDiary(
        context.container,
        prefs: context.prefs,
        id: diaryId,
        now: context.now,
      );
      final diary = read.diary;
      if (diary == null) throw AiToolFailure(read.refusal!);
      final sources = AiVisionImages.sourcesOf(diary.contentJson ?? '');
      diaryPhotos = sources.length;
      if (sources.isEmpty && refs.isEmpty) {
        throw const AiToolFailure('This entry has no photos.');
      }
      final ref = context.citations.refFor(
        diary.diaryId,
        title: diary.title,
        date: diary.createdAt,
      );
      subjects.add(aiContextDiarySubject(diary));
      final picked = numbers.isEmpty
          ? [for (var n = 1; n <= sources.length; n++) n]
          : <int>{...numbers}.toList();
      for (final number in picked) {
        if (number > sources.length) {
          problems.add(<String, Object?>{
            'image': number,
            'error': 'No photo $number; this entry has ${sources.length}.',
          });
          continue;
        }
        wanted.add((
          label: '$ref#$number',
          source: sources[number - 1],
          diaryId: diary.diaryId,
        ));
      }
    }
    for (final raw in <String>{...refs}) {
      final image = aiChatImageByRef(context.chatImages, raw);
      if (image == null || image.removed) {
        problems.add(<String, Object?>{
          'attachment': raw,
          'error': image == null
              ? 'No photo with this reference in this chat.'
              : 'The user deleted this photo.',
        });
        continue;
      }
      wanted.add((label: image.ref, source: image.path, diaryId: null));
    }

    final limit = context.prefs.visionMaxImages;
    final attached = <AiToolImage>[];
    final later = <String>[];
    var requestFull = false;
    for (final item in wanted) {
      if (attached.length >= limit || requestFull) {
        later.add(item.label);
        continue;
      }
      final part = await AiVisionImages.load(
        item.source,
        maxSide: context.prefs.visionMaxSide,
      );
      if (part == null) {
        problems.add(<String, Object?>{
          'image': item.label,
          'error':
              'Could not read this photo (the file is gone, is an online '
              'image, or cannot be decoded here).',
        });
        continue;
      }
      if (!context.imageBudget.fits(part.bytes.lengthInBytes)) {
        requestFull = true;
        later.add(item.label);
        continue;
      }
      context.imageBudget.add(part.bytes.lengthInBytes);
      attached.add(
        AiToolImage(
          label: item.label,
          source: item.source,
          diaryId: item.diaryId,
          part: part,
        ),
      );
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'attached': [for (final image in attached) image.label],
        if (diaryId != null) 'entry_photos': diaryPhotos,
        if (later.isNotEmpty) 'not_sent_yet': later,
        if (later.isNotEmpty)
          'hint': requestFull
              ? 'This request already carries as many photos as it can. '
                    'Answer from what you have seen; the user can ask again '
                    'in a new message to see the rest.'
              : 'Call view_images again for the photos in not_sent_yet.',
        if (problems.isNotEmpty) 'problems': problems,
        if (attached.isNotEmpty)
          'note':
              'The attached photos follow the tool results, in the order of '
              '`attached`.',
      },
      summary: context.l10n.aiToolViewedImages(attached.length),
      subjects: subjects,
      images: attached,
    );
  }
}
