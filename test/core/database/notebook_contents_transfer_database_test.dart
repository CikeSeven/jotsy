import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

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
    NotebookPayload payload = NotebookPayload.defaults,
  }) {
    return db.createNotebook(
      name: name,
      kind: kind,
      visibility: visibility,
      payload: payload,
      parentId: parentId,
    );
  }

  test(
    'transfers entire contents with chapters, book order and archived entries '
    'to a direct child',
    () async {
      final ch1 = NotebookChapter(id: 'c1', title: '东京');
      final ch2 = NotebookChapter(id: 'c2', title: '京都');
      final existingCh = NotebookChapter(id: 't1', title: '序章');

      final parent = await notebook(
        '旅行',
        payload: NotebookPayload(chapters: <NotebookChapter>[ch1, ch2]),
      );
      final child = await notebook(
        '日本',
        parentId: parent,
        payload: NotebookPayload(chapters: <NotebookChapter>[existingCh]),
      );

      final d0 = await diary('已有', notebookIds: <String>[child]);
      await db.setNotebookEntriesChapter(child, <String>[d0], 't1');

      // 故意让插入顺序与章节先后不同，验证搬运后保持成书顺序（先 c1，再 c2，后未分章）。
      final dKyoto = await diary('京都日', notebookIds: <String>[parent]);
      final dLoose = await diary('随笔', notebookIds: <String>[parent]);
      final dTokyo1 = await diary('东京一', notebookIds: <String>[parent]);
      final dTokyo2 = await diary('东京二', notebookIds: <String>[parent]);
      await db.setNotebookEntriesChapter(parent, <String>[dKyoto], 'c2');
      await db.setNotebookEntriesChapter(parent, <String>[
        dTokyo1,
        dTokyo2,
      ], 'c1');
      await db.archiveDiary(dTokyo2);

      final result = await db.transferNotebookContents(
        sourceId: parent,
        targetId: child,
      );
      expect(result.chapterCount, 2);
      expect(result.entryCount, 4);

      final parentAfter = (await db.getNotebook(parent))!.parsedPayload;
      final childAfter = (await db.getNotebook(child))!.parsedPayload;
      expect(parentAfter.chapters, isEmpty);
      expect(childAfter.chapters.map((c) => c.title), <String>[
        '序章',
        '东京',
        '京都',
      ]);

      expect(await db.getNotebookContents(parent), isEmpty);
      final childEntries = await db.getNotebookContents(child);
      expect(
        <(String, String?)>[
          for (final e in childEntries) (e.diaryId, e.chapterId),
        ],
        <(String, String?)>[
          (d0, 't1'),
          (dTokyo1, 'c1'),
          (dTokyo2, 'c1'),
          (dKyoto, 'c2'),
          (dLoose, null),
        ],
      );
    },
  );

  test('transfers contents to a grandchild manual notebook', () async {
    final ch = NotebookChapter(id: 'c1', title: '第一章');
    final root = await notebook(
      '总集',
      payload: NotebookPayload(chapters: <NotebookChapter>[ch]),
    );
    final child = await notebook('二级', parentId: root);
    final grand = await notebook('三级', parentId: child);
    final d1 = await diary('笔记', notebookIds: <String>[root]);
    await db.setNotebookEntriesChapter(root, <String>[d1], 'c1');

    final result = await db.transferNotebookContents(
      sourceId: root,
      targetId: grand,
    );
    expect(result.chapterCount, 1);
    expect(result.entryCount, 1);
    expect(await db.getNotebookContents(root), isEmpty);
    final grandContents = await db.getNotebookContents(grand);
    expect(grandContents.single.diaryId, d1);
    expect(grandContents.single.chapterId, 'c1');
  });

  test('transfers a single chapter while leaving other chapters and unassigned '
      'entries intact', () async {
    final ch1 = NotebookChapter(id: 'c1', title: '东京');
    final ch2 = NotebookChapter(id: 'c2', title: '京都');
    final emptyCh = NotebookChapter(id: 'c3', title: '北海道');
    final parent = await notebook(
      '旅行',
      payload: NotebookPayload(chapters: <NotebookChapter>[ch1, ch2, emptyCh]),
    );
    final child = await notebook('关东', parentId: parent);

    final d1 = await diary('浅草', notebookIds: <String>[parent]);
    final d2 = await diary('清水寺', notebookIds: <String>[parent]);
    final d3 = await diary('未分章', notebookIds: <String>[parent]);
    await db.setNotebookEntriesChapter(parent, <String>[d1], 'c1');
    await db.setNotebookEntriesChapter(parent, <String>[d2], 'c2');

    final r1 = await db.transferNotebookContents(
      sourceId: parent,
      targetId: child,
      chapterId: 'c1',
    );
    expect(r1.chapterCount, 1);
    expect(r1.entryCount, 1);

    final parentPayload = (await db.getNotebook(parent))!.parsedPayload;
    expect(parentPayload.chapters.map((c) => c.id), <String>['c2', 'c3']);
    final parentEntries = await db.getNotebookContents(parent);
    expect(parentEntries.map((e) => e.diaryId), <String>[d2, d3]);

    final childEntries = await db.getNotebookContents(child);
    expect(childEntries.single.diaryId, d1);
    expect(childEntries.single.chapterId, 'c1');

    // 空章节也能单独转移。
    final r2 = await db.transferNotebookContents(
      sourceId: parent,
      targetId: child,
      chapterId: 'c3',
    );
    expect(r2.chapterCount, 1);
    expect(r2.entryCount, 0);
    expect(
      (await db.getNotebook(parent))!.parsedPayload.chapters.map((c) => c.id),
      <String>['c2'],
    );
    expect(
      (await db.getNotebook(child))!.parsedPayload.chapters.map((c) => c.title),
      <String>['东京', '北海道'],
    );
  });

  test(
    'transfers entries-only directory without touching notebook payloads',
    () async {
      final parent = await notebook('随手记');
      final child = await notebook('归档', parentId: parent);
      final d1 = await diary('一', notebookIds: <String>[parent]);
      final d2 = await diary('二', notebookIds: <String>[parent]);

      final result = await db.transferNotebookContents(
        sourceId: parent,
        targetId: child,
      );
      expect(result.chapterCount, 0);
      expect(result.entryCount, 2);
      expect(await db.getNotebookContents(parent), isEmpty);
      final childEntries = await db.getNotebookContents(child);
      expect(childEntries.map((e) => e.diaryId), <String>[d1, d2]);
      expect(childEntries.every((e) => e.chapterId == null), isTrue);
    },
  );

  test(
    'remaps colliding chapter IDs cleanly without altering target entries',
    () async {
      final sourceCh = NotebookChapter(id: 'sameid01', title: '迁入章');
      final targetCh = NotebookChapter(id: 'sameid01', title: '原章');
      final parent = await notebook(
        '父本',
        payload: NotebookPayload(chapters: <NotebookChapter>[sourceCh]),
      );
      final child = await notebook(
        '子本',
        parentId: parent,
        payload: NotebookPayload(chapters: <NotebookChapter>[targetCh]),
      );
      final dTarget = await diary('原本日记', notebookIds: <String>[child]);
      await db.setNotebookEntriesChapter(child, <String>[dTarget], 'sameid01');
      final dSource = await diary('迁入日记', notebookIds: <String>[parent]);
      await db.setNotebookEntriesChapter(parent, <String>[dSource], 'sameid01');

      await db.transferNotebookContents(sourceId: parent, targetId: child);

      final chapters = (await db.getNotebook(child))!.parsedPayload.chapters;
      expect(chapters, hasLength(2));
      expect(chapters[0].id, 'sameid01');
      expect(chapters[0].title, '原章');
      expect(chapters[1].id, isNot('sameid01'));
      expect(chapters[1].title, '迁入章');

      final entries = await db.getNotebookContents(child);
      expect(
        entries.firstWhere((e) => e.diaryId == dTarget).chapterId,
        'sameid01',
      );
      expect(
        entries.firstWhere((e) => e.diaryId == dSource).chapterId,
        chapters[1].id,
      );
    },
  );

  test('handles diaries already present in target child notebook', () async {
    final srcCh = NotebookChapter(id: 's1', title: '源章');
    final dstCh = NotebookChapter(id: 't1', title: '目标原章');
    final parent = await notebook(
      '父本',
      payload: NotebookPayload(chapters: <NotebookChapter>[srcCh]),
    );
    final child = await notebook(
      '子本',
      parentId: parent,
      payload: NotebookPayload(chapters: <NotebookChapter>[dstCh]),
    );
    // dUnassigned 在目标本里未分章：转移后应归入搬来的源章。
    final dUnassigned = await diary(
      '双在无章',
      notebookIds: <String>[parent, child],
    );
    // dAssigned 在目标本里已有章节：转移后保持目标本原章不动。
    final dAssigned = await diary('双在有章', notebookIds: <String>[parent, child]);
    await db.setNotebookEntriesChapter(parent, <String>[
      dUnassigned,
      dAssigned,
    ], 's1');
    await db.setNotebookEntriesChapter(child, <String>[dAssigned], 't1');

    final result = await db.transferNotebookContents(
      sourceId: parent,
      targetId: child,
    );
    expect(result.entryCount, 2);
    expect(await db.getNotebookContents(parent), isEmpty);

    final entries = await db.getNotebookContents(child);
    expect(entries, hasLength(2));
    expect(entries.firstWhere((e) => e.diaryId == dUnassigned).chapterId, 's1');
    expect(entries.firstWhere((e) => e.diaryId == dAssigned).chapterId, 't1');
  });

  test('normal parent skips trashed and external private diaries and clears '
      'dangling chapter IDs', () async {
    final ch = NotebookChapter(id: 'c1', title: '第一章');
    final parent = await notebook(
      '公开本',
      payload: NotebookPayload(chapters: <NotebookChapter>[ch]),
    );
    final child = await notebook('公开子本', parentId: parent);
    final secret = await notebook('秘密本', visibility: NotebookVisibility.hidden);

    final dVisible = await diary('可见', notebookIds: <String>[parent]);
    final dTrashed = await diary('已删', notebookIds: <String>[parent]);
    final dPrivate = await diary('私密', notebookIds: <String>[parent, secret]);
    await db.setNotebookEntriesChapter(parent, <String>[
      dVisible,
      dTrashed,
      dPrivate,
    ], 'c1');
    await db.softDeleteDiary(dTrashed);

    final result = await db.transferNotebookContents(
      sourceId: parent,
      targetId: child,
    );
    expect(result.chapterCount, 1);
    expect(result.entryCount, 1);

    final childEntries = await db.getNotebookContents(child);
    expect(childEntries.map((e) => e.diaryId), <String>[dVisible]);

    // 恢复回收站日记并把私密日记移出秘密本后，它们仍留在父本且 chapter_id 已清空。
    await db.restoreDiary(dTrashed);
    await db.removeDiariesFromNotebook(secret, <String>[dPrivate]);
    final remaining = await db.getNotebookContents(parent);
    expect(remaining.map((e) => e.diaryId).toSet(), <String>{
      dTrashed,
      dPrivate,
    });
    expect(remaining.every((e) => e.chapterId == null), isTrue);
  });

  test(
    'private parent transfers all its visible private entries to child',
    () async {
      final ch = NotebookChapter(id: 'c1', title: '私密章');
      final parent = await notebook(
        '私密父本',
        visibility: NotebookVisibility.locked,
        payload: NotebookPayload(chapters: <NotebookChapter>[ch]),
      );
      final child = await notebook('私密子本', parentId: parent);
      final d1 = await diary('秘密一', notebookIds: <String>[parent]);
      await db.setNotebookEntriesChapter(parent, <String>[d1], 'c1');

      final result = await db.transferNotebookContents(
        sourceId: parent,
        targetId: child,
      );
      expect(result.chapterCount, 1);
      expect(result.entryCount, 1);
      expect(await db.getNotebookContents(parent), isEmpty);
      final childEntries = await db.getNotebookContents(child);
      expect(childEntries.single.diaryId, d1);
      expect(childEntries.single.chapterId, 'c1');
    },
  );

  test(
    'rejects invalid targets and missing chapters without mutating data',
    () async {
      final ch = NotebookChapter(id: 'c1', title: '第一章');
      final parent = await notebook(
        '父本',
        payload: NotebookPayload(chapters: <NotebookChapter>[ch]),
      );
      final child = await notebook('子本', parentId: parent);
      final otherChild = await notebook('另一个子本', parentId: parent);
      final smartChild = await notebook(
        '智能子本',
        parentId: parent,
        kind: NotebookKind.smart,
      );
      final sibling = await notebook('平行本');
      final d1 = await diary('甲', notebookIds: <String>[parent]);
      await db.setNotebookEntriesChapter(parent, <String>[d1], 'c1');

      await expectLater(
        db.transferNotebookContents(sourceId: parent, targetId: parent),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        db.transferNotebookContents(sourceId: parent, targetId: sibling),
        throwsA(isA<ArgumentError>()),
      );
      // 同一上级下的兄弟本既不是上级也不是子孙。
      await expectLater(
        db.transferNotebookContents(sourceId: child, targetId: otherChild),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        db.transferNotebookContents(sourceId: parent, targetId: smartChild),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        db.transferNotebookContents(
          sourceId: parent,
          targetId: child,
          chapterId: 'missing',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 失败后源本数据完好无损。
      expect(
        (await db.getNotebook(parent))!.parsedPayload.chapters,
        <NotebookChapter>[ch],
      );
      expect((await db.getNotebookContents(parent)).single.diaryId, d1);
      expect(await db.getNotebookContents(child), isEmpty);
    },
  );

  Future<List<(String, String?)>> placements(String notebookId) async =>
      <(String, String?)>[
        for (final e in await db.getNotebookContents(notebookId))
          (e.diaryId, e.chapterId),
      ];

  Future<List<String>> chapterTitles(String notebookId) async => <String>[
    for (final c in (await db.getNotebook(notebookId))!.parsedPayload.chapters)
      c.title,
  ];

  test('transfers contents moved into a child back to the parent and from a '
      'grandchild up to the root', () async {
    final tokyo = NotebookChapter(id: 'c1', title: '东京');
    final kyoto = NotebookChapter(id: 'c2', title: '京都');
    final root = await notebook(
      '旅行',
      payload: NotebookPayload(chapters: <NotebookChapter>[tokyo, kyoto]),
    );
    final child = await notebook('日本', parentId: root);
    final grand = await notebook('关西', parentId: child);
    final d1 = await diary('浅草', notebookIds: <String>[root]);
    final d2 = await diary('岚山', notebookIds: <String>[root]);
    final d3 = await diary('随笔', notebookIds: <String>[root]);
    await db.setNotebookEntriesChapter(root, <String>[d1], 'c1');
    await db.setNotebookEntriesChapter(root, <String>[d2], 'c2');

    // 转到子本后再原路转回上级：章节与成书顺序都回来，子本清空。
    await db.transferNotebookContents(sourceId: root, targetId: child);
    expect(await placements(root), isEmpty);
    final back = await db.transferNotebookContents(
      sourceId: child,
      targetId: root,
    );
    expect(back.chapterCount, 2);
    expect(back.entryCount, 3);
    expect(await chapterTitles(root), <String>['东京', '京都']);
    expect(await placements(root), <(String, String?)>[
      (d1, 'c1'),
      (d2, 'c2'),
      (d3, null),
    ]);
    expect(await placements(child), isEmpty);
    expect(await chapterTitles(child), isEmpty);

    // 孙子本可以直接转到顶层的祖本（单个章节）。
    await db.transferNotebookContents(
      sourceId: root,
      targetId: grand,
      chapterId: 'c2',
    );
    await db.transferNotebookContents(
      sourceId: grand,
      targetId: root,
      chapterId: 'c2',
    );
    expect(await chapterTitles(root), <String>['东京', '京都']);
    expect((await placements(root)).firstWhere((p) => p.$1 == d2).$2, 'c2');
    expect(await placements(grand), isEmpty);
  });

  test('undo restores both notebooks exactly, including renamed chapter ids, '
      'pre-existing target entries and cleared hidden entries', () async {
    final srcCh = NotebookChapter(id: 'c1', title: '源章');
    final dstCh = NotebookChapter(id: 'c1', title: '目标同 id 章');
    final parent = await notebook(
      '父本',
      payload: NotebookPayload(chapters: <NotebookChapter>[srcCh]),
    );
    final child = await notebook(
      '子本',
      parentId: parent,
      payload: NotebookPayload(chapters: <NotebookChapter>[dstCh]),
    );
    final dKept = await diary('子本原有', notebookIds: <String>[child]);
    await db.setNotebookEntriesChapter(child, <String>[dKept], 'c1');
    final dMoved = await diary('搬走', notebookIds: <String>[parent]);
    final dLoose = await diary('未分章', notebookIds: <String>[parent]);
    // 两本都在、子本里未分章：转移时会被归入搬来的章节。
    final dBoth = await diary('双在', notebookIds: <String>[parent, child]);
    final dTrashed = await diary('回收站', notebookIds: <String>[parent]);
    await db.setNotebookEntriesChapter(parent, <String>[
      dMoved,
      dBoth,
      dTrashed,
    ], 'c1');
    await db.softDeleteDiary(dTrashed);

    final parentBefore = await placements(parent);
    final childBefore = await placements(child);
    final parentChaptersBefore = (await db.getNotebook(
      parent,
    ))!.parsedPayload.chapters;
    final childChaptersBefore = (await db.getNotebook(
      child,
    ))!.parsedPayload.chapters;

    final transfer = await db.transferNotebookContents(
      sourceId: parent,
      targetId: child,
    );
    expect(transfer.isEmpty, isFalse);
    // 撞 id 的章节换了新 id，双在的日记归入它。
    final moved = (await db.getNotebook(child))!.parsedPayload.chapters.last;
    expect(moved.id, isNot('c1'));
    expect(
      (await placements(child)).firstWhere((p) => p.$1 == dBoth).$2,
      moved.id,
    );
    expect((await placements(child)).last, (dLoose, null));

    await db.undoNotebookContentsTransfer(transfer);

    expect(await placements(parent), parentBefore);
    expect(await placements(child), childBefore);
    expect(
      (await db.getNotebook(parent))!.parsedPayload.chapters,
      parentChaptersBefore,
    );
    expect(
      (await db.getNotebook(child))!.parsedPayload.chapters,
      childChaptersBefore,
    );
    // 回收站里那篇的章节归属也回来了。
    await db.restoreDiary(dTrashed);
    expect(
      (await placements(parent)).firstWhere((p) => p.$1 == dTrashed).$2,
      'c1',
    );
  });

  test(
    'undo skips permanently deleted diaries instead of writing orphan rows',
    () async {
      final parent = await notebook('父本');
      final child = await notebook('子本', parentId: parent);
      final d1 = await diary('留下', notebookIds: <String>[parent]);
      final d2 = await diary('彻底删除', notebookIds: <String>[parent]);

      final transfer = await db.transferNotebookContents(
        sourceId: parent,
        targetId: child,
      );
      await db.hardDeleteDiary(d2);
      await db.undoNotebookContentsTransfer(transfer);

      expect(await placements(parent), <(String, String?)>[(d1, null)]);
      expect(await placements(child), isEmpty);
      final rows = await db.select(db.diaryNotebooks).get();
      expect(rows, hasLength(1));
    },
  );
}
