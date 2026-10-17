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
    'record totals, streak gaps and current-month word counts stay unchanged',
    () {
      final data = controller.buildViewData(
        [
          entry('stats-today', [], text: '一二'),
          entry(
            'stats-yesterday',
            [],
            created: DateTime(2026, 10, 16, 23),
            text: 'hello world',
          ),
          entry('stats-gap', [], created: DateTime(2026, 10, 14), text: '字'),
          entry(
            'stats-last-month',
            [],
            created: DateTime(2026, 9, 30),
            text: '忽略上月',
          ),
        ],
        now: now,
        l10n: l10n,
      );
      expect(data.stats.totalRecords, 4);
      expect(data.stats.streakDays, 2);
      expect(data.stats.currentMonthWords, 5);
    },
  );

  test(
    'tag counts keep custom ordering and the first latest diary on ties',
    () {
      const alpha = Tag(id: 1, name: 'Alpha', color: 11);
      const beta = Tag(id: 2, name: 'Beta', color: 22);
      const gamma = Tag(id: 3, name: 'Gamma', color: 33);
      final latest = now.add(const Duration(hours: 1));
      final data = controller.buildViewData(
        [
          entry('new', [alpha, beta], updated: latest),
          entry('old', [beta, gamma]),
          entry('tie', [beta], updated: latest),
        ],
        now: now,
        l10n: l10n,
        orderedTagIds: [3, 2],
      );
      final tags = data.tagUsages;
      expect(tags.map((tag) => tag.id), [3, 2, 1]);
      expect(tags.map((tag) => tag.count), [1, 3, 1]);
      expect(tags.map((tag) => tag.maxCount), [3, 3, 3]);
      expect(tags[1].latestDiaryId, 'new');
      expect(tags[1].latestAt, latest);
      expect(tags[1].name, 'Beta');
      expect(tags[1].color, 22);
    },
  );

  test(
    'visible tags keep the global maximum when the largest tag is hidden',
    () {
      final tags = [
        for (var id = 1; id <= 22; id++)
          Tag(id: id, name: 'tag-${id.toString().padLeft(2, '0')}', color: id),
      ];
      final data = controller.buildViewData(
        [
          entry('all-tags', tags),
          entry('hidden-a', [tags.last]),
          entry('hidden-b', [tags.last]),
        ],
        now: now,
        l10n: l10n,
      );
      expect(data.tagUsages, hasLength(18));
      expect(data.tagUsages.map((tag) => tag.count), everyElement(1));
      expect(data.tagUsages.map((tag) => tag.maxCount), everyElement(3));
    },
  );

  test('empty libraries keep the existing empty presentation data', () {
    final data = controller.buildViewData([], now: now, l10n: l10n);
    expect(data.stats.totalRecords, 0);
    expect(data.stats.currentMonthWords, 0);
    expect(data.stats.streakDays, 0);
    expect(data.onThisDayDiaries, isEmpty);
    expect(data.tagUsages, isEmpty);
    expect(data.mediaItems, isEmpty);
    expect(data.moodWeights30, everyElement(isNull));
    expect(data.energyValues7, everyElement(isNull));
    expect(data.fallbackPrompt, isNotEmpty);
  });
}
