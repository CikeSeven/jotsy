import 'package:drift/drift.dart' show Value;

import '../../../database/app_database.dart';
import 'sync_canonical_support.dart';
import 'sync_media_refs.dart';
import 'sync_model.dart';

/// 日记本、成员关系与顺序列表 ↔ 规范记录（规格 §2.2）。
///
/// - notebook：definition 分面。payload 取库中原始 JSON 解析后的对象（规范
///   编码时键排序、封面路径归一），**不经** [NotebookPayload.decode]：它会丢掉
///   认不出的键（更新版本写入的设置），同步一圈就没了。书架位置不在这里，
///   在 orderList `shelf`；
/// - membership：只有手动日记本有成员（`kind` 原始值为 manual，与
///   `acceptsManualEntries` 同一口径），成员里不放位置，位置在书序列表里；
/// - orderList：书架 / 我的模板 / 每本手动日记本的书序，值都是业务 id 列表，
///   排序与应用自己的读取一致（同位置按本地 id 等决出先后，见各函数）。
///   本地 id 只在同一台设备上有意义，平手只发生在从未拖动排序过的数据上；
///   写入层按列表把位置重写为 0..n-1 之后，两端就不再有平手。
///
/// 无副作用。

SyncRecord syncNotebookRecord(SyncRawNotebook row) =>
    SyncRecord(SyncKey(SyncEntity.notebook, row.notebookId), <String, Object?>{
      SyncFacet.definition: <String, Object?>{
        'name': syncTruncate(row.name, SyncColumnLimits.notebookName),
        'kind': row.kind,
        'visibility': row.visibility,
        'payload': syncNormalizeMediaRefs(
          syncDecodeJsonObjectColumn(row.payload),
        ),
        'pinned': row.isPinned,
        'closed': row.isClosed,
        'parentId': row.parentId,
        'createdAt': syncMillisOfSeconds(row.createdAt),
        'updatedAt': syncMillisOfSeconds(row.updatedAt),
      },
    });

/// 日记本规范记录写回本机的列值（不含书架顺序，由 orderList `shelf` 决定）。
class SyncNotebookColumns {
  const SyncNotebookColumns({
    required this.notebookId,
    required this.name,
    required this.kind,
    required this.visibility,
    required this.payload,
    required this.pinned,
    required this.closed,
    required this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncNotebookColumns.fromRecord(
    SyncRecord record, {
    required String dataRoot,
  }) {
    if (record.key.entity != SyncEntity.notebook) {
      throw ArgumentError.value(record.key, 'record', '不是日记本记录');
    }
    final value = syncMapOf(
      record.facets[SyncFacet.definition],
      SyncFacet.definition,
    );
    return SyncNotebookColumns(
      notebookId: record.key.id,
      name: syncTruncate(
        syncStringOf(value['name'], 'name'),
        SyncColumnLimits.notebookName,
      ),
      kind: syncStringOf(value['kind'], 'kind'),
      visibility: syncStringOf(value['visibility'], 'visibility'),
      payload: syncEncodeJsonObjectColumn(
        syncRebindMediaRefs(value['payload'], dataRoot),
        'payload',
      ),
      pinned: syncBoolOf(value['pinned'], 'pinned'),
      closed: syncBoolOf(value['closed'], 'closed'),
      parentId: syncStringOrNullOf(value['parentId'], 'parentId'),
      createdAt: syncDateTimeOf(value['createdAt']),
      updatedAt: syncDateTimeOf(value['updatedAt']),
    );
  }

  final String notebookId;
  final String name;
  final String kind;
  final String visibility;
  final String payload;
  final bool pinned;
  final bool closed;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 不含本地 id；[sortOrder] 只在插入新行时给（之后由书架列表统一重排）。
  NotebooksCompanion toCompanion({int? sortOrder}) => NotebooksCompanion(
    notebookId: Value<String>(notebookId),
    name: Value<String>(name),
    kind: Value<String>(kind),
    visibility: Value<String>(visibility),
    payload: Value<String>(payload),
    isPinned: Value<bool>(pinned),
    isClosed: Value<bool>(closed),
    parentId: Value<String?>(parentId),
    createdAt: Value<DateTime>(createdAt),
    updatedAt: Value<DateTime>(updatedAt),
    sortOrder: sortOrder == null
        ? const Value<int>.absent()
        : Value<int>(sortOrder),
  );
}

SyncRecord syncMembershipRecord({
  required String notebookId,
  required String diaryId,
  required SyncRawMembership row,
}) => SyncRecord(
  SyncKey(SyncEntity.membership, syncMembershipId(notebookId, diaryId)),
  <String, Object?>{
    SyncFacet.main: <String, Object?>{
      'chapterId': row.chapterId,
      'addedAt': syncMillisOfSeconds(row.addedAt),
    },
  },
);

/// 成员关系写回本机的值（业务 id；本地 id 与位置由写入层换算）。
class SyncMembershipColumns {
  const SyncMembershipColumns({
    required this.notebookId,
    required this.diaryId,
    required this.chapterId,
    required this.addedAt,
  });

  factory SyncMembershipColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.membership) {
      throw ArgumentError.value(record.key, 'record', '不是成员关系记录');
    }
    final ids = parseSyncMembershipId(record.key.id);
    if (ids == null) throw FormatException('成员关系 id 无效', record.key.id);
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    return SyncMembershipColumns(
      notebookId: ids.notebookId,
      diaryId: ids.diaryId,
      chapterId: syncStringOrNullOf(value['chapterId'], 'chapterId'),
      addedAt: syncDateTimeOf(value['addedAt']),
    );
  }

  final String notebookId;
  final String diaryId;
  final String? chapterId;
  final DateTime addedAt;
}

SyncRecord syncOrderListRecord(String listId, List<String> ids) =>
    SyncRecord(SyncKey(SyncEntity.orderList, listId), <String, Object?>{
      SyncFacet.items: <String, Object?>{'ids': List<String>.of(ids)},
    });

/// orderList 记录里的业务 id 列表。
List<String> syncOrderListIdsOf(SyncRecord record) {
  if (record.key.entity != SyncEntity.orderList) {
    throw ArgumentError.value(record.key, 'record', '不是顺序列表记录');
  }
  final ids = syncMapOf(record.facets[SyncFacet.items], SyncFacet.items)['ids'];
  if (ids is! List) throw const FormatException('items.ids 不是列表');
  return <String>[for (final id in ids) syncStringOf(id, 'ids')];
}

/// 书架：全部日记本按 `sort_order`、同值按本地 id（应用的
/// `_notebookManualOrder`；置顶不在这里，它是 definition 的 `pinned`）。
List<String> syncShelfOrder(List<SyncRawNotebook> notebooks) {
  final sorted = notebooks.toList()
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.localId.compareTo(b.localId);
    });
  return <String>[for (final row in sorted) row.notebookId];
}

/// 我的模板：只含用户模板（`builtin.*` 是改过的内置模板，界面上按内置顺序
/// 显示、不看 `sort_order`），按 `sort_order`、同值按本地 id（应用的
/// `_templateOrder`）。
List<String> syncTemplateOrder(List<SyncRawTemplate> templates) {
  final sorted =
      templates
          .where(
            (row) => !row.templateId.startsWith(builtInDiaryTemplateIdPrefix),
          )
          .toList()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.localId.compareTo(b.localId);
        });
  return <String>[for (final row in sorted) row.templateId];
}

/// 书序：一本手动日记本的成员按 `position`、`added_at`、日记本地 id（应用的
/// `_entriesInOrder`），给出日记业务 id。[diaryIdOf] 查不到的（悬空关联）跳过。
List<String> syncBookOrder(
  Iterable<SyncRawMembership> entries,
  String? Function(int diaryLocalId) diaryIdOf,
) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      if (byPosition != 0) return byPosition;
      final byAdded = a.addedAt.compareTo(b.addedAt);
      return byAdded != 0 ? byAdded : a.diaryLocalId.compareTo(b.diaryLocalId);
    });
  return <String>[for (final row in sorted) ?diaryIdOf(row.diaryLocalId)];
}
