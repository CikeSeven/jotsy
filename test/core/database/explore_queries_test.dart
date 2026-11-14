import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 28, 12);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    DateTime? unlockAt,
    List<String>? notebookIds,
    String? cover,
    bool withImage = false,
    DateTime? createdAt,
    List<int> tagIds = const <int>[],
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: withImage
          ? '[{"type":"image","data":{"url":"/img/$title.png"}}]'
          : '[{"insert":"$title\\n"}]',
      contentText: title,
      metadataJson: '{}',
      cover: cover,
      tagIds: tagIds,
      notebookIds: notebookIds,
      createdAtOverride: createdAt ?? now.subtract(const Duration(days: 1)),
      capsuleUnlockAt: unlockAt,
      capsuleLockedAt: unlockAt == null
          ? null
          : now.subtract(const Duration(days: 30)),
    );
  }

  test('locked capsules skip opened, deleted and private ones', () async {
    final hidden = await db.createNotebook(
      name: 'secret',
      visibility: NotebookVisibility.locked,
    );
    await diary('later', unlockAt: now.add(const Duration(days: 40)));
    await diary('soon', unlockAt: now.add(const Duration(days: 2)));
    await diary('opened', unlockAt: now.subtract(const Duration(days: 1)));
    await diary('plain');
    final deleted = await diary(
      'deleted',
      unlockAt: now.add(const Duration(days: 5)),
    );
    await db.softDeleteDiary(deleted);
    await diary(
      'private',
      unlockAt: now.add(const Duration(days: 3)),
      notebookIds: <String>[hidden],
    );

    final capsules = await db.watchLockedCapsules(now: now).first;
    expect(capsules.map((capsule) => capsule.title), <String>['soon', 'later']);
    expect(capsules.first.unlockAt, now.add(const Duration(days: 2)));
    expect(capsules.first.lockedAt, isNotNull);
  });

  test(
    'overviews return one row per diary with complete tags and stable update ordering',
    () async {
      final firstTag = await db.createTag(name: 'first', color: 1);
      final secondTag = await db.createTag(name: 'second', color: 2);
      final tagged = await diary('tagged', tagIds: [firstTag, secondTag]);
      await db.archiveDiary(tagged);
      final plain = await diary('plain');
      await db.customStatement('UPDATE diaries SET updated_at = ?', [
        now.millisecondsSinceEpoch ~/ 1000,
      ]);
      final rows = await db.watchExploreDiaryOverviews().first;
      expect(rows.map((row) => row.diaryId), [plain, tagged]);
      expect(rows.first.tags, isEmpty);
      expect(
        rows.last.tags.map((tag) => tag.id),
        unorderedEquals([firstTag, secondTag]),
      );
      final unarchived = await db
          .watchExploreDiaryOverviews(includeArchived: false)
          .first;
      expect(unarchived.map((row) => row.diaryId), [plain]);
    },
  );

  test('recent media keeps the newest image diaries up to the limit', () async {
    final hidden = await db.createNotebook(
      name: 'secret',
      visibility: NotebookVisibility.hidden,
    );
    for (var i = 0; i < 5; i++) {
      await diary(
        'image-$i',
        withImage: true,
        createdAt: now.subtract(Duration(days: 10 - i)),
      );
    }
    await diary('cover', cover: '/c.png', createdAt: now);
    await diary('text-only', createdAt: now);
    await diary(
      'private',
      withImage: true,
      notebookIds: <String>[hidden],
      createdAt: now,
    );
    await diary(
      'locked',
      withImage: true,
      unlockAt: DateTime.now().add(const Duration(days: 9)),
      createdAt: now,
    );

    final recent = await db.watchRecentMediaContents(limit: 3).first;
    expect(recent, hasLength(3));
    final all = await db.watchRecentMediaContents(limit: 50).first;
    expect(all.map((row) => row.cover), contains('/c.png'));
    expect(all, hasLength(6));
  });
}
