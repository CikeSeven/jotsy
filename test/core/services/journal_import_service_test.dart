import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/notebook_payload.dart';
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

  /// 两个日记本的 Day One 导出：只有一本时不记日记本，所以至少要两本。
  /// [withUnreadable] 时 Travel 里再夹两条读不出来的条目（不是对象、缺创建
  /// 时间），解析会按“无法识别”跳过它们。
  Future<File> dayOneTwoJournalsZip({bool withUnreadable = false}) {
    final archive = Archive();
    for (final (name, keys) in [
      ('Travel', ['T1', 'T2']),
      ('Work', ['W1']),
    ]) {
      final bytes = utf8.encode(
        jsonEncode({
          'entries': [
            for (final (index, key) in keys.indexed)
              {
                'uuid': key,
                'creationDate': '2024-05-0${index + 1}T08:00:00Z',
                'text': key,
              },
            if (withUnreadable && name == 'Travel') ...[
              'not an entry',
              {'uuid': 'NO-DATE', 'text': 'undated'},
            ],
          ],
        }),
      );
      archive.addFile(ArchiveFile('$name.json', bytes.length, bytes));
    }
    final file = File(p.join(fixture.temporary.path, 'journals.zip'));
    return file.writeAsBytes(ZipEncoder().encode(archive)!);
  }

  Future<void> importJournals(BackupImportMode mode) async {
    final session = await JournalImportService.prepare(
      database: fixture.database,
      source: JournalImportSource.dayOne,
      filePath: (await dayOneTwoJournalsZip()).path,
    );
    try {
      await session.apply(database: fixture.database, mode: mode);
    } finally {
      await session.dispose();
    }
  }

  test(
    'keeps source journals as notebooks and re-imports into the same ones',
    () async {
      final db = fixture.database;
      await importJournals(BackupImportMode.merge);

      final notebooks = await db.getNotebooks();
      expect(notebooks.map((row) => row.name).toSet(), {'Travel', 'Work'});
      final travel = notebooks.firstWhere((row) => row.name == 'Travel');
      Future<List<String>> members(String notebookId) async {
        final rows = await db.select(db.diaryNotebooks).get();
        final notebook = await db.getNotebook(notebookId);
        final diaries = {
          for (final diary in await db.select(db.diaries).get())
            diary.id: diary.contentText,
        };
        return [
          for (final row in rows..sort((a, b) => a.position - b.position))
            if (row.notebookId == notebook!.id) diaries[row.diaryId]!,
        ];
      }

      expect(await members(travel.notebookId), ['T1', 'T2']);
      // 默认落成日记本，不再把日记本名加成标签。
      expect(await db.select(db.tags).get(), isEmpty);

      // 用户之后给这本换了图标与颜色、改了名字。
      await db.updateNotebook(
        travel.notebookId,
        name: 'Trips',
        payload: NotebookPayload(icon: 'plane', color: 0xFF123456),
      );
      final edited = await db.getNotebook(travel.notebookId);

      final again = await JournalImportService.prepare(
        database: db,
        source: JournalImportSource.dayOne,
        filePath: (await dayOneTwoJournalsZip()).path,
      );
      expect(again.preview.existingNotebookCount, 2);
      await again.apply(database: db, mode: BackupImportMode.mergeOverwrite);
      await again.dispose();

      // 覆盖导入用的是本机那一行的原样拷贝：名称、图标、颜色都保留。
      expect(await db.getNotebook(travel.notebookId), edited);
      expect(await db.getNotebooks(), hasLength(2));
      expect(await members(travel.notebookId), ['T1', 'T2']);
      expect(await db.select(db.diaryNotebooks).get(), hasLength(3));
    },
  );

  test('tags mode lands source journals as tags only', () async {
    final session = await JournalImportService.prepare(
      database: fixture.database,
      source: JournalImportSource.dayOne,
      filePath: (await dayOneTwoJournalsZip()).path,
      folderMode: JournalImportFolderMode.tags,
    );
    await session.apply(
      database: fixture.database,
      mode: BackupImportMode.merge,
    );
    await session.dispose();

    expect(await fixture.database.getNotebooks(), isEmpty);
    final tags = await fixture.database.select(fixture.database.tags).get();
    expect(tags.map((tag) => tag.name).toSet(), {'Travel', 'Work'});
  });

  test('a session without source folders offers no folder choice', () async {
    final session = await JournalImportService.prepare(
      database: fixture.database,
      source: JournalImportSource.dayOne,
      filePath: (await dayOneZip()).path,
    );
    addTearDown(session.dispose);
    expect(session.hasSourceFolders, isFalse);
    expect(session.sourceFolderCount, 0);
    expect(
      session.previewFor(JournalImportFolderMode.tags).tagCount,
      session.preview.tagCount,
    );
  });

  test('every folder mode previews the notes the parse skipped', () async {
    final session = await JournalImportService.prepare(
      database: fixture.database,
      source: JournalImportSource.dayOne,
      filePath: (await dayOneTwoJournalsZip(withUnreadable: true)).path,
    );
    addTearDown(session.dispose);
    expect(session.hasSourceFolders, isTrue);
    // 跳过的篇数来自解析，与来源文件夹落成什么无关：切换方式后预览照样说明。
    for (final mode in JournalImportFolderMode.values) {
      final preview = session.previewFor(mode);
      expect(preview.diaryCount, 3, reason: mode.name);
      expect(preview.skippedNotes, {
        JournalSkipReason.unreadable: 2,
      }, reason: mode.name);
    }
  });

  group('the folder mode chosen after parsing', () {
    final expectations = {
      JournalImportFolderMode.notebooks: (
        notebooks: {'Travel', 'Work'},
        tags: <String>{},
      ),
      JournalImportFolderMode.tags: (
        notebooks: <String>{},
        tags: {'Travel', 'Work'},
      ),
      JournalImportFolderMode.both: (
        notebooks: {'Travel', 'Work'},
        tags: {'Travel', 'Work'},
      ),
    };
    for (final MapEntry(key: mode, value: expected) in expectations.entries) {
      test('${mode.name} is what gets written', () async {
        final db = fixture.database;
        final session = await JournalImportService.prepare(
          database: db,
          source: JournalImportSource.dayOne,
          filePath: (await dayOneTwoJournalsZip()).path,
        );
        expect(session.hasSourceFolders, isTrue);
        expect(session.sourceFolderCount, 2);
        expect(session.folderMode, JournalImportFolderMode.notebooks);
        // 预检按方式预先算好：标签数跟着方式变。
        expect(session.previewFor(mode).tagCount, expected.tags.length);
        // 同一方式的载荷只建一次。
        expect(
          identical(session.payloadFor(mode), session.payloadFor(mode)),
          isTrue,
        );

        await session.apply(
          database: db,
          mode: BackupImportMode.merge,
          folderMode: mode,
        );
        await session.dispose();

        expect(
          (await db.getNotebooks()).map((row) => row.name).toSet(),
          expected.notebooks,
        );
        expect(
          (await db.select(db.tags).get()).map((tag) => tag.name).toSet(),
          expected.tags,
        );
        expect(
          await db.select(db.diaryNotebooks).get(),
          hasLength(expected.notebooks.isEmpty ? 0 : 3),
        );
      });
    }
  });

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

  test('dates undated Markdown notes by their time inside the ZIP', () async {
    final bytes = utf8.encode('Walked by the river.');
    final archive = Archive()
      ..addFile(
        ArchiveFile('Notes/River walk.md', bytes.length, bytes)
          ..lastModTime =
              DateTime(2023, 6, 1, 7, 30).millisecondsSinceEpoch ~/ 1000,
      );
    final zip = File(p.join(fixture.temporary.path, 'vault.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);

    final session = await JournalImportService.prepare(
      database: fixture.database,
      source: JournalImportSource.markdown,
      filePath: zip.path,
    );
    await session.apply(
      database: fixture.database,
      mode: BackupImportMode.merge,
    );
    await session.dispose();

    final diary =
        (await fixture.database.select(fixture.database.diaries).get()).single;
    expect(diary.title, 'River walk');
    expect(diary.createdAt, DateTime(2023, 6, 1, 7, 30));
  });
}
