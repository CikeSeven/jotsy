part of 'sync_apply.dart';

/// 把规范记录换成数据库写入（规格 §6 第 3 步）：还原列值、比对前置条件、
/// 按顺序执行。
///
/// 还原列值（[_prepareWrite]）在开事务之前做完：结构不对的记录记为
/// [SyncSkipReason.invalidRecord] 跳过，而不是在事务里抛异常让整批回滚——
/// 一条坏记录不该让之后每次同步都失败。事务里只剩比对与写库。

/// 一条还原好的写入。
class _PreparedWrite {
  _PreparedWrite(this.write, this.run, {this.deferred = false});

  final SyncWrite write;

  /// 执行写入；返回 false 表示依赖的记录不在、什么都没写。settings 为 null
  /// （事务提交后单独应用）。
  final Future<bool> Function(AppDatabase db)? run;

  /// 顺序列表：放到全部其他写入之后执行，见 [_runWrites]。
  final bool deferred;

  SyncKey get key => write.key;
}

/// 一条还原好的原地改名（颜色已从 `tag:新名` 的记录里取出）。
class _PreparedRename {
  _PreparedRename(this.op) : color = SyncTagColumns.fromRecord(op.record).color;

  final SyncTagRenameOp op;
  final int color;

  String get from => op.from;
  String get to => op.to;
  Map<String, String> get expected => op.expected;
}

/// 还原 [write] 的列值；记录结构不对时抛 [FormatException] / [ArgumentError]。
_PreparedWrite _prepareWrite(
  SyncWrite write, {
  required String dataRoot,
  required int newTagColor,
}) {
  final record = write.record;
  final id = write.key.id;
  _PreparedWrite op(Future<void> Function(AppDatabase db) run) =>
      _PreparedWrite(write, (db) async {
        await run(db);
        return true;
      });

  switch (write.key.entity) {
    case SyncEntity.diary:
      if (record == null) return op((db) => db.syncDeleteDiary(id));
      final columns = SyncDiaryColumns.fromRecord(record, dataRoot: dataRoot);
      return op(
        (db) => db.syncWriteDiary(
          columns.toCompanion(),
          columns.tagNames,
          newTagColor: newTagColor,
        ),
      );
    case SyncEntity.tag:
      if (record == null) return op((db) => db.syncDeleteTag(id));
      final columns = SyncTagColumns.fromRecord(record);
      return op((db) => db.syncWriteTag(columns.name, columns.color));
    case SyncEntity.notebook:
      if (record == null) return op((db) => db.syncDeleteNotebook(id));
      final columns = SyncNotebookColumns.fromRecord(
        record,
        dataRoot: dataRoot,
      );
      return op((db) => db.syncWriteNotebook(columns.toCompanion()));
    case SyncEntity.membership:
      if (record == null) {
        final ids = parseSyncMembershipId(id);
        if (ids == null) throw FormatException('成员关系 id 无效', id);
        return op(
          (db) => db.syncDeleteMembership(
            notebookId: ids.notebookId,
            diaryId: ids.diaryId,
          ),
        );
      }
      final columns = SyncMembershipColumns.fromRecord(record);
      return _PreparedWrite(
        write,
        (db) => db.syncWriteMembership(
          notebookId: columns.notebookId,
          diaryId: columns.diaryId,
          chapterId: columns.chapterId,
          addedAt: columns.addedAt,
        ),
      );
    case SyncEntity.orderList:
      return _PreparedWrite(write, _orderListRunner(write), deferred: true);
    case SyncEntity.comment:
      if (record == null) return op((db) => db.syncDeleteComment(id));
      final columns = SyncCommentColumns.fromRecord(record);
      return op((db) => db.syncWriteComment(columns.toCompanion()));
    case SyncEntity.template:
      if (record == null) return op((db) => db.syncDeleteTemplate(id));
      final columns = SyncTemplateColumns.fromRecord(
        record,
        dataRoot: dataRoot,
      );
      return op((db) => db.syncWriteTemplate(columns.toCompanion()));
    case SyncEntity.anniversary:
      if (record == null) return op((db) => db.syncDeleteAnniversary(id));
      final columns = SyncAnniversaryColumns.fromRecord(
        record,
        dataRoot: dataRoot,
      );
      return op((db) => db.syncWriteAnniversary(columns.toCompanion()));
    case SyncEntity.dayMood:
      if (record == null) return op((db) => db.syncDeleteDayMood(id));
      final columns = SyncDayMoodColumns.fromRecord(record);
      return op((db) => db.syncWriteDayMood(columns.toCompanion()));
    case SyncEntity.settings:
      if (record == null) throw const FormatException('不能删除设置记录');
      return _PreparedWrite(write, null);
  }
}

/// 顺序列表：按列表重排位置。删除（日记本删除或改成智能本后它的书序列表
/// 消失）不需要做任何事——列表本身不是一行数据。
Future<bool> Function(AppDatabase db) _orderListRunner(SyncWrite write) {
  final record = write.record;
  if (record == null) return (_) async => true;
  final ids = syncOrderListIdsOf(record);
  final listId = write.key.id;
  final notebookId = SyncOrderListId.notebookOf(listId);
  if (listId != SyncOrderListId.shelf &&
      listId != SyncOrderListId.templates &&
      notebookId == null) {
    throw FormatException('未知的顺序列表', listId);
  }
  return (db) async {
    if (listId == SyncOrderListId.shelf) {
      await db.syncReorderShelf(ids);
    } else if (listId == SyncOrderListId.templates) {
      await db.syncReorderTemplates(ids);
    } else {
      await db.syncReorderBook(notebookId!, ids);
    }
    return true;
  };
}

/// [expected] 与当前分面哈希是否完全相同（null 表示必须不存在）。
bool _syncHashesMatch(
  Map<String, String>? expected,
  Map<String, String>? current,
) {
  if (expected == null || current == null) {
    return expected == null && current == null;
  }
  if (expected.length != current.length) return false;
  return expected.entries.every((entry) => current[entry.key] == entry.value);
}

/// 事务内执行的结果。
class _WriteOutcome {
  _WriteOutcome(this.rowsAfter, this.performed, this.renamed, this.skipped);

  /// 写入后（仍在事务内）读出的原始行。
  final SyncRawSnapshot rowsAfter;

  /// 真正执行了的写入（含要在提交后应用的 settings）。
  final List<SyncWrite> performed;
  final List<SyncTagRenameOp> renamed;
  final List<SyncApplySkip> skipped;
}

/// 在调用方开好的事务里执行（规格 §4.6 写入层须知第 1 条）：
/// 1. 先逐条比对**全部**前置条件，不符的跳过——之后的改名与写入会改变
///    清单（如日记写入按名称建出标签），必须以开始时的状态为准；
/// 2. 原地改名（引用旧名的日记写入里 tags 已是新名，它的 expected 是改名前
///    的哈希，所以改名必须在比对之后、写入之前）；
/// 3. 按计划顺序执行其余写入（实体枚举顺序：日记在标签之前，日记按名称建出
///    的标签随后由 `tag:` 记录定下颜色）；
/// 4. 顺序列表最后执行。计划按键排序，`orderList:templates` 排在模板写入
///    之前：照原顺序执行时新模板还没插入，重排后它会被当作“列表里没有的
///    现有项”排到末尾。重排只看行是否存在，挪到最后与计划的结果相同。
Future<_WriteOutcome> _runWrites(
  AppDatabase db, {
  required SyncManifest current,
  required List<_PreparedRename> renames,
  required List<_PreparedWrite> writes,
}) async {
  final skipped = <SyncApplySkip>[];
  final renamed = <_PreparedRename>[];
  for (final rename in renames) {
    final from = SyncKey(SyncEntity.tag, rename.from);
    final to = SyncKey(SyncEntity.tag, rename.to);
    if (_syncHashesMatch(rename.expected, current[from]) &&
        !current.containsKey(to)) {
      renamed.add(rename);
    } else {
      skipped.add(SyncApplySkip(from, SyncSkipReason.precondition));
    }
  }
  final accepted = <_PreparedWrite>[];
  for (final write in writes) {
    if (_syncHashesMatch(write.write.expected, current[write.key])) {
      accepted.add(write);
    } else {
      skipped.add(SyncApplySkip(write.key, SyncSkipReason.precondition));
    }
  }

  for (final rename in renamed) {
    await db.syncRenameTag(
      from: rename.from,
      to: rename.to,
      color: rename.color,
    );
  }
  final performed = <SyncWrite>[];
  for (final write in <_PreparedWrite>[
    ...accepted.where((write) => !write.deferred),
    ...accepted.where((write) => write.deferred),
  ]) {
    final run = write.run;
    if (run == null || await run(db)) {
      performed.add(write.write);
    } else {
      skipped.add(SyncApplySkip(write.key, SyncSkipReason.missingDependency));
    }
  }
  return _WriteOutcome(await db.readSyncRows(), performed, <SyncTagRenameOp>[
    for (final rename in renamed) rename.op,
  ], skipped);
}
