part of 'app_database.dart';

// 存储管理（删除 / 压缩托管媒体）的读写，见 docs/rules/storage.md。
//
// - 读：全部可能引用托管媒体的行（日记含回收站、归档与未解封的胶囊；日记
//   本载荷；留言图片；草稿箱），附带私密 / 上锁 / 胶囊这些决定界面要不要
//   打码的标记。只返回纯数据，可以整份送进后台 isolate 解析；
// - 写：[applyStorageMediaEdits] 在一个事务里按前置条件（compare-and-swap）
//   改写引用。读取之后用户或局域网同步可能已改写某一行，内容不再是读取时
//   的样子就跳过那一行，绝不覆盖别人的改动；调用方据“文件是否仍被引用”
//   决定删哪个文件，被跳过的行仍引用的文件自然留下。
//
// 改写日记与日记本时 `updatedAt` 推后 1 秒（库里按秒存）而不是改成现在：
// 按 `(id, updatedAt)` 做键的派生缓存与局域网同步的时间戳分面要靠它看到
// 变化，1 秒在列表时间与排序里看不出来（与 HEIF 修复同一做法）。

/// 存储管理读到的一篇日记。
class StorageDiarySource {
  const StorageDiarySource({
    required this.id,
    required this.diaryId,
    required this.title,
    required this.createdAt,
    required this.content,
    required this.cover,
    required this.metadata,
    required this.isDeleted,
    required this.isArchived,
    required this.capsuleUnlockAt,
    required this.isPrivate,
    required this.isLocked,
  });

  /// 本地 id。
  final int id;

  /// 业务 id（打开日记、留言归属都用它）。
  final String diaryId;
  final String title;
  final DateTime createdAt;
  final String content;
  final String? cover;
  final String metadata;

  /// 在回收站里。
  final bool isDeleted;
  final bool isArchived;

  /// 时间胶囊的解封时间；未到期的胶囊界面上不预览内容。
  final DateTime? capsuleUnlockAt;

  /// 在私密（隐藏或上锁，含继承上级）的日记本里。
  final bool isPrivate;

  /// 在生效上锁的日记本里：揭示前要验证身份。
  final bool isLocked;
}

/// 存储管理读到的一本日记本（封面在载荷 JSON 的 `cover` 里）。
class StorageNotebookSource {
  const StorageNotebookSource({
    required this.id,
    required this.notebookId,
    required this.name,
    required this.payload,
    required this.isPrivate,
    required this.isLocked,
  });

  final int id;
  final String notebookId;
  final String name;
  final String payload;
  final bool isPrivate;
  final bool isLocked;
}

/// 存储管理读到的一条带图片的留言。
class StorageCommentSource {
  const StorageCommentSource({
    required this.id,
    required this.diaryId,
    required this.content,
    required this.images,
  });

  final int id;

  /// 所属日记的业务 id。
  final String diaryId;
  final String content;

  /// 原始图片列（JSON 数组字符串）。
  final String images;
}

/// 存储管理读到的一份草稿（正文与封面在载荷 JSON 里）。
class StorageDraftSource {
  const StorageDraftSource({
    required this.id,
    required this.title,
    required this.payload,
  });

  final int id;
  final String title;
  final String payload;
}

/// 一次读取的全部引用来源。
class StorageReferenceSources {
  const StorageReferenceSources({
    required this.diaries,
    required this.notebooks,
    required this.comments,
    required this.drafts,
  });

  final List<StorageDiarySource> diaries;
  final List<StorageNotebookSource> notebooks;
  final List<StorageCommentSource> comments;
  final List<StorageDraftSource> drafts;
}

/// 一篇日记的改写：正文与封面仍是 [expectedContent] / [expectedCover] 时写入。
/// [contentText] 为 null 表示纯文本镜像不变（只换路径时文字不变）。
class StorageDiaryEdit {
  const StorageDiaryEdit({
    required this.id,
    required this.expectedContent,
    required this.expectedCover,
    required this.content,
    required this.cover,
    this.contentText,
  });

  final int id;
  final String expectedContent;
  final String? expectedCover;
  final String content;
  final String? cover;
  final String? contentText;
}

/// 一本日记本载荷的改写，前置条件同 [StorageDiaryEdit]。
class StorageNotebookEdit {
  const StorageNotebookEdit({
    required this.id,
    required this.expectedPayload,
    required this.payload,
  });

  final int id;
  final String expectedPayload;
  final String payload;
}

/// 一条留言图片列的改写；[images] 为 null 且留言没有文字时整条删除（留言
/// 不能既没字也没图）。
class StorageCommentEdit {
  const StorageCommentEdit({
    required this.id,
    required this.expectedImages,
    required this.images,
  });

  final int id;
  final String expectedImages;
  final String? images;
}

/// 一份草稿载荷的改写；[contentText] 同步写进草稿表的纯文本列（列表摘要）。
class StorageDraftEdit {
  const StorageDraftEdit({
    required this.id,
    required this.expectedPayload,
    required this.payload,
    this.contentText,
  });

  final int id;
  final String expectedPayload;
  final String payload;
  final String? contentText;
}

/// 一次要写入的全部改写。
class StorageMediaEdits {
  const StorageMediaEdits({
    this.diaries = const [],
    this.notebooks = const [],
    this.comments = const [],
    this.drafts = const [],
  });

  final List<StorageDiaryEdit> diaries;
  final List<StorageNotebookEdit> notebooks;
  final List<StorageCommentEdit> comments;
  final List<StorageDraftEdit> drafts;

  int get length =>
      diaries.length + notebooks.length + comments.length + drafts.length;

  bool get isEmpty => length == 0;
}

/// 写入结果：[applied] 行已改写，[skipped] 行因读取后被改过而跳过。
class StorageMediaEditResult {
  const StorageMediaEditResult({required this.applied, required this.skipped});

  static const StorageMediaEditResult none = StorageMediaEditResult(
    applied: 0,
    skipped: 0,
  );

  final int applied;
  final int skipped;
}

/// 数据库文件的页统计：[freeBytes] 为空闲页占的字节，整理（VACUUM）可还给
/// 系统。
class StorageDatabaseStats {
  const StorageDatabaseStats({required this.pageSize, required this.freePages});

  final int pageSize;
  final int freePages;

  int get freeBytes => pageSize * freePages;
}

mixin _AppDatabaseStorageOps on _$AppDatabase {
  /// 全部引用来源（见文件头）。
  Future<StorageReferenceSources> getStorageReferenceSources() async {
    final isPrivate = CustomExpression<bool>(
      '"diaries"."id" IN ($_privateDiaryIdsSql)',
    );
    final isLocked = CustomExpression<bool>(
      '"diaries"."id" IN ($_lockedDiaryIdsSql)',
    );
    final diaryRows =
        await (selectOnly(diaries)..addColumns([
              diaries.id,
              diaries.diaryId,
              diaries.title,
              diaries.createdAt,
              diaries.content,
              diaries.cover,
              diaries.metadata,
              diaries.isDeleted,
              diaries.isArchived,
              diaries.capsuleUnlockAt,
              isPrivate,
              isLocked,
            ]))
            .get();
    final notebookPrivate = CustomExpression<bool>(
      '"notebooks"."id" IN ($_privateNotebookIdsSql)',
    );
    final notebookLocked = CustomExpression<bool>(
      '"notebooks"."id" IN ($_lockedNotebookIdsSql)',
    );
    final notebookRows =
        await (selectOnly(notebooks)..addColumns([
              notebooks.id,
              notebooks.notebookId,
              notebooks.name,
              notebooks.payload,
              notebookPrivate,
              notebookLocked,
            ]))
            .get();
    final commentRows = await (select(
      diaryComments,
    )..where((t) => t.images.isNotNull())).get();
    final draftRows = await select(diaryDrafts).get();
    return StorageReferenceSources(
      diaries: [
        for (final row in diaryRows)
          StorageDiarySource(
            id: row.read(diaries.id)!,
            diaryId: row.read(diaries.diaryId)!,
            title: row.read(diaries.title) ?? '',
            createdAt: row.read(diaries.createdAt)!,
            content: row.read(diaries.content)!,
            cover: row.read(diaries.cover),
            metadata: row.read(diaries.metadata) ?? '{}',
            isDeleted: row.read(diaries.isDeleted) ?? false,
            isArchived: row.read(diaries.isArchived) ?? false,
            capsuleUnlockAt: row.read(diaries.capsuleUnlockAt),
            isPrivate: row.read(isPrivate) ?? false,
            isLocked: row.read(isLocked) ?? false,
          ),
      ],
      notebooks: [
        for (final row in notebookRows)
          StorageNotebookSource(
            id: row.read(notebooks.id)!,
            notebookId: row.read(notebooks.notebookId)!,
            name: row.read(notebooks.name)!,
            payload: row.read(notebooks.payload)!,
            isPrivate: row.read(notebookPrivate) ?? false,
            isLocked: row.read(notebookLocked) ?? false,
          ),
      ],
      comments: [
        for (final row in commentRows)
          StorageCommentSource(
            id: row.id,
            diaryId: row.diaryId,
            content: row.content,
            images: row.images!,
          ),
      ],
      drafts: [
        for (final row in draftRows)
          StorageDraftSource(
            id: row.id,
            title: row.title,
            payload: row.payload,
          ),
      ],
    );
  }

  /// 在一个事务里写入全部改写（前置条件见文件头）。
  Future<StorageMediaEditResult> applyStorageMediaEdits(
    StorageMediaEdits edits,
  ) {
    if (edits.isEmpty) return Future.value(StorageMediaEditResult.none);
    return transaction(() async {
      var applied = 0;
      for (final edit in edits.diaries) {
        final row = await (select(
          diaries,
        )..where((t) => t.id.equals(edit.id))).getSingleOrNull();
        if (row == null ||
            row.content != edit.expectedContent ||
            row.cover != edit.expectedCover) {
          continue;
        }
        await (update(diaries)..where((t) => t.id.equals(edit.id))).write(
          DiariesCompanion(
            content: Value(edit.content),
            cover: Value(edit.cover),
            contentText: edit.contentText == null
                ? const Value.absent()
                : Value(edit.contentText!),
            updatedAt: Value(row.updatedAt.add(const Duration(seconds: 1))),
          ),
        );
        applied++;
      }
      for (final edit in edits.notebooks) {
        final row = await (select(
          notebooks,
        )..where((t) => t.id.equals(edit.id))).getSingleOrNull();
        if (row == null || row.payload != edit.expectedPayload) continue;
        await (update(notebooks)..where((t) => t.id.equals(edit.id))).write(
          NotebooksCompanion(
            payload: Value(edit.payload),
            updatedAt: Value(row.updatedAt.add(const Duration(seconds: 1))),
          ),
        );
        applied++;
      }
      for (final edit in edits.comments) {
        final row = await (select(
          diaryComments,
        )..where((t) => t.id.equals(edit.id))).getSingleOrNull();
        if (row == null || row.images != edit.expectedImages) continue;
        if (edit.images == null && !row.hasText) {
          await (delete(diaryComments)..where((t) => t.id.equals(row.id))).go();
        } else {
          // 与改留言同一口径：图片变了就是编辑过（同步的留言分面也带着它）。
          await (update(
            diaryComments,
          )..where((t) => t.id.equals(row.id))).write(
            DiaryCommentsCompanion(
              images: Value(edit.images),
              editedAt: Value(DateTime.now()),
            ),
          );
        }
        applied++;
      }
      for (final edit in edits.drafts) {
        final row = await (select(
          diaryDrafts,
        )..where((t) => t.id.equals(edit.id))).getSingleOrNull();
        if (row == null || row.payload != edit.expectedPayload) continue;
        await (update(diaryDrafts)..where((t) => t.id.equals(edit.id))).write(
          DiaryDraftsCompanion(
            payload: Value(edit.payload),
            contentText: edit.contentText == null
                ? const Value.absent()
                : Value(edit.contentText!),
            updatedAt: Value(row.updatedAt.add(const Duration(seconds: 1))),
          ),
        );
        applied++;
      }
      return StorageMediaEditResult(
        applied: applied,
        skipped: edits.length - applied,
      );
    });
  }

  /// 数据库文件的页大小与空闲页数。
  Future<StorageDatabaseStats> getStorageDatabaseStats() async {
    final pageSize = await customSelect('PRAGMA page_size').getSingle();
    final freePages = await customSelect('PRAGMA freelist_count').getSingle();
    return StorageDatabaseStats(
      pageSize: pageSize.data.values.first as int,
      freePages: freePages.data.values.first as int,
    );
  }

  /// 整理数据库文件（VACUUM），把空闲页还给系统。不能在事务里执行；需要
  /// 约一份数据库大小的临时空间。调用方负责与备份导入、局域网同步写入串行。
  Future<void> compactDatabase() => customStatement('VACUUM');
}
