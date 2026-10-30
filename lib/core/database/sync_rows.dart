/// 局域网同步读取的原始行（`AppDatabase.readSyncRows` 的结果）。
///
/// 为什么不用 Drift 生成的数据类：
/// - 这些行要整批送进 `Isolate.run` 做规范化与哈希，只放纯 Dart 字段
///   （字符串、整数、布尔、null），不带 Drift 的类型与连接；
/// - 时间保留库里的原始整数（Unix 秒），布尔保留读出时的 0/1 含义：原始列
///   指纹（哈希缓存的键）要按“库里实际存的值”计算，不经 [DateTime] 的本地
///   时区换算；
/// - 日记行不带 `content_text`：它由正文推出、不参与哈希（规格 §2.2），一万篇
///   日记少搬一份纯文本。
///
/// 纯 Dart、无导入：数据库层与同步层都能直接引用。
library;

/// `diaries` 表的一行（不含 `content_text`）。时间为 Unix 秒。
class SyncRawDiary {
  const SyncRawDiary({
    required this.localId,
    required this.diaryId,
    required this.title,
    required this.content,
    required this.cover,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.archivedAt,
    required this.isPinned,
    required this.capsuleUnlockAt,
    required this.capsuleLockedAt,
    required this.isDeleted,
    required this.deletedAt,
  });

  final int localId;
  final String diaryId;
  final String title;
  final String content;
  final String? cover;
  final String metadata;
  final int createdAt;
  final int updatedAt;
  final bool isArchived;
  final int? archivedAt;
  final bool isPinned;
  final int? capsuleUnlockAt;
  final int? capsuleLockedAt;
  final bool isDeleted;
  final int? deletedAt;
}

/// `tags` 表的一行。
class SyncRawTag {
  const SyncRawTag({
    required this.localId,
    required this.name,
    required this.color,
  });

  final int localId;
  final String name;
  final int color;
}

/// `diary_tags` 表的一行（两端都是本地 id）。
class SyncRawDiaryTag {
  const SyncRawDiaryTag({required this.diaryLocalId, required this.tagLocalId});

  final int diaryLocalId;
  final int tagLocalId;
}

/// `notebooks` 表的一行。时间为 Unix 秒。
class SyncRawNotebook {
  const SyncRawNotebook({
    required this.localId,
    required this.notebookId,
    required this.name,
    required this.kind,
    required this.visibility,
    required this.payload,
    required this.sortOrder,
    required this.isPinned,
    required this.isClosed,
    required this.createdAt,
    required this.updatedAt,
    required this.parentId,
  });

  final int localId;
  final String notebookId;
  final String name;
  final String kind;
  final String visibility;
  final String payload;
  final int sortOrder;
  final bool isPinned;
  final bool isClosed;
  final int createdAt;
  final int updatedAt;
  final String? parentId;
}

/// `diary_notebooks` 表的一行（两端都是本地 id）。`addedAt` 为 Unix 秒。
class SyncRawMembership {
  const SyncRawMembership({
    required this.diaryLocalId,
    required this.notebookLocalId,
    required this.chapterId,
    required this.position,
    required this.addedAt,
  });

  final int diaryLocalId;
  final int notebookLocalId;
  final String? chapterId;
  final int position;
  final int addedAt;
}

/// `diary_comments` 表的一行。`diaryId` 是日记业务 id；时间为 Unix 秒。
class SyncRawComment {
  const SyncRawComment({
    required this.localId,
    required this.commentId,
    required this.diaryId,
    required this.content,
    required this.mood,
    required this.createdAt,
    required this.editedAt,
  });

  final int localId;
  final String commentId;
  final String diaryId;
  final String content;
  final String? mood;
  final int createdAt;
  final int? editedAt;
}

/// `diary_templates` 表的一行。时间为 Unix 秒。
class SyncRawTemplate {
  const SyncRawTemplate({
    required this.localId,
    required this.templateId,
    required this.name,
    required this.payload,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final int localId;
  final String templateId;
  final String name;
  final String payload;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
}

/// `anniversaries` 表的一行。时间为 Unix 秒。
class SyncRawAnniversary {
  const SyncRawAnniversary({
    required this.localId,
    required this.anniversaryId,
    required this.title,
    required this.baseDate,
    required this.recurrence,
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
    required this.linkedDiaryId,
    required this.note,
    required this.isPinned,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final int localId;
  final String anniversaryId;
  final String title;
  final String baseDate;
  final String recurrence;
  final int? lunarYear;
  final int? lunarMonth;
  final int? lunarDay;
  final String? linkedDiaryId;
  final String note;
  final bool isPinned;
  final String metadata;
  final int createdAt;
  final int updatedAt;
}

/// `day_moods` 表的一行。`updatedAt` 为 Unix 秒。
class SyncRawDayMood {
  const SyncRawDayMood({
    required this.day,
    required this.mood,
    required this.updatedAt,
  });

  final String day;
  final String mood;
  final int updatedAt;
}

/// 同一个事务里读出的全部原始行（一致的快照）。
class SyncRawSnapshot {
  const SyncRawSnapshot({
    required this.diaries,
    required this.tags,
    required this.diaryTags,
    required this.notebooks,
    required this.memberships,
    required this.comments,
    required this.templates,
    required this.anniversaries,
    required this.dayMoods,
  });

  final List<SyncRawDiary> diaries;
  final List<SyncRawTag> tags;
  final List<SyncRawDiaryTag> diaryTags;
  final List<SyncRawNotebook> notebooks;
  final List<SyncRawMembership> memberships;
  final List<SyncRawComment> comments;
  final List<SyncRawTemplate> templates;
  final List<SyncRawAnniversary> anniversaries;
  final List<SyncRawDayMood> dayMoods;
}
