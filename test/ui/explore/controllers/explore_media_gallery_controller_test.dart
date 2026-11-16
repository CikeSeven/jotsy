import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/explore/controllers/explore_media_gallery_controller.dart';
import 'package:node_diary/ui/explore/models/explore_media_gallery_filter.dart';

import '../explore_test_fixtures.dart';

void main() {
  const batch = ExploreMediaGalleryController.batchSize;
  late _GalleryDatabase database;
  late ExploreMediaGalleryController controller;

  setUp(() {
    database = _GalleryDatabase();
    controller = ExploreMediaGalleryController(database: database);
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  test('keeps every image of a diary with many images', () async {
    final sources = List.generate(45, (index) => '/image-$index.jpg');
    final row = createExploreTestMediaRow(
      cover: '/cover.jpg',
      content: jsonEncode([
        for (final source in sources)
          {
            'insert': {'image': source},
          },
      ]),
    );
    database.readPage = (_, _) async => [row];

    await controller.loadMore();

    expect(controller.items.map((item) => item.source), [
      '/cover.jpg',
      ...sources,
    ]);
    expect(controller.items.every((item) => item.diaryId == row.diaryId), true);
    expect(controller.hasMore, isFalse);
    expect(controller.hasError, isFalse);
    await controller.loadMore();
    expect(database.offsets, [0]);
  });

  test('one load reads every batch and dedupes across them', () async {
    final firstPage = List.generate(
      batch,
      (index) =>
          createExploreTestMediaRow(id: index, cover: '/image-$index.jpg'),
    );
    database.readPage = (_, offset) async => offset == 0
        ? firstPage
        : [
            createExploreTestMediaRow(
              id: batch + 1,
              cover: '/image-0.jpg',
              content: '[{"insert":{"image":"/later.jpg"}}]',
            ),
          ];
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    await controller.loadMore();

    // 不等滚动到底：一次读完全部批次，首批到了就先通知页面显示。
    expect(database.offsets, [0, batch]);
    expect(controller.items, hasLength(batch + 1));
    expect(controller.items.last.source, '/later.jpg');
    expect(controller.hasMore, isFalse);
    expect(controller.isLoading, isFalse);
    // 开始、首批、结束。
    expect(notifications, 3);
  });

  test('a failed batch keeps earlier batches and retries in place', () async {
    final firstPage = List.generate(
      batch,
      (index) => createExploreTestMediaRow(id: index, cover: '/shared.jpg'),
    );
    database.readPage = (_, offset) async {
      if (offset == 0) return firstPage;
      throw StateError('Database temporarily unavailable');
    };

    await controller.loadMore();

    expect(controller.hasError, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.items.map((item) => item.source), ['/shared.jpg']);
    database.readPage = (_, offset) async => [
      createExploreTestMediaRow(id: batch + 1, cover: '/later.jpg'),
    ];
    await controller.loadMore();

    expect(database.offsets, [0, batch, batch]);
    expect(controller.items.map((item) => item.source), [
      '/shared.jpg',
      '/later.jpg',
    ]);
    expect(controller.hasError, isFalse);
  });

  test('coalesces concurrent load requests', () async {
    final pending = Completer<List<DiaryMediaContent>>();
    database.readPage = (_, _) => pending.future;

    final firstLoad = controller.loadMore();
    await controller.loadMore();
    expect(controller.isLoading, isTrue);
    expect(database.offsets, [0]);
    pending.complete([createExploreTestMediaRow(cover: '/cover.jpg')]);
    await firstLoad;

    expect(controller.items, hasLength(1));
    expect(controller.isLoading, isFalse);
  });

  test(
    'a new filter restarts from the top and drops the in-flight page',
    () async {
      final stale = Completer<List<DiaryMediaContent>>();
      database.readPage = (_, _) => stale.future;
      final staleLoad = controller.loadMore();

      final fresh = Completer<List<DiaryMediaContent>>();
      database.readPage = (_, _) => fresh.future;
      const filter = ExploreMediaGalleryFilter(
        scope: DiaryListScope.unfiled,
        newestFirst: false,
      );
      controller.configure(filter);
      expect(controller.filter, filter);
      expect(controller.isLoading, isTrue);
      expect(database.scopes.last, DiaryListScope.unfiled);
      expect(database.newestFirst.last, isFalse);

      stale.complete([createExploreTestMediaRow(cover: '/old.jpg')]);
      await staleLoad;
      expect(controller.items, isEmpty);
      expect(controller.isLoading, isTrue);

      fresh.complete([createExploreTestMediaRow(id: 2, cover: '/new.jpg')]);
      await pumpEventQueue();
      expect(controller.items.map((item) => item.source), ['/new.jpg']);
      // 媒体带上所在日记的发表时间，页面据此分组。
      expect(controller.items.single.date, DateTime(2026, 10, 13, 23, 58));
      expect(controller.isLoading, isFalse);
      expect(database.offsets, [0, 0]);

      // 相同筛选不重查。
      controller.configure(filter);
      expect(database.offsets, [0, 0]);
    },
  );

  test('ignores an in-flight result after disposal', () async {
    final pending = Completer<List<DiaryMediaContent>>();
    database.readPage = (_, _) => pending.future;
    final disposedController = ExploreMediaGalleryController(
      database: database,
    );
    var notifications = 0;
    disposedController.addListener(() => notifications += 1);

    final load = disposedController.loadMore();
    disposedController.dispose();
    pending.complete([createExploreTestMediaRow(cover: '/cover.jpg')]);
    await load;

    expect(notifications, 1);
    expect(disposedController.items, isEmpty);
    expect(database.offsets, [0]);
  });
}

class _GalleryDatabase extends AppDatabase {
  _GalleryDatabase() : super.forTesting(NativeDatabase.memory());

  final offsets = <int>[];
  final scopes = <DiaryListScope>[];
  final newestFirst = <bool>[];
  late Future<List<DiaryMediaContent>> Function(int limit, int offset) readPage;

  @override
  Future<List<DiaryMediaContent>> getGalleryMediaPage({
    required int limit,
    required int offset,
    DiaryListScope scope = DiaryListScope.all,
    bool newestFirst = true,
    DateTime? from,
    DateTime? to,
  }) {
    offsets.add(offset);
    scopes.add(scope);
    this.newestFirst.add(newestFirst);
    return readPage(limit, offset);
  }
}
