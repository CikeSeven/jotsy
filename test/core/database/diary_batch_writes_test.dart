import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 首页多选（含全选）的批量置顶、归档、删除与撤销：一个事务写完、分批
/// 绑定 id（超过 500 篇也不触到 SQLite 的变量上限），不改更新时间。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> seed(int count) async {
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      ids.add(
        await db.createDiary(
          title: '日记 $i',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        ),
      );
    }
    return ids;
  }

  Future<Diary> row(String id) async =>
      (await db.getDiaryWithTagsByDiaryId(id))!.diary;

  test('archives and unarchives more than one chunk of diaries at once '
      'without touching updatedAt', () async {
    final ids = await seed(620);
    final before = await row(ids.last);

    await db.setDiariesArchived(ids, archived: true);
    expect(await db.getActiveDiaryIds(), isEmpty);
    final archived = await row(ids.last);
    expect(archived.isArchived, isTrue);
    expect(archived.archivedAt, isNotNull);
    expect(archived.updatedAt, before.updatedAt);

    await db.setDiariesArchived(ids, archived: false);
    expect((await db.getActiveDiaryIds()).toSet(), ids.toSet());
    expect((await row(ids.first)).archivedAt, isNull);
  });

  test(
    'soft deletes clear the archive flag and restore brings them back',
    () async {
      final ids = await seed(3);
      await db.setDiariesArchived(<String>[ids.first], archived: true);

      await db.softDeleteDiaries(ids);
      final deleted = await row(ids.first);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.isArchived, isFalse);
      expect(await db.getActiveDiaryIds(), isEmpty);

      await db.restoreDiaries(ids);
      expect((await db.getActiveDiaryIds()).toSet(), ids.toSet());
      expect((await row(ids.first)).deletedAt, isNull);
    },
  );

  test('pins only the given diaries and ignores an empty list', () async {
    final ids = await seed(3);
    await db.setDiariesPinned(const <String>[], pinned: true);
    await db.setDiariesPinned(ids.take(2), pinned: true);
    expect(
      <bool>[for (final id in ids) (await row(id)).isPinned],
      <bool>[true, true, false],
    );
    await db.setDiariesPinned(ids, pinned: false);
    expect(
      <bool>[for (final id in ids) (await row(id)).isPinned],
      <bool>[false, false, false],
    );
  });
}
