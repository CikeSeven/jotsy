import 'package:drift/drift.dart' show Value;

import '../../../database/app_database.dart';
import 'sync_canonical_support.dart';
import 'sync_media_refs.dart';
import 'sync_model.dart';

/// 标签、留言、模板、纪念日与这天的心情 ↔ 规范记录（规格 §2.2）。
///
/// - tag：以名称为 id（各设备的本地 id 不同，名称在库里唯一），只有颜色分面；
/// - comment / anniversary / dayMood：全部业务列；纪念日的 `metadata`、模板的
///   `payload` 取库中原始 JSON 解析后的对象（解析不了的原文保留，见
///   [syncDecodeJsonObjectColumn]）；
/// - template：payload 原样搬运。保存模板时已经过 UI 层的白名单重建，读取时
///   应用自己还会再经 `sanitizeDiaryTemplateBlocks`；同步层在 core，不引用 UI
///   模块的清理函数，也不该替用户“修”数据；
/// - 媒体路径归一只作用于可能存放媒体的 JSON 列（metadata、payload），标题、
///   备注、留言正文这类用户文字不改写（见规格 §2.3 的说明）。
///
/// 无副作用。

/// 标签记录的 id：库里的名称（按列长截断，与写回时同一口径）。
String syncTagRecordName(SyncRawTag row) =>
    syncTruncate(row.name, SyncColumnLimits.tagName);

SyncRecord syncTagRecord(SyncRawTag row) => SyncRecord(
  SyncKey(SyncEntity.tag, syncTagRecordName(row)),
  <String, Object?>{
    SyncFacet.color: <String, Object?>{'color': row.color},
  },
);

class SyncTagColumns {
  const SyncTagColumns({required this.name, required this.color});

  factory SyncTagColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.tag) {
      throw ArgumentError.value(record.key, 'record', '不是标签记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.color], SyncFacet.color);
    return SyncTagColumns(
      name: syncTruncate(record.key.id, SyncColumnLimits.tagName),
      color: syncIntOf(value['color'], 'color'),
    );
  }

  final String name;
  final int color;

  TagsCompanion toCompanion() =>
      TagsCompanion(name: Value<String>(name), color: Value<int>(color));
}

SyncRecord syncCommentRecord(SyncRawComment row) =>
    SyncRecord(SyncKey(SyncEntity.comment, row.commentId), <String, Object?>{
      SyncFacet.main: <String, Object?>{
        'diaryId': row.diaryId,
        'content': row.content,
        'mood': row.mood,
        'createdAt': syncMillisOfSeconds(row.createdAt),
        'editedAt': syncMillisOfSecondsOrNull(row.editedAt),
      },
    });

class SyncCommentColumns {
  const SyncCommentColumns({
    required this.commentId,
    required this.diaryId,
    required this.content,
    required this.mood,
    required this.createdAt,
    required this.editedAt,
  });

  factory SyncCommentColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.comment) {
      throw ArgumentError.value(record.key, 'record', '不是留言记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    return SyncCommentColumns(
      commentId: record.key.id,
      diaryId: syncStringOf(value['diaryId'], 'diaryId'),
      content: syncStringOf(value['content'], 'content'),
      mood: syncStringOrNullOf(value['mood'], 'mood'),
      createdAt: syncDateTimeOf(value['createdAt']),
      editedAt: syncDateTimeOrNullOf(value['editedAt']),
    );
  }

  final String commentId;
  final String diaryId;
  final String content;
  final String? mood;
  final DateTime createdAt;
  final DateTime? editedAt;

  DiaryCommentsCompanion toCompanion() => DiaryCommentsCompanion(
    commentId: Value<String>(commentId),
    diaryId: Value<String>(diaryId),
    content: Value<String>(content),
    mood: Value<String?>(mood),
    createdAt: Value<DateTime>(createdAt),
    editedAt: Value<DateTime?>(editedAt),
  );
}

SyncRecord syncTemplateRecord(SyncRawTemplate row) =>
    SyncRecord(SyncKey(SyncEntity.template, row.templateId), <String, Object?>{
      SyncFacet.main: <String, Object?>{
        'name': row.name,
        'payload': syncNormalizeMediaRefs(
          syncDecodeJsonObjectColumn(row.payload),
        ),
        'createdAt': syncMillisOfSeconds(row.createdAt),
        'updatedAt': syncMillisOfSeconds(row.updatedAt),
      },
    });

/// 模板写回本机的列值（不含手动顺序，由 orderList `templates` 决定）。
class SyncTemplateColumns {
  const SyncTemplateColumns({
    required this.templateId,
    required this.name,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncTemplateColumns.fromRecord(
    SyncRecord record, {
    required String dataRoot,
  }) {
    if (record.key.entity != SyncEntity.template) {
      throw ArgumentError.value(record.key, 'record', '不是模板记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    return SyncTemplateColumns(
      templateId: record.key.id,
      name: syncStringOf(value['name'], 'name'),
      payload: syncEncodeJsonObjectColumn(
        syncRebindMediaRefs(value['payload'], dataRoot),
        'payload',
      ),
      createdAt: syncDateTimeOf(value['createdAt']),
      updatedAt: syncDateTimeOf(value['updatedAt']),
    );
  }

  final String templateId;
  final String name;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// [sortOrder] 只在插入新行时给（之后由模板顺序列表统一重排）。
  DiaryTemplatesCompanion toCompanion({int? sortOrder}) =>
      DiaryTemplatesCompanion(
        templateId: Value<String>(templateId),
        name: Value<String>(name),
        payload: Value<String>(payload),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
        sortOrder: sortOrder == null
            ? const Value<int>.absent()
            : Value<int>(sortOrder),
      );
}

SyncRecord syncAnniversaryRecord(SyncRawAnniversary row) => SyncRecord(
  SyncKey(SyncEntity.anniversary, row.anniversaryId),
  <String, Object?>{
    SyncFacet.main: <String, Object?>{
      'title': syncTruncate(row.title, SyncColumnLimits.anniversaryTitle),
      'baseDate': row.baseDate,
      'recurrence': row.recurrence,
      'lunarYear': row.lunarYear,
      'lunarMonth': row.lunarMonth,
      'lunarDay': row.lunarDay,
      'linkedDiaryId': row.linkedDiaryId,
      'note': row.note,
      'pinned': row.isPinned,
      'metadata': syncNormalizeMediaRefs(
        syncDecodeJsonObjectColumn(row.metadata),
      ),
      'createdAt': syncMillisOfSeconds(row.createdAt),
      'updatedAt': syncMillisOfSeconds(row.updatedAt),
    },
  },
);

class SyncAnniversaryColumns {
  const SyncAnniversaryColumns({
    required this.anniversaryId,
    required this.title,
    required this.baseDate,
    required this.recurrence,
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
    required this.linkedDiaryId,
    required this.note,
    required this.pinned,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncAnniversaryColumns.fromRecord(
    SyncRecord record, {
    required String dataRoot,
  }) {
    if (record.key.entity != SyncEntity.anniversary) {
      throw ArgumentError.value(record.key, 'record', '不是纪念日记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    return SyncAnniversaryColumns(
      anniversaryId: record.key.id,
      title: syncTruncate(
        syncStringOf(value['title'], 'title'),
        SyncColumnLimits.anniversaryTitle,
      ),
      baseDate: syncStringOf(value['baseDate'], 'baseDate'),
      recurrence: syncStringOf(value['recurrence'], 'recurrence'),
      lunarYear: syncIntOrNullOf(value['lunarYear'], 'lunarYear'),
      lunarMonth: syncIntOrNullOf(value['lunarMonth'], 'lunarMonth'),
      lunarDay: syncIntOrNullOf(value['lunarDay'], 'lunarDay'),
      linkedDiaryId: syncStringOrNullOf(
        value['linkedDiaryId'],
        'linkedDiaryId',
      ),
      note: syncStringOf(value['note'], 'note'),
      pinned: syncBoolOf(value['pinned'], 'pinned'),
      metadata: syncEncodeJsonObjectColumn(
        syncRebindMediaRefs(value['metadata'], dataRoot),
        'metadata',
      ),
      createdAt: syncDateTimeOf(value['createdAt']),
      updatedAt: syncDateTimeOf(value['updatedAt']),
    );
  }

  final String anniversaryId;
  final String title;
  final String baseDate;
  final String recurrence;
  final int? lunarYear;
  final int? lunarMonth;
  final int? lunarDay;
  final String? linkedDiaryId;
  final String note;
  final bool pinned;
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnniversariesCompanion toCompanion() => AnniversariesCompanion(
    anniversaryId: Value<String>(anniversaryId),
    title: Value<String>(title),
    baseDate: Value<String>(baseDate),
    recurrence: Value<String>(recurrence),
    lunarYear: Value<int?>(lunarYear),
    lunarMonth: Value<int?>(lunarMonth),
    lunarDay: Value<int?>(lunarDay),
    linkedDiaryId: Value<String?>(linkedDiaryId),
    note: Value<String>(note),
    isPinned: Value<bool>(pinned),
    metadata: Value<String>(metadata),
    createdAt: Value<DateTime>(createdAt),
    updatedAt: Value<DateTime>(updatedAt),
  );
}

/// 这天的心情：`mood` 原样搬运（认不出的枚举名同样保留，见 [DayMood.parse]）。
SyncRecord syncDayMoodRecord(SyncRawDayMood row) =>
    SyncRecord(SyncKey(SyncEntity.dayMood, row.day), <String, Object?>{
      SyncFacet.main: <String, Object?>{
        'mood': row.mood,
        'updatedAt': syncMillisOfSeconds(row.updatedAt),
      },
    });

class SyncDayMoodColumns {
  const SyncDayMoodColumns({
    required this.day,
    required this.mood,
    required this.updatedAt,
  });

  factory SyncDayMoodColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.dayMood) {
      throw ArgumentError.value(record.key, 'record', '不是心情记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    return SyncDayMoodColumns(
      day: record.key.id,
      mood: syncStringOf(value['mood'], 'mood'),
      updatedAt: syncDateTimeOf(value['updatedAt']),
    );
  }

  final String day;
  final String mood;
  final DateTime updatedAt;

  DayMoodsCompanion toCompanion() => DayMoodsCompanion(
    day: Value<String>(day),
    mood: Value<String>(mood),
    updatedAt: Value<DateTime>(updatedAt),
  );
}
