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

  group('notebooks', () {
    DiaryCalendarMarker inBooks(
      String id, {
      String? mood,
      List<String> notebooks = const <String>[],
      DateTime? unlockAt,
    }) => DiaryCalendarMarker(
      diaryId: id,
      createdAt: DateTime(2026, 10, 3),
      moodEmoji: mood,
      notebookIds: notebooks,
      capsuleUnlockAt: unlockAt,
    );
    final markers = <DiaryCalendarMarker>[
      inBooks('trip', mood: '😀', notebooks: <String>['t']),
      inBooks('work', mood: '😢', notebooks: <String>['w']),
      inBooks('both', mood: '😢', notebooks: <String>['t', 'w']),
      inBooks('none', mood: '😀'),
      inBooks('locked', mood: '😢', unlockAt: DateTime(2027)),
    ];
    List<String> notebookIds(CalendarMarkerFilter filter) =>
        filter.apply(markers, now: now).map((m) => m.diaryId).toList();

    test('choosing notebooks keeps diaries in any of them', () {
      const filter = CalendarMarkerFilter(notebookIds: <String>{'t'});
      expect(filter.isActive, isTrue);
      expect(notebookIds(filter), <String>['trip', 'both', 'locked']);
      expect(
        notebookIds(
          const CalendarMarkerFilter(notebookIds: <String>{'t', 'w'}),
        ),
        <String>['trip', 'work', 'both', 'locked'],
      );
    });

    test('notebooks combine with moods and tags', () {
      expect(
        notebookIds(
          const CalendarMarkerFilter(
            notebookIds: <String>{'t'},
            moods: <String>{'😢'},
          ),
        ),
        <String>['both', 'locked'],
      );
      // 选了标签但这些日记都没有该标签：只剩不参与筛选的胶囊。
      expect(
        notebookIds(
          const CalendarMarkerFilter(
            notebookIds: <String>{'t'},
            tagIds: <int>{1},
          ),
        ),
        <String>['locked'],
      );
    });

    test('toggling, equality and retaining notebooks', () {
      const empty = CalendarMarkerFilter();
      final picked = empty.toggleNotebook('t').toggleNotebook('w');
      expect(
        picked,
        const CalendarMarkerFilter(notebookIds: <String>{'w', 't'}),
      );
      expect(picked.hashCode, isNot(empty.hashCode));
      expect(picked.toggleNotebook('t').toggleNotebook('w'), empty);
      expect(
        identical(picked.retainNotebooks(<String>['t', 'w', 'x']), picked),
        isTrue,
      );
      expect(
        picked.retainNotebooks(<String>['w']),
        const CalendarMarkerFilter(notebookIds: <String>{'w'}),
      );
      // 换组时保留其他组的条件。
      expect(
        const CalendarMarkerFilter(moods: <String>{'😀'}).toggleNotebook('t'),
        const CalendarMarkerFilter(
          moods: <String>{'😀'},
          notebookIds: <String>{'t'},
        ),
      );
    });
  });

  test('a chosen parent notebook also matches its sub-notebooks', () {
    DiaryCalendarMarker inNotebooks(String id, List<String> notebooks) =>
        DiaryCalendarMarker(
          diaryId: id,
          createdAt: DateTime(2026, 10, 3),
          notebookIds: notebooks,
        );
    final markers = <DiaryCalendarMarker>[
      inNotebooks('own', <String>['parent']),
      inNotebooks('child', <String>['child']),
      inNotebooks('other', <String>['other']),
    ];
    final picked = const CalendarMarkerFilter(notebookIds: <String>{'parent'})
        .withSubNotebooks(
          (String id) => id == 'parent' ? <String>['child'] : const <String>[],
        );
    expect(picked.subNotebookIds, <String>{'child'});
    expect(picked.apply(markers, now: now).map((m) => m.diaryId), <String>[
      'own',
      'child',
    ]);
    // 没选日记本时不变；子本只参与匹配，不是选中态。
    const none = CalendarMarkerFilter(moods: <String>{'😀'});
    expect(
      identical(none.withSubNotebooks((_) => <String>['x']), none),
      isTrue,
    );
    expect(picked.notebookIds, <String>{'parent'});
  });
}
