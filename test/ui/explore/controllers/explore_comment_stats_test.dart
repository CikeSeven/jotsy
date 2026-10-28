import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/explore/controllers/explore_comment_stats.dart';

void main() {
  DiaryCommentTiming timing(
    String diaryId,
    DateTime diaryCreatedAt,
    DateTime commentCreatedAt,
  ) => DiaryCommentTiming(
    diaryId: diaryId,
    createdAt: commentCreatedAt,
    diaryCreatedAt: diaryCreatedAt,
  );

  group('ExploreCommentStats.of', () {
    test('no comments gives zero counts and no average gap', () {
      final stats = ExploreCommentStats.of(const <DiaryCommentTiming>[]);
      expect(stats, ExploreCommentStats.empty);
      expect(stats.total, 0);
      expect(stats.diaryCount, 0);
      expect(stats.averageGapDays, isNull);
    });

    test('counts comments and the distinct diaries they answer', () {
      final a = DateTime(2026, 1, 1, 10);
      final b = DateTime(2026, 2, 1, 23);
      final stats = ExploreCommentStats.of(<DiaryCommentTiming>[
        // 3 天
        timing('a', a, DateTime(2026, 1, 4, 9)),
        // 10 天
        timing('a', a, DateTime(2026, 1, 11, 20)),
        // 只隔两小时，但已是第二天：按日历日算 1 天
        timing('b', b, DateTime(2026, 2, 2, 1)),
      ]);
      expect(stats.total, 3);
      expect(stats.diaryCount, 2);
      // (3 + 10 + 1) / 3 = 4.67 → 5
      expect(stats.averageGapDays, 5);
    });

    test('rounds the average gap to the nearest day', () {
      final day = DateTime(2026, 3, 1, 8);
      // (1 + 2) / 2 = 1.5 → 2
      expect(
        ExploreCommentStats.of(<DiaryCommentTiming>[
          timing('a', day, DateTime(2026, 3, 2, 8)),
          timing('b', day, DateTime(2026, 3, 3, 8)),
        ]).averageGapDays,
        2,
      );
      // (1 + 1 + 2) / 3 = 1.33 → 1
      expect(
        ExploreCommentStats.of(<DiaryCommentTiming>[
          timing('a', day, DateTime(2026, 3, 2, 8)),
          timing('b', day, DateTime(2026, 3, 2, 22)),
          timing('c', day, DateTime(2026, 3, 3, 8)),
        ]).averageGapDays,
        1,
      );
    });

    test('same-day and earlier-than-diary comments count as zero days', () {
      final day = DateTime(2026, 5, 10, 9);
      final stats = ExploreCommentStats.of(<DiaryCommentTiming>[
        timing('a', day, DateTime(2026, 5, 10, 23)),
        // 日记的时间被改到了留言之后
        timing('b', DateTime(2026, 6, 1), DateTime(2026, 5, 20)),
      ]);
      expect(stats.total, 2);
      expect(stats.diaryCount, 2);
      expect(stats.averageGapDays, 0);
    });
  });
}
