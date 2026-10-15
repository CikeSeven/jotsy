import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

/// 其他日记应用导出的端到端导入：预检不写数据，合并写入日记、标签与媒体，
/// 重复导入识别为已存在，结束后暂存区被清理。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  Future<File> dayOneZip({String text = 'Hello\n![](dayone-moment://P1)'}) {
    final journal = utf8.encode(
      jsonEncode({
        'metadata': {'version': '1.0'},
        'entries': [
          {
            'uuid': 'ENTRY-1',
            'creationDate': '2024-05-01T08:00:00Z',
            'text': text,
            'tags': ['travel', 'spring'],
            'photos': [
              {'identifier': 'P1', 'md5': 'abc', 'type': 'jpeg'},
            ],
          },
          {
            'uuid': 'ENTRY-2',
            'creationDate': '2024-05-02T08:00:00Z',
            'text': '# Second\nNo media',
            'tags': ['travel'],
          },
        ],
      }),
    );
    final photo = [0xFF, 0xD8, 0xFF, 0xE0];
    final archive = Archive()
      ..addFile(ArchiveFile('Journal.json', journal.length, journal))
      ..addFile(ArchiveFile('photos/abc.jpeg', photo.length, photo));
    final file = File(p.join(fixture.temporary.path, 'dayone.zip'));
    return file.writeAsBytes(ZipEncoder().encode(archive)!);
  }

  List<Directory> stagingDirectories() => fixture.documents
      .listSync()
      .whereType<Directory>()
      .where((dir) => p.basename(dir.path).startsWith('.journal_import_'))
      .toList();

  test(
    'previews, merges diaries with tags and media, then cleans up',
    () async {
      final session = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: (await dayOneZip()).path,
        tagColors: const [0xFF112233],
      );
      final preview = session.preview;
      expect(preview.kind, BackupArchiveKind.journalExport);
      expect(preview.journalSource, JournalImportSource.dayOne);
      expect((preview.diaryCount, preview.tagCount), (2, 2));
      expect(preview.existingDiaryCount, 0);
      expect(preview.availableModes, [BackupImportMode.merge]);
      // 预检不写数据库。
      expect(await fixture.database.select(fixture.database.diaries).get(), []);

      final result = await session.apply(
        database: fixture.database,
        mode: BackupImportMode.merge,
      );
      await session.dispose();

      expect(result.addedDiaries, 2);
      final diaries =
          await fixture.database.select(fixture.database.diaries).get()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(diaries.map((diary) => diary.title), ['', 'Second']);
      final first = diaries.first;
      expect(first.createdAt, DateTime.utc(2024, 5, 1, 8).toLocal());
      expect(first.contentText, deltaJsonToPlainText(first.content));
      final image =
          ((jsonDecode(first.content) as List).firstWhere(
                    (op) => (op as Map)['insert'] is Map,
                  )
                  as Map)['insert']['image']
              as String;
      expect(
        p.isWithin(p.join(fixture.documents.path, 'diary_images'), image),
        isTrue,
      );
      expect(await File(image).readAsBytes(), [0xFF, 0xD8, 0xFF, 0xE0]);
      final metadata = jsonDecode(first.metadata) as Map;
      expect(metadata['import'], {'source': 'dayOne', 'sourceKey': 'ENTRY-1'});

      final tags = await fixture.database.select(fixture.database.tags).get();
      expect(tags.map((tag) => tag.name).toSet(), {'travel', 'spring'});
      expect(tags.firstWhere((tag) => tag.name == 'travel').color, 0xFF112233);
      expect(
        await fixture.database.select(fixture.database.diaryTags).get(),
        hasLength(3),
      );
      expect(stagingDirectories(), isEmpty);
    },
  );

  test(
    'a second import of the same export is recognised and can overwrite',
    () async {
      final first = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: (await dayOneZip()).path,
      );
      await first.apply(
        database: fixture.database,
        mode: BackupImportMode.merge,
      );
      await first.dispose();

      final again = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: (await dayOneZip(text: 'Edited in Day One')).path,
      );
      expect(again.preview.existingDiaryCount, 2);
      expect(again.preview.availableModes, [
        BackupImportMode.merge,
        BackupImportMode.mergeOverwrite,
      ]);
      expect(
        () => again.apply(
          database: fixture.database,
          mode: BackupImportMode.replaceAll,
        ),
        throwsArgumentError,
      );
      final result = await again.apply(
        database: fixture.database,
        mode: BackupImportMode.mergeOverwrite,
      );
      await again.dispose();

      expect((result.addedDiaries, result.replacedDiaries), (0, 2));
      final texts =
          (await fixture.database.select(fixture.database.diaries).get()).map(
            (diary) => diary.contentText,
          );
      expect(texts, containsAll(['Edited in Day One', 'No media']));
    },
  );

  test('maps Daylio moods onto the user mood scale', () async {
    final csv = File(p.join(fixture.temporary.path, 'daylio.csv'))
      ..writeAsStringSync(
        'full_date,date,weekday,time,mood,activities,note_title,note\n'
        '2024-03-05,5 March,Tuesday,9:30 pm,rad,,Great,Yes\n'
        '2024-03-06,6 March,Wednesday,9:30 pm,awful,,Bad,No\n',
      );
    final moods = List<String>.generate(10, (index) => 'm${index + 1}');
    final session = await JournalImportService.prepare(
      database: fixture.database,
      source: JournalImportSource.daylio,
      filePath: csv.path,
      moodOptions: moods,
    );
    await session.apply(
      database: fixture.database,
      mode: BackupImportMode.merge,
    );
    await session.dispose();

    final byTitle = {
      for (final diary
          in await fixture.database.select(fixture.database.diaries).get())
        diary.title:
            (jsonDecode(diary.metadata) as Map)['context']['moodEmoji'],
    };
    expect(byTitle, {'Great': 'm10', 'Bad': 'm1'});
    expect(SettingsService.moodWeight('m10', moods), 10);
  });

  test(
    'rejects a file of another format and leaves no staging behind',
    () async {
      final other = File(p.join(fixture.temporary.path, 'notes.json'))
        ..writeAsStringSync('{"hello": "world"}');
      await expectLater(
        JournalImportService.prepare(
          database: fixture.database,
          source: JournalImportSource.journey,
          filePath: other.path,
        ),
        throwsA(
          isA<JournalImportFormatException>().having(
            (error) => error.noEntries,
            'noEntries',
            isFalse,
          ),
        ),
      );
      expect(stagingDirectories(), isEmpty);
    },
  );

  test('reports an export without entries separately', () async {
    final empty = File(p.join(fixture.temporary.path, 'Journal.json'))
      ..writeAsStringSync('{"metadata": {}, "entries": []}');
    await expectLater(
      JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.dayOne,
        filePath: empty.path,
      ),
      throwsA(
        isA<JournalImportFormatException>().having(
          (error) => error.noEntries,
          'noEntries',
          isTrue,
        ),
      ),
    );
  });
}
