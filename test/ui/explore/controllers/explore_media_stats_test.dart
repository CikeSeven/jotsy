import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/explore/controllers/explore_media_stats.dart';

void main() {
  const rows = <DiaryMediaContent>[
    DiaryMediaContent(
      diaryId: 'first',
      cover: '/cover.jpg',
      content:
          '[{"insert":{"image":"/cover.jpg"}},'
          '{"insert":{"image":"/inline.jpg"}}]',
    ),
    DiaryMediaContent(
      diaryId: 'second',
      content:
          '{"root":{"children":[{"type":"image","attributes":{"url":"/inline.jpg"}},'
          '{"type":"image","attributes":{"url":"/other.jpg"}}]}}',
    ),
    DiaryMediaContent(
      diaryId: 'broken',
      cover: '/broken.jpg',
      content: '{broken',
    ),
  ];

  test('recent media deduplicates sources and stops at the display limit', () {
    final recent = ExploreMediaStats.recent(rows, limit: 3);
    expect(recent.map((item) => item.source), <String>[
      '/cover.jpg',
      '/inline.jpg',
      '/other.jpg',
    ]);
    expect(recent.map((item) => item.diaryId), <String>[
      'first',
      'first',
      'second',
    ]);
    expect(ExploreMediaStats.recent(rows, limit: 0), isEmpty);
  });

  test(
    'large recent-media documents are parsed in the background with the same ordering',
    () async {
      final large = <DiaryMediaContent>[
        DiaryMediaContent(
          diaryId: 'large',
          cover: '/cover.jpg',
          content: jsonEncode([
            for (var i = 0; i < 4000; i++)
              {
                'insert': {'image': '/image-$i.jpg'},
              },
          ]),
        ),
      ];
      final recent = await ExploreMediaStats.loadRecent(large, limit: 3);
      expect(recent.map((item) => item.source), [
        '/cover.jpg',
        '/image-0.jpg',
        '/image-1.jpg',
      ]);
      expect(await ExploreMediaStats.loadRecent(const [], limit: 3), isEmpty);
    },
  );

  test(
    'background photo statistics preserve per-diary deduplication and corrupt-body fallback',
    () async {
      expect(await ExploreMediaStats.photoCounts(rows), <String, int>{
        'first': 2,
        'second': 2,
        'broken': 1,
      });
      expect(await ExploreMediaStats.photoCounts(const []), isEmpty);
    },
  );
}
