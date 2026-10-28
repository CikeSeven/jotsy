import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_constants.dart';
import 'backup_import_models.dart';
import 'backup_media_paths.dart';
import 'backup_notebook_merge.dart';
import 'backup_payload.dart';

/// 合并导入：把已解压、已校验的备份或日记包并入本机数据，不删除本机任何
/// 日记、标签或媒体文件。
///
/// - 日记按 diaryId 匹配：本机没有的新增并重新分配本地 id（文件里的本地 id
///   来自另一安装，可能与本机冲突）；本机已有的按导入方式保留本机版本，或把
///   整行连同标签绑定替换为文件中的版本；
/// - 标签按名称匹配：同名复用本机标签且颜色保持本机，缺少的新增；只补进实际
///   写入的日记用到的标签，跳过的日记不会把本机已改名或删除的标签带回来；
/// - 纪念日按 anniversaryId 匹配：本机没有的新增，本机已有的按导入方式保留
///   或替换；关联的日记存业务 id，日记换了本地 id 也不影响；
/// - 这天的心情按日期匹配：本机没有的新增，本机已有的按导入方式保留或替换；
/// - 日记留言按 commentId 匹配：本机没有的新增（包括本机保留了自己版本的
///   日记——留言只会越合越全），本机已有的按导入方式保留或替换；所属日记
///   存业务 id，日记换了本地 id 也不影响；
/// - 日记模板按 templateId 匹配：两种合并方式都只新增本机没有的模板，接在
///   “我的模板”最后，**从不覆盖**本机已有的模板——模板是写作习惯的配置，
///   本机那份往往是刻意改过的；只有覆盖全部恢复才整表换掉；
/// - 日记本按 notebookId 匹配（[BackupNotebookMerge]）：本机没有的新增，接在
///   书架最后；本机已有的，合并保留本机定义，合并并覆盖替换名称、类型、
///   可见性、载荷、置顶与合上状态（书架顺序保留本机的）。成员关系只随实际
///   写入的日记走：新增的日记带上文件里的成员关系；被替换的日记在文件带来
///   的日记本里与文件一致，本机独有日记本里的成员关系保留；跳过的日记不动。
///   章节只认目标日记本现有的章节，否则归到“未分章”；写进本机原有日记本的
///   排到末尾，写进新增日记本的保留文件中的位置；智能日记本从不写关联行；
/// - 媒体：只搬运实际写入的日记引用到的文件，统一放进各托管目录下的新批次
///   子目录（`<托管目录>/import_…/<原相对路径>`），不覆盖、不移动本机已有
///   文件；
/// - 不修改应用设置与新建日记草稿。
///
/// 搬运文件与写表在同一个数据库事务里完成。任一步失败时事务回滚，再删除本次
/// 新建的批次目录，本机数据保持导入前的样子。被替换日记原先引用的媒体留给
/// DiaryMediaCleanupService 按引用回收（新文件的修改时间在宽限期内，回收不会
/// 抢在事务提交前删掉它们）。
class BackupMerge {
  BackupMerge({required this.documents, required this.staging});

  final Directory documents;

  /// 已解压的导入暂存区，与 [documents] 同一文件系统，搬运只需 rename。
  final Directory staging;

  Future<BackupImportResult> apply({
    required AppDatabase database,
    required BackupPayload payload,
    required BackupImportMode mode,
  }) async {
    assert(mode != BackupImportMode.replaceAll);
    final batch = await _newBatchName();
    try {
      return await database.transaction(
        () => _write(database, payload, mode, batch),
      );
    } catch (error, stack) {
      await _removeBatch(batch);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<BackupImportResult> _write(
    AppDatabase db,
    BackupPayload payload,
    BackupImportMode mode,
    String batch,
  ) async {
    // 只取两列建立 diaryId → 本地 id 的映射，避免把全部正文读进内存；也不用
    // IN 查询，全量备份上千篇日记时不会碰到 SQLite 的变量个数上限。
    final localIds = <String, int>{
      for (final row in await (db.selectOnly(
        db.diaries,
      )..addColumns([db.diaries.id, db.diaries.diaryId])).get())
        row.read(db.diaries.diaryId)!: row.read(db.diaries.id)!,
    };

    final paths = BackupMediaPaths(
      documentsDirectory: documents,
      stagingDirectory: staging,
      targetSubdirectory: batch,
    );
    final inserts = <Diary>[];
    final replacements = <Diary>[];
    var skipped = 0;
    for (final diary in payload.diaries) {
      final exists = localIds.containsKey(diary.diaryId);
      if (exists && mode != BackupImportMode.mergeOverwrite) {
        skipped++;
        continue;
      }
      final rebound = diary.copyWith(
        content: await paths.rewriteContent(diary.content),
        cover: Value(
          await paths.rewritePath(
            diary.cover,
            directoryNames: const ['diary_covers', 'diary_images'],
          ),
        ),
      );
      (exists ? replacements : inserts).add(rebound);
    }
    // 日记本封面同样要在搬运文件前改写路径，才会登记进 boundFiles。
    final notebooks = await BackupNotebookMerge.prepare(
      db: db,
      payload: payload,
      mode: mode,
      paths: paths,
    );

    for (final entry in paths.boundFiles.entries) {
      final target = File(entry.value);
      await target.parent.create(recursive: true);
      await File(entry.key).rename(target.path);
    }

    // 文件里的本地 id → 本机 id；关联表按它改写两端。
    final diaryIds = <int, int>{};
    for (final diary in inserts) {
      diaryIds[diary.id] = await db
          .into(db.diaries)
          .insert(_withoutLocalId(diary));
    }
    for (final diary in replacements) {
      final localId = localIds[diary.diaryId]!;
      await (db.update(
        db.diaries,
      )..where((row) => row.id.equals(localId))).write(_withoutLocalId(diary));
      // 旧连接可能没开外键级联，替换标签前显式清掉本机原有绑定。
      await (db.delete(
        db.diaryTags,
      )..where((row) => row.diaryId.equals(localId))).go();
      diaryIds[diary.id] = localId;
    }

    final relations = payload.diaryTags
        .where((row) => diaryIds.containsKey(row.diaryId))
        .toList(growable: false);
    final tagIds = await _mergeTags(
      db,
      payload.tags,
      relations.map((row) => row.tagId).toSet(),
    );
    await db.batch((writes) {
      writes.insertAll(
        db.diaryTags,
        relations.map(
          (row) => DiaryTagsCompanion.insert(
            diaryId: diaryIds[row.diaryId]!,
            tagId: tagIds[row.tagId]!,
          ),
        ),
      );
    });

    final addedNotebooks = await notebooks.write(
      db,
      diaryIds: diaryIds,
      replacedDiaryIds: {for (final diary in replacements) diary.id},
    );

    final anniversaries = await _mergeAnniversaries(
      db,
      payload.anniversaries,
      mode,
    );
    final addedTemplates = await _mergeTemplates(db, payload.diaryTemplates);
    final dayMoods = await _mergeDayMoods(db, payload.dayMoods, mode);
    final comments = await _mergeDiaryComments(db, payload.diaryComments, mode);

    return BackupImportResult(
      mode: mode,
      addedDiaries: inserts.length,
      replacedDiaries: replacements.length,
      skippedDiaries: skipped,
      addedAnniversaries: anniversaries.added,
      replacedAnniversaries: anniversaries.replaced,
      skippedAnniversaries: anniversaries.skipped,
      addedTemplates: addedTemplates,
      addedNotebooks: addedNotebooks,
      addedDayMoods: dayMoods.added,
      replacedDayMoods: dayMoods.replaced,
      addedComments: comments.added,
      replacedComments: comments.replaced,
    );
  }

  /// 日记留言并入本机：按 commentId 匹配，本机没有的新增（去掉文件里的本地
  /// id）；本机已有的，合并保留本机的，合并并覆盖整行换成文件里的（保留
  /// 本机 id）。
  ///
  /// 载荷里的留言都属于载荷里的日记（见 `BackupPayload._withRestorableRelations`），
  /// 而载荷里的每篇日记合并后在本机都有——新增、替换或保留本机版本——所以
  /// 每条留言都有地方显示，不必再按日记过滤。
  Future<({int added, int replaced})> _mergeDiaryComments(
    AppDatabase db,
    List<DiaryCommentRow> incoming,
    BackupImportMode mode,
  ) async {
    if (incoming.isEmpty) return (added: 0, replaced: 0);
    final table = db.diaryComments;
    final localIds = <String, int>{
      for (final row in await (db.selectOnly(
        table,
      )..addColumns([table.id, table.commentId])).get())
        row.read(table.commentId)!: row.read(table.id)!,
    };
    var added = 0;
    var replaced = 0;
    for (final row in incoming) {
      final companion = row
          .toCompanion(false)
          .copyWith(id: const Value.absent());
      final localId = localIds[row.commentId];
      if (localId == null) {
        await db.into(table).insert(companion);
        added++;
      } else if (mode == BackupImportMode.mergeOverwrite) {
        await (db.update(
          table,
        )..where((t) => t.id.equals(localId))).write(companion);
        replaced++;
      }
    }
    return (added: added, replaced: replaced);
  }

  /// 这天的心情并入本机：按日期匹配，本机没有的那天新增；本机那天已有心情
  /// 时，合并保留本机的，合并并覆盖换成文件里的。
  Future<({int added, int replaced})> _mergeDayMoods(
    AppDatabase db,
    List<DayMoodRow> incoming,
    BackupImportMode mode,
  ) async {
    if (incoming.isEmpty) return (added: 0, replaced: 0);
    final table = db.dayMoods;
    final localDays = {
      for (final row in await (db.selectOnly(
        table,
      )..addColumns([table.day])).get())
        row.read(table.day)!,
    };
    final writes = <DayMoodRow>[];
    var replaced = 0;
    for (final row in incoming) {
      if (!localDays.contains(row.day)) {
        writes.add(row);
      } else if (mode == BackupImportMode.mergeOverwrite) {
        writes.add(row);
        replaced++;
      }
    }
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        table,
        writes.map((row) => row.toCompanion(false)).toList(),
      );
    });
    return (added: writes.length - replaced, replaced: replaced);
  }

  /// 本机没有的模板按文件中的顺序接在本机最后，返回新增个数；本机已有的
  /// 同一模板保持不动（与导入方式无关）。
  Future<int> _mergeTemplates(
    AppDatabase db,
    List<DiaryTemplateRow> incoming,
  ) async {
    if (incoming.isEmpty) return 0;
    final local = await db.getDiaryTemplates();
    final localIds = local.map((row) => row.templateId).toSet();
    var nextOrder = local.isEmpty
        ? 0
        : local.map((row) => row.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final added =
        incoming.where((row) => !localIds.contains(row.templateId)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final row in added) {
      await db
          .into(db.diaryTemplates)
          .insert(
            row
                .toCompanion(false)
                .copyWith(
                  id: const Value.absent(),
                  sortOrder: Value(nextOrder++),
                ),
          );
    }
    return added.length;
  }

  /// 纪念日并入本机：本机已有的按 [mode] 跳过或整行替换（保留本机 id），
  /// 新的去掉文件里的本地 id 后插入。
  Future<({int added, int replaced, int skipped})> _mergeAnniversaries(
    AppDatabase db,
    List<Anniversary> incoming,
    BackupImportMode mode,
  ) async {
    if (incoming.isEmpty) return (added: 0, replaced: 0, skipped: 0);
    final table = db.anniversaries;
    final localIds = <String, int>{
      for (final row in await (db.selectOnly(
        table,
      )..addColumns([table.id, table.anniversaryId])).get())
        row.read(table.anniversaryId)!: row.read(table.id)!,
    };
    var added = 0;
    var replaced = 0;
    var skipped = 0;
    for (final row in incoming) {
      final companion = row
          .toCompanion(false)
          .copyWith(id: const Value.absent());
      final localId = localIds[row.anniversaryId];
      if (localId == null) {
        await db.into(table).insert(companion);
        added++;
      } else if (mode == BackupImportMode.mergeOverwrite) {
        await (db.update(
          table,
        )..where((t) => t.id.equals(localId))).write(companion);
        replaced++;
      } else {
        skipped++;
      }
    }
    return (added: added, replaced: replaced, skipped: skipped);
  }

  /// 返回文件标签 id → 本机标签 id，只处理 [usedTagIds] 中的标签。
  Future<Map<int, int>> _mergeTags(
    AppDatabase db,
    List<Tag> incoming,
    Set<int> usedTagIds,
  ) async {
    if (usedTagIds.isEmpty) return const <int, int>{};
    final localByName = <String, int>{
      for (final tag in await db.select(db.tags).get()) tag.name: tag.id,
    };
    final result = <int, int>{};
    for (final tag in incoming) {
      if (!usedTagIds.contains(tag.id)) continue;
      result[tag.id] =
          localByName[tag.name] ??
          await db
              .into(db.tags)
              .insert(TagsCompanion.insert(name: tag.name, color: tag.color));
    }
    return result;
  }

  static DiariesCompanion _withoutLocalId(Diary diary) =>
      diary.toCompanion(false).copyWith(id: const Value.absent());

  /// 各托管目录下都未被占用的批次名；批次目录在搬运第一个文件时才创建。
  Future<String> _newBatchName() async {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (true) {
      final name = 'import_$stamp';
      var taken = false;
      for (final directory in backupMediaDirectories) {
        final type = await FileSystemEntity.type(
          p.join(documents.path, directory, name),
          followLinks: false,
        );
        if (type != FileSystemEntityType.notFound) {
          taken = true;
          break;
        }
      }
      if (!taken) return name;
      stamp++;
    }
  }

  /// 删除本次导入新建的批次目录。数据库已回滚，这些文件不被任何日记引用；
  /// 个别目录删除失败只会暂时多占空间，媒体回收过了宽限期会兜底，不能因此
  /// 掩盖导入失败的原始异常。
  Future<void> _removeBatch(String batch) async {
    for (final directory in backupMediaDirectories) {
      try {
        final target = Directory(p.join(documents.path, directory, batch));
        if (await target.exists()) await target.delete(recursive: true);
      } on FileSystemException {
        // 见上。
      }
    }
  }
}
