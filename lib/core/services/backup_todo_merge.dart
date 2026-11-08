import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import 'backup_import_models.dart';

/// 合并导入里的待办部分：清单按 listId、待办按 todoId 匹配。
///
/// - 本机没有的新增，去掉文件里的本地 id 后插入（本地 id 来自另一安装，可能
///   与本机冲突）；
/// - 本机已有的：合并保留本机版本，合并并覆盖整行替换为文件中的版本（保留
///   本机 id）；清单被替换时拖动顺序保留本机的（与日记本的书架顺序同一口径），
///   待办的顺序随文件——它跟着这条待办同步与备份；
/// - 待办按业务 id 引用清单与日记、没有外键：文件里的清单 id 与本机一致，
///   不需要改写。所在清单既不在文件里、也不在本机的待办，载荷解析时已落回
///   收集箱（见 `BackupPayload._withRestorableRelations`）。
///
/// 只在 `BackupMerge` 的写库事务里调用，失败随事务回滚。
abstract final class BackupTodoMerge {
  static Future<({int added, int replaced, int skipped})> write(
    AppDatabase db, {
    required List<TodoListRow> lists,
    required List<TodoRow> todos,
    required BackupImportMode mode,
  }) async {
    final overwrite = mode == BackupImportMode.mergeOverwrite;
    if (lists.isNotEmpty) {
      final table = db.todoLists;
      final local = <String, ({int id, double sortOrder})>{
        for (final row in await db.select(table).get())
          row.listId: (id: row.id, sortOrder: row.sortOrder),
      };
      for (final row in lists) {
        final existing = local[row.listId];
        if (existing == null) {
          await db
              .into(table)
              .insert(
                row.toCompanion(false).copyWith(id: const Value.absent()),
              );
        } else if (overwrite) {
          await (db.update(
            table,
          )..where((t) => t.id.equals(existing.id))).write(
            row
                .toCompanion(false)
                .copyWith(
                  id: const Value.absent(),
                  sortOrder: Value(existing.sortOrder),
                ),
          );
        }
      }
    }

    if (todos.isEmpty) return (added: 0, replaced: 0, skipped: 0);
    final table = db.todos;
    final localIds = <String, int>{
      for (final row in await (db.selectOnly(
        table,
      )..addColumns([table.id, table.todoId])).get())
        row.read(table.todoId)!: row.read(table.id)!,
    };
    var added = 0;
    var replaced = 0;
    var skipped = 0;
    for (final row in todos) {
      final companion = row
          .toCompanion(false)
          .copyWith(id: const Value.absent());
      final localId = localIds[row.todoId];
      if (localId == null) {
        await db.into(table).insert(companion);
        added++;
      } else if (overwrite) {
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
}
