import 'dart:convert';

import '../../database/app_database.dart';
import '../../database/diary_blocks/diary_blocks_media.dart';
import '../diary_media_references.dart';
import 'storage_usage_models.dart';

/// 托管媒体的引用索引：定位键 → 谁在引用它（纯函数，可在后台 isolate 里建）。
///
/// 结构化地解析每一种已知来源（日记正文与封面、日记本封面、留言图片、草稿
/// 正文与封面、AI 对话里用户附带的图片），删除与压缩据此知道要改写哪些行。另外用与媒体回收同一份
/// 保守扫描（[DiaryMediaReferences]：遍历 JSON 里每个字符串，再按“原文包含”
/// 兜底）判断文件是否在用：结构化解析不认识的提及（日记 metadata、旧版单份
/// 草稿）记为 [StorageOtherRef]，文件算在用、但存储管理不删不压；回收与这里
/// 的“未使用”口径因此完全一致，界面上显示能清多少，清理时就清多少。
class StorageReferenceIndex {
  StorageReferenceIndex._(this.refsByKey, this._conservative);

  /// 每个被引用文件的引用（同一行的同一角色只记一次）。
  final Map<String, List<StorageMediaRef>> refsByKey;
  final DiaryMediaReferences _conservative;

  /// 与媒体回收同一口径：只要被提到就算在用。
  bool isReferenced(String key) =>
      refsByKey.containsKey(key) || _conservative.contains(key);

  List<StorageMediaRef> refsOf(String key) =>
      refsByKey[key] ?? const <StorageMediaRef>[];
}

/// 正文、封面与留言里的一个路径（绝对路径或 `file:` URI）对应的定位键；
/// 不在托管目录里（网络图片、相册原图）时为 null。
String? storageMediaKeyOf(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('file:')) {
    try {
      return diaryMediaKeyOf(Uri.decodeComponent(Uri.parse(trimmed).path));
    } on FormatException {
      return diaryMediaKeyOf(trimmed);
    }
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return null;
  }
  return diaryMediaKeyOf(trimmed);
}

StorageReferenceIndex buildStorageReferenceIndex(
  StorageReferenceSources sources, {
  required DateTime now,
  String? legacyDraftRaw,
}) {
  final refs = <String, List<StorageMediaRef>>{};
  final seen = <String>{};
  void add(String? path, StorageMediaRef ref, String identity) {
    final key = storageMediaKeyOf(path);
    if (key == null || !seen.add('$key|$identity')) return;
    (refs[key] ??= <StorageMediaRef>[]).add(ref);
  }

  final diariesById = <String, StorageDiarySource>{};
  for (final diary in sources.diaries) {
    diariesById[diary.diaryId] = diary;
    final visibility = diaryVisibility(diary, now);
    StorageDiaryRef ref({required bool isCover}) => StorageDiaryRef(
      diaryLocalId: diary.id,
      diaryId: diary.diaryId,
      title: diary.title,
      createdAt: diary.createdAt,
      isCover: isCover,
      isDeleted: diary.isDeleted,
      visibility: visibility,
    );
    for (final media in _safeMedia(diary.content)) {
      add(media.path, ref(isCover: false), 'd${diary.id}');
    }
    add(diary.cover, ref(isCover: true), 'c${diary.id}');
  }
  for (final notebook in sources.notebooks) {
    add(
      notebookCoverOf(notebook.payload),
      StorageNotebookCoverRef(
        notebookLocalId: notebook.id,
        notebookId: notebook.notebookId,
        name: notebook.name,
        visibility: notebook.isLocked
            ? StorageRefVisibility.locked
            : notebook.isPrivate
            ? StorageRefVisibility.private
            : StorageRefVisibility.visible,
      ),
      'n${notebook.id}',
    );
  }
  for (final comment in sources.comments) {
    final diary = diariesById[comment.diaryId];
    final ref = StorageCommentRef(
      commentLocalId: comment.id,
      diaryId: comment.diaryId,
      diaryTitle: diary?.title ?? '',
      diaryCreatedAt: diary?.createdAt,
      diaryIsDeleted: diary?.isDeleted ?? false,
      visibility: diary == null
          ? StorageRefVisibility.visible
          : diaryVisibility(diary, now),
    );
    for (final image in decodeDiaryCommentImages(comment.images)) {
      add(image, ref, 'm${comment.id}');
    }
  }
  for (final message in sources.aiMessages) {
    final ref = StorageAiMessageRef(
      messageLocalId: message.id,
      conversationId: message.conversationId,
      conversationTitle: message.conversationTitle,
      createdAt: message.createdAt,
    );
    // 墓碑（被删掉的位置）是空串，没有定位键，自然跳过。
    for (final image in decodeAiMessageImages(message.images)) {
      add(image, ref, 'a${message.id}');
    }
  }
  for (final draft in sources.drafts) {
    final payload = draftPayloadOf(draft.payload);
    if (payload == null) continue;
    final ref = StorageDraftRef(draftLocalId: draft.id, title: draft.title);
    final content = payload['contentDocJson'];
    if (content is String) {
      for (final media in _safeMedia(content)) {
        add(media.path, ref, 'r${draft.id}');
      }
    }
    final cover = payload['cover'];
    add(cover is String ? cover : null, ref, 'r${draft.id}');
  }

  final conservative = DiaryMediaReferences([
    for (final diary in sources.diaries) ...[
      diary.content,
      diary.cover,
      diary.metadata,
    ],
    for (final draft in sources.drafts) draft.payload,
    for (final notebook in sources.notebooks) notebook.payload,
    for (final comment in sources.comments) comment.images,
    for (final message in sources.aiMessages) message.images,
    legacyDraftRaw,
  ]);
  for (final key in conservative.keys) {
    refs.putIfAbsent(key, () => const <StorageMediaRef>[StorageOtherRef()]);
  }
  return StorageReferenceIndex._(refs, conservative);
}

/// 一篇日记的可见程度（见 [StorageRefVisibility]）。
StorageRefVisibility diaryVisibility(StorageDiarySource diary, DateTime now) {
  final unlockAt = diary.capsuleUnlockAt;
  if (unlockAt != null && unlockAt.isAfter(now)) {
    return StorageRefVisibility.capsule;
  }
  if (diary.isLocked) return StorageRefVisibility.locked;
  if (diary.isPrivate) return StorageRefVisibility.private;
  return StorageRefVisibility.visible;
}

/// 日记本载荷里的封面路径；载荷损坏时为 null。
String? notebookCoverOf(String payload) {
  final json = _jsonMap(payload);
  final cover = json?['cover'];
  return cover is String ? cover : null;
}

/// 草稿载荷（`NewDiaryDraft.toJson`）；损坏时为 null。
Map<String, Object?>? draftPayloadOf(String payload) => _jsonMap(payload);

Map<String, Object?>? _jsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// 解析失败的正文不让整次扫描失败：那一篇按没有结构化引用处理（保守扫描
/// 仍会把它提到的文件算作在用）。
Iterable<DiaryBlockMedia> _safeMedia(String content) {
  try {
    return diaryContentMedia(content).toList(growable: false);
  } catch (_) {
    return const <DiaryBlockMedia>[];
  }
}
