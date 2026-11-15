// 桌面小组件预览用的示例数据（启动器的小组件列表：Android 15+ 的生成预览与更早系统的
// 预览图）。
//
// 小组件列表谁都能翻，开着应用锁也一样，所以预览一律不用用户自己的日记、待办与纪念日，
// 只用这里按界面语言写好的示例：几篇日记（有照片的、只有文字的）、几项待办、两个纪念日、
// 一年的写作记录。快照的构建、配色与文案与真实快照完全同一套（`HomeWidgetSnapshotBuilder`），
// 只是数据换成了这里。
//
// 示例照片不是文件：路径写成 `sample:<名字>`，原生按名字画一幅平涂的小风景
// （`WidgetBitmaps.photo`）。

import 'dart:convert';
import 'dart:ui' show Color;

import '../../../core/database/app_database.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/calendar_display_options.dart';
import 'home_widget_data_source.dart';
import 'home_widget_snapshot_builder.dart';
import 'home_widget_today_section.dart';

/// 示例照片路径的前缀（原生按名字画示例图）。
const String kHomeWidgetSamplePhotoScheme = 'sample:';

/// 预览用的示例快照：全部种类、默认配置、所有相关功能开启、没有应用锁。
Future<Map<String, Object?>> buildHomeWidgetSampleSnapshot({
  required DateTime now,
  required AppLocalizations l10n,
  required Color appSeed,
  CalendarWeekStart weekStart = CalendarWeekStart.locale,
}) => HomeWidgetSnapshotBuilder(HomeWidgetSampleData(l10n, now)).build(
  HomeWidgetSnapshotInput(
    now: now,
    l10n: l10n,
    appSeed: appSeed,
    features: const AppFeatures(todos: true, anniversaries: true),
    appLocked: false,
    settings: HomeWidgetSettings.empty,
    installed: const [],
    kinds: HomeWidgetKind.values.toSet(),
    weekStart: weekStart,
  ),
);

class HomeWidgetSampleData implements HomeWidgetDataSource {
  HomeWidgetSampleData(this.l10n, DateTime now)
    : today = DateTime(now.year, now.month, now.day);

  final AppLocalizations l10n;
  final DateTime today;

  DateTime _day(int offset, [int hour = 20, int minute = 0]) =>
      DateTime(today.year, today.month, today.day + offset, hour, minute);

  late final List<DiaryWithTags> _diaries = <DiaryWithTags>[
    _diary(
      'sample-run',
      _day(0, 7, 40),
      title: l10n.homeWidgetSampleDiaryTitle4,
      text: l10n.homeWidgetSampleDiaryExcerpt4,
      image: 'run',
      mood: '💪',
    ),
    _diary(
      'sample-bread',
      _day(-1, 19),
      title: l10n.homeWidgetSampleDiaryTitle2,
      text: l10n.homeWidgetSampleDiaryExcerpt2,
      mood: '😋',
    ),
    _diary(
      'sample-books',
      _day(-4, 16),
      title: l10n.homeWidgetSampleDiaryTitle3,
      text: l10n.homeWidgetSampleDiaryExcerpt3,
      image: 'books',
    ),
    // 往年的今天：三年前带照片的一篇、五年前只有文字的一篇。
    _diary(
      'sample-sea',
      DateTime(today.year - 3, today.month, today.day, 18, 30),
      title: l10n.homeWidgetSampleDiaryTitle1,
      text: l10n.homeWidgetSampleDiaryExcerpt1,
      image: 'sunset',
      mood: '😊',
    ),
    _diary(
      'sample-start',
      DateTime(today.year - 5, today.month, today.day, 9),
      text: l10n.homeWidgetSampleDiaryExcerpt5,
    ),
  ];

  DiaryWithTags _diary(
    String id,
    DateTime createdAt, {
    String title = '',
    required String text,
    String? image,
    String? mood,
  }) {
    final children = <Object?>[
      <String, Object?>{
        'type': 'paragraph',
        'data': <String, Object?>{
          'delta': <Object?>[
            <String, Object?>{'insert': text},
          ],
        },
      },
      if (image != null)
        <String, Object?>{
          'type': 'image',
          'data': <String, Object?>{
            'url': '$kHomeWidgetSamplePhotoScheme$image',
          },
        },
    ];
    return DiaryWithTags(
      diary: Diary(
        id: id.hashCode,
        diaryId: id,
        title: title,
        content: jsonEncode(<String, Object?>{
          'document': <String, Object?>{'type': 'page', 'children': children},
        }),
        contentText: text,
        metadata: mood == null
            ? '{}'
            : jsonEncode(<String, Object?>{
                'context': <String, Object?>{'moodEmoji': mood},
              }),
        createdAt: createdAt,
        updatedAt: createdAt,
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
  }

  bool _inRange(DateTime at, DateTime start, DateTime end) =>
      !at.isBefore(start) && at.isBefore(end);

  @override
  Future<List<DiaryWithTags>> diariesCreatedInRanges(
    List<(DateTime, DateTime)> ranges,
  ) async => <DiaryWithTags>[
    for (final row in _diaries)
      if (ranges.any(
        (range) => _inRange(row.diary.createdAt, range.$1, range.$2),
      ))
        row,
  ];

  @override
  Future<List<DiaryWithTags>> recentDiaries(
    RecentDiariesSource source, {
    String? notebookId,
    String? tagName,
    required DateTime now,
    required int limit,
  }) async => source == RecentDiariesSource.all
      ? _diaries.take(limit).toList()
      : const <DiaryWithTags>[];

  @override
  Future<List<DiaryWithTags>> photoDiaries({
    String? notebookId,
    required DateTime now,
    required int limit,
  }) async => <DiaryWithTags>[
    if (notebookId == null)
      for (final row in _diaries)
        if (row.diary.content.contains('"image"')) row,
  ];

  @override
  String? localImage(String source) =>
      source.startsWith(kHomeWidgetSamplePhotoScheme) ? source : null;

  @override
  Future<Map<String, String>> readableNotebooks() async =>
      const <String, String>{};

  @override
  Future<Map<String, String>> writableNotebooks() async =>
      const <String, String>{};

  @override
  Future<Set<String>> tagNames() async => const <String>{};

  /// 一年的写作记录：大约三天里写两天，字数有多有少；最近一周天天写（连续记录）。
  @override
  Future<List<DiaryCalendarMarker>> markersBetween(
    DateTime start,
    DateTime end,
  ) async => <DiaryCalendarMarker>[
    for (var offset = 0; offset < 400; offset++)
      if (offset < 7 || (offset % 3 != 1 && offset % 11 != 5))
        if (_day(-offset, 21) case final at when _inRange(at, start, end))
          DiaryCalendarMarker(
            diaryId: 'sample-marker-$offset',
            createdAt: at,
            wordCount: 120 + (offset * 173) % 1400,
          ),
  ];

  @override
  Future<int> wordsOn(DateTime day) async => 860;

  @override
  Future<Map<String, DayMood>> dayMoods() async => <String, DayMood>{
    for (final (offset, mood) in <(int, DayMood)>[
      (0, DayMood.good),
      (-2, DayMood.great),
      (-5, DayMood.meh),
      (-8, DayMood.good),
      (-11, DayMood.bad),
      (-13, DayMood.great),
    ])
      homeWidgetDayKey(_day(offset)): mood,
  };

  @override
  Future<List<Anniversary>> anniversaries() async => <Anniversary>[
    _anniversary(1, l10n.homeWidgetSampleAnniversary2, _day(9), 1968, true),
    _anniversary(2, l10n.homeWidgetSampleAnniversary1, _day(-120), 2021, false),
  ];

  Anniversary _anniversary(
    int id,
    String title,
    DateTime day,
    int baseYear,
    bool pinned,
  ) {
    final created = DateTime(2020);
    final base = DateTime(baseYear, day.month, day.day);
    return Anniversary(
      id: id,
      anniversaryId: 'sample-anniversary-$id',
      title: title,
      baseDate: homeWidgetDayKey(base),
      recurrence: AnniversaryRecurrence.solarYearly.name,
      note: '',
      isPinned: pinned,
      metadata: '{}',
      createdAt: created,
      updatedAt: created,
    );
  }

  late final List<TodoRow> _open = <TodoRow>[
    _todo(1, l10n.homeWidgetSampleTodo2, due: -1),
    _todo(2, l10n.homeWidgetSampleTodo1, due: 0, minute: 19 * 60 + 30),
    _todo(3, l10n.homeWidgetSampleTodo3, due: 0),
    _todo(4, l10n.homeWidgetSampleTodo4),
  ];

  TodoRow _todo(int id, String title, {int? due, int? minute}) => TodoRow(
    id: id,
    todoId: 'sample-todo-$id',
    title: title,
    note: '',
    priority: 0,
    dueDate: due == null ? null : homeWidgetDayKey(_day(due)),
    dueMinute: minute,
    reminders: '[]',
    steps: '[]',
    sortOrder: id.toDouble(),
    metadata: '{}',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  @override
  Future<List<TodoRow>> openTodos() async => _open;

  @override
  Future<List<String?>> openTodoDueDates() async => <String?>[
    for (final row in _open) row.dueDate,
  ];

  @override
  Future<List<TodoRow>> completedTodos() async => const <TodoRow>[];

  @override
  Future<List<TodoListRow>> todoLists() async => const <TodoListRow>[];
}
