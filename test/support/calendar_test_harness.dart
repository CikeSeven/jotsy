import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/providers/calendar_diary_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expressive_test_theme.dart';

/// 日历页组件测试脚手架：设置服务用真实实现（SharedPreferences mock），
/// 打点、当天日记、那年今日与纪念日用固定数据，不打开数据库；需要写库的
/// 测试经 [extraOverrides] 注入内存数据库。
///
/// 页宽默认 401.6：日历面板左右合计 41.6dp 内缩，页宽为整数 360，避免
/// PageView 在数千页后触发 SliverFillViewport 的浮点精度断言；自定义
/// [width] 也要满足“减 41.6 为整数”（如窄屏用 321.6）。
/// 主题与应用同源（[expressiveTestTheme]），[brightness] 用于明暗双跑。
Future<SettingsService> pumpCalendarPage(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  Brightness brightness = Brightness.light,
  double width = 401.6,
  Map<String, Object> prefs = const <String, Object>{},
  List<DiaryCalendarMarker> markers = const <DiaryCalendarMarker>[],
  List<DiaryWithTags> Function(DateTime day)? dayDiaries,
  List<DiaryWithTags> onThisDay = const <DiaryWithTags>[],
  List<Tag> tags = const <Tag>[],
  List<Anniversary> anniversaries = const <Anniversary>[],
  Map<String, DiaryWithTags> linkedDiaries = const <String, DiaryWithTags>{},
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        calendarMonthMarkersProvider.overrideWith(
          (ref, month) => Stream.value(markers),
        ),
        calendarYearMarkersProvider.overrideWith(
          (ref, year) => Stream.value(markers),
        ),
        calendarRangeMarkersProvider.overrideWith(
          (ref, range) => Stream.value(markers),
        ),
        calendarDayDiariesProvider.overrideWith(
          (ref, day) =>
              Stream.value(dayDiaries?.call(day) ?? const <DiaryWithTags>[]),
        ),
        calendarOnThisDayProvider.overrideWith(
          (ref, day) => Stream.value(onThisDay),
        ),
        calendarMonthInlineImagesProvider.overrideWith(
          (ref, month) => Stream.value(const <String, String>{}),
        ),
        moodOptionsProvider.overrideWith(
          (ref) => Stream.value(SettingsService.defaultMoodOptions),
        ),
        diaryCardTagLimitProvider.overrideWith((ref) => Stream.value(2)),
        tagListProvider.overrideWith((ref) => Stream.value(tags)),
        anniversaryListProvider.overrideWith(
          (ref) => Stream.value(anniversaries),
        ),
        anniversaryLinkedDiaryProvider.overrideWith(
          (ref, diaryId) => Stream.value(linkedDiaries[diaryId]),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: locale,
        theme: expressiveTestTheme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // 与 Home 的真实装配一致，覆盖多个滚动控件共用路由存储的场景。
        home: const CalendarPage(key: PageStorageKey<String>('tab_calendar')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

/// 测试用日记；[createdAt] 同时作为更新时间，[diaryId] 需在测试间唯一
/// （DiaryCardViewData 按 id + 更新时间缓存）。
DiaryWithTags calendarTestDiary(
  String diaryId,
  DateTime createdAt, {
  String title = '',
  String text = 'body',
  DateTime? capsuleUnlockAt,
}) {
  return DiaryWithTags(
    diary: Diary(
      id: diaryId.hashCode,
      diaryId: diaryId,
      title: title,
      content: '[{"insert":"$text\\n"}]',
      contentText: text,
      metadata: '{}',
      createdAt: createdAt,
      updatedAt: createdAt,
      isArchived: false,
      isPinned: false,
      capsuleLockedAt: capsuleUnlockAt == null ? null : createdAt,
      capsuleUnlockAt: capsuleUnlockAt,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}
