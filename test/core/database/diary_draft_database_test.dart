import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> save(String title, DateTime at, {String? draftId}) {
    return db.saveDiaryDraft(
      draftId: draftId,
      title: title,
      contentText: '$title 正文',
      payload: '{"title":"$title"}',
      now: at,
    );
  }

  test('saving without an id creates a draft and returns its id', () async {
    final id = await save('第一份', DateTime(2026, 10, 18, 9));
    final row = (await db.getDiaryDraft(id))!;
    expect(row.title, '第一份');
    expect(row.contentText, '第一份 正文');
    expect(row.payload, '{"title":"第一份"}');
    expect(row.createdAt, DateTime(2026, 10, 18, 9));
    expect(row.updatedAt, DateTime(2026, 10, 18, 9));
  });

  test('saving with an id updates that draft and keeps createdAt', () async {
    final id = await save('原标题', DateTime(2026, 10, 18, 9));
    final other = await save('另一份', DateTime(2026, 10, 18, 9, 30));
    await save('改过的标题', DateTime(2026, 10, 18, 10), draftId: id);

    final row = (await db.getDiaryDraft(id))!;
    expect(row.title, '改过的标题');
    expect(row.createdAt, DateTime(2026, 10, 18, 9));
    expect(row.updatedAt, DateTime(2026, 10, 18, 10));
    expect((await db.getDiaryDraft(other))!.title, '另一份');
    expect(await db.countDiaryDrafts(), 2);
  });

  test('saving with an id that no longer exists inserts it again', () async {
    final id = await save('被删的', DateTime(2026, 10, 18, 9));
    await db.deleteDiaryDrafts([id]);
    expect(await db.getDiaryDraft(id), isNull);

    final again = await save('编辑页还在写', DateTime(2026, 10, 18, 10), draftId: id);
    expect(again, id);
    expect((await db.getDiaryDraft(id))!.title, '编辑页还在写');
  });

  test('drafts are listed with the most recently edited first', () async {
    final older = await save('早', DateTime(2026, 10, 17));
    final newer = await save('晚', DateTime(2026, 10, 18));
    expect((await db.watchDiaryDrafts().first).map((row) => row.draftId), [
      newer,
      older,
    ]);

    await save('早（刚改）', DateTime(2026, 10, 19), draftId: older);
    expect((await db.watchDiaryDrafts().first).map((row) => row.draftId), [
      older,
      newer,
    ]);
    expect((await db.getRecentDiaryDrafts(1)).map((row) => row.draftId), [
      older,
    ]);
  });

  test('restoring deleted drafts puts the same rows back', () async {
    final a = await save('甲', DateTime(2026, 10, 17));
    final b = await save('乙', DateTime(2026, 10, 18));
    final before = await db.watchDiaryDrafts().first;

    await db.deleteDiaryDrafts([a, b]);
    expect(await db.watchDiaryDraftCount().first, 0);

    await db.restoreDiaryDrafts(before);
    expect(await db.watchDiaryDrafts().first, before);
  });

  group('schema v11 migration', () {
    Future<File> v10DatabaseFile({required bool keepDraftsTable}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v11_drafts');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v10.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        if (keepDraftsTable) {
          await original.saveDiaryDraft(
            draftId: 'kept-draft',
            title: '降级时留下的草稿',
            contentText: '',
            payload: '{}',
          );
        }
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (!keepDraftsTable) legacy.execute('DROP TABLE diary_drafts');
      legacy.execute('PRAGMA user_version = 10');
      legacy.close();
      return file;
    }

    test('v10 upgrade creates the drafts table and keeps diaries', () async {
      final file = await v10DatabaseFile(keepDraftsTable: false);
      for (var attempt = 0; attempt < 2; attempt++) {
        final migrated = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(await migrated.countDiaryDrafts(), attempt);
          if (attempt == 0) {
            await migrated.saveDiaryDraft(
              title: '升级后新写的',
              contentText: '',
              payload: '{}',
            );
          }
          final diaries = await migrated.select(migrated.diaries).get();
          expect(diaries.single.title, '升级前的日记');
        } finally {
          await migrated.close();
        }
      }
    });

    test(
      'upgrading over a drafts table a downgrade left keeps its drafts',
      () async {
        final file = await v10DatabaseFile(keepDraftsTable: true);
        final migrated = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final row = (await migrated.getDiaryDraft('kept-draft'))!;
          expect(row.title, '降级时留下的草稿');
          final version = await migrated
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), migrated.schemaVersion);
        } finally {
          await migrated.close();
        }
      },
    );
  });
}
