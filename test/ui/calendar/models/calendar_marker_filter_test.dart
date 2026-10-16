import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/calendar/models/calendar_marker_filter.dart';

void main() {
  final now = DateTime(2026, 10, 15);
  DiaryCalendarMarker marker(
    String id, {
    String? mood,
    List<int> tags = const <int>[],
    DateTime? unlockAt,
  }) => DiaryCalendarMarker(
    diaryId: id,
    createdAt: DateTime(2026, 10, 3),
    moodEmoji: mood,
    tagIds: tags,
    capsuleUnlockAt: unlockAt,
  );

  final happyTravel = marker('a', mood: '😀', tags: <int>[1]);
  final sadWork = marker('b', mood: '😢', tags: <int>[2]);
  final happyPlain = marker('c', mood: '😀');
  final lockedSad = marker(
    'd',
    mood: '😢',
    tags: <int>[2],
    unlockAt: DateTime(2027),
  );
  final all = <DiaryCalendarMarker>[
    happyTravel,
    sadWork,
    happyPlain,
    lockedSad,
  ];

  List<String> ids(CalendarMarkerFilter filter) =>
      filter.apply(all, now: now).map((m) => m.diaryId).toList();

  test('an empty filter keeps the very same list', () {
    const filter = CalendarMarkerFilter();
    expect(filter.isActive, isFalse);
    expect(identical(filter.apply(all, now: now), all), isTrue);
  });

  test('choices within a group match any of them', () {
    expect(
      ids(const CalendarMarkerFilter(moods: <String>{'😀', '😢'})),
      <String>['a', 'b', 'c', 'd'],
    );
    expect(ids(const CalendarMarkerFilter(tagIds: <int>{1, 2})), <String>[
      'a',
      'b',
      'd',
    ]);
  });

  test('mood and tag must both match', () {
    expect(
      ids(const CalendarMarkerFilter(moods: <String>{'😀'}, tagIds: <int>{1})),
      <String>['a', 'd'],
    );
  });

  test('locked capsules stay regardless of the filter', () {
    // 只按心情/标签决定锁是否出现，会提前泄露胶囊内容。
    expect(ids(const CalendarMarkerFilter(moods: <String>{'😀'})), <String>[
      'a',
      'c',
      'd',
    ]);
    expect(
      const CalendarMarkerFilter(
        moods: <String>{'😀'},
      ).matches(lockedSad, now: DateTime(2027, 1, 2)),
      isFalse,
    );
  });

  test('toggling adds and removes choices, deleted tags are dropped', () {
    final filter = const CalendarMarkerFilter()
        .toggleTag(1)
        .toggleTag(2)
        .toggleMood('😀')
        .toggleTag(1);
    expect(
      filter,
      const CalendarMarkerFilter(tagIds: <int>{2}, moods: <String>{'😀'}),
    );
    expect(identical(filter.retainTags(<int>[2, 3]), filter), isTrue);
    expect(
      filter.retainTags(<int>[3]),
      const CalendarMarkerFilter(moods: <String>{'😀'}),
    );
  });
}
