import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// AI 助手用到的几个数据库操作：带快照的删除 / 合并标签与撤销（覆盖回收站
/// 里的日记），以及只改信息、不碰归档与删除标记的 patchDiaryFields。
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(String title, List<int> tagIds) => db.createDiary(
    title: title,
    contentDocJson: '',
    contentText: title,
    metadataJson: '{}',
    tagIds: tagIds,
  );

  Future<Set<String>> tagNamesOf(String diaryId) async =>
      (await db.getDiaryWithTagsByDiaryId(
        diaryId,
      ))!.tags.map((tag) => tag.name).toSet();

  test(
    'deleting with a snapshot can be undone, including trashed entries',
    () async {
      final travel = await db.createTag(name: '旅行', color: 1);
      final kept = await diary('a', [travel]);
      final trashed = await diary('b', [travel]);
      await db.softDeleteDiary(trashed);

      final deletion = (await db.deleteTagWithSnapshot(travel))!;
      expect(deletion.diaryIds, hasLength(2));
      expect(await db.watchAllTags().first, isEmpty);

      // 经 JSON 往返（撤销数据存在步骤记录里）。
      await db.restoreTagDeletion(TagDeletion.fromJson(deletion.toJson()));
      final tags = await db.watchAllTags().first;
      expect(tags.single.id, travel);
      expect(tags.single.color, 1);
      expect(await tagNamesOf(kept), {'旅行'});
      expect(await tagNamesOf(trashed), {'旅行'});
    },
  );

  test('restoring refuses when the name was taken again', () async {
    final travel = await db.createTag(name: '旅行', color: 1);
    final deletion = (await db.deleteTagWithSnapshot(travel))!;
    await db.createTag(name: '旅行', color: 2);
    expect(() => db.restoreTagDeletion(deletion), throwsStateError);
  });

  test('merging moves entries to the target and undo puts it back', () async {
    final trip = await db.createTag(name: '出行', color: 1);
    final travel = await db.createTag(name: '旅行', color: 2);
    final onlyTrip = await diary('a', [trip]);
    final both = await diary('b', [trip, travel]);
    final onlyTravel = await diary('c', [travel]);

    final merge = await db.mergeTags([trip], travel);
    expect(await tagNamesOf(onlyTrip), {'旅行'});
    expect(await tagNamesOf(both), {'旅行'});
    expect((await db.watchAllTags().first).map((t) => t.name), ['旅行']);
    // 本来就有目标标签的日记不算新挂上的。
    expect(merge.addedTargetDiaryIds, hasLength(1));

    await db.restoreTagMerge(TagMerge.fromJson(merge.toJson()));
    expect(await tagNamesOf(onlyTrip), {'出行'});
    expect(await tagNamesOf(both), {'出行', '旅行'});
    expect(await tagNamesOf(onlyTravel), {'旅行'});
  });

  test('batch tag undo survives a JSON round trip', () async {
    final a = await db.createTag(name: 'a', color: 1);
    final b = await db.createTag(name: 'b', color: 1);
    final id = await diary('x', [a]);
    final undo = await db.applyDiaryTagBatch([id], add: {b}, remove: {a});
    expect(await tagNamesOf(id), {'b'});
    await db.restoreDiaryTagBatch(DiaryTagBatchUndo.fromJson(undo.toJson()));
    expect(await tagNamesOf(id), {'a'});
  });

  test('patchDiaryFields keeps archive state, tags and body', () async {
    final tag = await db.createTag(name: 't', color: 1);
    final id = await diary('旧标题', [tag]);
    await db.archiveDiary(id);
    final updatedAt = await db.patchDiaryFields(
      diaryId: id,
      title: '  新标题 ',
      createdAt: DateTime(2026, 1, 2, 3, 4),
    );
    final row = (await db.getDiaryWithTagsByDiaryId(id))!;
    expect(row.diary.title, '新标题');
    expect(row.diary.createdAt, DateTime(2026, 1, 2, 3, 4));
    expect(row.diary.isArchived, isTrue);
    expect(row.diary.contentText, '旧标题');
    expect(row.tags.single.name, 't');
    expect(row.diary.updatedAt, updatedAt);
    expect(await db.patchDiaryFields(diaryId: 'missing', title: 'x'), isNull);
  });
}
