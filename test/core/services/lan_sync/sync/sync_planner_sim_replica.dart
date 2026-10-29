import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_fold.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_planner_sim_tables.dart';

export 'sync_planner_sim_tables.dart';

/// 收敛模拟里的一台“设备”：用几张内存表模拟数据库，按生产的口径推出规范
/// 记录（tags 分面由标签表推出、书架 / 书序由位置推出、成员只算手动本里
/// 存在的日记），并模拟写入层：先比对前置条件，再改名、按键序写入，删除时
/// 清理关联（日记 → 成员、留言、纪念日关联；日记本 → 成员；标签 → 日记标签），
/// 顺序列表按列表重排位置。同步状态用生产的 `foldSyncObservation` 维护。

class SimReplica {
  SimReplica(this.name, {this.skew = 0});

  final String name;

  /// 本机时钟相对全局时钟的偏差（毫秒，1000 的倍数）。
  final int skew;

  final Map<String, SimDiary> diaries = <String, SimDiary>{};
  final Map<int, SimTag> tags = <int, SimTag>{};
  final Map<String, SimNotebook> notebooks = <String, SimNotebook>{};
  final Map<String, SimMember> members = <String, SimMember>{};
  final Map<String, SimComment> comments = <String, SimComment>{};
  final Map<String, SimAnniversary> anniversaries = <String, SimAnniversary>{};

  final SyncStateData state = SyncStateData();
  SyncObservation? checkpoint;

  /// 丢失同步状态（模拟覆盖恢复后的 `resetAfterRestore`）之后，还没同步过的
  /// 设备；与它们同步时 `restoredPending` 为 true。
  final Set<String> restoredPendingWith = <String>{};
  int _nextLocal = 1;

  /// 写入层按名称建了计划里没有的标签（应当始终为 0）。
  int unexpectedTags = 0;

  int nextLocalId() => _nextLocal++;

  SimTag? tagNamed(String name) {
    for (final tag in tags.values) {
      if (tag.name == name) return tag;
    }
    return null;
  }

  // ---------------------------------------------------------------- 规范记录

  Map<SyncKey, SyncRecord> records() {
    final out = <SyncKey, SyncRecord>{};
    void add(SyncRecord record) => out[record.key] = record;
    for (final d in diaries.values) {
      add(
        SyncRecord(SyncKey(SyncEntity.diary, d.id), <String, Object?>{
          SyncFacet.content: <String, Object?>{
            'title': d.title,
            'content': d.body,
            'cover': null,
            'metadata': d.metadata,
            'createdAt': d.createdAt,
          },
          SyncFacet.stamp: <String, Object?>{'updatedAt': d.updatedAt},
          SyncFacet.pin: <String, Object?>{'pinned': d.pinned},
          SyncFacet.archive: <String, Object?>{
            'archived': d.archived,
            'archivedAt': d.archivedAt,
          },
          SyncFacet.trash: <String, Object?>{
            'deleted': d.deleted,
            'deletedAt': d.deletedAt,
          },
          SyncFacet.capsule: <String, Object?>{
            'unlockAt': d.unlockAt,
            'lockedAt': d.unlockAt == null ? null : d.createdAt,
            'meta': null,
          },
          SyncFacet.tags: <String, Object?>{
            'names': <String>{
              for (final id in d.tagIds) ?tags[id]?.name,
            }.toList()..sort(),
          },
        }),
      );
    }
    for (final tag in tags.values) {
      add(
        SyncRecord(SyncKey(SyncEntity.tag, tag.name), <String, Object?>{
          SyncFacet.color: <String, Object?>{'color': tag.color},
        }),
      );
    }
    final shelf = notebooks.values.toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.localId.compareTo(b.localId);
      });
    for (final n in shelf) {
      add(
        SyncRecord(SyncKey(SyncEntity.notebook, n.id), <String, Object?>{
          SyncFacet.definition: <String, Object?>{
            'name': n.name,
            'kind': n.kind,
            'visibility': n.visibility,
            'payload': <String, Object?>{
              if (n.chapters.isNotEmpty)
                'chapters': <Object?>[
                  for (final c in n.chapters)
                    <String, Object?>{'id': c, 'title': 'Chapter $c'},
                ],
            },
            'pinned': false,
            'closed': false,
            'parentId': n.parentId,
            'createdAt': n.createdAt,
            'updatedAt': n.updatedAt,
          },
        }),
      );
      if (n.kind != 'manual') continue;
      final entries = <({String diary, SimMember row})>[
        for (final entry in members.entries)
          if (_notebookOf(entry.key) == n.id &&
              diaries.containsKey(_diaryOf(entry.key)))
            (diary: _diaryOf(entry.key), row: entry.value),
      ];
      for (final entry in entries) {
        add(
          SyncRecord(
            SyncKey(SyncEntity.membership, syncMembershipId(n.id, entry.diary)),
            <String, Object?>{
              SyncFacet.main: <String, Object?>{
                'chapterId': entry.row.chapterId,
                'addedAt': entry.row.addedAt,
              },
            },
          ),
        );
      }
      entries.sort((a, b) {
        final byPosition = a.row.position.compareTo(b.row.position);
        if (byPosition != 0) return byPosition;
        final byAdded = a.row.addedAt.compareTo(b.row.addedAt);
        return byAdded != 0
            ? byAdded
            : diaries[a.diary]!.localId.compareTo(diaries[b.diary]!.localId);
      });
      add(
        _list(SyncOrderListId.book(n.id), [for (final e in entries) e.diary]),
      );
    }
    add(_list(SyncOrderListId.shelf, [for (final n in shelf) n.id]));
    add(_list(SyncOrderListId.templates, const <String>[]));
    for (final entry in comments.entries) {
      final c = entry.value;
      add(
        SyncRecord(SyncKey(SyncEntity.comment, entry.key), <String, Object?>{
          SyncFacet.main: <String, Object?>{
            'diaryId': c.diaryId,
            'content': c.content,
            'mood': null,
            'createdAt': c.createdAt,
            'editedAt': c.editedAt,
          },
        }),
      );
    }
    for (final entry in anniversaries.entries) {
      final a = entry.value;
      add(
        SyncRecord(
          SyncKey(SyncEntity.anniversary, entry.key),
          <String, Object?>{
            SyncFacet.main: <String, Object?>{
              'title': a.title,
              'linkedDiaryId': a.linkedDiaryId,
              'updatedAt': a.updatedAt,
            },
          },
        ),
      );
    }
    return out;
  }

  static SyncRecord _list(String id, List<String> ids) =>
      SyncRecord(SyncKey(SyncEntity.orderList, id), <String, Object?>{
        SyncFacet.items: <String, Object?>{'ids': ids},
      });

  static String memberId(String notebook, String diary) =>
      syncMembershipId(notebook, diary);
  static String _notebookOf(String id) => parseSyncMembershipId(id)!.notebookId;
  static String _diaryOf(String id) => parseSyncMembershipId(id)!.diaryId;

  SyncManifest manifest() => SyncManifest.fromRecords(records().values);

  SyncObservation observe() {
    final all = records();
    return SyncObservation(
      manifest: SyncManifest.fromRecords(all.values),
      trackedValues: <SyncKey, Map<String, Object?>>{
        for (final record in all.values)
          if (record.key.entity == SyncEntity.diary)
            record.key: <String, Object?>{
              SyncFacet.tags: record.facets[SyncFacet.tags],
            }
          else if (record.key.entity == SyncEntity.orderList)
            record.key: <String, Object?>{
              SyncFacet.items: record.facets[SyncFacet.items],
            },
      },
      tagLocalIds: <String, int>{
        for (final tag in tags.values) tag.name: tag.localId,
      },
      observed: <SyncEntity>{
        for (final entity in SyncEntity.values)
          if (entity != SyncEntity.settings) entity,
      },
    );
  }

  /// 刷新检查点（会话开始时 / 写入之后；写入之后带上计划的
  /// `historySeenAt`，与生产的 `recordAppliedState` 相同）。
  void refresh(
    int globalNow, {
    Map<SyncKey, Map<String, int>> seenAtOverrides =
        const <SyncKey, Map<String, int>>{},
  }) {
    checkpoint = foldSyncObservation(
      previous: checkpoint,
      current: observe(),
      state: state,
      now: globalNow + skew,
      seenAtOverrides: seenAtOverrides,
    );
  }

  /// 规划用的一侧：本机历史与墓碑可答；对方只有清单、墓碑键与改名。
  /// 丢掉检查点、历史、墓碑与改名（数据不变），与 [peers] 的下一次同步走
  /// “以哪边为准”。
  void loseSyncState(Iterable<String> peers) {
    checkpoint = null;
    state.history.clear();
    state.tombstones.clear();
    state.renames.clear();
    restoredPendingWith.addAll(peers);
  }

  SyncPlanSideData planSide({
    required bool local,
    required String peer,
    bool full = false,
  }) {
    final manifest = checkpoint!.manifest;
    return SyncPlanSideData(
      deviceId: name,
      manifest: manifest,
      restoredPending: restoredPendingWith.contains(peer),
      allHistoryKnown: local || full,
      tombstoneKeys: state.tombstones.keys,
      tombstones: local || full ? state.tombstones : null,
      renames: state.renames,
      history: local || full ? state.history : null,
      records: full ? records().values : const <SyncRecord>[],
    );
  }
}
