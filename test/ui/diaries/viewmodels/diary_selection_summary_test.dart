import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_selection_summary.dart';

void main() {
  DiaryWithTags loaded(String id, {bool pinned = false}) {
    final at = DateTime(2026, 1, 1);
    return DiaryWithTags(
      diary: Diary(
        id: id.hashCode,
        diaryId: id,
        title: id,
        content: '[]',
        contentText: '',
        metadata: '{}',
        createdAt: at,
        updatedAt: at,
        isArchived: false,
        isPinned: pinned,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
  }

  DiaryTimelineEntry entry(String id, {bool pinned = false}) {
    final at = DateTime(2026, 1, 1);
    return DiaryTimelineEntry(
      diaryId: id,
      isPinned: pinned,
      createdAt: at,
      updatedAt: at,
      title: id,
    );
  }

  test('a fully loaded list is all selected once every card is selected', () {
    final summary = DiarySelectionSummary.resolve(
      selectedIds: <String>{'a', 'b'},
      loadedItems: <DiaryWithTags>[loaded('a'), loaded('b')],
      timeline: null,
      hasMore: false,
    );
    expect(summary.allSelected, isTrue);
    expect(summary.allPinned, isFalse);
  });

  test('with unloaded pages it waits for the timeline before counting as '
      'all selected', () {
    DiarySelectionSummary resolve(List<DiaryTimelineEntry>? timeline) =>
        DiarySelectionSummary.resolve(
          selectedIds: <String>{'a', 'b'},
          loadedItems: <DiaryWithTags>[loaded('a'), loaded('b')],
          timeline: timeline,
          hasMore: true,
        );
    expect(resolve(null).allSelected, isFalse);
    expect(
      resolve(<DiaryTimelineEntry>[
        entry('a'),
        entry('b'),
        entry('c'),
      ]).allSelected,
      isFalse,
    );
    expect(
      resolve(<DiaryTimelineEntry>[entry('a'), entry('b')]).allSelected,
      isTrue,
    );
  });

  test('diaries hidden while waiting for undo do not count', () {
    final summary = DiarySelectionSummary.resolve(
      selectedIds: <String>{'a'},
      loadedItems: <DiaryWithTags>[loaded('a'), loaded('b')],
      timeline: null,
      hasMore: false,
      hiddenIds: <String>{'b'},
    );
    expect(summary.allSelected, isTrue);
  });

  test('nothing selected or an empty list is never all selected', () {
    expect(
      DiarySelectionSummary.resolve(
        selectedIds: const <String>{},
        loadedItems: <DiaryWithTags>[loaded('a')],
        timeline: null,
        hasMore: false,
      ).allSelected,
      isFalse,
    );
    expect(
      DiarySelectionSummary.resolve(
        selectedIds: <String>{'gone'},
        loadedItems: const <DiaryWithTags>[],
        timeline: null,
        hasMore: false,
      ).allSelected,
      isFalse,
    );
  });

  test('all pinned reads unloaded diaries from the timeline and is false '
      'when one is unknown', () {
    DiarySelectionSummary resolve(List<DiaryTimelineEntry>? timeline) =>
        DiarySelectionSummary.resolve(
          selectedIds: <String>{'a', 'z'},
          loadedItems: <DiaryWithTags>[loaded('a', pinned: true)],
          timeline: timeline,
          hasMore: true,
        );
    expect(resolve(null).allPinned, isFalse);
    expect(
      resolve(<DiaryTimelineEntry>[
        entry('a', pinned: true),
        entry('z', pinned: true),
      ]).allPinned,
      isTrue,
    );
    expect(
      resolve(<DiaryTimelineEntry>[
        entry('a', pinned: true),
        entry('z'),
      ]).allPinned,
      isFalse,
    );
  });
}
