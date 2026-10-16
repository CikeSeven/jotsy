import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 日历打点与照片候选查询：轻量字段的取值口径。
///
/// drift 默认以秒存储 DateTime，测试时间戳之间至少相差 1 秒。
void main() {
  late AppDatabase db;
  final monthStart = DateTime(2026, 3);
  final nextMonthStart = DateTime(2026, 4);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> insert(
    String diaryId, {
    required DateTime createdAt,
    String contentText = 'body',
    String content = '[{"insert":"body\\n"}]',
    String metadata = '{}',
    String? cover,
    DateTime? capsuleUnlockAt,
    bool deleted = false,
  }) {
    return db
        .into(db.diaries)
        .insert(
          DiariesCompanion.insert(
            diaryId: diaryId,
            content: content,
            contentText: contentText,
            metadata: Value<String>(metadata),
            cover: Value<String?>(cover),
            createdAt: createdAt,
            updatedAt: createdAt,
            capsuleUnlockAt: Value<DateTime?>(capsuleUnlockAt),
            capsuleLockedAt: Value<DateTime?>(
              capsuleUnlockAt == null ? null : createdAt,
            ),
            isDeleted: Value<bool>(deleted),
          ),
        );
  }

  Future<void> tag(int diaryRowId, int tagId) {
    return db
        .into(db.diaryTags)
        .insert(DiaryTagsCompanion.insert(diaryId: diaryRowId, tagId: tagId));
  }

  test('markers carry the scalar fields each cell style needs', () async {
    final rowId = await insert(
      'a',
      createdAt: DateTime(2026, 3, 5, 9),
      contentText: '  hello world\n',
      metadata:
          '{"context":{"moodEmoji":" 😊 ","weather":"晴","weatherIconCode":"100"}}',
      cover: '/covers/a.jpg',
    );
    final red = await db.createTag(name: 'red', color: 0xFFFF0000);
    final blue = await db.createTag(name: 'blue', color: 0xFF0000FF);
    await tag(rowId, blue);
    await tag(rowId, red);
    await insert(
      'plain',
      createdAt: DateTime(2026, 3, 6, 9),
      contentText: '今天很好，去了海边。',
    );
    await insert('deleted', createdAt: DateTime(2026, 3, 7), deleted: true);
    await insert('next-month', createdAt: DateTime(2026, 4, 1));

    final markers = await db
        .watchDiaryMarkersInRange(monthStart, nextMonthStart)
        .first;

    expect(markers.map((m) => m.diaryId), <String>['a', 'plain']);
    final first = markers.first;
    expect(first.moodEmoji, '😊');
    // 字数按 TextStats 口径：英文按词计。
    expect(first.wordCount, 2);
    expect(first.cover, '/covers/a.jpg');
    expect(first.weather, '晴');
    expect(first.weatherIconCode, '100');
    // diary_tags 主键顺序：标签 id 升序，与挂标签的先后无关。
    expect(first.tagColors, <int>[0xFFFF0000, 0xFF0000FF]);
    expect(first.tagIds, <int>[red, blue]..sort());
    final plain = markers.last;
    // 汉字与全角标点各算 1 字。
    expect(plain.wordCount, 10);
    expect(plain.moodEmoji, isNull);
    expect(plain.cover, isNull);
    expect(plain.tagColors, isEmpty);
    expect(plain.tagIds, isEmpty);
  });

  test('locked capsules are reported until they unlock', () async {
    final unlockAt = DateTime(2026, 3, 20, 8);
    await insert('capsule', createdAt: unlockAt, capsuleUnlockAt: unlockAt);

    final marker =
        (await db.watchDiaryMarkersInRange(monthStart, nextMonthStart).first)
            .single;

    expect(marker.isLockedCapsuleAt(DateTime(2026, 3, 19)), isTrue);
    expect(marker.isLockedCapsuleAt(DateTime(2026, 3, 20, 8)), isFalse);
  });

  test('marker stream refreshes when a tag is attached', () async {
    final rowId = await insert('a', createdAt: DateTime(2026, 3, 5));
    final colorTag = await db.createTag(name: 'green', color: 0xFF00FF00);
    final emissions = db
        .watchDiaryMarkersInRange(monthStart, nextMonthStart)
        .map((markers) => markers.single.tagColors)
        .take(2)
        .toList();

    await Future<void>.delayed(Duration.zero);
    await tag(rowId, colorTag);

    expect(await emissions, <List<int>>[
      <int>[],
      <int>[0xFF00FF00],
    ]);
  });

  test('image candidates skip explicit covers and text-only diaries', () async {
    await insert(
      'inline',
      createdAt: DateTime(2026, 3, 5),
      content: '[{"insert":{"image":"/img/1.jpg"}},{"insert":"\\n"}]',
    );
    await insert(
      'covered',
      createdAt: DateTime(2026, 3, 6),
      cover: '/covers/b.jpg',
      content: '[{"insert":{"image":"/img/2.jpg"}},{"insert":"\\n"}]',
    );
    await insert('text', createdAt: DateTime(2026, 3, 7));

    final candidates = await db
        .watchDiaryImageCandidatesInRange(monthStart, nextMonthStart)
        .first;

    expect(candidates.map((c) => c.diaryId), <String>['inline']);
  });

  test('range query returns diaries from any range, newest first', () async {
    await insert('y2024', createdAt: DateTime(2024, 3, 12, 9));
    await insert('y2025', createdAt: DateTime(2025, 3, 12, 21));
    await insert('other-day', createdAt: DateTime(2025, 3, 13, 9));
    await insert('gone', createdAt: DateTime(2023, 3, 12), deleted: true);

    final diaries = await db.watchDiariesCreatedInRanges(<(DateTime, DateTime)>[
      (DateTime(2023, 3, 12), DateTime(2023, 3, 13)),
      (DateTime(2024, 3, 12), DateTime(2024, 3, 13)),
      (DateTime(2025, 3, 12), DateTime(2025, 3, 13)),
    ]).first;

    expect(diaries.map((d) => d.diary.diaryId), <String>['y2025', 'y2024']);
    expect(await db.watchDiariesCreatedInRanges(const []).first, isEmpty);
  });
}
