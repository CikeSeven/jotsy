import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_planner_sim_replica.dart';

/// 收敛模拟的写入层：按规格 §6 的口径执行一侧的计划，返回跳过的条数。
///
/// 1. 事务开始时逐条比对前置条件（写入的 expected、改名的 from / to），不符
///    的跳过；
/// 2. 原地改名（本地 id 不变，颜色取计划里的记录）；
/// 3. 按键序（实体枚举顺序）写入：按原值写列；删除时清理关联；顺序列表按
///    列表重排位置（列表里没有的现有项按原相对顺序排在末尾）。
int simApply(SimReplica replica, SyncSidePlan plan) {
  final current = replica.manifest();
  bool matches(SyncKey key, Map<String, String>? expected) {
    final now = current[key];
    if (expected == null || now == null) return expected == null && now == null;
    if (expected.length != now.length) return false;
    return expected.entries.every((e) => now[e.key] == e.value);
  }

  var skipped = 0;
  final renames = <SyncTagRenameOp>[];
  for (final rename in plan.renames) {
    if (matches(SyncKey(SyncEntity.tag, rename.from), rename.expected) &&
        !current.containsKey(SyncKey(SyncEntity.tag, rename.to))) {
      renames.add(rename);
    } else {
      skipped++;
    }
  }
  final writes = <SyncWrite>[];
  for (final write in plan.writes) {
    if (matches(write.key, write.expected)) {
      writes.add(write);
    } else {
      skipped++;
    }
  }
  // 写入层按名称建标签（日记写在标签之前）；颜色随后由同一计划里的标签
  // 记录写定。计划里没有对应标签记录的才算“补建”。
  _plannedTags = <String>{
    for (final write in writes)
      if (write.key.entity == SyncEntity.tag && write.record != null)
        write.key.id,
    for (final rename in renames) rename.to,
  };
  for (final rename in renames) {
    final tag = replica.tagNamed(rename.from)!;
    tag.name = rename.to;
    tag.color = _int(rename.record.facets[SyncFacet.color], 'color');
  }
  for (final write in writes) {
    final record = write.record;
    switch (write.key.entity) {
      case SyncEntity.diary:
        record == null
            ? simHardDeleteDiary(replica, write.key.id)
            : _putDiary(replica, record);
      case SyncEntity.tag:
        record == null
            ? _deleteTag(replica, write.key.id)
            : _putTag(replica, write.key.id, record);
      case SyncEntity.notebook:
        record == null
            ? _deleteNotebook(replica, write.key.id)
            : _putNotebook(replica, record);
      case SyncEntity.membership:
        record == null
            ? replica.members.remove(write.key.id)
            : _putMember(replica, record);
      case SyncEntity.orderList:
        if (record != null) _putList(replica, record);
      case SyncEntity.comment:
        record == null
            ? replica.comments.remove(write.key.id)
            : _putComment(replica, record);
      case SyncEntity.anniversary:
        record == null
            ? replica.anniversaries.remove(write.key.id)
            : _putAnniversary(replica, record);
      case SyncEntity.template || SyncEntity.dayMood || SyncEntity.settings:
        throw UnsupportedError('模拟里没有 ${write.key.entity}');
    }
  }
  return skipped;
}

/// 彻底删除日记：与 `hardDeleteDiary` 同一清理范围。
void simHardDeleteDiary(SimReplica replica, String id) {
  replica.diaries.remove(id);
  replica.members.removeWhere(
    (key, _) => parseSyncMembershipId(key)!.diaryId == id,
  );
  replica.comments.removeWhere((_, comment) => comment.diaryId == id);
  for (final anniversary in replica.anniversaries.values) {
    if (anniversary.linkedDiaryId == id) anniversary.linkedDiaryId = null;
  }
}

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();

int _int(Object? facet, String field) => _map(facet)[field]! as int;

void _putDiary(SimReplica replica, SyncRecord record) {
  final f = record.facets;
  final diary = replica.diaries.putIfAbsent(
    record.key.id,
    () => SimDiary(record.key.id, replica.nextLocalId()),
  );
  final content = _map(f[SyncFacet.content]);
  diary
    ..title = content['title']! as String
    ..body = content['content']
    ..metadata = content['metadata']
    ..createdAt = content['createdAt']! as int
    ..updatedAt = _int(f[SyncFacet.stamp], 'updatedAt')
    ..pinned = _map(f[SyncFacet.pin])['pinned']! as bool
    ..archived = _map(f[SyncFacet.archive])['archived']! as bool
    ..archivedAt = _map(f[SyncFacet.archive])['archivedAt'] as int?
    ..deleted = _map(f[SyncFacet.trash])['deleted']! as bool
    ..deletedAt = _map(f[SyncFacet.trash])['deletedAt'] as int?
    ..unlockAt = _map(f[SyncFacet.capsule])['unlockAt'] as int?;
  final names = (_map(f[SyncFacet.tags])['names']! as List).cast<String>();
  diary.tagIds = <int>{
    for (final name in names) _ensureTag(replica, name).localId,
  };
}

/// `ensureTagsByName` 口径：有同名标签就用它（不改颜色），没有才新建。
Set<String> _plannedTags = const <String>{};

SimTag _ensureTag(SimReplica replica, String name) {
  final existing = replica.tagNamed(name);
  if (existing != null) return existing;
  if (!_plannedTags.contains(name)) replica.unexpectedTags++;
  final tag = SimTag(replica.nextLocalId(), name, 0);
  replica.tags[tag.localId] = tag;
  return tag;
}

void _putTag(SimReplica replica, String name, SyncRecord record) {
  final color = _int(record.facets[SyncFacet.color], 'color');
  final existing = replica.tagNamed(name);
  if (existing != null) {
    existing.color = color;
  } else {
    final tag = SimTag(replica.nextLocalId(), name, color);
    replica.tags[tag.localId] = tag;
  }
}

void _deleteTag(SimReplica replica, String name) {
  final tag = replica.tagNamed(name);
  if (tag == null) return;
  replica.tags.remove(tag.localId);
  for (final diary in replica.diaries.values) {
    diary.tagIds.remove(tag.localId);
  }
}

void _putNotebook(SimReplica replica, SyncRecord record) {
  final value = _map(record.facets[SyncFacet.definition]);
  final isNew = !replica.notebooks.containsKey(record.key.id);
  final notebook = replica.notebooks.putIfAbsent(
    record.key.id,
    () => SimNotebook(record.key.id, replica.nextLocalId()),
  );
  final chapters = _map(value['payload'])['chapters'];
  notebook
    ..name = value['name']! as String
    ..kind = value['kind']! as String
    ..visibility = value['visibility']! as String
    ..chapters = <String>[
      if (chapters is List)
        for (final c in chapters) _map(c)['id']! as String,
    ]
    ..parentId = value['parentId'] as String?
    ..createdAt = value['createdAt']! as int
    ..updatedAt = value['updatedAt']! as int;
  if (isNew) {
    notebook.sortOrder =
        replica.notebooks.values.fold<int>(
          0,
          (m, n) => m > n.sortOrder ? m : n.sortOrder,
        ) +
        1;
  }
}

/// 写入层删除日记本：清理成员关系；不提升子本（层级以计划为准）。
void _deleteNotebook(SimReplica replica, String id) {
  replica.notebooks.remove(id);
  replica.members.removeWhere(
    (key, _) => parseSyncMembershipId(key)!.notebookId == id,
  );
}

void _putMember(SimReplica replica, SyncRecord record) {
  final value = _map(record.facets[SyncFacet.main]);
  final existing = replica.members[record.key.id];
  if (existing != null) {
    existing
      ..chapterId = value['chapterId'] as String?
      ..addedAt = value['addedAt']! as int;
    return;
  }
  replica.members[record.key.id] = SimMember(
    value['chapterId'] as String?,
    value['addedAt']! as int,
    1 << 30,
  );
}

void _putList(SimReplica replica, SyncRecord record) {
  final ids = (_map(record.facets[SyncFacet.items])['ids']! as List)
      .cast<String>();
  final notebookId = SyncOrderListId.notebookOf(record.key.id);
  if (record.key.id == SyncOrderListId.shelf) {
    final rest =
        replica.notebooks.values.where((n) => !ids.contains(n.id)).toList()
          ..sort((a, b) {
            final byOrder = a.sortOrder.compareTo(b.sortOrder);
            return byOrder != 0 ? byOrder : a.localId.compareTo(b.localId);
          });
    var position = 0;
    for (final id in ids) {
      replica.notebooks[id]?.sortOrder = position++;
    }
    for (final notebook in rest) {
      notebook.sortOrder = position++;
    }
  } else if (notebookId != null) {
    final rows = <String, SimMember>{
      for (final entry in replica.members.entries)
        if (parseSyncMembershipId(entry.key)!.notebookId == notebookId)
          parseSyncMembershipId(entry.key)!.diaryId: entry.value,
    };
    final rest = rows.keys.where((id) => !ids.contains(id)).toList()
      ..sort((a, b) => rows[a]!.position.compareTo(rows[b]!.position));
    var position = 0;
    for (final id in <String>[...ids, ...rest]) {
      rows[id]?.position = position++;
    }
  }
}

void _putComment(SimReplica replica, SyncRecord record) {
  final value = _map(record.facets[SyncFacet.main]);
  replica.comments[record.key.id] = SimComment(
    value['diaryId']! as String,
    value['content']! as String,
    value['createdAt']! as int,
    value['editedAt'] as int?,
  );
}

void _putAnniversary(SimReplica replica, SyncRecord record) {
  final value = _map(record.facets[SyncFacet.main]);
  replica.anniversaries[record.key.id] = SimAnniversary(
    value['title']! as String,
    value['linkedDiaryId'] as String?,
    value['updatedAt']! as int,
  );
}
