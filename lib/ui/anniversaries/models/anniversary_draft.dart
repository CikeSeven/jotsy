import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../viewmodels/anniversary_rule.dart';

/// 编辑页里还没保存的纪念日。
///
/// 输入：长按的日期、已有的纪念日行或日记；输出：保存时写库的字段与农历
/// 快照。不可变，编辑页每次改动 copyWith 出新草稿，与初值比较判断是否有
/// 未保存的修改。
@immutable
class AnniversaryDraft {
  const AnniversaryDraft({
    required this.title,
    required this.date,
    required this.recurrence,
    this.linkedDiaryId,
    this.note = '',
    this.isPinned = false,
  });

  /// 从日历某一天新建：未来的日子默认“不重复”（倒数到那天），今天及以前
  /// 默认“每年”（纪念那天）。
  factory AnniversaryDraft.forDay(DateTime day, {required DateTime today}) {
    final date = DateTime(day.year, day.month, day.day);
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    return AnniversaryDraft(
      title: '',
      date: date,
      recurrence: isFuture
          ? AnniversaryRecurrence.once
          : AnniversaryRecurrence.solarYearly,
    );
  }

  factory AnniversaryDraft.fromRow(Anniversary row) {
    final rule = AnniversaryRule.fromRow(row);
    return AnniversaryDraft(
      title: row.title,
      date: rule?.base ?? DateTime.now(),
      recurrence: AnniversaryRecurrence.parse(row.recurrence),
      linkedDiaryId: row.linkedDiaryId,
      note: row.note,
      isPinned: row.isPinned,
    );
  }

  /// 从一篇日记新建：日期取日记的发表日期，名称取日记标题，并关联这篇日记。
  factory AnniversaryDraft.fromDiary(Diary diary) {
    final created = diary.createdAt.toLocal();
    final title = diary.title.trim();
    return AnniversaryDraft(
      title: title.length > maxTitleLength
          ? title.substring(0, maxTitleLength)
          : title,
      date: DateTime(created.year, created.month, created.day),
      recurrence: AnniversaryRecurrence.solarYearly,
      linkedDiaryId: diary.diaryId,
    );
  }

  /// 编辑页名称上限；数据库允许 100，日期格与卡片放不下太长的名字。
  static const int maxTitleLength = 40;
  static const int maxNoteLength = 200;

  final String title;
  final DateTime date;
  final AnniversaryRecurrence recurrence;
  final String? linkedDiaryId;
  final String note;
  final bool isPinned;

  bool get isValid => title.trim().isNotEmpty;

  /// 保存用的日期规则（农历每年时含按日期现算的农历快照）。
  AnniversaryRule get rule => AnniversaryRule.forDate(date, recurrence);

  /// 写库的农历快照；非农历规则为 null。
  ({int year, int month, int day})? get lunarSnapshot {
    final lunar = rule.lunar;
    return lunar == null
        ? null
        : (year: lunar.year, month: lunar.month, day: lunar.day);
  }

  AnniversaryDraft copyWith({
    String? title,
    DateTime? date,
    AnniversaryRecurrence? recurrence,
    ValueGetter<String?>? linkedDiaryId,
    String? note,
    bool? isPinned,
  }) {
    return AnniversaryDraft(
      title: title ?? this.title,
      date: date ?? this.date,
      recurrence: recurrence ?? this.recurrence,
      linkedDiaryId: linkedDiaryId == null
          ? this.linkedDiaryId
          : linkedDiaryId(),
      note: note ?? this.note,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  /// 与 [other] 比较是否有需要保存的修改；名称与备注忽略首尾空白。
  bool differsFrom(AnniversaryDraft other) {
    return title.trim() != other.title.trim() ||
        date != other.date ||
        recurrence != other.recurrence ||
        linkedDiaryId != other.linkedDiaryId ||
        note.trim() != other.note.trim() ||
        isPinned != other.isPinned;
  }
}
