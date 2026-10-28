import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/explore/controllers/explore_media_gallery_controller.dart';

import '../explore_test_fixtures.dart';

void main() {
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

  test('retains every image when one diary exceeds the batch target', () async {
    final sources = List.generate(45, (index) => '/image-$index.jpg');
    final diary = createExploreTestDiary(
      cover: '/cover.jpg',
      content: jsonEncode([
        for (final source in sources)
          {
            'insert': {'image': source},
          },
      ]),
    );
    database.readPage = (_, _) async => [diary];

    await controller.loadMore();

    expect(controller.items.map((item) => item.source), [
      '/cover.jpg',
      ...sources,
    ]);
    expect(
      controller.items.every((item) => item.diaryId == diary.diaryId),
      isTrue,
    );
    expect(controller.hasMore, isFalse);
    expect(controller.hasError, isFalse);
    await controller.loadMore();
    expect(database.offsets, [0]);
  });

  test('deduplicates across pages while retaining later images', () async {
    final firstPage = List.generate(
      40,
      (index) => createExploreTestDiary(id: index, cover: '/image-$index.jpg'),
    );
    database.readPage = (_, offset) async => offset == 0
        ? firstPage
        : [
            createExploreTestDiary(
              id: 41,
              cover: '/image-0.jpg',
              content: '[{"insert":{"image":"/later.jpg"}}]',
            ),
          ];

    await controller.loadMore();
    expect(controller.items, hasLength(40));
    expect(controller.hasMore, isTrue);
    await controller.loadMore();

    expect(database.offsets, [0, 40]);
    expect(controller.items, hasLength(41));
    expect(controller.items.last.source, '/later.jpg');
    expect(controller.hasMore, isFalse);
  });

  test('retries from the original offset after a later query fails', () async {
    final firstPage = List.generate(
      40,
      (index) => createExploreTestDiary(id: index, cover: '/shared.jpg'),
    );
    database.readPage = (_, offset) async {
      if (offset == 0) return firstPage;
      throw StateError('Database temporarily unavailable');
    };

    await controller.loadMore();

    expect(controller.hasError, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.items, isEmpty);
    database.readPage = (_, offset) async => offset == 0
        ? firstPage
        : [createExploreTestDiary(id: 41, cover: '/later.jpg')];
    await controller.loadMore();

    expect(database.offsets, [0, 40, 0, 40]);
    expect(controller.items.map((item) => item.source), [
      '/shared.jpg',
      '/later.jpg',
    ]);
    expect(controller.hasError, isFalse);
  });

  test('coalesces concurrent load requests', () async {
    final pending = Completer<List<Diary>>();
    database.readPage = (_, _) => pending.future;

    final firstLoad = controller.loadMore();
    await controller.loadMore();
    expect(controller.isLoading, isTrue);
    expect(database.offsets, [0]);
    pending.complete([createExploreTestDiary(cover: '/cover.jpg')]);
    await firstLoad;

    expect(controller.items, hasLength(1));
    expect(controller.isLoading, isFalse);
  });

  test('ignores an in-flight result after disposal', () async {
    final pending = Completer<List<Diary>>();
    database.readPage = (_, _) => pending.future;
    final disposedController = ExploreMediaGalleryController(
      database: database,
    );
    var notifications = 0;
    disposedController.addListener(() => notifications += 1);

    final load = disposedController.loadMore();
    disposedController.dispose();
    pending.complete([createExploreTestDiary(cover: '/cover.jpg')]);
    await load;

    expect(notifications, 1);
    expect(disposedController.items, isEmpty);
    expect(database.offsets, [0]);
  });
}

class _GalleryDatabase extends AppDatabase {
  _GalleryDatabase() : super.forTesting(NativeDatabase.memory());

  final offsets = <int>[];
  late Future<List<Diary>> Function(int limit, int offset) readPage;

  @override
  Future<List<Diary>> getActiveDiariesPage({
    required int limit,
    required int offset,
  }) {
    offsets.add(offset);
    return readPage(limit, offset);
  }
}
