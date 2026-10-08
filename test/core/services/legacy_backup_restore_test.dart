import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  for (final password in [null, 'legacy-password']) {
    for (final foreignKeys in [false, true]) {
      test(
        'legacy ${password == null ? 'plain' : 'encrypted'} backups with orphan bindings restore all records with foreign keys ${foreignKeys ? 'on' : 'off'}',
        () async {
          final db = fixture.database;
          await db.customStatement('PRAGMA foreign_keys = OFF');
          final original = await db.select(db.diaries).getSingle();
          final retainedTag = await db.createTag(
            name: 'retained',
            color: 0xff112233,
          );
          final removedTag = await db.createTag(
            name: 'removed',
            color: 0xff445566,
          );
          final removedDiaryId = await db.createDiary(
            title: 'removed diary',
            contentDocJson: '[{"insert":"removed\\n"}]',
            contentText: 'removed',
            metadataJson: '{}',
          );
          final removedDiary = (await db.select(db.diaries).get()).singleWhere(
            (row) => row.diaryId == removedDiaryId,
          );
          await db.batch((batch) {
            batch.insertAll(db.diaryTags, [
              DiaryTagsCompanion.insert(
                diaryId: original.id,
                tagId: retainedTag,
              ),
              DiaryTagsCompanion.insert(
                diaryId: original.id,
                tagId: removedTag,
              ),
              DiaryTagsCompanion.insert(
                diaryId: removedDiary.id,
                tagId: retainedTag,
              ),
              DiaryTagsCompanion.insert(
                diaryId: removedDiary.id,
                tagId: removedTag,
              ),
            ]);
          });
          // Reproduce historical deletion with foreign keys disabled. The older
          // exporter serialized the leftover bindings together with intact rows.
          await db.customStatement('DELETE FROM tags WHERE id = ?', [
            removedTag,
          ]);
          await db.customStatement('DELETE FROM diaries WHERE id = ?', [
            removedDiary.id,
          ]);
          final zip = await DataArchiveService.exportToZip(
            database: db,
            settingsService: fixture.settings,
            zipPassword: password,
          );
          expect(await db.select(db.diaryTags).get(), hasLength(4));
          await db.customStatement(
            'PRAGMA foreign_keys = ${foreignKeys ? 'ON' : 'OFF'}',
          );
          await fixture.import(zip, password: password);
          expect(await db.select(db.diaries).get(), hasLength(1));
          expect(
            (await db.select(db.diaries).getSingle()).diaryId,
            original.diaryId,
          );
          expect((await db.select(db.tags).getSingle()).id, retainedTag);
          expect(await db.select(db.diaryTags).get(), [
            DiaryTag(diaryId: original.id, tagId: retainedTag),
          ]);
          expect(
            (await db.getDiaryWithTagsByDiaryId(
              original.diaryId,
            ))!.tags.map((tag) => tag.id),
            [retainedTag],
          );
          await fixture.expectCurrentDataIntact();
        },
      );
    }
  }

  test(
    'legacy SQLite row id zero is retained along with valid tag bindings',
    () async {
      final payload = await fixture.capturePayload();
      final tables = payload['database'] as Map;
      final diary = (tables['diaries'] as List).single as Map;
      diary['id'] = 0;
      tables['tags'] = [
        {'id': 0, 'name': 'legacy zero id', 'color': 0xff112233},
      ];
      tables['diaryTags'] = [
        {'diaryId': 0, 'tagId': 0},
      ];
      final files = {
        for (final entry in fixture.originalMedia.entries)
          p.relative(entry.key, from: fixture.documents.path): entry.value,
      };
      await fixture.import(await fixture.writeZip(payload, files: files));
      expect(
        (await fixture.database.select(fixture.database.diaries).getSingle())
            .id,
        0,
      );
      expect(
        (await fixture.database.select(fixture.database.tags).getSingle()).id,
        0,
      );
      expect(await fixture.database.select(fixture.database.diaryTags).get(), [
        const DiaryTag(diaryId: 0, tagId: 0),
      ]);
      await fixture.expectCurrentDataIntact();
    },
  );
}
