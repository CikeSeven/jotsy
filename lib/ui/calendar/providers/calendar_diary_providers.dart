import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

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
