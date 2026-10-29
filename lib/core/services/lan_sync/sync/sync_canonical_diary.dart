import 'package:drift/drift.dart' show Value;

import '../../../database/app_database.dart';
import '../../../database/diary_blocks/diary_blocks_codec.dart';
import 'sync_canonical_support.dart';
import 'sync_media_refs.dart';
import 'sync_model.dart';

/// 日记行 ↔ 规范记录（规格 §2.2 的 diary 行）。
///
/// - 输入：[SyncRawDiary] 与这篇日记的标签名；输出：分面 content / stamp / pin /
///   archive / trash / capsule / tags；
/// - 反向：[SyncDiaryColumns.fromRecord] 给出写库的列值（媒体引用还原到本机
///   数据根、`content_text` 由正文重新生成、标题按列长截断）；
/// - 无副作用。
///
/// metadata 的处理：
/// - 去掉 `tagIds`：发布面板写入的是本机标签 id（见 `PublishMetadataComposer`），
///   没有任何地方读取，带到另一台设备上只会是错的 id；
/// - `capsule` 挪进 capsule 分面：胶囊的解封时间与 metadata 里的胶囊块是一体的，
///   放在 content 里会让“只改了胶囊”被当成正文冲突；
/// - 其余键（generatedAt、device、stats、context、import、geo…）原样保留。

const String _kTagIdsKey = 'tagIds';
const String _kCapsuleKey = 'capsule';

/// 由日记行算出除 tags 以外的分面（哈希缓存按行指纹缓存的就是这一部分）。
Map<String, Object?> syncDiaryRowFacets(SyncRawDiary row) {
  final metadata = syncDecodeJsonObjectColumn(row.metadata);
  Object? metadataValue = metadata;
  Object? capsuleMeta;
  if (metadata is Map<String, Object?>) {
    final copy = Map<String, Object?>.of(metadata)..remove(_kTagIdsKey);
    capsuleMeta = copy.remove(_kCapsuleKey);
    metadataValue = syncNormalizeMediaRefs(copy);
  }
  // 历史 Delta / 旧节点 / 纯文本经 decodeStoredDiaryBlocks 统一成块文档；
  // 再提一次看不见的子块：Delta 转换的结果不经过这一步，写回后再读时就会
  // 被提起，规范值必须一开始就是提过之后的形状，否则写到对方后不再相等。
  final document = liftHiddenDiaryBlockChildren(
    decodeStoredDiaryBlocks(row.content),
  );
  return <String, Object?>{
    SyncFacet.content: <String, Object?>{
      'title': syncTruncate(row.title, SyncColumnLimits.diaryTitle),
      'content': syncNormalizeMediaRefs(document),
      'cover': syncNormalizeMediaRefs(row.cover),
      'metadata': metadataValue,
      'createdAt': syncMillisOfSeconds(row.createdAt),
    },
    SyncFacet.stamp: <String, Object?>{
      'updatedAt': syncMillisOfSeconds(row.updatedAt),
    },
    SyncFacet.pin: <String, Object?>{'pinned': row.isPinned},
    SyncFacet.archive: <String, Object?>{
      'archived': row.isArchived,
      'archivedAt': syncMillisOfSecondsOrNull(row.archivedAt),
    },
    SyncFacet.trash: <String, Object?>{
      'deleted': row.isDeleted,
      'deletedAt': syncMillisOfSecondsOrNull(row.deletedAt),
    },
    SyncFacet.capsule: <String, Object?>{
      'unlockAt': syncMillisOfSecondsOrNull(row.capsuleUnlockAt),
      'lockedAt': syncMillisOfSecondsOrNull(row.capsuleLockedAt),
      'meta': syncNormalizeMediaRefs(capsuleMeta),
    },
  };
}

/// tags 分面：去重、按 UTF-16 码元排序的标签名列表。
Map<String, Object?> syncDiaryTagsFacet(Iterable<String> names) {
  final sorted = <String>{
    for (final name in names) syncTruncate(name, SyncColumnLimits.tagName),
  }.toList()..sort();
  return <String, Object?>{'names': sorted};
}

SyncRecord syncDiaryRecord(SyncRawDiary row, Iterable<String> tagNames) =>
    SyncRecord(SyncKey(SyncEntity.diary, row.diaryId), <String, Object?>{
      ...syncDiaryRowFacets(row),
      SyncFacet.tags: syncDiaryTagsFacet(tagNames),
    });

/// 规范记录写回本机日记表的列值。标签按名称给出，换算本地 id 由写入层负责。
class SyncDiaryColumns {
  const SyncDiaryColumns({
    required this.diaryId,
    required this.title,
    required this.content,
    required this.contentText,
    required this.cover,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
    required this.archived,
    required this.archivedAt,
    required this.deleted,
    required this.deletedAt,
    required this.capsuleUnlockAt,
    required this.capsuleLockedAt,
    required this.tagNames,
  });

  /// 由完整的日记规范记录还原；缺分面或字段类型不对时抛 [FormatException]。
  ///
  /// [dataRoot] 是本机数据根目录的路径：`jotsy-media:<键>` 还原为
  /// `<dataRoot>/<键>`。`content_text` 与现有写库口径一致，由（还原后的）
  /// 正文经 [diaryBlocksPlainText] 生成。
  factory SyncDiaryColumns.fromRecord(
    SyncRecord record, {
    required String dataRoot,
  }) {
    if (record.key.entity != SyncEntity.diary) {
      throw ArgumentError.value(record.key, 'record', '不是日记记录');
    }
    final facets = record.facets;
    final content = syncMapOf(facets[SyncFacet.content], 'content');
    final stamp = syncMapOf(facets[SyncFacet.stamp], 'stamp');
    final pin = syncMapOf(facets[SyncFacet.pin], 'pin');
    final archive = syncMapOf(facets[SyncFacet.archive], 'archive');
    final trash = syncMapOf(facets[SyncFacet.trash], 'trash');
    final capsule = syncMapOf(facets[SyncFacet.capsule], 'capsule');
    final tags = syncMapOf(facets[SyncFacet.tags], 'tags');

    final document = syncMapOf(
      syncRebindMediaRefs(content['content'], dataRoot),
      'content.content',
    );

    var metadata = syncRebindMediaRefs(content['metadata'], dataRoot);
    final capsuleMeta = syncRebindMediaRefs(capsule['meta'], dataRoot);
    if (metadata is Map && capsuleMeta != null) {
      metadata = <String, Object?>{
        ...metadata.cast<String, Object?>(),
        _kCapsuleKey: capsuleMeta,
      };
    }

    final names = tags['names'];
    if (names is! List) throw const FormatException('tags.names 不是列表');

    return SyncDiaryColumns(
      diaryId: record.key.id,
      title: syncTruncate(
        syncStringOf(content['title'], 'title'),
        SyncColumnLimits.diaryTitle,
      ),
      content: encodeDiaryBlocks(document),
      contentText: diaryBlocksPlainText(document),
      cover: syncStringOrNullOf(
        syncRebindMediaRefs(content['cover'], dataRoot),
        'cover',
      ),
      metadata: syncEncodeJsonObjectColumn(metadata, 'metadata'),
      createdAt: syncDateTimeOf(content['createdAt']),
      updatedAt: syncDateTimeOf(stamp['updatedAt']),
      pinned: syncBoolOf(pin['pinned'], 'pinned'),
      archived: syncBoolOf(archive['archived'], 'archived'),
      archivedAt: syncDateTimeOrNullOf(archive['archivedAt']),
      deleted: syncBoolOf(trash['deleted'], 'deleted'),
      deletedAt: syncDateTimeOrNullOf(trash['deletedAt']),
      capsuleUnlockAt: syncDateTimeOrNullOf(capsule['unlockAt']),
      capsuleLockedAt: syncDateTimeOrNullOf(capsule['lockedAt']),
      tagNames: <String>[
        for (final name in names)
          syncTruncate(syncStringOf(name, 'tags'), SyncColumnLimits.tagName),
      ],
    );
  }

  final String diaryId;
  final String title;
  final String content;
  final String contentText;
  final String? cover;
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final bool archived;
  final DateTime? archivedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final DateTime? capsuleUnlockAt;
  final DateTime? capsuleLockedAt;
  final List<String> tagNames;

  /// 全部业务列都给值的 companion（不含本地 id），插入与按原值更新共用。
  DiariesCompanion toCompanion() => DiariesCompanion(
    diaryId: Value<String>(diaryId),
    title: Value<String>(title),
    content: Value<String>(content),
    contentText: Value<String>(contentText),
    cover: Value<String?>(cover),
    metadata: Value<String>(metadata),
    createdAt: Value<DateTime>(createdAt),
    updatedAt: Value<DateTime>(updatedAt),
    isPinned: Value<bool>(pinned),
    isArchived: Value<bool>(archived),
    archivedAt: Value<DateTime?>(archivedAt),
    isDeleted: Value<bool>(deleted),
    deletedAt: Value<DateTime?>(deletedAt),
    capsuleUnlockAt: Value<DateTime?>(capsuleUnlockAt),
    capsuleLockedAt: Value<DateTime?>(capsuleLockedAt),
  );
}
