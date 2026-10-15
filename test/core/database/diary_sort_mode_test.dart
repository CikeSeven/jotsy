import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 日记列表排序：枚举组合关系 + `watchDiaries` 的 SQL 排序口径。
///
/// drift 默认以秒存储 DateTime，测试时间戳之间至少相差 1 秒。
void main() {
  group('DiarySortMode', () {
    test('every field and direction maps to exactly one mode', () {
      for (final field in DiarySortField.values) {
        for (final direction in DiarySortDirection.values) {
          final mode = DiarySortMode.of(field, direction);
          expect(mode.field, field);
          expect(mode.direction, direction);
        }
      }
      expect(
        DiarySortMode.values.length,
        DiarySortField.values.length * DiarySortDirection.values.length,
      );
    });

    test('switching the field keeps the direction and vice versa', () {
      expect(
        DiarySortMode.updatedDesc.withField(DiarySortField.createdAt),
        DiarySortMode.createdDesc,
      );
      expect(
        DiarySortMode.titleAsc.withField(DiarySortField.createdAt),
        DiarySortMode.createdAsc,
      );
      expect(
        DiarySortMode.createdDesc.withDirection(DiarySortDirection.ascending),
        DiarySortMode.createdAsc,
      );
      expect(
        DiarySortMode.titleAsc.withDirection(DiarySortDirection.descending),
        DiarySortMode.titleDesc,
      );
    });

    test('names stored by earlier versions still exist', () {
      // 枚举名即持久化值，旧版本只写过这三种。
      expect(
        DiarySortMode.values.asNameMap().keys,
        containsAll(<String>['updatedDesc', 'updatedAsc', 'titleAsc']),
      );
    });
  });

  group('watchDiaries ordering', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> insert(
      String diaryId, {
      String title = '',
      required DateTime createdAt,
      required DateTime updatedAt,
      bool pinned = false,
    }) {
      return db
          .into(db.diaries)
          .insert(
            DiariesCompanion.insert(
              diaryId: diaryId,
              title: Value<String>(title),
              content: '[{"insert":"body\\n"}]',
              contentText: 'body',
              createdAt: createdAt,
              updatedAt: updatedAt,
              isPinned: Value<bool>(pinned),
            ),
          );
    }

    Future<List<String>> idsFor(DiarySortMode mode, {int? limit}) async {
      final rows = await db.watchDiaries(sortMode: mode, limit: limit).first;
      return rows.map((DiaryWithTags row) => row.diary.diaryId).toList();
    }

    test('publish time orders by created_at regardless of edits', () async {
      // 发表与更新的先后顺序刻意不同，确保两种排序互不串味。
      await insert(
        'a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      await insert(
        'b',
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 3, 1),
      );
      await insert(
        'c',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 2),
      );
      await insert(
        'pinned',
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
        pinned: true,
      );

      expect(await idsFor(DiarySortMode.createdDesc), <String>[
        'pinned',
        'c',
        'b',
        'a',
      ]);
      expect(await idsFor(DiarySortMode.createdAsc), <String>[
        'pinned',
        'a',
        'b',
        'c',
      ]);
      expect(await idsFor(DiarySortMode.updatedDesc), <String>[
        'pinned',
        'a',
        'c',
        'b',
      ]);
      expect(await idsFor(DiarySortMode.updatedAsc), <String>[
        'pinned',
        'b',
        'c',
        'a',
      ]);
    });

    test(
      'equal timestamps keep a stable order across paging windows',
      () async {
        final sameTime = DateTime(2026, 6, 1, 8);
        for (final id in <String>['x', 'y', 'z']) {
          await insert(id, createdAt: sameTime, updatedAt: sameTime);
        }

        final descending = await idsFor(DiarySortMode.createdDesc);
        expect(descending, <String>['z', 'y', 'x']);
        expect(await idsFor(DiarySortMode.createdAsc), <String>['x', 'y', 'z']);
        // 加载更多是扩大 LIMIT 重新查询：小窗口必须是大窗口的前缀，卡片不换位。
        expect(
          await idsFor(DiarySortMode.createdDesc, limit: 2),
          descending.take(2).toList(),
        );
      },
    );

    test(
      'title order ignores case and padding, untitled always last',
      () async {
        Future<void> titled(String id, String title, int minute) => insert(
          id,
          title: title,
          createdAt: DateTime(2026, 7, 1, 9, minute),
          updatedAt: DateTime(2026, 7, 1, 9, minute),
        );
        await titled('banana', 'banana', 1);
        await titled('apple-old', 'Apple', 2);
        await titled('cherry', '  cherry', 3);
        await titled('empty', '', 4);
        await titled('blank', '   ', 5);
        await titled('apple-new', 'apple', 6);

        // 同名（忽略大小写）时最近更新的在前；无标题的正/倒序都排在最后。
        expect(await idsFor(DiarySortMode.titleAsc), <String>[
          'apple-new',
          'apple-old',
          'banana',
          'cherry',
          'blank',
          'empty',
        ]);
        expect(await idsFor(DiarySortMode.titleDesc), <String>[
          'cherry',
          'banana',
          'apple-new',
          'apple-old',
          'blank',
          'empty',
        ]);
      },
    );
  });
}
