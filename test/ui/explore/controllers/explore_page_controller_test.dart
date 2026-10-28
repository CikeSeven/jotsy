import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/ui/explore/controllers/explore_page_controller.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);
  final l10n = AppLocalizationsEn();
  const controller = ExplorePageController();
  ExploreDiaryOverview entry(
    String id,
    List<Tag> tags, {
    DateTime? updated,
    DateTime? created,
    String text = '',
  }) => ExploreDiaryOverview(
    diaryId: id,
    title: id,
    contentText: text,
    metadata: '{}',
    createdAt: created ?? now,
    updatedAt: updated ?? now,
    tags: tags,
  );

  test(
    'tag counts keep custom ordering and the first latest diary on ties',
    () {
      const alpha = Tag(id: 1, name: 'Alpha', color: 11);
      const beta = Tag(id: 2, name: 'Beta', color: 22);
      const gamma = Tag(id: 3, name: 'Gamma', color: 33);
      final latest = now.add(const Duration(hours: 1));
      final tags = controller.buildTagUsages(
        [
          entry('new', [alpha, beta], updated: latest),
          entry('old', [beta, gamma]),
          entry('tie', [beta], updated: latest),
        ],
        orderedTagIds: [3, 2],
      );
      expect(tags.map((tag) => tag.id), [3, 2, 1]);
      expect(tags.map((tag) => tag.count), [1, 3, 1]);
      expect(tags.map((tag) => tag.maxCount), [3, 3, 3]);
      expect(tags[1].latestDiaryId, 'new');
      expect(tags[1].latestAt, latest);
      expect(tags[1].name, 'Beta');
      expect(tags[1].color, 22);
    },
  );

  test('on this day keeps the newest years first within the limit', () {
    final picked = controller.pickOnThisDayList(
      [
        for (var year = 2016; year <= 2025; year++)
          entry('y$year', [], created: DateTime(year, 10, 17, 9)),
        entry('today', [], created: now),
      ],
      now: now,
      l10n: l10n,
      limit: 3,
    );
    expect(picked.map((item) => item.diaryId), ['y2025', 'y2024', 'y2023']);
    expect(picked.first.timeLabel, l10n.exploreOnThisDayYearsAgo(1));
  });
}
