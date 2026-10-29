part of 'app_database.dart';

/// 局域网同步的数据库读写（规格见 docs/lan_sync.md §1、§6）。
///
/// - 读：[readSyncRows] 在一个事务里读出规范化所需的全部原始行（一致的快照），
///   结果是纯 Dart 的 [SyncRawSnapshot]，可以整批送进 `Isolate.run`；
/// - 写：见文件末尾“写入”一节（任务 6 补上）。
///
/// 读取一律用原始 SQL 而不是 Drift 的 `select`：要的是库里实际存的值（时间是
/// Unix 秒、布尔是 0/1），原始列指纹按它计算；也省掉一万篇日记逐行构造
/// [DateTime] 与数据类的开销。日记不读 `content_text`（由正文推出，不参与哈希）。
mixin _AppDatabaseSyncOps on _$AppDatabase {
  /// 在一个事务里读出日记、标签、标签关联、日记本、成员关系、留言、模板、
  /// 纪念日与这天的心情的原始行。草稿不同步，不读。
  Future<SyncRawSnapshot> readSyncRows() {
    return transaction(() async {
      final diaryRows = await customSelect(
        'SELECT id, diary_id, title, content, cover, metadata, created_at, '
        'updated_at, is_archived, archived_at, is_pinned, capsule_unlock_at, '
        'capsule_locked_at, is_deleted, deleted_at FROM diaries',
      ).get();
      final tagRows = await customSelect(
        'SELECT id, name, color FROM tags',
      ).get();
      final diaryTagRows = await customSelect(
        'SELECT diary_id, tag_id FROM diary_tags',
      ).get();
      final notebookRows = await customSelect(
        'SELECT id, notebook_id, name, kind, visibility, payload, sort_order, '
        'is_pinned, is_closed, created_at, updated_at, parent_id FROM notebooks',
      ).get();
      final membershipRows = await customSelect(
        'SELECT diary_id, notebook_id, chapter_id, position, added_at '
        'FROM diary_notebooks',
      ).get();
      final commentRows = await customSelect(
        'SELECT id, comment_id, diary_id, content, mood, created_at, edited_at '
        'FROM diary_comments',
      ).get();
      final templateRows = await customSelect(
        'SELECT id, template_id, name, payload, sort_order, created_at, '
        'updated_at FROM diary_templates',
      ).get();
      final anniversaryRows = await customSelect(
        'SELECT id, anniversary_id, title, base_date, recurrence, lunar_year, '
        'lunar_month, lunar_day, linked_diary_id, note, is_pinned, metadata, '
        'created_at, updated_at FROM anniversaries',
      ).get();
      final dayMoodRows = await customSelect(
        'SELECT day, mood, updated_at FROM day_moods',
      ).get();

      return SyncRawSnapshot(
        diaries: <SyncRawDiary>[
          for (final row in diaryRows)
            SyncRawDiary(
              localId: _syncInt(row.data['id']),
              diaryId: row.data['diary_id'] as String,
              title: row.data['title'] as String,
              content: row.data['content'] as String,
              cover: row.data['cover'] as String?,
              metadata: row.data['metadata'] as String,
              createdAt: _syncInt(row.data['created_at']),
              updatedAt: _syncInt(row.data['updated_at']),
              isArchived: _syncBool(row.data['is_archived']),
              archivedAt: _syncIntOrNull(row.data['archived_at']),
              isPinned: _syncBool(row.data['is_pinned']),
              capsuleUnlockAt: _syncIntOrNull(row.data['capsule_unlock_at']),
              capsuleLockedAt: _syncIntOrNull(row.data['capsule_locked_at']),
              isDeleted: _syncBool(row.data['is_deleted']),
              deletedAt: _syncIntOrNull(row.data['deleted_at']),
            ),
        ],
        tags: <SyncRawTag>[
          for (final row in tagRows)
            SyncRawTag(
              localId: _syncInt(row.data['id']),
              name: row.data['name'] as String,
              color: _syncInt(row.data['color']),
            ),
        ],
        diaryTags: <SyncRawDiaryTag>[
          for (final row in diaryTagRows)
            SyncRawDiaryTag(
              diaryLocalId: _syncInt(row.data['diary_id']),
              tagLocalId: _syncInt(row.data['tag_id']),
            ),
        ],
        notebooks: <SyncRawNotebook>[
          for (final row in notebookRows)
            SyncRawNotebook(
              localId: _syncInt(row.data['id']),
              notebookId: row.data['notebook_id'] as String,
              name: row.data['name'] as String,
              kind: row.data['kind'] as String,
              visibility: row.data['visibility'] as String,
              payload: row.data['payload'] as String,
              sortOrder: _syncInt(row.data['sort_order']),
              isPinned: _syncBool(row.data['is_pinned']),
              isClosed: _syncBool(row.data['is_closed']),
              createdAt: _syncInt(row.data['created_at']),
              updatedAt: _syncInt(row.data['updated_at']),
              parentId: row.data['parent_id'] as String?,
            ),
        ],
        memberships: <SyncRawMembership>[
          for (final row in membershipRows)
            SyncRawMembership(
              diaryLocalId: _syncInt(row.data['diary_id']),
              notebookLocalId: _syncInt(row.data['notebook_id']),
              chapterId: row.data['chapter_id'] as String?,
              position: _syncInt(row.data['position']),
              addedAt: _syncInt(row.data['added_at']),
            ),
        ],
        comments: <SyncRawComment>[
          for (final row in commentRows)
            SyncRawComment(
              localId: _syncInt(row.data['id']),
              commentId: row.data['comment_id'] as String,
              diaryId: row.data['diary_id'] as String,
              content: row.data['content'] as String,
              mood: row.data['mood'] as String?,
              createdAt: _syncInt(row.data['created_at']),
              editedAt: _syncIntOrNull(row.data['edited_at']),
            ),
        ],
        templates: <SyncRawTemplate>[
          for (final row in templateRows)
            SyncRawTemplate(
              localId: _syncInt(row.data['id']),
              templateId: row.data['template_id'] as String,
              name: row.data['name'] as String,
              payload: row.data['payload'] as String,
              sortOrder: _syncInt(row.data['sort_order']),
              createdAt: _syncInt(row.data['created_at']),
              updatedAt: _syncInt(row.data['updated_at']),
            ),
        ],
        anniversaries: <SyncRawAnniversary>[
          for (final row in anniversaryRows)
            SyncRawAnniversary(
              localId: _syncInt(row.data['id']),
              anniversaryId: row.data['anniversary_id'] as String,
              title: row.data['title'] as String,
              baseDate: row.data['base_date'] as String,
              recurrence: row.data['recurrence'] as String,
              lunarYear: _syncIntOrNull(row.data['lunar_year']),
              lunarMonth: _syncIntOrNull(row.data['lunar_month']),
              lunarDay: _syncIntOrNull(row.data['lunar_day']),
              linkedDiaryId: row.data['linked_diary_id'] as String?,
              note: row.data['note'] as String,
              isPinned: _syncBool(row.data['is_pinned']),
              metadata: row.data['metadata'] as String,
              createdAt: _syncInt(row.data['created_at']),
              updatedAt: _syncInt(row.data['updated_at']),
            ),
        ],
        dayMoods: <SyncRawDayMood>[
          for (final row in dayMoodRows)
            SyncRawDayMood(
              day: row.data['day'] as String,
              mood: row.data['mood'] as String,
              updatedAt: _syncInt(row.data['updated_at']),
            ),
        ],
      );
    });
  }

  // ---- 写入（任务 6）----
  //
  // 单事务、带前置条件的按原值写入与关联清理（规格 §6）放在这里，与上面的
  // 读取共用同一套列口径：时间按 Unix 秒、布尔按 0/1、业务 id ↔ 本地 id 换算。
}

/// SQLite 整数列读出来是 int；损坏数据里偶尔是浮点数，按截断取整。
int _syncInt(Object? value) => (value as num).toInt();

int? _syncIntOrNull(Object? value) => value == null ? null : _syncInt(value);

/// Drift 的布尔列存 0/1。
bool _syncBool(Object? value) => value is bool ? value : _syncInt(value) != 0;
