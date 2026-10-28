import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    String? body,
    DateTime? unlockAt,
    List<String>? notebookIds,
  }) {
    final text = body ?? title;
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$text\\n"}]',
      contentText: text,
      metadataJson: '{}',
      notebookIds: notebookIds,
      createdAtOverride: DateTime.now().subtract(const Duration(days: 10)),
      capsuleUnlockAt: unlockAt,
      capsuleLockedAt: unlockAt == null
          ? null
          : DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  Future<List<DiaryCommentRow>> comments(String diaryId) =>
      db.watchDiaryComments(diaryId).first;

  group('diary comments', () {
    test('writes trimmed comments in order with an optional mood', () async {
      final id = await diary('a');
      await db.addDiaryComment(diaryId: id, content: '  第一条  ');
      await db.addDiaryComment(diaryId: id, content: '第二条', mood: '😊');
      await db.addDiaryComment(diaryId: id, content: '第三条', mood: '  ');

      final rows = await comments(id);
      expect(rows.map((row) => row.content), <String>['第一条', '第二条', '第三条']);
      expect(rows.map((row) => row.mood), <String?>[null, '😊', null]);
      expect(rows.every((row) => row.editedAt == null), isTrue);
    });

    test('a blank comment is rejected', () async {
      final id = await diary('a');
      await expectLater(
        db.addDiaryComment(diaryId: id, content: ' \n '),
        throwsFormatException,
      );
      expect(await comments(id), isEmpty);
    });

    test('editing marks it edited only when something changed', () async {
      final id = await diary('a');
      final commentId = await db.addDiaryComment(diaryId: id, content: '原话');
      final created = (await comments(id)).single.createdAt;

      expect(await db.updateDiaryComment(commentId, content: ' 原话 '), isFalse);
      expect((await comments(id)).single.editedAt, isNull);

      expect(
        await db.updateDiaryComment(commentId, content: '改过', mood: '🙂'),
        isTrue,
      );
      final edited = (await comments(id)).single;
      expect(edited.content, '改过');
      expect(edited.mood, '🙂');
      expect(edited.editedAt, isNotNull);
      // 写下的时间不随编辑改变：时间线按它排序、相对时间从它算起。
      expect(edited.createdAt, created);
    });

    test(
      'deleting returns the row and undo writes it back as it was',
      () async {
        final id = await diary('a');
        final commentId = await db.addDiaryComment(
          diaryId: id,
          content: '要删的',
          mood: '😢',
        );
        final before = (await comments(id)).single;
        final removed = await db.deleteDiaryComment(commentId);
        expect(removed, before);
        expect(await comments(id), isEmpty);
        expect(await db.deleteDiaryComment(commentId), isNull);

        await db.restoreDiaryComment(removed!);
        expect((await comments(id)).single, before);
      },
    );

    test('counts are per diary', () async {
      final a = await diary('a');
      final b = await diary('b');
      await db.addDiaryComment(diaryId: a, content: '1');
      await db.addDiaryComment(diaryId: a, content: '2');
      await db.addDiaryComment(diaryId: b, content: '3');
      await diary('c');

      expect(await db.watchDiaryCommentCounts().first, <String, int>{
        a: 2,
        b: 1,
      });
    });

    test('export reads several diaries at once, oldest first', () async {
      final a = await diary('a');
      final b = await diary('b');
      await db.addDiaryComment(diaryId: a, content: 'a1');
      await db.addDiaryComment(diaryId: b, content: 'b1');
      await db.addDiaryComment(diaryId: a, content: 'a2');

      final grouped = await db.getDiaryCommentsFor(<String>[a, b, 'missing']);
      expect(grouped.keys.toSet(), <String>{a, b});
      expect(grouped[a]!.map((row) => row.content), <String>['a1', 'a2']);
    });

    test(
      'deleting a diary for good removes its comments, the trash does not',
      () async {
        final id = await diary('a');
        final other = await diary('b');
        await db.addDiaryComment(diaryId: id, content: '留着');
        await db.addDiaryComment(diaryId: other, content: '别人的');

        await db.softDeleteDiary(id);
        await db.restoreDiary(id);
        expect(await comments(id), hasLength(1));

        await db.softDeleteDiary(id);
        await db.hardDeleteDiary(id);
        expect(await comments(id), isEmpty);
        expect(await comments(other), hasLength(1));
      },
    );
  });

  group('looking back across diaries', () {
    test(
      'recent comments and timings skip trash, sealed and private diaries',
      () async {
        final secret = await db.createNotebook(
          name: 'secret',
          visibility: NotebookVisibility.hidden,
        );
        final plain = await diary('plain');
        final archived = await diary('archived');
        await db.archiveDiary(archived);
        final trashed = await diary('trashed');
        final sealed = await diary(
          'sealed',
          unlockAt: DateTime.now().add(const Duration(days: 3)),
        );
        final private = await diary('private', notebookIds: <String>[secret]);
        for (final id in <String>[plain, archived, trashed, sealed, private]) {
          await db.addDiaryComment(diaryId: id, content: 'note $id');
        }
        await db.softDeleteDiary(trashed);

        final recent = await db.watchRecentDiaryComments(limit: 10).first;
        expect(recent.map((row) => row.diaryId).toSet(), <String>{
          plain,
          archived,
        });
        expect(recent.first.diaryTitle, isNotEmpty);

        final timings = await db.watchDiaryCommentTimings().first;
        expect(timings.map((row) => row.diaryId).toSet(), <String>{
          plain,
          archived,
        });
        expect(await db.watchRecentDiaryComments(limit: 1).first, hasLength(1));
      },
    );

    test('comment hits keep the first matching comment per diary', () async {
      final a = await diary('a');
      final b = await diary('b');
      await db.addDiaryComment(diaryId: a, content: '没提到');
      await db.addDiaryComment(diaryId: a, content: '后来去了海边');
      await db.addDiaryComment(diaryId: a, content: '海边真好');
      await db.addDiaryComment(diaryId: b, content: '山里');

      final hits = await db.watchDiaryCommentHits('海边').first;
      expect(hits.keys, <String>[a]);
      expect(hits[a]!.content, '后来去了海边');
      expect(await db.watchDiaryCommentHits('  ').first, isEmpty);
    });

    test('search matches comments only when asked to', () async {
      final viaComment = await diary('标题', body: '正文');
      final sealed = await diary(
        '胶囊',
        body: '正文',
        unlockAt: DateTime.now().add(const Duration(days: 3)),
      );
      await diary('无关', body: '正文');
      await db.addDiaryComment(diaryId: viaComment, content: '想起了灯塔');
      await db.addDiaryComment(diaryId: sealed, content: '灯塔');

      Future<Set<String>> search({required bool matchComments}) async {
        final rows = await db
            .watchDiaries(keyword: '灯塔', matchComments: matchComments)
            .first;
        return rows.map((row) => row.diary.diaryId).toSet();
      }

      expect(await search(matchComments: false), isEmpty);
      // 未解封的胶囊只按标题匹配，留言与正文一样看不到。
      expect(await search(matchComments: true), <String>{viaComment});
      expect(
        await db.getActiveDiaryIds(keyword: '灯塔', matchComments: true),
        <String>[viaComment],
      );
    });
  });

  group('schema v16 migration', () {
    Future<File> v15DatabaseFile({required bool keepCommentsTable}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v16_comments');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v15.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final id = await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        if (keepCommentsTable) {
          await original.addDiaryComment(diaryId: id, content: '降级前写的');
        }
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (!keepCommentsTable) legacy.execute('DROP TABLE diary_comments');
      legacy.execute('PRAGMA user_version = 15');
      legacy.close();
      return file;
    }

    test('v15 upgrade creates the table and keeps the diaries', () async {
      final file = await v15DatabaseFile(keepCommentsTable: false);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final diary = await migrated.select(migrated.diaries).getSingle();
        expect(diary.title, '升级前的日记');
        await migrated.addDiaryComment(diaryId: diary.diaryId, content: '新的');
        expect(
          await migrated.watchDiaryComments(diary.diaryId).first,
          hasLength(1),
        );
      } finally {
        await migrated.close();
      }
    });

    test('upgrading over a table a downgrade left keeps its rows', () async {
      final file = await v15DatabaseFile(keepCommentsTable: true);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final rows = await migrated.select(migrated.diaryComments).get();
        expect(rows.single.content, '降级前写的');
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
