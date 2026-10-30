part of 'sync_planner.dart';

/// 冲突副本（规格 §4.1 diary.content）。
///
/// 正文真冲突时，stamp 较新者留在原 id，败方版本另存为一篇新日记：
/// - id = UUIDv5([kSyncConflictCopyNamespace], 原 diaryId + 败方 content 哈希)：
///   只由数据决定，中断后重新规划、换一台发起方规划都得到同一个 id；
/// - 这个 id 在任一侧已经存在（上次同步只写了一侧）或任一侧有它的墓碑（用户
///   看过并删掉了）时不再生成——已存在的副本作为普通记录照常复制；
/// - 标题 = 原标题 + 本地化后缀，截断到日记标题列长（不切开代理对）；
///   metadata 加 `sync.conflictOf = 原 diaryId`（metadata 是坏数据原文时无处
///   可加，原样保留）；
/// - 继承败方的 stamp、tags、pin、archive、trash、capsule 分面与败方的日记本
///   成员关系（含章节）：私密日记本里的内容不会因副本出现在“全部日记”，
///   未解封的胶囊不会提前解封，回收站里的仍在回收站。
/// 副本与它的成员关系在两侧都是新增（expected 为 null）；书序列表在 `_lists`
/// 里把副本排在原日记之后。

/// 冲突副本 id 的 UUIDv5 命名空间（固定值，改了就等于改协议）。
const String kSyncConflictCopyNamespace =
    '6f1d3c2a-8b4e-4c7d-9a15-3e2f7b9d0c48';

/// 冲突副本的 diaryId。
String syncConflictCopyId(String originalId, String loserContentHash) =>
    syncUuidV5(kSyncConflictCopyNamespace, '$originalId$loserContentHash');

/// RFC 4122 第 5 版 UUID：SHA-1(命名空间 16 字节 ‖ UTF-8 名称) 取前 16 字节，
/// 置版本号 5 与 RFC 4122 变体位，小写带连字符。
@visibleForTesting
String syncUuidV5(String namespace, String name) {
  final hex = namespace.replaceAll('-', '');
  if (hex.length != 32) {
    throw ArgumentError.value(namespace, 'namespace', '不是 UUID');
  }
  final bytes = <int>[
    for (var i = 0; i < 32; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
    ...utf8.encode(name),
  ];
  final digest = sha1.convert(bytes).bytes.sublist(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  final out = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) out.write('-');
    out.write(digest[i].toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

extension _Copies on _Planner {
  void createCopies() {
    final losers = contentLosers.keys.toList()..sort();
    for (final key in losers) {
      final loser = contentLosers[key]!;
      final loserHash = hashesOn(loser, key)![SyncFacet.content]!;
      final copyKey = SyncKey(
        SyncEntity.diary,
        syncConflictCopyId(key.id, loserHash),
      );
      if (_existsAnywhere(copyKey)) continue;
      final facets = record(loser, key)!.facets;
      final memberships = _membershipsOf(loser, key.id);
      final values = <SyncKey, Map<String, Object?>>{};
      for (final membership in memberships) {
        final value = currentFacets(loser, membership);
        if (value != null) values[membership] = value;
      }
      if (values.length != memberships.length) continue;
      final copy = _copyFacets(
        facets,
        key.id,
        loser == _Side.local
            ? options.localLoserTitleSuffix
            : options.remoteLoserTitleSuffix,
      );
      finals[copyKey] = _Final.value(copy);
      createdKeys.add(copyKey);
      copyOriginals[copyKey.id] = key.id;
      copies.add(
        SyncConflictCopy(
          originalId: key.id,
          copyId: copyKey.id,
          title: _field(copy, SyncFacet.content, 'title')! as String,
          loser: loser.role,
        ),
      );
      for (final entry in values.entries) {
        final notebookId = parseSyncMembershipId(entry.key.id)!.notebookId;
        final memberKey = SyncKey(
          SyncEntity.membership,
          syncMembershipId(notebookId, copyKey.id),
        );
        if (_existsAnywhere(memberKey)) continue;
        finals[memberKey] = _Final.value(entry.value);
        createdKeys.add(memberKey);
      }
    }
  }

  bool _existsAnywhere(SyncKey key) =>
      presentOn(_Side.local, key) ||
      presentOn(_Side.remote, key) ||
      local.hasTombstone(key) ||
      remote.hasTombstone(key);

  /// [side] 上日记 [diaryId] 的成员关系键（来自清单，排序）。
  List<SyncKey> _membershipsOf(_Side side, String diaryId) {
    final result = <SyncKey>[
      for (final key in sideOf(side).manifest.keys)
        if (key.entity == SyncEntity.membership &&
            participates(key) &&
            parseSyncMembershipId(key.id)?.diaryId == diaryId)
          key,
    ];
    return result..sort();
  }

  Map<String, Object?> _copyFacets(
    Map<String, Object?> loser,
    String originalId,
    String titleSuffix,
  ) {
    final content = <String, Object?>{...?_mapOf(loser[SyncFacet.content])};
    final title = content['title'];
    content['title'] = syncTruncate(
      '${title is String ? title : ''}$titleSuffix',
      kSyncCopyTitleLimit,
    );
    final metadata = content['metadata'];
    if (metadata is Map) {
      final map = metadata.cast<String, Object?>();
      content['metadata'] = <String, Object?>{
        ...map,
        'sync': <String, Object?>{
          ...?_mapOf(map['sync']),
          'conflictOf': originalId,
        },
      };
    }
    return <String, Object?>{...loser, SyncFacet.content: content};
  }
}
