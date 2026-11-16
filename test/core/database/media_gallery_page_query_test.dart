import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 媒体画廊的分页查询：只取可能带图的日记，按发表时间排序、日记本范围与
/// 时间段，私密日记不进。
void main() {
  late AppDatabase db;
  final day = DateTime(2026, 3, 10, 9);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    List<String>? notebookIds,
    DateTime? createdAt,
    bool withImage = true,
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: withImage
          ? '[{"insert":{"image":"/$title.jpg"}},{"insert":"\\n"}]'
          : '[{"insert":"$title body\\n"}]',
      contentText: '$title body',
      metadataJson: '{}',
      tagIds: const <int>[],
      notebookIds: notebookIds,
      createdAtOverride: createdAt ?? day,
    );
  }

  group('media gallery page query', () {
    Future<List<String>> ids({
      DiaryListScope scope = DiaryListScope.all,
      bool newestFirst = true,
      DateTime? from,
      DateTime? to,
    }) async {
      final rows = await db.getGalleryMediaPage(
        limit: 50,
        offset: 0,
        scope: scope,
        newestFirst: newestFirst,
        from: from,
        to: to,
      );
      return rows.map((row) => row.diaryId).toList();
    }

    test('orders by publish time and honours the date range', () async {
      final march = await diary('march', createdAt: DateTime(2026, 3, 1));
      final april = await diary('april', createdAt: DateTime(2026, 4, 15));
      final may = await diary('may', createdAt: DateTime(2026, 5, 31, 23, 59));

      expect(await ids(), <String>[may, april, march]);
      expect(await ids(newestFirst: false), <String>[march, april, may]);
      expect(
        await ids(
          from: DateTime(2026, 4, 1),
          to: DateTime(2026, 5, 31, 23, 59, 59),
        ),
        <String>[may, april],
      );
      final rows = await db.getGalleryMediaPage(limit: 1, offset: 0);
      // 画廊按发表时间分组：每行带上发表时间与正文原文。
      expect(rows.single.createdAt, DateTime(2026, 5, 31, 23, 59));
      expect(rows.single.content, contains('/may.jpg'));
    });

    test('text-only diaries are left out in the database', () async {
      final photo = await diary('photo');
      await diary('words', withImage: false);
      final covered = await db.createDiary(
        title: 'covered',
        contentDocJson: '[{"insert":"no inline image\\n"}]',
        contentText: 'no inline image',
        metadataJson: '{}',
        tagIds: const <int>[],
        cover: '/cover.jpg',
        createdAtOverride: day,
      );

      expect(await ids(), unorderedEquals(<String>[photo, covered]));
    });

    test('notebook and unfiled scopes; private diaries stay out', () async {
      final book = await db.createNotebook(name: 'Book');
      final secret = await db.createNotebook(
        name: 'Secret',
        visibility: NotebookVisibility.locked,
      );
      final inBook = await diary('in book', notebookIds: <String>[book]);
      final loose = await diary('loose');
      await diary('hidden', notebookIds: <String>[secret]);

      expect(await ids(), unorderedEquals(<String>[inBook, loose]));
      expect(await ids(scope: DiaryListScope.unfiled), <String>[loose]);
      expect(await ids(scope: DiaryNotebookScope(notebookId: book)), <String>[
        inBook,
      ]);
    });
  });
}
