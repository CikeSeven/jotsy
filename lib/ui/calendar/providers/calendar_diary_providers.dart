import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/viewmodels/diary_card_view_data.dart';

/// 某个月份的日历打点流（未删除，含归档）。
final calendarMonthMarkersProvider =
    StreamProvider.family<List<DiaryCalendarMarker>, DateTime>((ref, month) {
      final db = ref.watch(appDatabaseProvider);
      final normalizedMonth = DateTime(month.year, month.month);
      return db.watchDiaryMarkersByMonth(normalizedMonth);
    });

/// 某个日期的日记列表流（按 createdAt 归类，未删除，含归档）。
final calendarDayDiariesProvider =
    StreamProvider.family<List<DiaryWithTags>, DateTime>((ref, day) {
      final db = ref.watch(appDatabaseProvider);
      final normalizedDay = DateUtils.dateOnly(day);
      return db.watchDiariesCreatedOnDay(normalizedDay);
    });

/// 某一年的日历打点流（年视图用；未删除，含归档）。
final calendarYearMarkersProvider =
    StreamProvider.family<List<DiaryCalendarMarker>, int>((ref, year) {
      final db = ref.watch(appDatabaseProvider);
      return db.watchDiaryMarkersInRange(DateTime(year), DateTime(year + 1));
    });

/// 选中日期在其他年份的同月同日写下的日记（“那年今日”），按年份倒序。
///
/// 只回看 [calendarOnThisDayYearSpan] 年，向后只到今年（之后的年份只可能有
/// 未解封的胶囊，展示层也会过滤掉）。2 月 29 日只在闰年有对应日期，平年
/// 跳过而不是顺延到 3 月 1 日。
final calendarOnThisDayProvider =
    StreamProvider.family<List<DiaryWithTags>, DateTime>((ref, day) {
      final db = ref.watch(appDatabaseProvider);
      return db.watchDiariesCreatedInRanges(
        calendarOnThisDayRanges(day, now: DateTime.now()),
      );
    });

/// “那年今日”回看的年数上限。
const int calendarOnThisDayYearSpan = 30;

/// 计算 [day] 在其他年份的同月同日区间（本地日期边界）。
List<(DateTime, DateTime)> calendarOnThisDayRanges(
  DateTime day, {
  required DateTime now,
}) {
  final ranges = <(DateTime, DateTime)>[];
  final lastYear = now.year;
  for (
    var year = day.year - calendarOnThisDayYearSpan;
    year <= lastYear;
    year++
  ) {
    if (year == day.year) {
      continue;
    }
    final start = DateTime(year, day.month, day.day);
    if (start.month != day.month) {
      // 平年没有 2 月 29 日，DateTime 会溢出到 3 月 1 日。
      continue;
    }
    ranges.add((start, DateTime(year, day.month, day.day + 1)));
  }
  return ranges;
}

/// 某个月份里无显式封面日记的正文首图：`diaryId → 图片地址`。
///
/// 只有照片样式会 watch 它，其他样式不为解析正文付出任何代价。月份内任意
/// 日记变动都会让查询重新推送整月候选，解析结果按 `(diaryId, updatedAt)`
/// 缓存，未改动的日记不再重复 jsonDecode 正文。
final calendarMonthInlineImagesProvider =
    StreamProvider.family<Map<String, String>, DateTime>((ref, month) {
      final db = ref.watch(appDatabaseProvider);
      return db
          .watchDiaryImageCandidatesInRange(
            DateTime(month.year, month.month),
            DateTime(month.year, month.month + 1),
          )
          .map(_resolveInlineImages);
    });

Map<String, String> _resolveInlineImages(List<DiaryImageCandidate> rows) {
  final images = <String, String>{};
  for (final row in rows) {
    final image = _InlineImageCache.resolve(row);
    if (image != null) {
      images[row.diaryId] = image;
    }
  }
  return images;
}

/// 正文首图解析结果的 LRU 缓存；`null`（正文里只有“image”字样、没有真正
/// 的图片嵌入）同样缓存，避免每次推送都重新解析。
class _InlineImageCache {
  static const int _maxEntries = 400;
  static final LinkedHashMap<String, String?> _entries =
      LinkedHashMap<String, String?>();

  static String? resolve(DiaryImageCandidate row) {
    final key = '${row.diaryId}_${row.updatedAt.microsecondsSinceEpoch}';
    if (_entries.containsKey(key)) {
      final cached = _entries.remove(key);
      _entries[key] = cached;
      return cached;
    }
    final image = DiaryCardViewData.firstImageInContent(row.content);
    _entries[key] = image;
    if (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return image;
  }
}
