import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_export_scope.dart';

DiaryWithTags _diary(
  String id,
  DateTime createdAt, {
  bool archived = false,
  List<int> tagIds = const <int>[],
}) {
  return DiaryWithTags(
    diary: Diary(
      id: id.hashCode,
      diaryId: id,
      title: id,
      content: '[]',
      contentText: '',
      metadata: '{}',
      createdAt: createdAt,
      updatedAt: createdAt,
      isArchived: archived,
      isPinned: false,
      isDeleted: false,
    ),
    tags: <Tag>[
      for (final tagId in tagIds) Tag(id: tagId, name: 't$tagId', color: 0),
    ],
  );
}

void main() {
  final now = DateTime(2026, 10, 16, 15);
  final diaries = <DiaryWithTags>[
    _diary('old', DateTime(2025, 12, 31, 23, 59), tagIds: <int>[1]),
    _diary('new-year', DateTime(2026, 1, 1)),
    _diary('month-ago', DateTime(2026, 9, 16, 23, 59)),
    _diary('recent', DateTime(2026, 9, 17), archived: true, tagIds: <int>[2]),
    _diary('today', DateTime(2026, 10, 16, 8), tagIds: <int>[1, 2]),
  ];
  List<String> ids(DiaryExportScope scope) => scope
      .apply(diaries, now)
      .map((DiaryWithTags d) => d.diary.diaryId)
      .toList();

  test('date ranges include both ends by local calendar day', () {
    expect(ids(const DiaryExportScope()), hasLength(5));
    expect(
      ids(const DiaryExportScope(range: DiaryExportRange.thisYear)),
      <String>['new-year', 'month-ago', 'recent', 'today'],
    );
    expect(
      ids(const DiaryExportScope(range: DiaryExportRange.last30Days)),
      <String>['recent', 'today'],
    );
    expect(
      ids(
        DiaryExportScope(
          range: DiaryExportRange.custom,
          customRange: DateTimeRange(
            start: DateTime(2025, 12, 31),
            end: DateTime(2026, 1, 1),
          ),
        ),
      ),
      <String>['old', 'new-year'],
    );
  });

  test('any selected tag matches and archived diaries can be left out', () {
    expect(ids(const DiaryExportScope(tagIds: <int>{2})), <String>[
      'recent',
      'today',
    ]);
    expect(
      ids(const DiaryExportScope(tagIds: <int>{1, 2}, includeArchived: false)),
      <String>['old', 'today'],
    );
  });

  test('a custom range that was never picked exports everything', () {
    expect(
      ids(const DiaryExportScope(range: DiaryExportRange.custom)),
      hasLength(5),
    );
  });
}
