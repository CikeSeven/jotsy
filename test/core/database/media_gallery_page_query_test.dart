import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 媒体画廊的分页查询：按发表时间排序、日记本范围与时间段，私密日记不进。
void main() {
  late AppDatabase db;
  final day = DateTime(2026, 3, 10, 9);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    List<String>? notebookIds,
    DateTime? createdAt,
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$title body\\n"}]',
      contentText: '$title body',
      metadataJson: '{}',
      tagIds: const <int>[],
      notebookIds: notebookIds,
      createdAtOverride: createdAt ?? day,
    );
  }

  group('media gallery page query', () {
    Future<List<String>> titles({
      DiaryListScope scope = DiaryListScope.all,
      bool newestFirst = true,
      DateTime? from,
      DateTime? to,
    }) async {
      final rows = await db.getActiveDiariesPage(
        limit: 50,
        offset: 0,
        scope: scope,
        newestFirst: newestFirst,
        from: from,
        to: to,
      );
      return rows.map((row) => row.title).toList();
    }

    test('orders by publish time and honours the date range', () async {
      await diary('march', createdAt: DateTime(2026, 3, 1));
      await diary('april', createdAt: DateTime(2026, 4, 15));
      await diary('may', createdAt: DateTime(2026, 5, 31, 23, 59));

      expect(await titles(), <String>['may', 'april', 'march']);
      expect(await titles(newestFirst: false), <String>[
        'march',
        'april',
        'may',
      ]);
      expect(
        await titles(
          from: DateTime(2026, 4, 1),
          to: DateTime(2026, 5, 31, 23, 59, 59),
        ),
        <String>['may', 'april'],
      );
    });

    test('notebook and unfiled scopes; private diaries stay out', () async {
      final book = await db.createNotebook(name: 'Book');
      final secret = await db.createNotebook(
        name: 'Secret',
        visibility: NotebookVisibility.locked,
      );
      await diary('in book', notebookIds: <String>[book]);
      await diary('loose');
      await diary('hidden', notebookIds: <String>[secret]);

      expect(await titles(), unorderedEquals(<String>['in book', 'loose']));
      expect(await titles(scope: DiaryListScope.unfiled), <String>['loose']);
      expect(
        await titles(scope: DiaryNotebookScope(notebookId: book)),
        <String>['in book'],
      );
    });
  });
}
