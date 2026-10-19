import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';
import '../../support/journal_export_samples.dart';
import '../../support/journal_import_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  List<Directory> staging() => fixture.documents
      .listSync()
      .whereType<Directory>()
      .where(
        (directory) =>
            p.basename(directory.path).startsWith('.journal_import_'),
      )
      .toList();

  for (final source in JournalImportSource.values.where(
    (source) => !cloudJournalSources.contains(source),
  )) {
    test(
      '${source.name} preserves text and media through merge and repeated import',
      () async {
        final localId = await fixture.seedCurrentData();
        final file = await writeJournalExportSample(fixture.temporary, source);
        final session = await JournalImportService.prepare(
          database: fixture.database,
          source: source,
          filePath: file.path,
        );
        expect(session.preview.diaryCount, 1);
        expect(session.preview.missingMediaCount, 0);
        expect(session.preview.skippedNotes, isEmpty);
        await fixture.expectCurrentDataIntact();

        final result = await session.apply(
          database: fixture.database,
          mode: BackupImportMode.merge,
        );
        await session.dispose();
        expect(result.addedDiaries, 1);
        final rows = await fixture.database
            .select(fixture.database.diaries)
            .get();
        final diary = rows.singleWhere((row) => row.diaryId != localId);
        expect(diary.contentText, contains('正文 😀'));
        expect(diary.contentText, deltaJsonToPlainText(diary.content));
        expect(
          (jsonDecode(diary.metadata) as Map)['import']['source'],
          source.name,
        );
        final embeds = (jsonDecode(diary.content) as List).where(
          (op) => (op as Map)['insert'] is Map,
        );
        final image =
            ((embeds.single as Map)['insert'] as Map)['image'] as String;
        expect(
          p.isWithin(p.join(fixture.documents.path, 'diary_images'), image),
          isTrue,
        );
        expect(File(image).readAsBytesSync(), JournalImportFixture.jpeg);
        expect(staging(), isEmpty);

        for (final mode in [
          BackupImportMode.merge,
          BackupImportMode.mergeOverwrite,
        ]) {
          final again = await JournalImportService.prepare(
            database: fixture.database,
            source: source,
            filePath: file.path,
          );
          expect(again.preview.existingDiaryCount, 1);
          final repeated = await again.apply(
            database: fixture.database,
            mode: mode,
          );
          await again.dispose();
          expect(repeated.addedDiaries, 0);
          expect(
            repeated.replacedDiaries,
            mode == BackupImportMode.mergeOverwrite ? 1 : 0,
          );
          expect(
            await fixture.database.select(fixture.database.diaries).get(),
            hasLength(2),
          );
        }
        expect(
          (await fixture.database
                  .select(fixture.database.diaryDrafts)
                  .getSingle())
              .draftId,
          'current-draft',
        );
        expect(
          (await fixture.database
                  .select(fixture.database.diaryTemplates)
                  .getSingle())
              .templateId,
          'current-template',
        );
        expect(
          (await fixture.database
                  .select(fixture.database.anniversaries)
                  .getSingle())
              .title,
          'current anniversary',
        );
        for (final entry in fixture.originalMedia.entries) {
          expect(File(entry.key).readAsBytesSync(), entry.value);
        }
      },
    );
  }

  test(
    'disposing while apply is queued keeps media until the transaction ends',
    () async {
      final file = await writeJournalExportSample(
        fixture.temporary,
        JournalImportSource.dayOne,
      );
      final session = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: file.path,
      );
      final release = Completer<void>();
      final blocker = DataArchiveService.runSerialized(() => release.future);
      final application = session.apply(
        database: fixture.database,
        mode: BackupImportMode.merge,
      );
      var disposed = false;
      final disposal = session.dispose().then((_) => disposed = true);
      await Future<void>.delayed(Duration.zero);
      expect(disposed, isFalse);
      expect(staging(), hasLength(1));
      release.complete();
      await blocker;
      expect((await application).addedDiaries, 1);
      await disposal;
      expect(staging(), isEmpty);
    },
  );

  test(
    'a disposed session cannot write or leave a broken media reference',
    () async {
      final file = await writeJournalExportSample(
        fixture.temporary,
        JournalImportSource.dayOne,
      );
      final session = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: file.path,
      );
      await session.dispose();
      expect(
        () => session.apply(
          database: fixture.database,
          mode: BackupImportMode.merge,
        ),
        throwsStateError,
      );
      expect(
        await fixture.database.select(fixture.database.diaries).get(),
        isEmpty,
      );
    },
  );

  test('concurrent preparation leaves both live sessions intact', () async {
    final file = await writeJournalExportSample(
      fixture.temporary,
      JournalImportSource.dayOne,
    );
    final sessions = await Future.wait(
      List.generate(
        2,
        (_) => JournalImportService.prepare(
          database: fixture.database,
          source: JournalImportSource.dayOne,
          filePath: file.path,
        ),
      ),
    );
    expect(staging(), hasLength(2));
    for (final session in sessions) {
      await session.apply(
        database: fixture.database,
        mode: BackupImportMode.merge,
      );
      await session.dispose();
    }
    expect(
      await fixture.database.select(fixture.database.diaries).get(),
      hasLength(1),
    );
    expect(staging(), isEmpty);
  });

  test(
    'partial ENEX content is explained and its ciphertext survives backup',
    () async {
      final file = File(p.join(fixture.temporary.path, 'Mixed.enex'))
        ..writeAsStringSync(
          '<en-export><note><title>Mixed</title><created>20240229T083000Z</created>'
          '<content><![CDATA[<en-note><div>Visible</div><en-crypt hint="hint">ciphertext</en-crypt></en-note>]]>'
          '</content></note></en-export>',
        );
      final session = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.evernote,
        filePath: file.path,
      );
      expect(session.preview.partialContentCount, 1);
      await session.apply(
        database: fixture.database,
        mode: BackupImportMode.merge,
      );
      await session.dispose();
      final diary = await fixture.database
          .select(fixture.database.diaries)
          .getSingle();
      expect(diary.contentText, 'Visible');
      final backup = await fixture.capturePayload();
      final database = backup['database'] as Map;
      final metadata =
          jsonDecode(
                ((database['diaries'] as List).single as Map)['metadata']
                    as String,
              )
              as Map;
      expect(metadata['import']['details']['encryptedFragments'], [
        {'hint': 'hint', 'ciphertext': 'ciphertext'},
      ]);
    },
  );

  test(
    'an entirely unreadable export reports the skipped count without writing',
    () async {
      await fixture.seedCurrentData();
      final file = File(p.join(fixture.temporary.path, 'Bad.json'))
        ..writeAsStringSync(
          jsonEncode({
            'entries': [
              {
                'uuid': 'one',
                'creationDate': '2024-02-30T08:00:00Z',
                'text': 'Invalid date',
              },
            ],
          }),
        );
      await expectLater(
        JournalImportService.prepare(
          database: fixture.database,
          source: JournalImportSource.dayOne,
          filePath: file.path,
        ),
        throwsA(
          isA<JournalImportFormatException>().having(
            (error) => error.skippedNotes,
            'skippedNotes',
            {JournalSkipReason.unreadable: 1},
          ),
        ),
      );
      await fixture.expectCurrentDataIntact();
      expect(staging(), isEmpty);
    },
  );

  test(
    'a database failure rolls back imported media and leaves local data intact',
    () async {
      await fixture.seedCurrentData();
      final file = await writeJournalExportSample(
        fixture.temporary,
        JournalImportSource.dayOne,
      );
      final session = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: file.path,
      );
      await fixture.database.customStatement(
        "CREATE TRIGGER reject_import BEFORE INSERT ON diaries BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        session.apply(database: fixture.database, mode: BackupImportMode.merge),
        throwsA(anything),
      );
      await session.dispose();
      await fixture.expectCurrentDataIntact();
      expect(staging(), isEmpty);
      expect(
        fixture.documents
            .listSync(recursive: true)
            .whereType<Directory>()
            .where(
              (directory) => p.basename(directory.path).startsWith('import_'),
            ),
        isEmpty,
      );
    },
  );
}
