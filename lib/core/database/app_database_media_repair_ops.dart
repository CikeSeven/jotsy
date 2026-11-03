part of 'app_database.dart';

/// 一篇日记的媒体引用改写：只在正文与封面仍是读取时的 [expectedContent] /
/// [expectedCover] 时写入 [content] / [cover]。
class DiaryMediaPathRepair {
  const DiaryMediaPathRepair({
    required this.id,
    required this.expectedContent,
    required this.expectedCover,
    required this.content,
    required this.cover,
  });

  /// 日记的本地 id。
  final int id;
  final String expectedContent;
  final String? expectedCover;
  final String content;
  final String? cover;
}

/// 一本日记本载荷（封面路径在其中）的改写，前置条件同 [DiaryMediaPathRepair]。
class NotebookMediaPathRepair {
  const NotebookMediaPathRepair({
    required this.id,
    required this.expectedPayload,
    required this.payload,
  });

  /// 日记本的本地 id。
  final int id;
  final String expectedPayload;
  final String payload;
}

/// 托管媒体的格式修复（`HeifMediaRepairService`：已存的 HEIC 转成 JPEG 后
/// 改写引用）用到的读写。
///
/// 写入不是用户编辑，但仍把 `updatedAt` 推后 1 秒（库里按秒存）：按
/// `(diaryId, updatedAt)` 做键的派生缓存（卡片、日历首图）与“内容变了时间
/// 一定变”的假设要靠它刷新；1 秒在界面上的时间与排序里看不出来。
///
/// 前置条件（compare-and-swap）：读取之后用户或局域网同步可能已改写这一行，
/// 内容不再是读取时的样子就跳过这一行，下次启动再处理，绝不覆盖别人的改动。
mixin _AppDatabaseMediaRepairOps on _$AppDatabase {
  /// 全部日记（含归档、回收站与未解封的胶囊）的本地 id、正文与封面。
  Future<List<({int id, String content, String? cover})>>
  getDiaryMediaSources() async {
    final rows = await (selectOnly(
      diaries,
    )..addColumns([diaries.id, diaries.content, diaries.cover])).get();
    return [
      for (final row in rows)
        (
          id: row.read(diaries.id)!,
          content: row.read(diaries.content)!,
          cover: row.read(diaries.cover),
        ),
    ];
  }

  /// 全部日记本的本地 id 与载荷。
  Future<List<({int id, String payload})>> getNotebookMediaSources() async {
    final rows = await (selectOnly(
      notebooks,
    )..addColumns([notebooks.id, notebooks.payload])).get();
    return [
      for (final row in rows)
        (id: row.read(notebooks.id)!, payload: row.read(notebooks.payload)!),
    ];
  }

  /// 在一个事务里写入全部改写，返回实际写入的行数（不含因前置条件跳过的）。
  Future<int> applyMediaPathRepairs({
    List<DiaryMediaPathRepair> diaryRepairs = const [],
    List<NotebookMediaPathRepair> notebookRepairs = const [],
  }) {
    return transaction(() async {
      var written = 0;
      for (final repair in diaryRepairs) {
        final row = await (select(
          diaries,
        )..where((t) => t.id.equals(repair.id))).getSingleOrNull();
        if (row == null ||
            row.content != repair.expectedContent ||
            row.cover != repair.expectedCover) {
          continue;
        }
        await (update(diaries)..where((t) => t.id.equals(repair.id))).write(
          DiariesCompanion(
            content: Value(repair.content),
            cover: Value(repair.cover),
            updatedAt: Value(row.updatedAt.add(const Duration(seconds: 1))),
          ),
        );
        written++;
      }
      for (final repair in notebookRepairs) {
        final row = await (select(
          notebooks,
        )..where((t) => t.id.equals(repair.id))).getSingleOrNull();
        if (row == null || row.payload != repair.expectedPayload) continue;
        await (update(notebooks)..where((t) => t.id.equals(repair.id))).write(
          NotebooksCompanion(
            payload: Value(repair.payload),
            updatedAt: Value(row.updatedAt.add(const Duration(seconds: 1))),
          ),
        );
        written++;
      }
      return written;
    });
  }
}
