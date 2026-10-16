import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('anniversary writes', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('create, update, pin, link and watch order', () async {
      final first = await db.createAnniversary(
        title: '  在一起  ',
        baseDate: DateTime(2020, 5, 23, 18, 30),
        recurrence: AnniversaryRecurrence.lunarYearly,
        lunar: (year: 2020, month: -4, day: 1),
        note: ' 第一次见面 ',
      );
      final second = await db.createAnniversary(
        title: '考试',
        baseDate: DateTime(2026, 12, 20),
        recurrence: AnniversaryRecurrence.once,
      );

      var rows = await db.watchAnniversaries().first;
      expect(rows.map((row) => row.anniversaryId), <String>[first, second]);
      final created = rows.first;
      expect(created.title, '在一起');
      expect(created.baseDate, '2020-05-23');
      expect(created.recurrence, 'lunarYearly');
      expect(
        (created.lunarYear, created.lunarMonth, created.lunarDay),
        (2020, -4, 1),
      );
      expect(created.note, '第一次见面');
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));

      await db.setAnniversaryPinned(second, true);
      rows = await db.watchAnniversaries().first;
      expect(rows.first.anniversaryId, second, reason: '置顶排在最前');

      await db.updateAnniversary(
        first,
        title: '纪念日',
        baseDate: DateTime(2020, 5, 24),
        recurrence: AnniversaryRecurrence.solarYearly,
      );
      final updated = await db.watchAnniversary(first).first;
      expect(updated?.title, '纪念日');
      expect(updated?.lunarMonth, isNull, reason: '非农历规则清掉快照');
      expect(updated?.createdAt, created.createdAt);

      await db.setAnniversaryLink(first, 'diary-1');
      expect(
        (await db.watchAnniversary(first).first)?.linkedDiaryId,
        'diary-1',
      );
    });

    test(
      'delete returns the row and restore brings it back unchanged',
      () async {
        final id = await db.createAnniversary(
          title: '生日',
          baseDate: DateTime(2000, 2, 29),
          recurrence: AnniversaryRecurrence.solarYearly,
          isPinned: true,
        );
        final before = (await db.watchAnniversaries().first).single;

        final deleted = await db.deleteAnniversary(id);
        expect(deleted, before);
        expect(await db.watchAnniversaries().first, isEmpty);
        expect(await db.deleteAnniversary(id), isNull);

        await db.restoreAnniversary(deleted!);
        expect((await db.watchAnniversaries().first).single, before);
      },
    );

    test('a blank name is rejected', () async {
      await expectLater(
        db.createAnniversary(
          title: '   ',
          baseDate: DateTime(2026),
          recurrence: AnniversaryRecurrence.once,
        ),
        throwsFormatException,
      );
      expect(await db.watchAnniversaries().first, isEmpty);
    });
  });

  test('anniversary dates parse strictly', () {
    expect(parseAnniversaryDate('2024-02-29'), DateTime(2024, 2, 29));
    expect(parseAnniversaryDate('2023-02-29'), isNull);
    expect(parseAnniversaryDate('2024-2-9'), isNull);
    expect(parseAnniversaryDate(''), isNull);
    expect(formatAnniversaryDate(DateTime(987, 3, 4)), '0987-03-04');
    expect(AnniversaryRecurrence.parse('weekly'), AnniversaryRecurrence.once);
  });

  group('migration', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('jotsy_anniv_mig');
    });
    tearDown(() => tempDir.delete(recursive: true));

    Future<Set<String>> tableNames(AppDatabase db) async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      return rows.map((row) => row.read<String>('name')).toSet();
    }

    void createTagTables(Database legacy) {
      legacy.execute('''
CREATE TABLE tags (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color INTEGER NOT NULL
);
''');
      legacy.execute('''
CREATE TABLE diary_tags (
  diary_id INTEGER NOT NULL REFERENCES diaries (id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
  PRIMARY KEY (diary_id, tag_id)
);
''');
    }

    test('v8 databases gain the table and keep their diaries', () async {
      final file = File('${tempDir.path}/v8.sqlite');
      final legacy = sqlite3.open(file.path);
      legacy.execute('''
CREATE TABLE diaries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  diary_id TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL,
  content_text TEXT NOT NULL,
  cover TEXT NULL,
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  archived_at INTEGER NULL,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  capsule_unlock_at INTEGER NULL,
  capsule_locked_at INTEGER NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER NULL
);
''');
      createTagTables(legacy);
      legacy.execute(
        "INSERT INTO diaries (diary_id, title, content, content_text, "
        "created_at, updated_at) VALUES ('keep', '旧日记', '[]', '', 1, 1)",
      );
      legacy.execute('PRAGMA user_version = 8;');
      legacy.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      expect(await tableNames(db), contains('anniversaries'));
      expect(
        (await db.select(db.diaries).get()).map((row) => row.diaryId),
        <String>['keep'],
      );
      await db.createAnniversary(
        title: '升级后',
        baseDate: DateTime(2026, 10, 16),
        recurrence: AnniversaryRecurrence.solarYearly,
      );
      expect(await db.watchAnniversaries().first, hasLength(1));
    });

    test('v1 databases gain the table despite the early return', () async {
      final file = File('${tempDir.path}/v1.sqlite');
      final legacy = sqlite3.open(file.path);
      legacy.execute('''
CREATE TABLE diaries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL,
  content_text TEXT NOT NULL,
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER NULL
);
''');
      createTagTables(legacy);
      legacy.execute('PRAGMA user_version = 1;');
      legacy.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        await tableNames(db),
        containsAll(<String>['anniversaries', 'diaries']),
      );
    });

    test('fresh databases have the table', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(await tableNames(db), contains('anniversaries'));
    });
  });
}
