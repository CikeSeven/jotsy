import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

/// 规划器测试用的规范记录：字段与分面组成和 `sync_canonical_*.dart` 的生产
/// 规范形式一致（规格 §2.2），省掉与规划无关的细节（正文是 `{"body": …}`）。

SyncKey diaryKey(String id) => SyncKey(SyncEntity.diary, id);
SyncKey tagKey(String name) => SyncKey(SyncEntity.tag, name);
SyncKey notebookKey(String id) => SyncKey(SyncEntity.notebook, id);
SyncKey memberKey(String notebook, String diary) =>
    SyncKey(SyncEntity.membership, syncMembershipId(notebook, diary));
SyncKey listKey(String id) => SyncKey(SyncEntity.orderList, id);
SyncKey commentKey(String id) => SyncKey(SyncEntity.comment, id);
SyncKey anniversaryKey(String id) => SyncKey(SyncEntity.anniversary, id);
const SyncKey settingsKey = SyncKey(SyncEntity.settings, kSyncSettingsId);
const SyncKey prefsKey = SyncKey(SyncEntity.prefs, kSyncPrefsId);

SyncRecord diaryRecord(
  String id, {
  String title = 'title',
  String? body,
  int createdAt = 1000,
  int updatedAt = 1000,
  bool pinned = false,
  bool archived = false,
  bool deleted = false,
  int? unlockAt,
  List<String> tags = const <String>[],
  Object? metadata,
}) => SyncRecord(diaryKey(id), <String, Object?>{
  SyncFacet.content: <String, Object?>{
    'title': title,
    'content': <String, Object?>{'body': body ?? title},
    'cover': null,
    'metadata': metadata ?? <String, Object?>{},
    'createdAt': createdAt,
  },
  SyncFacet.stamp: <String, Object?>{'updatedAt': updatedAt},
  SyncFacet.pin: <String, Object?>{'pinned': pinned},
  SyncFacet.archive: <String, Object?>{
    'archived': archived,
    'archivedAt': archived ? updatedAt : null,
  },
  SyncFacet.trash: <String, Object?>{
    'deleted': deleted,
    'deletedAt': deleted ? updatedAt : null,
  },
  SyncFacet.capsule: <String, Object?>{
    'unlockAt': unlockAt,
    'lockedAt': unlockAt == null ? null : createdAt,
    'meta': null,
  },
  SyncFacet.tags: <String, Object?>{'names': tags.toSet().toList()..sort()},
});

SyncRecord tagRecord(String name, {int color = 1}) =>
    SyncRecord(tagKey(name), <String, Object?>{
      SyncFacet.color: <String, Object?>{'color': color},
    });

SyncRecord notebookRecord(
  String id, {
  String? name,
  String kind = 'manual',
  String visibility = 'normal',
  String? parentId,
  List<String> chapters = const <String>[],
  int updatedAt = 1000,
}) => SyncRecord(notebookKey(id), <String, Object?>{
  SyncFacet.definition: <String, Object?>{
    'name': name ?? id,
    'kind': kind,
    'visibility': visibility,
    'payload': <String, Object?>{
      if (chapters.isNotEmpty)
        'chapters': <Object?>[
          for (final chapter in chapters)
            <String, Object?>{'id': chapter, 'title': 'Chapter $chapter'},
        ],
    },
    'pinned': false,
    'closed': false,
    'parentId': parentId,
    'createdAt': 1000,
    'updatedAt': updatedAt,
  },
});

SyncRecord memberRecord(
  String notebook,
  String diary, {
  String? chapter,
  int addedAt = 1000,
}) => SyncRecord(memberKey(notebook, diary), <String, Object?>{
  SyncFacet.main: <String, Object?>{'chapterId': chapter, 'addedAt': addedAt},
});

SyncRecord listRecord(String id, List<String> ids) =>
    SyncRecord(listKey(id), <String, Object?>{
      SyncFacet.items: <String, Object?>{'ids': ids},
    });

SyncRecord commentRecord(
  String id,
  String diaryId, {
  String content = 'comment',
  int createdAt = 1000,
  int? editedAt,
}) => SyncRecord(commentKey(id), <String, Object?>{
  SyncFacet.main: <String, Object?>{
    'diaryId': diaryId,
    'content': content,
    'mood': null,
    'createdAt': createdAt,
    'editedAt': editedAt,
  },
});

SyncRecord anniversaryRecord(
  String id, {
  String title = 'anniversary',
  String? linkedDiaryId,
  int updatedAt = 1000,
}) => SyncRecord(anniversaryKey(id), <String, Object?>{
  SyncFacet.main: <String, Object?>{
    'title': title,
    'baseDate': '2024-01-01',
    'recurrence': 'yearly',
    'lunarYear': null,
    'lunarMonth': null,
    'lunarDay': null,
    'linkedDiaryId': linkedDiaryId,
    'note': '',
    'pinned': false,
    'metadata': <String, Object?>{},
    'createdAt': 1000,
    'updatedAt': updatedAt,
  },
});

SyncRecord settingsRecord(Map<String, Object?> values) =>
    SyncRecord(settingsKey, <String, Object?>{
      for (final entry in values.entries)
        entry.key: <String, Object?>{'value': entry.value},
    });

/// prefs 记录：标签顺序与数据类功能开关（没给的开关不出现）。
SyncRecord prefsRecord({
  List<String> tagOrder = const <String>[],
  Map<String, bool> features = const <String, bool>{},
}) => SyncRecord(prefsKey, <String, Object?>{
  SyncPrefsFacet.tagOrder: <String, Object?>{'value': tagOrder},
  for (final entry in features.entries)
    SyncPrefsFacet.feature(entry.key): SyncPrefsFacet.featureValue(entry.value),
});
