import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 日记卡片的“显示所属日记本”：列表查询带出每篇所在的日记本。
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

  group('list rows carry their notebooks', () {
    test('name, icon and color in shelf order; none for unfiled', () async {
      final travel = await db.createNotebook(
        name: 'Travel',
        payload: NotebookPayload(icon: 'plane', color: 0xFF3366CC),
      );
      final work = await db.createNotebook(name: 'Work');
      await db.updateNotebook(work, isPinned: true);
      await diary('both', notebookIds: <String>[travel, work]);
      await diary('loose');

      final rows = await db.watchDiaries().first;
      final byTitle = {for (final row in rows) row.diary.title: row};
      // 置顶的本子排在前面；没设图标、颜色的为 null（卡片回退默认与主题色）。
      expect(byTitle['both']!.notebooks, <DiaryNotebookRef>[
        DiaryNotebookRef(id: work, name: 'Work'),
        DiaryNotebookRef(
          id: travel,
          name: 'Travel',
          icon: 'plane',
          color: 0xFF3366CC,
        ),
      ]);
      expect(byTitle['loose']!.notebooks, isEmpty);
    });

    test('archived and calendar day lists carry them too', () async {
      final book = await db.createNotebook(name: 'Book');
      final id = await diary('archived', notebookIds: <String>[book]);
      await diary('on day', notebookIds: <String>[book]);
      await db.archiveDiary(id);

      final archived = await db.watchArchivedDiaries().first;
      expect(archived.single.notebooks.single.name, 'Book');
      final onDay = await db.watchDiariesCreatedOnDay(day).first;
      expect(
        onDay.map((row) => row.notebooks.map((n) => n.name).toList()),
        everyElement(<String>['Book']),
      );
    });

    test('renaming a notebook re-emits the list', () async {
      final book = await db.createNotebook(name: 'Old');
      await diary('entry', notebookIds: <String>[book]);
      final iterator = StreamIterator(db.watchDiaries());
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.single.notebooks.single.name, 'Old');

      await db.updateNotebook(book, name: 'New');
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline)) {
        final moved = await iterator.moveNext().timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
        if (!moved) break;
        if (iterator.current.single.notebooks.single.name == 'New') return;
      }
      fail('list never re-emitted with the new notebook name');
    });
  });
}
