part of 'app_database.dart';

/// 纪念日读写。
///
/// 输入：页面与编辑器整理好的字段（农历快照由调用方按日期推算规则算好）；
/// 输出：drift watch 流与业务 id。删除是硬删除——纪念日没有回收站，撤销由
/// 调用方持有被删的整行、经 [restoreAnniversary] 原样写回。
mixin _AppDatabaseAnniversaryOps on _$AppDatabase {
  /// 全部纪念日：置顶在前，其余按创建先后。列表页再按下一次日期排序，这里
  /// 给出稳定的基础顺序（同一天有几条时日期格显示第一条）。
  Stream<List<Anniversary>> watchAnniversaries() {
    return (select(anniversaries)
          ..orderBy(<OrderClauseGenerator<$AnniversariesTable>>[
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<Anniversary?> watchAnniversary(String anniversaryId) {
    return (select(
      anniversaries,
    )..where((t) => t.anniversaryId.equals(anniversaryId))).watchSingleOrNull();
  }

  /// 新建纪念日，返回业务 id。标题去掉首尾空白后不能为空。
  Future<String> createAnniversary({
    required String title,
    required DateTime baseDate,
    required AnniversaryRecurrence recurrence,
    ({int year, int month, int day})? lunar,
    String? linkedDiaryId,
    String note = '',
    bool isPinned = false,
  }) async {
    final id = _newBusinessUuid();
    final now = DateTime.now();
    await into(anniversaries).insert(
      AnniversariesCompanion.insert(
        anniversaryId: id,
        title: _normalizeAnniversaryTitle(title),
        baseDate: formatAnniversaryDate(baseDate),
        recurrence: Value(recurrence.name),
        lunarYear: Value(lunar?.year),
        lunarMonth: Value(lunar?.month),
        lunarDay: Value(lunar?.day),
        linkedDiaryId: Value(linkedDiaryId),
        note: Value(note.trim()),
        isPinned: Value(isPinned),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// 整体更新可编辑字段；`createdAt` 与 `metadata` 保持不变。
  Future<void> updateAnniversary(
    String anniversaryId, {
    required String title,
    required DateTime baseDate,
    required AnniversaryRecurrence recurrence,
    ({int year, int month, int day})? lunar,
    String? linkedDiaryId,
    String note = '',
    bool isPinned = false,
  }) async {
    await (update(
      anniversaries,
    )..where((t) => t.anniversaryId.equals(anniversaryId))).write(
      AnniversariesCompanion(
        title: Value(_normalizeAnniversaryTitle(title)),
        baseDate: Value(formatAnniversaryDate(baseDate)),
        recurrence: Value(recurrence.name),
        lunarYear: Value(lunar?.year),
        lunarMonth: Value(lunar?.month),
        lunarDay: Value(lunar?.day),
        linkedDiaryId: Value(linkedDiaryId),
        note: Value(note.trim()),
        isPinned: Value(isPinned),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setAnniversaryPinned(String anniversaryId, bool pinned) {
    return (update(
      anniversaries,
    )..where((t) => t.anniversaryId.equals(anniversaryId))).write(
      AnniversariesCompanion(
        isPinned: Value(pinned),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setAnniversaryLink(String anniversaryId, String? diaryId) {
    return (update(
      anniversaries,
    )..where((t) => t.anniversaryId.equals(anniversaryId))).write(
      AnniversariesCompanion(
        linkedDiaryId: Value(diaryId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 是否建过纪念日；功能开关的升级迁移据此决定是否保留纪念日（见
  /// `keepLegacyAnniversariesVisible`）。
  Future<bool> hasAnniversaries() async {
    final row = await (select(anniversaries)..limit(1)).getSingleOrNull();
    return row != null;
  }

  /// 删除并返回被删的整行（供撤销）；不存在时返回 null。
  Future<Anniversary?> deleteAnniversary(String anniversaryId) {
    return transaction(() async {
      final row = await (select(
        anniversaries,
      )..where((t) => t.anniversaryId.equals(anniversaryId))).getSingleOrNull();
      if (row != null) {
        await (delete(anniversaries)..where((t) => t.id.equals(row.id))).go();
      }
      return row;
    });
  }

  /// 撤销删除：按原 id 与业务 id 写回整行，排序与关联都与删除前一致。
  Future<void> restoreAnniversary(Anniversary row) {
    return into(anniversaries).insertOnConflictUpdate(row.toCompanion(false));
  }

  String _normalizeAnniversaryTitle(String raw) {
    final title = raw.trim();
    if (title.isEmpty) {
      throw const FormatException('纪念日名称不能为空');
    }
    return title;
  }
}
