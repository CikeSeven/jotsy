import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_reading_snapshot.dart';

void main() {
  final created = DateTime(2025, 3, 2, 9, 30);
  final base = Diary(
    id: 7,
    diaryId: 'reading-1',
    title: 'Stored title',
    content: '[]',
    contentText: '',
    metadata: '{}',
    createdAt: created,
    updatedAt: created,
    isArchived: true,
    isPinned: false,
    isDeleted: false,
  );
  const tags = <Tag>[
    Tag(id: 1, name: 'Work', color: 0xFF2196F3),
    Tag(id: 2, name: 'Art', color: 0xFFE91E63),
    Tag(id: 3, name: 'Travel', color: 0xFF4CAF50),
  ];

  DiaryReadingSnapshot build(
    DiaryReadingSnapshotBuilder builder, {
    DiaryMetaDraft meta = const DiaryMetaDraft(),
    String content = '[]',
  }) => builder.build(
    base: base,
    title: 'Draft title',
    contentJson: content,
    contentText: '',
    meta: meta,
    createdAt: created.add(const Duration(hours: 1)),
    updatedAt: created.add(const Duration(days: 1)),
    allTags: tags,
  );

  test(
    'the snapshot carries the draft values and keeps the stored columns',
    () {
      final snapshot = build(
        DiaryReadingSnapshotBuilder(),
        meta: const DiaryMetaDraft(
          moodEmoji: '😊',
          energyLevel: 3,
          location: 'West Lake',
          weather: 'Sunny',
          cover: '  ',
          tagIds: <int>{1, 2},
        ),
      );
      final diary = snapshot.detail.diary;
      expect(diary.diaryId, 'reading-1');
      expect(diary.isArchived, isTrue);
      expect(diary.title, 'Draft title');
      expect(diary.createdAt, created.add(const Duration(hours: 1)));
      // 空白封面按“没有封面”处理（与写库时的规整一致）。
      expect(diary.cover, isNull);
      expect(snapshot.viewData.moodEmoji, '😊');
      expect(snapshot.viewData.energyLevel, 3);
      expect(snapshot.viewData.location, 'West Lake');
      expect(snapshot.viewData.weather, 'Sunny');
      // 标签按名称排序，与库里读出的日记标签同一顺序（首个标签决定配色基调）。
      expect(snapshot.detail.tags.map((tag) => tag.name), <String>[
        'Art',
        'Work',
      ]);
    },
  );

  test(
    'derived data is reused while the draft and the content stay the same',
    () {
      final builder = DiaryReadingSnapshotBuilder();
      const meta = DiaryMetaDraft(moodEmoji: '😊');
      final first = build(builder, meta: meta);
      final again = build(builder, meta: meta);
      expect(identical(first.viewData, again.viewData), isTrue);

      final moodChanged = build(builder, meta: meta.copyWith(moodEmoji: '😢'));
      expect(identical(moodChanged.viewData, again.viewData), isFalse);
      expect(moodChanged.viewData.moodEmoji, '😢');
    },
  );

  test('tags deleted elsewhere are skipped', () {
    expect(
      DiaryReadingSnapshotBuilder.tagsOf(<int>{3, 99}, tags).map((t) => t.id),
      <int>[3],
    );
    expect(DiaryReadingSnapshotBuilder.tagsOf(<int>{}, tags), isEmpty);
  });
}
