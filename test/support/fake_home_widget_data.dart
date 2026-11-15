// 快照构建测试用的假数据源（`HomeWidgetDataSource`）：各项由测试设定，查询口径
// 按真实实现的约定模拟（发表时间区间、来源筛选、只认本机文件）。

import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_content.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_data_source.dart';

/// 假图片路径的前缀：[FakeHomeWidgetData.localImage] 只认它开头的来源（当作存在的
/// 本机文件）。Kotlin 渲染测试把它换成测试时现画的图片所在目录。
const String kFakeHomeWidgetImagePrefix = '/fixture/';

class FakeHomeWidgetData implements HomeWidgetDataSource {
  FakeHomeWidgetData({
    this.words = 0,
    this.dueDates = const <String?>[],
    this.notebooks = const <String, String>{},
    this.anniversaryRows = const <Anniversary>[],
    this.moods = const <String, DayMood>{},
    this.markers = const <DiaryCalendarMarker>[],
    this.open = const <TodoRow>[],
    this.completed = const <TodoRow>[],
    this.lists = const <TodoListRow>[],
    this.diaries = const <DiaryWithTags>[],
    this.readable = const <String, String>{},
    this.notebookMembers = const <String, Set<String>>{},
  });

  final int words;
  final List<String?> dueDates;
  final Map<String, String> notebooks;
  final List<Anniversary> anniversaryRows;
  final Map<String, DayMood> moods;
  final List<DiaryCalendarMarker> markers;
  final List<TodoRow> open;
  final List<TodoRow> completed;
  final List<TodoListRow> lists;

  /// 全部（非私密的）日记；私密日记由真实查询排除，这里不放。
  final List<DiaryWithTags> diaries;

  /// 能看的日记本 id → 名字。
  final Map<String, String> readable;

  /// 日记本 id → 本子里的日记 id。
  final Map<String, Set<String>> notebookMembers;

  /// 查过的发表时间区间（核对查询范围用）。
  final List<(DateTime, DateTime)> queriedRanges = <(DateTime, DateTime)>[];

  /// 查过的最近日记来源。
  final List<RecentDiariesSource> queriedSources = <RecentDiariesSource>[];

  @override
  Future<List<TodoRow>> openTodos() async => open;

  @override
  Future<List<TodoRow>> completedTodos() async => completed;

  @override
  Future<List<TodoListRow>> todoLists() async => lists;

  @override
  Future<List<Anniversary>> anniversaries() async => anniversaryRows;

  @override
  Future<Map<String, DayMood>> dayMoods() async => moods;

  @override
  Future<List<DiaryCalendarMarker>> markersBetween(
    DateTime start,
    DateTime end,
  ) async => <DiaryCalendarMarker>[
    for (final marker in markers)
      if (!marker.createdAt.isBefore(start) && marker.createdAt.isBefore(end))
        marker,
  ];

  @override
  Future<int> wordsOn(DateTime day) async => words;

  @override
  Future<List<String?>> openTodoDueDates() async => dueDates;

  @override
  Future<Map<String, String>> writableNotebooks() async => notebooks;

  @override
  Future<List<DiaryWithTags>> diariesCreatedInRanges(
    List<(DateTime, DateTime)> ranges,
  ) async {
    queriedRanges.addAll(ranges);
    return <DiaryWithTags>[
      for (final row in diaries)
        if (ranges.any(
          (range) =>
              !row.diary.createdAt.isBefore(range.$1) &&
              row.diary.createdAt.isBefore(range.$2),
        ))
          row,
    ]..sort((a, b) => b.diary.createdAt.compareTo(a.diary.createdAt));
  }

  @override
  Future<List<DiaryWithTags>> recentDiaries(
    RecentDiariesSource source, {
    String? notebookId,
    String? tagName,
    required DateTime now,
    required int limit,
  }) async {
    queriedSources.add(source);
    bool matches(DiaryWithTags row) => switch (source) {
      RecentDiariesSource.all => true,
      RecentDiariesSource.pinned => row.diary.isPinned,
      RecentDiariesSource.notebook =>
        notebookMembers[notebookId]?.contains(row.diary.diaryId) ?? false,
      RecentDiariesSource.tag => row.tags.any((tag) => tag.name == tagName),
    };
    final unlocked = <DiaryWithTags>[
      for (final row in diaries)
        if (matches(row) &&
            (row.diary.capsuleUnlockAt == null ||
                !row.diary.capsuleUnlockAt!.isAfter(now)))
          row,
    ]..sort((a, b) => b.diary.createdAt.compareTo(a.diary.createdAt));
    return unlocked.take(limit).toList();
  }

  @override
  Future<Map<String, String>> readableNotebooks() async => readable;

  @override
  Future<Set<String>> tagNames() async => <String>{
    for (final row in diaries)
      for (final tag in row.tags) tag.name,
  };

  @override
  String? localImage(String source) =>
      source.startsWith(kFakeHomeWidgetImagePrefix) ? source : null;
}

/// 测试用日记。[cover] 与 [images]（正文里的图片）为图片来源，[mood] 写进
/// metadata 的 `context.moodEmoji`。
DiaryWithTags fakeWidgetDiary(
  String diaryId,
  DateTime createdAt, {
  String title = '',
  String text = '',
  String? cover,
  List<String> images = const <String>[],
  String? mood,
  bool pinned = false,
  List<String> tags = const <String>[],
  DateTime? capsuleUnlockAt,
}) {
  final blocks = <String>[
    if (text.isNotEmpty)
      '{"type":"paragraph","data":{"delta":[{"insert":"$text"}]}}',
    for (final image in images) '{"type":"image","data":{"url":"$image"}}',
  ];
  return DiaryWithTags(
    diary: Diary(
      id: diaryId.hashCode,
      diaryId: diaryId,
      title: title,
      content: '{"document":{"type":"page","children":[${blocks.join(',')}]}}',
      contentText: text,
      cover: cover,
      metadata: mood == null ? '{}' : '{"context":{"moodEmoji":"$mood"}}',
      createdAt: createdAt,
      updatedAt: createdAt,
      isArchived: false,
      isPinned: pinned,
      capsuleLockedAt: capsuleUnlockAt == null ? null : DateTime(2020),
      capsuleUnlockAt: capsuleUnlockAt,
      isDeleted: false,
    ),
    tags: <Tag>[
      for (final (index, name) in tags.indexed)
        Tag(id: index + 1, name: name, color: 0xFF1E6586),
    ],
  );
}
