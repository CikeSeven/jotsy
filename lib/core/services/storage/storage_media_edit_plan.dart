import 'dart:convert';

import '../../database/app_database.dart';
import '../../database/diary_blocks/diary_blocks_codec.dart';
import '../../database/diary_blocks/diary_blocks_media.dart';
import '../../database/diary_blocks/diary_blocks_media_edit.dart';
import 'storage_reference_index.dart';

/// 把“删掉这些文件”或“把这些文件换成新文件”换算成逐行改写（纯函数）。
///
/// - 输入：一次读取的全部引用来源与要处理的定位键；
/// - 输出：带前置条件的改写（[StorageMediaEdits]）与受影响的数量（确认
///   对话框的文案用）；
/// - 不读写数据库与文件。
///
/// 删除：正文里的媒体块整块移除（纯文本镜像随之重算），日记封面清空，日记
/// 本封面去掉 `cover` 并重置取景（换图或移除封面图时取景重置，与日记本编辑
/// 页同一口径），留言图片列去掉该项，草稿同正文与封面。替换：只换路径，
/// 其余数据（显示宽高、小图标记、取景）原样保留：压缩不改变画面比例。
class StorageEditPlan {
  const StorageEditPlan({
    required this.edits,
    required this.diaries,
    required this.notebooks,
    required this.comments,
    required this.removedComments,
    required this.drafts,
  });

  final StorageMediaEdits edits;

  /// 正文或封面要改的日记篇数。
  final int diaries;
  final int notebooks;
  final int comments;

  /// 删完图片后既没字也没图、要整条删除的留言数（已含在 [comments] 里）。
  final int removedComments;
  final int drafts;
}

/// 删除 [keys] 指向的文件前要做的改写。
Future<StorageEditPlan> planStorageMediaRemoval(
  StorageReferenceSources sources,
  Set<String> keys,
) => _plan(sources, keys, null);

/// 把 [replacements]（定位键 → 新文件的绝对路径）换进全部引用。
Future<StorageEditPlan> planStorageMediaReplacement(
  StorageReferenceSources sources,
  Map<String, String> replacements,
) => _plan(sources, replacements.keys.toSet(), replacements);

Future<StorageEditPlan> _plan(
  StorageReferenceSources sources,
  Set<String> keys,
  Map<String, String>? replacements,
) async {
  bool hit(String? path) => keys.contains(storageMediaKeyOf(path));
  String? replaced(String? path) {
    final key = storageMediaKeyOf(path);
    if (key == null || !keys.contains(key)) return path;
    return replacements?[key];
  }

  final diaryEdits = <StorageDiaryEdit>[];
  for (final diary in sources.diaries) {
    final content = await _editContent(diary.content, keys, replacements);
    final coverHit = hit(diary.cover);
    if (content == null && !coverHit) continue;
    diaryEdits.add(
      StorageDiaryEdit(
        id: diary.id,
        expectedContent: diary.content,
        expectedCover: diary.cover,
        content: content?.encoded ?? diary.content,
        contentText: content?.plainText,
        cover: coverHit ? replaced(diary.cover) : diary.cover,
      ),
    );
  }

  final notebookEdits = <StorageNotebookEdit>[];
  for (final notebook in sources.notebooks) {
    final json = _jsonMap(notebook.payload);
    final cover = json?['cover'];
    if (json == null || cover is! String || !hit(cover)) continue;
    final target = replaced(cover);
    if (target == null) {
      json.remove('cover');
      final style = json['coverStyle'];
      if (style is Map) {
        final kept = Map<Object?, Object?>.of(style)
          ..remove('x')
          ..remove('y')
          ..remove('zoom');
        if (kept.isEmpty) {
          json.remove('coverStyle');
        } else {
          json['coverStyle'] = kept;
        }
      }
    } else {
      json['cover'] = target;
    }
    notebookEdits.add(
      StorageNotebookEdit(
        id: notebook.id,
        expectedPayload: notebook.payload,
        payload: jsonEncode(json),
      ),
    );
  }

  final commentEdits = <StorageCommentEdit>[];
  var removedComments = 0;
  for (final comment in sources.comments) {
    final images = decodeDiaryCommentImages(comment.images);
    if (!images.any(hit)) continue;
    final next = encodeDiaryCommentImages([
      for (final image in images)
        if (replaced(image) case final target?) target,
    ]);
    if (next == null && comment.content.trim().isEmpty) removedComments++;
    commentEdits.add(
      StorageCommentEdit(
        id: comment.id,
        expectedImages: comment.images,
        images: next,
      ),
    );
  }

  final draftEdits = <StorageDraftEdit>[];
  for (final draft in sources.drafts) {
    final json = _jsonMap(draft.payload);
    if (json == null) continue;
    final rawContent = json['contentDocJson'];
    final content = rawContent is String
        ? await _editContent(rawContent, keys, replacements)
        : null;
    final cover = json['cover'];
    final coverHit = cover is String && hit(cover);
    if (content == null && !coverHit) continue;
    if (content != null) {
      json['contentDocJson'] = content.encoded;
      if (content.plainText case final text?) json['contentText'] = text;
    }
    if (coverHit) json['cover'] = replaced(cover);
    draftEdits.add(
      StorageDraftEdit(
        id: draft.id,
        expectedPayload: draft.payload,
        payload: jsonEncode(json),
        contentText: content?.plainText,
      ),
    );
  }

  return StorageEditPlan(
    edits: StorageMediaEdits(
      diaries: diaryEdits,
      notebooks: notebookEdits,
      comments: commentEdits,
      drafts: draftEdits,
    ),
    diaries: diaryEdits.length,
    notebooks: notebookEdits.length,
    comments: commentEdits.length,
    removedComments: removedComments,
    drafts: draftEdits.length,
  );
}

/// 改写后的正文；没有命中时为 null。删除时 [plainText] 为重算的纯文本
/// 镜像，替换时为 null（文字不变）。
typedef _ContentEdit = ({String encoded, String? plainText});

Future<_ContentEdit?> _editContent(
  String raw,
  Set<String> keys,
  Map<String, String>? replacements,
) async {
  if (raw.isEmpty) return null;
  final Map<String, Object?> document;
  try {
    // 先用原文粗筛：绝大多数日记不含要处理的文件，不必逐篇解码（`file:`
    // URI 里的文件名是百分号编码的，两种写法都查）。
    final mentioned = keys.any((key) {
      final name = key.split('/').last;
      return raw.contains(name) || raw.contains(Uri.encodeComponent(name));
    });
    if (!mentioned) return null;
    document = decodeStoredDiaryBlocks(raw);
  } catch (_) {
    return null;
  }
  bool matches(String path) => keys.contains(storageMediaKeyOf(path));
  if (replacements == null) {
    final removed = removeDiaryBlocksMedia(
      document,
      (_, path) => matches(path),
    );
    if (removed == 0) return null;
    return (
      encoded: encodeDiaryBlocks(document),
      plainText: diaryBlocksPlainText(document),
    );
  }
  var touched = false;
  await rewriteDiaryBlocksMediaPaths(document, (_, path) async {
    final target = replacements[storageMediaKeyOf(path)];
    if (target == null) return path;
    touched = true;
    return target;
  });
  if (!touched) return null;
  return (encoded: encodeDiaryBlocks(document), plainText: null);
}

Map<String, Object?>? _jsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, Object?>.of(decoded.cast()) : null;
  } on FormatException {
    return null;
  }
}
