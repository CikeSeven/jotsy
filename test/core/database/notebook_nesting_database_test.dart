import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/models/notebook_scope_resolver.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_tree.dart';
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
    String? parentId,
    NotebookKind kind = NotebookKind.manual,
    NotebookVisibility visibility = NotebookVisibility.normal,
    NotebookPayload? payload,
  }) {
    return db.createNotebook(
      name: name,
      kind: kind,
      visibility: visibility,
      payload: payload ?? NotebookPayload.defaults,
      parentId: parentId,
    );
  }

  Future<NotebookTree> tree() async => NotebookTree(await db.getNotebooks());

  Future<List<String>> titles(DiaryListScope scope) async {
    final rows = await db
        .watchDiaries(scope: scope, sortMode: DiarySortMode.createdAsc)
        .first;
    return rows.map((row) => row.diary.title).toList();
  }

  Future<String?> parentOf(String id) async =>
      (await db.getNotebook(id))!.parentId;

  group('creating and moving', () {
    test('a notebook can be created under a manual parent', () async {
      final travel = await notebook('旅行');
      final japan = await notebook('日本', parentId: travel);
      final shelf = await tree();
      expect(shelf[japan]!.parentId, travel);
      expect(shelf[japan]!.depth, 2);
      expect(shelf[travel]!.hasChildren, isTrue);
      expect(shelf.roots.map((n) => n.name), <String>['旅行']);
    });

    test('smart notebooks can be children but never parents', () async {
      final travel = await notebook('旅行');
      final smart = await notebook(
        '含标签',
        kind: NotebookKind.smart,
        parentId: travel,
      );
      expect(await parentOf(smart), travel);
      await expectLater(
        notebook('孙本', parentId: smart),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('nesting stops at three levels', () async {
      final a = await notebook('A');
      final b = await notebook('B', parentId: a);
      final c = await notebook('C', parentId: b);
      await expectLater(
        notebook('D', parentId: c),
        throwsA(isA<ArgumentError>()),
      );
      // 带着子本的 B 也放不进别的第二层下面。
      final other = await notebook('X');
      final otherChild = await notebook('Y', parentId: other);
      await expectLater(
        db.moveNotebook(b, otherChild),
        throwsA(isA<ArgumentError>()),
      );
      expect(await parentOf(b), a);
      expect(await parentOf(c), b);
    });

    test('moving under its own descendant is rejected', () async {
      final a = await notebook('A');
      final b = await notebook('B', parentId: a);
      await expectLater(db.moveNotebook(a, b), throwsA(isA<ArgumentError>()));
      await expectLater(db.moveNotebook(a, a), throwsA(isA<ArgumentError>()));
      expect(await parentOf(a), isNull);
    });

    test('moving puts the notebook last among its new siblings', () async {
      final parent = await notebook('父');
      final first = await notebook('一', parentId: parent);
      final loose = await notebook('散');
      await db.moveNotebook(loose, parent);
      final shelf = await tree();
      expect(shelf.childrenOf(parent).map((n) => n.id), <String>[first, loose]);
      await db.moveNotebook(loose, null);
      expect(await parentOf(loose), isNull);
    });

    test('updateNotebook changes the parent in the same write', () async {
      final parent = await notebook('父');
      final child = await notebook('子');
      await db.updateNotebook(child, name: '子本', parentId: Value(parent));
      final row = (await db.getNotebook(child))!;
      expect(row.parentId, parent);
      expect(row.name, '子本');
      await expectLater(
        db.updateNotebook(parent, name: '改不了', parentId: Value(child)),
        throwsA(isA<ArgumentError>()),
      );
      expect((await db.getNotebook(parent))!.name, '父');
    });
  });

  group('privacy inheritance', () {
    test('a hidden parent hides the diaries of its children too', () async {
      final parent = await notebook(
        '私密',
        visibility: NotebookVisibility.hidden,
      );
      final child = await notebook('子本', parentId: parent);
      final hiddenId = await diary('子本里的', notebookIds: <String>[child]);
      await diary('公开的');

      expect(await titles(DiaryListScope.all), <String>['公开的']);
      // 子本自己的范围里照常列出（它随上级私密）。
      expect(await titles(DiaryNotebookScope(notebookId: child)), <String>[
        '子本里的',
      ]);
      final counts = await db.watchManualNotebookEntryCounts().first;
      expect(counts[child], 1);
      expect(await db.isDiaryPrivate(hiddenId), isTrue);
    });

    test('effective visibility takes the strictest ancestor', () async {
      final locked = await notebook('锁', visibility: NotebookVisibility.locked);
      final hidden = await notebook(
        '藏',
        parentId: locked,
        visibility: NotebookVisibility.hidden,
      );
      final leaf = await notebook('叶', parentId: hidden);
      final shelf = await tree();
      expect(shelf[leaf]!.effectiveVisibility, NotebookVisibility.locked);
      expect(shelf[leaf]!.visibility, NotebookVisibility.normal);
      expect(shelf[leaf]!.inheritsPrivacy, isTrue);
      expect(shelf.lockRootOf(leaf), locked);
    });

    test('a smart child does not hide what its rules match', () async {
      final parent = await notebook(
        '私密',
        visibility: NotebookVisibility.hidden,
      );
      await notebook(
        '全部',
        kind: NotebookKind.smart,
        parentId: parent,
        payload: NotebookPayload(
          rules: const <String, Object?>{
            'match': 'all',
            'rules': <Object?>[
              <String, Object?>{'type': 'keyword', 'text': '日'},
            ],
          },
        ),
      );
      await diary('某日');
      expect(await titles(DiaryListScope.all), <String>['某日']);
    });
  });

  group('parent lists include sub-notebooks', () {
    test('own entries, child entries and smart child matches', () async {
      final travel = await notebook('旅行');
      final japan = await notebook('日本', parentId: travel);
      final deep = await notebook('东京', parentId: japan);
      await notebook(
        '海边',
        kind: NotebookKind.smart,
        parentId: travel,
        payload: NotebookPayload(
          rules: const <String, Object?>{
            'match': 'all',
            'rules': <Object?>[
              <String, Object?>{'type': 'keyword', 'text': '海'},
            ],
          },
        ),
      );
      await diary('出发', notebookIds: <String>[travel]);
      await diary('京都', notebookIds: <String>[japan]);
      await diary('浅草', notebookIds: <String>[deep, travel]);
      await diary('看海');
      await diary('无关');

      final shelf = await tree();
      final scope = resolveNotebookScope(shelf[travel]!, tree: shelf);
      expect(await titles(scope), <String>['出发', '京都', '浅草', '看海']);
      expect(await db.watchScopedDiaryCount(scope).first, 4);
      // 没有树时（或选了章节时）只看本子自己的。
      expect(await titles(resolveNotebookScope(shelf[travel]!)), <String>[
        '出发',
        '浅草',
      ]);
    });

    test('a locked child is left out of a normal parent', () async {
      final parent = await notebook('父');
      final secret = await notebook(
        '秘',
        parentId: parent,
        visibility: NotebookVisibility.locked,
      );
      final open = await notebook('开', parentId: parent);
      await diary('秘密', notebookIds: <String>[secret]);
      await diary('公开', notebookIds: <String>[open]);
      final shelf = await tree();
      expect(shelf.aggregatedDescendantsOf(parent).map((n) => n.id), <String>[
        open,
      ]);
      expect(
        await titles(resolveNotebookScope(shelf[parent]!, tree: shelf)),
        <String>['公开'],
      );
    });

    test('a locked parent lists its children without extra checks', () async {
      final parent = await notebook('锁', visibility: NotebookVisibility.locked);
      final child = await notebook('子', parentId: parent);
      await diary('父的', notebookIds: <String>[parent]);
      await diary('子的', notebookIds: <String>[child]);
      final shelf = await tree();
      expect(
        await titles(resolveNotebookScope(shelf[parent]!, tree: shelf)),
        <String>['父的', '子的'],
      );
      expect(await titles(DiaryListScope.all), isEmpty);
    });

    test('book order puts own chapters first, then each child', () async {
      final chapter = NotebookChapter.create('第一章');
      final parent = await notebook(
        '书',
        payload: NotebookPayload(
          chapters: <NotebookChapter>[chapter],
          sort: NotebookSort.book,
        ),
      );
      final second = await notebook('二', parentId: parent);
      final first = await notebook('一', parentId: parent);
      await db.moveNotebook(second, null);
      await db.moveNotebook(second, parent);
      // 树序：一、二。
      await diary('二-1', notebookIds: <String>[second]);
      await diary('一-1', notebookIds: <String>[first]);
      await diary('一-2', notebookIds: <String>[first]);
      await diary('父-未分章', notebookIds: <String>[parent]);
      final chaptered = await diary('父-第一章', notebookIds: <String>[parent]);
      await db.setNotebookEntriesChapter(parent, <String>[
        chaptered,
      ], chapter.id);
      final shelf = await tree();
      final scope = resolveNotebookScope(shelf[parent]!, tree: shelf);
      expect((scope as DiaryNotebookScope).bookOrder, isTrue);
      final expected = <String>['父-第一章', '父-未分章', '一-1', '一-2', '二-1'];
      expect(
        (await db.watchDiaries(scope: scope).first).map((r) => r.diary.title),
        expected,
      );
      final ids = await db.getActiveDiaryIds(scope: scope);
      final byId = <String, String>{
        for (final row in await db.watchDiaries(scope: scope).first)
          row.diary.diaryId: row.diary.title,
      };
      expect(ids.map((id) => byId[id]), expected);
    });

    test('choosing a chapter shows only the parent own entries', () async {
      final parent = await notebook('父');
      final child = await notebook('子', parentId: parent);
      await diary('父的', notebookIds: <String>[parent]);
      await diary('子的', notebookIds: <String>[child]);
      final shelf = await tree();
      expect(
        await titles(
          resolveNotebookScope(
            shelf[parent]!,
            tree: shelf,
            unassignedChapterOnly: true,
          ),
        ),
        <String>['父的'],
      );
    });
  });

  group('deleting and merging', () {
    test(
      'deleting a parent lifts its children and undo puts them back',
      () async {
        final root = await notebook('根');
        final parent = await notebook('父', parentId: root);
        final child = await notebook('子', parentId: parent);
        await diary('子的', notebookIds: <String>[child]);

        final deletion = await db.deleteNotebook(parent, trashDiaries: true);
        expect(await parentOf(child), root);
        expect(deletion.childIds, <String>[child]);
        expect(await titles(DiaryNotebookScope(notebookId: child)), <String>[
          '子的',
        ]);

        await db.restoreNotebookDeletion(deletion);
        expect(await parentOf(child), parent);
      },
    );

    test('merging moves the source children under the target', () async {
      final source = await notebook('源');
      final child = await notebook('源的子', parentId: source);
      final target = await notebook('目标');
      await db.mergeNotebook(sourceId: source, targetId: target);
      expect(await parentOf(child), target);
    });

    test('merging into its own child keeps the tree acyclic', () async {
      final grand = await notebook('祖');
      final source = await notebook('源', parentId: grand);
      final target = await notebook('目标', parentId: source);
      final sibling = await notebook('兄弟', parentId: source);
      await db.mergeNotebook(sourceId: source, targetId: target);
      expect(await parentOf(target), grand);
      expect(await parentOf(sibling), target);
    });
  });

  group('repair', () {
    test(
      'broken links, cycles and too deep chains go back to top level',
      () async {
        final a = await notebook('A');
        final b = await notebook('B', parentId: a);
        final c = await notebook('C', parentId: b);
        final d = await notebook('D');
        final e = await notebook('E');
        final orphan = await notebook('孤');
        final smart = await notebook('智', kind: NotebookKind.smart);
        final underSmart = await notebook('挂在智能本下');
        Future<void> raw(String id, String parent) =>
            (db.update(db.notebooks)..where((t) => t.notebookId.equals(id)))
                .write(NotebooksCompanion(parentId: Value(parent)));
        await raw(d, c); // 第四层
        await raw(e, e); // 指向自己
        await raw(orphan, 'missing');
        await raw(underSmart, smart);

        final repaired = await db.repairNotebookHierarchy();
        expect(repaired, 4);
        expect(await parentOf(d), isNull);
        expect(await parentOf(e), isNull);
        expect(await parentOf(orphan), isNull);
        expect(await parentOf(underSmart), isNull);
        expect(await parentOf(c), b);
        expect(await db.repairNotebookHierarchy(), 0);
      },
    );

    test('a two-node cycle is treated as two top-level notebooks', () async {
      final a = await notebook('A');
      final b = await notebook('B', parentId: a);
      await (db.update(db.notebooks)..where((t) => t.notebookId.equals(a)))
          .write(NotebooksCompanion(parentId: Value(b)));
      final shelf = await tree();
      expect(shelf.roots.map((n) => n.id).toSet(), <String>{a, b});
      await db.repairNotebookHierarchy();
      expect(await parentOf(a), isNull);
      expect(await parentOf(b), isNull);
    });
  });

  test(
    'upgrading from v14 adds the parent column and keeps notebooks',
    () async {
      final root = await Directory.systemTemp.createTemp('jotsy_v15_nesting');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v14.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await original.createNotebook(name: '升级前的本子');
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      legacy.execute('ALTER TABLE notebooks DROP COLUMN parent_id');
      legacy.execute('PRAGMA user_version = 14');
      legacy.close();

      for (var attempt = 0; attempt < 2; attempt++) {
        final migrated = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final rows = await migrated.getNotebooks();
          expect(rows.first.name, '升级前的本子');
          expect(rows.first.parentId, isNull);
          if (attempt == 0) {
            await migrated.createNotebook(
              name: '子本',
              parentId: rows.first.notebookId,
            );
          } else {
            expect(rows.last.parentId, rows.first.notebookId);
          }
        } finally {
          await migrated.close();
        }
      }
    },
  );
}
