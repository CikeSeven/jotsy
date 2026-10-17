import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late _QueryPlans plans;
  final at = DateTime(2026, 1, 1);

  setUp(() async {
    plans = _QueryPlans();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(plans));
    await db.batch((batch) {
      batch.insertAll(db.tags, [
        for (var id = 1; id <= 3; id++)
          TagsCompanion.insert(id: Value(id), name: 'tag-$id', color: id),
      ]);
      batch.insertAll(db.diaries, [
        for (var id = 1; id <= 80; id++)
          DiariesCompanion.insert(
            id: Value(id),
            diaryId: 'entry-$id',
            title: Value(id % 13 == 0 ? '  ' : 'Entry ${id % 7}'),
            content: '[{"insert":"body-$id\\n"}]',
            contentText: id % 3 == 0 ? 'needle $id' : 'body $id',
            createdAt: at.add(Duration(days: id % 9)),
            updatedAt: at.add(Duration(minutes: id % 11)),
            isPinned: Value(id % 9 == 0),
            isArchived: Value(id % 7 == 0),
            isDeleted: Value(id % 11 == 0),
            capsuleUnlockAt: id % 10 == 0
                ? Value(DateTime.now().add(const Duration(days: 365)))
                : const Value.absent(),
          ),
      ]);
      batch.insertAll(db.diaryTags, [
        for (var id = 1; id <= 80; id++) ...[
          DiaryTagsCompanion.insert(diaryId: id, tagId: 1),
          if (id.isEven) DiaryTagsCompanion.insert(diaryId: id, tagId: 2),
          if (id % 3 == 0) DiaryTagsCompanion.insert(diaryId: id, tagId: 3),
        ],
      ]);
    });
  });
  tearDown(() => db.close());

  test(
    'every sorted and filtered page matches the complete sequence',
    () async {
      for (final mode in DiarySortMode.values) {
        for (final (keyword, tagIds) in <(String, List<int>)>[
          ('', []),
          ('  needle  ', []),
          ('', [2, 1, 2]),
          ('needle', [1, 3]),
          ('Entry', [2]),
        ]) {
          final all = await db
              .watchDiaries(
                keyword: keyword,
                requiredTagIds: tagIds,
                sortMode: mode,
              )
              .first;
          final ids = await db.getActiveDiaryIds(
            keyword: keyword,
            requiredTagIds: tagIds,
            sortMode: mode,
          );
          expect(ids, all.map((row) => row.diary.diaryId));
          final paged = <DiaryWithTags>[];
          for (var offset = 0; offset < all.length + 5; offset += 5) {
            paged.addAll(
              await db
                  .watchDiaries(
                    keyword: keyword,
                    requiredTagIds: tagIds,
                    sortMode: mode,
                    limit: 5,
                    offset: offset,
                  )
                  .first,
            );
          }
          expect(paged.map((row) => row.diary), all.map((row) => row.diary));
          for (var i = 0; i < all.length; i++) {
            // 标签过滤只缩小日记候选，不能使返回项丢失未参与过滤的其他标签。
            expect(paged[i].tags, all[i].tags);
            expect(paged[i].diary.isDeleted, isFalse);
            expect(paged[i].diary.isArchived, isFalse);
            expect(
              paged[i].tags.map((tag) => tag.id),
              containsAll(tagIds.toSet()),
            );
          }
          if (keyword.trim() == 'needle') {
            expect(
              all.every((row) => row.diary.capsuleUnlockAt == null),
              isTrue,
            );
            expect(
              all.every((row) => row.diary.contentText.contains('needle')),
              isTrue,
            );
          }
        }
      }
    },
  );

  test(
    'empty and negative windows keep the original boundary behavior',
    () async {
      expect(await db.watchDiaries(limit: 0).first, isEmpty);
      expect(await db.watchDiaries(limit: -1).first, isEmpty);
      expect(await db.watchDiaries(limit: 5, offset: 1000).first, isEmpty);
      final first = await db.watchDiaries(limit: 5).first;
      final negativeOffset = await db.watchDiaries(limit: 5, offset: -5).first;
      expect(
        negativeOffset.map((row) => row.diary),
        first.map((row) => row.diary),
      );
      final blank = await db.watchDiaries(limit: 5, keyword: '  ').first;
      expect(blank.map((row) => row.diary), first.map((row) => row.diary));
      expect(
        await db.watchDiaries(limit: 5, requiredTagIds: [999]).first,
        isEmpty,
      );
    },
  );

  test('common time orders read the matching partial indexes', () async {
    for (final (mode, index) in [
      (DiarySortMode.updatedDesc, 'idx_diaries_active_updated'),
      (DiarySortMode.createdDesc, 'idx_diaries_active_created'),
    ]) {
      await db.watchDiaries(limit: 5, sortMode: mode).first;
      expect(
        plans.last.any((detail) => detail.contains(index)),
        isTrue,
        reason: plans.last.join('\n'),
      );
    }
  });

  test(
    'paged subscriptions still react to tag edits and diary removal',
    () async {
      final iterator = StreamIterator(
        db.watchDiaries(limit: 2, requiredTagIds: [2]),
      );
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      final removed = iterator.current.first.diary.diaryId;

      await db.updateTag(tagId: 2, name: 'renamed', color: 99);
      expect(await iterator.moveNext(), isTrue);
      expect(
        iterator.current.first.tags.singleWhere((tag) => tag.id == 2).name,
        'renamed',
      );
      expect(
        iterator.current.first.tags.singleWhere((tag) => tag.id == 2).color,
        99,
      );

      await db.softDeleteDiary(removed);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, hasLength(2));
      expect(
        iterator.current.map((row) => row.diary.diaryId),
        isNot(contains(removed)),
      );
    },
  );
}

/// 记录真实查询的执行计划，不以易受机器负载影响的耗时作为测试断言。
class _QueryPlans extends QueryInterceptor {
  List<String> last = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.startsWith('WITH diary_page AS')) {
      final plan = await executor.runSelect(
        'EXPLAIN QUERY PLAN $statement',
        args,
      );
      last = [for (final row in plan) row['detail'] as String];
    }
    return executor.runSelect(statement, args);
  }
}
