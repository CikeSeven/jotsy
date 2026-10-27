import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/calendar/providers/day_mood_providers.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<DateTime, DayMood>> moods() async =>
      indexDayMoods(await db.watchDayMoods().first);

  group('day moods', () {
    test(
      'setting a mood keys it by the date and a second one replaces it',
      () async {
        await db.setDayMood(DateTime(2026, 10, 27, 23, 59), DayMood.good);
        await db.setDayMood(DateTime(2026, 10, 27, 8), DayMood.great);
        await db.setDayMood(DateTime(2026, 10, 28), DayMood.awful);

        final rows = await db.select(db.dayMoods).get();
        expect(rows.map((row) => row.day), <String>[
          '2026-10-27',
          '2026-10-28',
        ]);
        expect(await moods(), <DateTime, DayMood>{
          DateTime(2026, 10, 27): DayMood.great,
          DateTime(2026, 10, 28): DayMood.awful,
        });
      },
    );

    test('clearing returns the removed row and undo writes it back', () async {
      await db.setDayMood(DateTime(2026, 10, 27), DayMood.meh);
      final removed = await db.clearDayMood(DateTime(2026, 10, 27, 12));
      expect(removed?.mood, DayMood.meh.name);
      expect(await moods(), isEmpty);

      await db.restoreDayMood(removed!);
      expect(await db.select(db.dayMoods).getSingle(), removed);
    });

    test('clearing a day without a mood is a no-op', () async {
      await db.setDayMood(DateTime(2026, 10, 27), DayMood.bad);
      expect(await db.clearDayMood(DateTime(2026, 10, 26)), isNull);
      expect(await moods(), hasLength(1));
    });

    test('the calendar index skips rows it cannot read', () async {
      final now = DateTime(2026, 10, 27);
      final index = indexDayMoods(<DayMoodRow>[
        DayMoodRow(day: '2026-10-27', mood: 'good', updatedAt: now),
        // 更新版本写入的新心情：保留在库里，日历上按没有心情显示。
        DayMoodRow(day: '2026-10-28', mood: 'ecstatic', updatedAt: now),
        DayMoodRow(day: '2026-02-30', mood: 'good', updatedAt: now),
      ]);
      expect(index, <DateTime, DayMood>{DateTime(2026, 10, 27): DayMood.good});
    });
  });

  group('schema v14 migration', () {
    Future<File> v13DatabaseFile({required bool keepMoodsTable}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v14_mood');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v13.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        if (keepMoodsTable) {
          await original.setDayMood(DateTime(2026, 1, 1), DayMood.great);
        }
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (!keepMoodsTable) legacy.execute('DROP TABLE day_moods');
      legacy.execute('PRAGMA user_version = 13');
      legacy.close();
      return file;
    }

    test('v13 upgrade creates the table and keeps the diaries', () async {
      final file = await v13DatabaseFile(keepMoodsTable: false);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await migrated.setDayMood(DateTime(2026, 10, 27), DayMood.good);
        expect(
          indexDayMoods(await migrated.watchDayMoods().first),
          <DateTime, DayMood>{DateTime(2026, 10, 27): DayMood.good},
        );
        final diaries = await migrated.select(migrated.diaries).get();
        expect(diaries.single.title, '升级前的日记');
      } finally {
        await migrated.close();
      }
    });

    test('upgrading over a table a downgrade left keeps its rows', () async {
      final file = await v13DatabaseFile(keepMoodsTable: true);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          indexDayMoods(await migrated.watchDayMoods().first),
          <DateTime, DayMood>{DateTime(2026, 1, 1): DayMood.great},
        );
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
