import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(String title, {List<String>? notebookIds}) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
      notebookIds: notebookIds,
    );
  }

  Future<String> notebook(
    String name, {
    NotebookKind kind = NotebookKind.manual,
    NotebookPayload? payload,
  }) {
    return db.createNotebook(
      name: name,
      kind: kind,
      payload: payload ?? NotebookPayload.defaults,
    );
  }

  Future<List<String>> shelf() async =>
      (await db.watchNotebooks().first).map((row) => row.name).toList();

  /// 本子里的成员：按成书位置排好的 (日记标题, 章节 id)。
  Future<List<(String, String?)>> entries(String notebookId) async {
    final book = (await db.getNotebook(notebookId))!;
    final query =
        db.select(db.diaryNotebooks).join(<Join>[
            innerJoin(
              db.diaries,
              db.diaries.id.equalsExp(db.diaryNotebooks.diaryId),
            ),
          ])
          ..where(db.diaryNotebooks.notebookId.equals(book.id))
          ..orderBy(<OrderingTerm>[
            OrderingTerm.asc(db.diaryNotebooks.position),
          ]);
    return <(String, String?)>[
      for (final row in await query.get())
        (
          row.readTable(db.diaries).title,
          row.readTable(db.diaryNotebooks).chapterId,
        ),
    ];
  }

  group('notebooks', () {
    test('new notebooks append and pinned ones lead the shelf', () async {
      final a = await notebook('甲');
      await notebook('乙');
      final c = await notebook('丙');
      expect(await shelf(), <String>['甲', '乙', '丙']);
      expect((await db.getNotebooks()).map((r) => r.sortOrder), <int>[0, 1, 2]);

      await db.updateNotebook(c, isPinned: true);
      expect(await shelf(), <String>['丙', '甲', '乙']);

      await db.reorderNotebooks(<String>[c]);
      expect((await db.getNotebook(c))!.sortOrder, 0);
      expect((await db.getNotebook(a))!.sortOrder, 1);
      expect(await shelf(), <String>['丙', '甲', '乙']);
    });

    test('reordering keeps unlisted notebooks after in their order', () async {
      final a = await notebook('甲');
      final b = await notebook('乙');
      await notebook('丙');
      await notebook('丁');
      await db.reorderNotebooks(<String>[b, a]);
      expect(await shelf(), <String>['乙', '甲', '丙', '丁']);
    });

    test('names are trimmed and validated', () async {
      final id = await notebook('  旅行  ');
      expect((await db.getNotebook(id))!.name, '旅行');
      expect(() => notebook('   '), throwsArgumentError);
      expect(() => notebook('名' * 61), throwsArgumentError);
      expect(
        () => db.updateNotebook('missing', name: 'x'),
        throwsArgumentError,
      );
    });

    test('updates change fields and bump updatedAt', () async {
      final id = await notebook('原名');
      final before = (await db.getNotebook(id))!;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.updateNotebook(
        id,
        name: '新名',
        visibility: NotebookVisibility.locked,
        payload: NotebookPayload(description: '简介'),
        isClosed: true,
      );
      final after = (await db.getNotebook(id))!;
      expect(after.name, '新名');
      expect(after.notebookVisibility, NotebookVisibility.locked);
      expect(after.parsedPayload.description, '简介');
      expect(after.isClosed, isTrue);
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue);
    });

    test('smart notebooks are always stored with normal visibility', () async {
      final id = await db.createNotebook(
        name: '智能',
        kind: NotebookKind.smart,
        visibility: NotebookVisibility.hidden,
      );
      expect(
        (await db.getNotebook(id))!.notebookVisibility,
        NotebookVisibility.normal,
      );
      await db.updateNotebook(id, visibility: NotebookVisibility.locked);
      expect(
        (await db.getNotebook(id))!.notebookVisibility,
        NotebookVisibility.normal,
      );
    });

    test('watchNotebook emits the row and then null after deletion', () async {
      final id = await notebook('甲');
      final stream = db.watchNotebook(id);
      expect((await stream.first)!.name, '甲');
      await db.deleteNotebook(id);
      expect(await stream.first, isNull);
    });
  });

  group('memberships', () {
    test('adding appends in order and skips present and unknown', () async {
      final book = await notebook('本子');
      final a = await diary('甲');
      final b = await diary('乙');
      final c = await diary('丙');

      expect(await db.addDiariesToNotebook(book, <String>[b, a]), 2);
      expect(await db.addDiariesToNotebook(book, <String>[a, 'nope', c, c]), 1);
      expect(await entries(book), <(String, String?)>[
        ('乙', null),
        ('甲', null),
        ('丙', null),
      ]);
      expect(await db.getDiaryNotebookIds(a), <String>{book});
    });

    test('chapter ids that are not in the payload fall back to none', () async {
      final book = await notebook(
        '本子',
        payload: NotebookPayload(
          chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
        ),
      );
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(book, <String>[a], chapterId: 'c1');
      await db.addDiariesToNotebook(book, <String>[b], chapterId: 'gone');
      expect(await entries(book), <(String, String?)>[
        ('甲', 'c1'),
        ('乙', null),
      ]);

      await db.setNotebookEntriesChapter(book, <String>[b], 'c1');
      await db.setNotebookEntriesChapter(book, <String>[a], null);
      expect(await entries(book), <(String, String?)>[
        ('甲', null),
        ('乙', 'c1'),
      ]);
    });

    test('removing returns rows that restore puts back unchanged', () async {
      final book = await notebook('本子');
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(book, <String>[a, b]);
      final before = await db.select(db.diaryNotebooks).get();

      final removed = await db.removeDiariesFromNotebook(book, <String>[a]);
      expect(removed, hasLength(1));
      expect(await entries(book), <(String, String?)>[('乙', null)]);

      await db.restoreNotebookMemberships(removed);
      expect(await db.select(db.diaryNotebooks).get(), unorderedEquals(before));
    });

    test('restoring skips rows whose diary or notebook is gone', () async {
      final book = await notebook('本子');
      final other = await notebook('另一本');
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(book, <String>[a, b]);
      await db.addDiariesToNotebook(other, <String>[a]);
      final removed = <DiaryNotebookRow>[
        ...await db.removeDiariesFromNotebook(book, <String>[a, b]),
        ...await db.removeDiariesFromNotebook(other, <String>[a]),
      ];
      await db.hardDeleteDiary(b);
      await db.deleteNotebook(other);

      await db.restoreNotebookMemberships(removed);
      expect(await entries(book), <(String, String?)>[('甲', null)]);
      expect(await db.select(db.diaryNotebooks).get(), hasLength(1));
    });

    test('moving takes diaries out of one notebook into another', () async {
      final from = await notebook('原本');
      final to = await notebook('新本');
      final a = await diary('甲');
      final b = await diary('乙');
      final c = await diary('丙');
      await db.addDiariesToNotebook(from, <String>[a, b, c]);
      await db.addDiariesToNotebook(to, <String>[b]);

      await db.moveDiariesBetweenNotebooks(
        fromId: from,
        toId: to,
        diaryIds: <String>[a, b],
      );
      expect(await entries(from), <(String, String?)>[('丙', null)]);
      expect(await entries(to), <(String, String?)>[('乙', null), ('甲', null)]);
      expect(
        () => db.moveDiariesBetweenNotebooks(
          fromId: to,
          toId: to,
          diaryIds: <String>[a],
        ),
        throwsArgumentError,
      );
    });

    test('smart and unknown notebooks reject membership changes', () async {
      final smart = await notebook('智能', kind: NotebookKind.smart);
      final a = await diary('甲');
      expect(
        () => db.addDiariesToNotebook(smart, <String>[a]),
        throwsArgumentError,
      );
      expect(
        () => db.removeDiariesFromNotebook(smart, <String>[a]),
        throwsArgumentError,
      );
      expect(
        () => db.addDiariesToNotebook('missing', <String>[a]),
        throwsArgumentError,
      );
    });

    test('closed notebooks still accept diaries', () async {
      final book = await notebook('合上的');
      await db.updateNotebook(book, isClosed: true);
      expect(
        await db.addDiariesToNotebook(book, <String>[await diary('甲')]),
        1,
      );
    });

    test('lookups report manual notebooks per diary', () async {
      final first = await notebook('一');
      final second = await notebook('二');
      await notebook('智能', kind: NotebookKind.smart);
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(second, <String>[a]);
      await db.addDiariesToNotebook(first, <String>[a]);
      await db.updateNotebook(second, isPinned: true);

      final map = await db.getNotebookIdsForDiaries(<String>[a, b, 'nope']);
      expect(map, <String, Set<String>>{
        a: <String>{first, second},
        b: <String>{},
        'nope': <String>{},
      });
      final ofDiary = await db.watchNotebooksOfDiary(a).first;
      expect(ofDiary.map((row) => row.name), <String>['二', '一']);
    });

    test('entry counts skip deleted and archived diaries', () async {
      final book = await notebook('本子');
      final empty = await notebook('空本');
      final a = await diary('甲');
      final b = await diary('乙');
      final c = await diary('丙');
      await db.addDiariesToNotebook(book, <String>[a, b, c]);
      await db.softDeleteDiary(b);
      await db.archiveDiary(c);

      final counts = await db.watchManualNotebookEntryCounts().first;
      expect(counts, <String, int>{book: 1});
      expect(counts[empty], isNull);
    });

    test('reordering entries rewrites positions and chapters', () async {
      final book = await notebook(
        '本子',
        payload: NotebookPayload(
          chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
        ),
      );
      final a = await diary('甲');
      final b = await diary('乙');
      final c = await diary('丙');
      final d = await diary('丁');
      await db.addDiariesToNotebook(book, <String>[a, b, c, d]);

      await db
          .reorderNotebookEntries(book, <({String diaryId, String? chapterId})>[
            (diaryId: c, chapterId: 'c1'),
            (diaryId: a, chapterId: 'gone'),
            (diaryId: c, chapterId: null),
            (diaryId: 'nope', chapterId: null),
          ]);
      expect(await entries(book), <(String, String?)>[
        ('丙', 'c1'),
        ('甲', null),
        ('乙', null),
        ('丁', null),
      ]);
      final positions =
          (await db.select(db.diaryNotebooks).get())
              .map((row) => row.position)
              .toList()
            ..sort();
      expect(positions, <int>[0, 1, 2, 3]);
    });

    test('dropping a chapter from the payload clears it on entries', () async {
      final one = NotebookChapter(id: 'c1', title: '一');
      final two = NotebookChapter(id: 'c2', title: '二');
      final book = await notebook(
        '本子',
        payload: NotebookPayload(chapters: <NotebookChapter>[one, two]),
      );
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(book, <String>[a], chapterId: 'c1');
      await db.addDiariesToNotebook(book, <String>[b], chapterId: 'c2');

      await db.updateNotebook(
        book,
        payload: NotebookPayload(chapters: <NotebookChapter>[two]),
      );
      expect(await entries(book), <(String, String?)>[
        ('甲', null),
        ('乙', 'c2'),
      ]);

      // 删光章节：NOT IN 空集合也要生效。
      await db.updateNotebook(book, payload: NotebookPayload.defaults);
      expect(await entries(book), <(String, String?)>[
        ('甲', null),
        ('乙', null),
      ]);
    });
  });

  group('diary writes', () {
    test('createDiary joins manual notebooks and ignores smart ones', () async {
      final book = await notebook('本子');
      final smart = await notebook('智能', kind: NotebookKind.smart);
      await diary('先来的', notebookIds: <String>[book]);
      final a = await diary('甲', notebookIds: <String>[book, smart, 'nope']);
      expect(await db.getDiaryNotebookIds(a), <String>{book});
      expect(await entries(book), <(String, String?)>[
        ('先来的', null),
        ('甲', null),
      ]);
    });

    test('updateDiary keeps chapter and position of kept notebooks', () async {
      final kept = await notebook(
        '留下',
        payload: NotebookPayload(
          chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
        ),
      );
      final dropped = await notebook('移出');
      final added = await notebook('新加');
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(kept, <String>[a, b], chapterId: 'c1');
      await db.addDiariesToNotebook(dropped, <String>[a]);
      await db.addDiariesToNotebook(added, <String>[b]);
      final keptRowBefore = (await db.select(db.diaryNotebooks).get())
          .firstWhere((row) => row.position == 0 && row.chapterId == 'c1');

      Future<void> update({List<String>? notebookIds}) => db.updateDiary(
        diaryId: a,
        title: '甲',
        contentDocJson: '[{"insert":"改过\\n"}]',
        contentText: '改过',
        metadataJson: '{}',
        notebookIds: notebookIds,
      );

      await update(notebookIds: <String>[kept, added]);
      expect(await db.getDiaryNotebookIds(a), <String>{kept, added});
      expect(await entries(kept), <(String, String?)>[
        ('甲', 'c1'),
        ('乙', 'c1'),
      ]);
      expect(await entries(added), <(String, String?)>[
        ('乙', null),
        ('甲', null),
      ]);
      expect(await entries(dropped), isEmpty);
      final keptRowAfter = (await db.select(db.diaryNotebooks).get())
          .firstWhere(
            (row) =>
                row.diaryId == keptRowBefore.diaryId &&
                row.notebookId == keptRowBefore.notebookId,
          );
      expect(keptRowAfter, keptRowBefore);

      await update();
      expect(await db.getDiaryNotebookIds(a), <String>{kept, added});
      await update(notebookIds: const <String>[]);
      expect(await db.getDiaryNotebookIds(a), isEmpty);
    });

    test(
      'hard deletion removes memberships, soft deletion keeps them',
      () async {
        final book = await notebook('本子');
        final a = await diary('甲', notebookIds: <String>[book]);
        final b = await diary('乙', notebookIds: <String>[book]);

        await db.softDeleteDiary(a);
        await db.restoreDiary(a);
        expect(await db.getDiaryNotebookIds(a), <String>{book});

        await db.hardDeleteDiary(b);
        expect(await entries(book), <(String, String?)>[('甲', null)]);
        expect(await db.select(db.diaryNotebooks).get(), hasLength(1));
      },
    );
  });

  group('delete, restore and merge', () {
    test('deleting keeps diaries and undo restores the notebook', () async {
      final book = await notebook(
        '本子',
        payload: NotebookPayload(
          chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
        ),
      );
      await notebook('别的');
      final a = await diary('甲');
      final b = await diary('乙');
      await db.addDiariesToNotebook(book, <String>[a, b], chapterId: 'c1');
      final rowBefore = (await db.getNotebook(book))!;
      final joinsBefore = await db.select(db.diaryNotebooks).get();

      final deletion = await db.deleteNotebook(book);
      expect(await db.getNotebook(book), isNull);
      expect(await db.select(db.diaryNotebooks).get(), isEmpty);
      expect(deletion.trashedDiaryIds, isEmpty);
      expect(await db.select(db.diaries).get(), hasLength(2));

      await notebook('删除后新建');
      await db.restoreNotebookDeletion(deletion);
      expect(await db.getNotebook(book), rowBefore);
      expect(
        await db.select(db.diaryNotebooks).get(),
        unorderedEquals(joinsBefore),
      );
      expect(await shelf(), <String>['本子', '别的', '删除后新建']);
    });

    test('trashing diaries with the notebook is undone exactly', () async {
      final book = await notebook('本子');
      final a = await diary('甲', notebookIds: <String>[book]);
      final b = await diary('乙', notebookIds: <String>[book]);
      final c = await diary('丙', notebookIds: <String>[book]);
      final outside = await diary('本外');
      await db.archiveDiary(b);
      await db.softDeleteDiary(c);
      Future<Diary> row(String id) => (db.select(
        db.diaries,
      )..where((t) => t.diaryId.equals(id))).getSingle();
      final archivedBefore = await row(b);
      final trashedBefore = await row(c);

      final deletion = await db.deleteNotebook(book, trashDiaries: true);
      expect(deletion.trashedDiaryIds, unorderedEquals(<String>[a, b]));
      expect((await row(a)).isDeleted, isTrue);
      expect((await row(b)).isDeleted, isTrue);
      expect((await row(b)).isArchived, isFalse);
      expect((await row(outside)).isDeleted, isFalse);

      await db.restoreNotebookDeletion(deletion);
      expect((await row(a)).isDeleted, isFalse);
      expect(await row(b), archivedBefore);
      expect(await row(c), trashedBefore);
      expect(await db.getDiaryNotebookIds(c), <String>{book});
    });

    test('undo skips memberships of diaries deleted in between', () async {
      final book = await notebook('本子');
      final a = await diary('甲', notebookIds: <String>[book]);
      final b = await diary('乙', notebookIds: <String>[book]);
      final deletion = await db.deleteNotebook(book, trashDiaries: true);
      await db.hardDeleteDiary(b);
      await db.restoreNotebookDeletion(deletion);
      expect(await entries(book), <(String, String?)>[('甲', null)]);
      expect(await db.getDiaryNotebookIds(a), <String>{book});
    });

    test(
      'merging appends new diaries to the target and deletes the source',
      () async {
        final source = await notebook(
          '来源',
          payload: NotebookPayload(
            chapters: <NotebookChapter>[NotebookChapter(id: 's1', title: '一')],
          ),
        );
        final target = await notebook('目标');
        final a = await diary('甲');
        final b = await diary('乙');
        final c = await diary('丙');
        await db.addDiariesToNotebook(target, <String>[b]);
        await db.addDiariesToNotebook(source, <String>[
          c,
          b,
          a,
        ], chapterId: 's1');

        await db.mergeNotebook(sourceId: source, targetId: target);
        expect(await db.getNotebook(source), isNull);
        expect(await entries(target), <(String, String?)>[
          ('乙', null),
          ('丙', null),
          ('甲', null),
        ]);
        expect(await db.select(db.diaryNotebooks).get(), hasLength(3));
      },
    );

    test('merging rejects smart notebooks and the same id', () async {
      final manual = await notebook('手动');
      final smart = await notebook('智能', kind: NotebookKind.smart);
      expect(
        () => db.mergeNotebook(sourceId: manual, targetId: manual),
        throwsArgumentError,
      );
      expect(
        () => db.mergeNotebook(sourceId: smart, targetId: manual),
        throwsArgumentError,
      );
      expect(
        () => db.mergeNotebook(sourceId: manual, targetId: smart),
        throwsArgumentError,
      );
      expect(await shelf(), <String>['手动', '智能']);
    });
  });

  group('schema v13 migration', () {
    Future<File> v12DatabaseFile({required bool keepNotebookTables}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v13_nb');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v12.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final book = await original.createNotebook(name: '降级时留下的本子');
        await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
          notebookIds: <String>[book],
        );
        await original.saveDiaryTemplate(name: '升级前的模板', payload: '{}');
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (keepNotebookTables) {
        // 模拟定义不同的开发构建留下的同名索引。
        legacy.execute('DROP INDEX idx_diary_notebooks_notebook');
        legacy.execute(
          'CREATE INDEX idx_diary_notebooks_notebook '
          'ON diary_notebooks (notebook_id)',
        );
      } else {
        legacy.execute('DROP TABLE diary_notebooks');
        legacy.execute('DROP TABLE notebooks');
      }
      legacy.execute('PRAGMA user_version = 12');
      legacy.close();
      return file;
    }

    Future<String?> indexSql(AppDatabase db) async {
      final row = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_diary_notebooks_notebook'",
          )
          .getSingleOrNull();
      return row?.read<String>('sql');
    }

    test('v12 upgrade creates the tables and keeps existing data', () async {
      final file = await v12DatabaseFile(keepNotebookTables: false);
      for (var attempt = 0; attempt < 2; attempt++) {
        final migrated = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(await migrated.getNotebooks(), hasLength(attempt));
          if (attempt == 0) {
            await migrated.createNotebook(name: '升级后新建');
          }
          final diaries = await migrated.select(migrated.diaries).get();
          expect(diaries.single.title, '升级前的日记');
          expect(await migrated.countDiaryTemplates(), 1);
          expect(await indexSql(migrated), contains('position'));
        } finally {
          await migrated.close();
        }
      }
    });

    test('upgrading over tables a downgrade left keeps them', () async {
      final file = await v12DatabaseFile(keepNotebookTables: true);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final book = (await migrated.getNotebooks()).single;
        expect(book.name, '降级时留下的本子');
        final diaryId =
            (await migrated.select(migrated.diaries).get()).single.diaryId;
        expect(await migrated.getDiaryNotebookIds(diaryId), <String>{
          book.notebookId,
        });
        expect(await indexSql(migrated), contains('position'));
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), migrated.schemaVersion);
      } finally {
        await migrated.close();
      }
    });
  });
}
