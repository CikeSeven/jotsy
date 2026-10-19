import 'dart:math' as math;

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, InsertMode, Value;

import '../database/app_database.dart';
import 'backup_import_models.dart';
import 'backup_media_paths.dart';
import 'backup_payload.dart';

/// 合并导入中的日记本一步：定义按 notebookId 并入本机，成员关系经日记与
/// 日记本两张 id 映射改写后写入。规则要点列在 [BackupMerge] 的类注释里。
///
/// 输入：已校验的载荷（关联行只剩两端都在载荷里、日记本为手动的行）、
/// 导入方式、合并写入日记后得到的“文件日记 id → 本机日记 id”。
/// 输出：新增的日记本个数。副作用：在调用方的事务里写 `notebooks` 与
/// `diary_notebooks`；[prepare] 还会在 [BackupMediaPaths] 里登记要搬运的
/// 封面文件。
///
/// 分两段调用，因为媒体文件必须在写表前统一搬运：[prepare] 在搬运之前改写
/// “确实会写入”的定义（本机没有的，或合并并覆盖时本机已有的）的封面路径，
/// 保留本机版本的定义不改写，它的封面文件也就不会被搬进来；[write] 在日记
/// 写入之后再写定义与成员关系。
class BackupNotebookMerge {
  BackupNotebookMerge._(this._payload, this._mode, this._local, this._rebound);

  final BackupPayload _payload;
  final BackupImportMode _mode;

  /// 本机日记本，按业务 id 索引。
  final Map<String, NotebookRow> _local;

  /// 会写入的文件定义（按文件本地 id）→ 封面已改写的载荷。
  final Map<int, String> _rebound;

  static Future<BackupNotebookMerge> prepare({
    required AppDatabase db,
    required BackupPayload payload,
    required BackupImportMode mode,
    required BackupMediaPaths paths,
  }) async {
    final local = <String, NotebookRow>{
      for (final row in await db.select(db.notebooks).get())
        row.notebookId: row,
    };
    final rebound = <int, String>{};
    for (final row in payload.notebooks) {
      if (local.containsKey(row.notebookId) &&
          mode != BackupImportMode.mergeOverwrite) {
        continue;
      }
      rebound[row.id] = await BackupPayload.rebindNotebookPayload(
        row.payload,
        paths,
      );
    }
    return BackupNotebookMerge._(payload, mode, local, rebound);
  }

  /// 写入定义与成员关系，返回新增的日记本个数。
  ///
  /// [diaryIds] 只含本次实际写入（新增或替换）的日记；[replacedDiaryIds] 是
  /// 其中被替换的那些（文件本地 id）。跳过的日记不在映射里，它们的成员关系
  /// 一行都不动。
  Future<int> write(
    AppDatabase db, {
    required Map<int, int> diaryIds,
    required Set<int> replacedDiaryIds,
  }) async {
    final definitions = await _writeDefinitions(db);
    await _writeMemberships(
      db,
      definitions.targets,
      diaryIds,
      replacedDiaryIds,
    );
    return definitions.added;
  }

  /// 文件日记本 id → 写入后本机那一本（本机 id、本机侧的载荷）以及是否本次
  /// 新增。新增的按文件中的书架顺序接在本机最后。
  Future<({int added, Map<int, _Target> targets})> _writeDefinitions(
    AppDatabase db,
  ) async {
    final targets = <int, _Target>{};
    var nextOrder = _local.isEmpty
        ? 0
        : _local.values.map((row) => row.sortOrder).reduce(math.max) + 1;
    // Dart 的 sort 不保证稳定，同序号时按文件 id 定序，结果可复现。
    final ordered = [..._payload.notebooks]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    var added = 0;
    for (final row in ordered) {
      final local = _local[row.notebookId];
      if (local != null && _mode != BackupImportMode.mergeOverwrite) {
        targets[row.id] = (row: local, isNew: false);
        continue;
      }
      if (local != null) {
        // 整行替换为文件版本，但保留本机 id 与书架顺序：书架是这台设备上
        // 手动排好的，文件里的序号来自另一台设备。
        final replaced = row.copyWith(
          id: local.id,
          sortOrder: local.sortOrder,
          payload: _rebound[row.id],
        );
        await (db.update(
          db.notebooks,
        )..where((t) => t.id.equals(local.id))).write(
          replaced
              .toCompanion(false)
              .copyWith(
                id: const Value.absent(),
                sortOrder: const Value.absent(),
              ),
        );
        await _repairLocalMemberships(db, replaced);
        targets[row.id] = (row: replaced, isNew: false);
        continue;
      }
      final inserted = row.copyWith(
        sortOrder: nextOrder++,
        payload: _rebound[row.id],
      );
      final id = await db
          .into(db.notebooks)
          .insert(
            inserted.toCompanion(false).copyWith(id: const Value.absent()),
          );
      targets[row.id] = (row: inserted.copyWith(id: id), isNew: true);
      added++;
    }
    return (added: added, targets: targets);
  }

  /// 替换定义后，本机已有的成员行要跟上新定义：不再是手动日记本时整本的
  /// 关联行删除（只有手动日记本有关联行）；章节被删掉的归到“未分章”，与
  /// 编辑日记本时的处理一致。
  Future<void> _repairLocalMemberships(
    AppDatabase db,
    NotebookRow notebook,
  ) async {
    if (!notebook.acceptsManualEntries) {
      await (db.delete(
        db.diaryNotebooks,
      )..where((t) => t.notebookId.equals(notebook.id))).go();
      return;
    }
    await (db.update(db.diaryNotebooks)..where(
          (t) =>
              t.notebookId.equals(notebook.id) &
              t.chapterId.isNotNull() &
              t.chapterId.isNotIn(notebook.parsedPayload.chapterIds),
        ))
        .write(const DiaryNotebooksCompanion(chapterId: Value(null)));
  }

  /// 成员关系：
  /// - 新增的日记：文件里的行全部写入；
  /// - 被替换的日记：在文件带来的日记本里与文件一致（文件没有的移出，文件
  ///   有的加入或改章节），本机独有的日记本里的成员关系保留——替换正文不该
  ///   悄悄把日记踢出本机自建的本子；原本就在、文件里也在的保持本机的成书
  ///   位置，只换章节，避免每次合并都把它挪到本子末尾；
  /// - 章节只认目标日记本（本机侧）现有的章节，否则归到“未分章”；
  /// - 写进本机原有日记本的行按文件中的相对顺序接在末尾；写进本次新增的
  ///   日记本的行保留文件里的位置。
  Future<void> _writeMemberships(
    AppDatabase db,
    Map<int, _Target> targets,
    Map<int, int> diaryIds,
    Set<int> replacedDiaryIds,
  ) async {
    if (diaryIds.isEmpty) return;
    final replacedLocalIds = {for (final id in replacedDiaryIds) ?diaryIds[id]};
    final targetLocalIds = {for (final target in targets.values) target.row.id};

    // 关联行通常与日记同一量级，整表读一次，避免对上千篇日记做 IN 查询碰到
    // SQLite 的变量个数上限。
    final maxPosition = <int, int>{};
    final stale = <(int, int), DiaryNotebookRow>{};
    for (final row in await db.select(db.diaryNotebooks).get()) {
      maxPosition.update(
        row.notebookId,
        (value) => math.max(value, row.position),
        ifAbsent: () => row.position,
      );
      if (replacedLocalIds.contains(row.diaryId) &&
          targetLocalIds.contains(row.notebookId)) {
        stale[(row.diaryId, row.notebookId)] = row;
      }
    }

    final incoming =
        _payload.diaryNotebooks.where((row) {
          final target = targets[row.notebookId];
          return diaryIds.containsKey(row.diaryId) &&
              target != null &&
              target.row.acceptsManualEntries;
        }).toList()..sort((a, b) {
          final byPosition = a.position.compareTo(b.position);
          return byPosition != 0 ? byPosition : a.diaryId.compareTo(b.diaryId);
        });

    final inserts = <DiaryNotebooksCompanion>[];
    for (final row in incoming) {
      final target = targets[row.notebookId]!;
      final diaryId = diaryIds[row.diaryId]!;
      final notebookId = target.row.id;
      final chapterId =
          row.chapterId != null &&
              target.row.parsedPayload.chapterIds.contains(row.chapterId)
          ? row.chapterId
          : null;
      if (stale.remove((diaryId, notebookId)) != null) {
        await (db.update(db.diaryNotebooks)..where(
              (t) =>
                  t.diaryId.equals(diaryId) & t.notebookId.equals(notebookId),
            ))
            .write(DiaryNotebooksCompanion(chapterId: Value(chapterId)));
        continue;
      }
      final int position;
      if (target.isNew) {
        position = row.position;
      } else {
        position = (maxPosition[notebookId] ?? -1) + 1;
        maxPosition[notebookId] = position;
      }
      inserts.add(
        DiaryNotebooksCompanion.insert(
          diaryId: diaryId,
          notebookId: notebookId,
          chapterId: Value(chapterId),
          position: Value(position),
          addedAt: row.addedAt,
        ),
      );
    }
    // 被替换的日记在文件带来的日记本里、但文件版本已不在其中的成员关系。
    for (final key in stale.keys) {
      await (db.delete(db.diaryNotebooks)..where(
            (t) => t.diaryId.equals(key.$1) & t.notebookId.equals(key.$2),
          ))
          .go();
    }
    // 本库不开外键，历史上删日记可能留下悬空关联；新插入的日记 id 不复用，
    // 这里按“插入或替换”只是兜底，不让一行残留拖垮整次导入。
    await db.batch((batch) {
      batch.insertAll(
        db.diaryNotebooks,
        inserts,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}

typedef _Target = ({NotebookRow row, bool isNew});
