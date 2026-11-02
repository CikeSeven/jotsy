import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 多选日记的批量标签：单事务改写 `diary_tags`、不改 `updatedAt`、撤销后
/// 与原来逐一相等、没有变化时不写库。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<int> tag(String name) => db.createTag(name: name, color: 0xff2196f3);

  Future<String> diary(String title, {List<int> tagIds = const <int>[]}) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
      tagIds: tagIds,
      createdAtOverride: DateTime(2024, 1, 1, 8),
    );
  }

  Future<Map<String, Set<int>>> tagsOf(List<String> ids) =>
      db.getTagIdsForDiaries(ids);

  Future<Map<String, DateTime>> updatedAtOf(List<String> ids) async {
    final rows = await (db.select(
      db.diaries,
    )..where((Diaries d) => d.diaryId.isIn(ids))).get();
    return <String, DateTime>{
      for (final row in rows) row.diaryId: row.updatedAt,
    };
  }

  test('adds and removes tags across several diaries at once', () async {
    final travel = await tag('旅行');
    final food = await tag('美食');
    final work = await tag('工作');
    final a = await diary('京都', tagIds: <int>[travel, work]);
    final b = await diary('大阪', tagIds: <int>[food]);
    final c = await diary('东京');

    final undo = await db.applyDiaryTagBatch(
      <String>[a, b, c],
      add: <int>{travel},
      remove: <int>{work},
    );

    expect(await tagsOf(<String>[a, b, c]), <String, Set<int>>{
      a: <int>{travel},
      b: <int>{food, travel},
      c: <int>{travel},
    });
    // 撤销信息只记真正改动过的日记，标签按原样升序记下。
    expect(undo.before, <String, List<int>>{
      a: <int>[travel, work]..sort(),
      b: <int>[food],
      c: <int>[],
    });
    expect(undo.add, <int>{travel});
    expect(undo.remove, <int>{work});
    // 去掉只删关联，标签本身还在。
    expect((await db.select(db.tags).get()).map((Tag t) => t.id).toSet(), <int>{
      travel,
      food,
      work,
    });
  });

  test('leaves updatedAt untouched for every diary', () async {
    final travel = await tag('旅行');
    final a = await diary('京都');
    final b = await diary('大阪', tagIds: <int>[travel]);
    final before = await updatedAtOf(<String>[a, b]);

    final undo = await db.applyDiaryTagBatch(
      <String>[a, b],
      add: <int>{travel},
    );
    expect(await updatedAtOf(<String>[a, b]), before);

    await db.restoreDiaryTagBatch(undo);
    expect(await updatedAtOf(<String>[a, b]), before);
  });

  test('undo restores every diary exactly as it was', () async {
    final travel = await tag('旅行');
    final food = await tag('美食');
    final work = await tag('工作');
    final a = await diary('京都', tagIds: <int>[travel, work]);
    final b = await diary('大阪', tagIds: <int>[food]);
    final c = await diary('东京');
    final ids = <String>[a, b, c];
    final original = await tagsOf(ids);

    final undo = await db.applyDiaryTagBatch(
      ids,
      add: <int>{food},
      remove: <int>{travel, work},
    );
    expect(await tagsOf(ids), isNot(original));

    await db.restoreDiaryTagBatch(undo);
    expect(await tagsOf(ids), original);
  });

  test('undo keeps changes made meanwhile to other tags', () async {
    final travel = await tag('旅行');
    final food = await tag('美食');
    final a = await diary('京都');

    final undo = await db.applyDiaryTagBatch(<String>[a], add: <int>{travel});
    // 撤销窗口里别处给它加了另一个标签：撤销只收回这次加上的。
    await db.applyDiaryTagBatch(<String>[a], add: <int>{food});
    await db.restoreDiaryTagBatch(undo);

    expect((await tagsOf(<String>[a]))[a], <int>{food});
  });

  test('no change writes nothing', () async {
    final travel = await tag('旅行');
    final work = await tag('工作');
    final a = await diary('京都', tagIds: <int>[travel]);
    final b = await diary('大阪', tagIds: <int>[travel]);

    var updates = 0;
    final subscription = db
        .tableUpdates(TableUpdateQuery.onTable(db.diaryTags))
        .listen((_) => updates++);
    addTearDown(subscription.cancel);

    // 都已有要加的、都没有要去掉的：不写库。
    final undo = await db.applyDiaryTagBatch(
      <String>[a, b],
      add: <int>{travel},
      remove: <int>{work},
    );
    // 空集合同样直接返回。
    final empty = await db.applyDiaryTagBatch(<String>[a, b]);
    await db.restoreDiaryTagBatch(undo);
    await pumpEventQueue();

    expect(undo.isEmpty, isTrue);
    expect(empty.isEmpty, isTrue);
    expect(updates, 0);
  });

  test(
    'skips tags deleted before the write and does not restore them',
    () async {
      final travel = await tag('旅行');
      final gone = await tag('已删除');
      final a = await diary('京都', tagIds: <int>[travel]);

      await db.deleteTag(gone);
      final undo = await db.applyDiaryTagBatch(
        <String>[a],
        add: <int>{gone},
        remove: <int>{travel},
      );
      expect((await tagsOf(<String>[a]))[a], isEmpty);

      await db.deleteTag(travel);
      await db.restoreDiaryTagBatch(undo);
      // 撤销时“旅行”已被删掉：不放回悬空的关联。
      expect((await tagsOf(<String>[a]))[a], isEmpty);
      expect(await db.select(db.diaryTags).get(), isEmpty);
    },
  );

  test('rejects a tag that is both added and removed', () async {
    final travel = await tag('旅行');
    final a = await diary('京都');
    await expectLater(
      db.applyDiaryTagBatch(
        <String>[a],
        add: <int>{travel},
        remove: <int>{travel},
      ),
      throwsArgumentError,
    );
  });

  test('the diary list stream refreshes after a tag-only change', () async {
    final travel = await tag('旅行');
    final a = await diary('京都');

    final pages = StreamIterator<List<DiaryWithTags>>(
      db.watchDiaries(limit: 20),
    );
    addTearDown(pages.cancel);
    expect(await pages.moveNext(), isTrue);
    expect(pages.current.single.tags, isEmpty);

    await db.applyDiaryTagBatch(<String>[a], add: <int>{travel});
    expect(await pages.moveNext(), isTrue);
    expect(pages.current.single.tags.map((Tag t) => t.id), <int>[travel]);
  });
}
