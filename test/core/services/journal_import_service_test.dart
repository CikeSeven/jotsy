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

  /// 「笔记互迁」的打包导出：同一组笔记分别导出为 HTML 与 Markdown。
  Future<File> noteBridgeZip(String format) {
    const stamp =
        '创建时间：2024-11-03 08:30:05+08:00\n修改时间：2024-11-04 10:00:00+08:00';
    final body = switch (format) {
      'html' =>
        '<html><head><title>小米笔记 · 笔记互迁</title></head><body>'
            '<script id="note-data" type="application/json">${jsonEncode([
              {'html': '<h2>周末计划</h2><div class="meta">${stamp.replaceAll('\n', '<br>')}</div><p>跑步</p><figure><img src="resources/0123456789abcdef-a.jpg"></figure>'},
              {'html': '<h2>买菜</h2><div class="meta">创建时间：2024-11-05 09:00:00+08:00<br>修改时间：未知</div><p>鸡蛋</p>'},
            ])}</script></body></html>',
      _ =>
        '# 周末计划\n\n$stamp\n\n跑步\n\n'
            '![a.jpg](resources/0123456789abcdef-a.jpg)\n\n---\n\n'
            '# 买菜\n\n创建时间：2024-11-05 09:00:00+08:00\n修改时间：未知\n\n鸡蛋\n',
    };
    final bytes = utf8.encode(body);
    final photo = [0xFF, 0xD8, 0xFF, 0xE0];
    final archive = Archive()
      ..addFile(ArchiveFile('小米笔记.$format', bytes.length, bytes))
      ..addFile(
        ArchiveFile('resources/0123456789abcdef-a.jpg', photo.length, photo),
      );
    final file = File(
      p.join(fixture.temporary.path, '小米笔记-20261016-030104-$format.zip'),
    );
    return file.writeAsBytes(ZipEncoder().encode(archive)!);
  }

  test(
    'imports a Note Bridge export and recognises the same notes in another format',
    () async {
      final html = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.xiaomiNotes,
        filePath: (await noteBridgeZip('html')).path,
      );
      expect(html.preview.journalSource, JournalImportSource.xiaomiNotes);
      expect(html.preview.diaryCount, 2);
      await html.apply(
        database: fixture.database,
        mode: BackupImportMode.merge,
      );
      await html.dispose();

      final diaries = await fixture.database
          .select(fixture.database.diaries)
          .get();
      final plan = diaries.firstWhere((diary) => diary.title == '周末计划');
      expect(plan.createdAt, DateTime.utc(2024, 11, 3, 0, 30, 5).toLocal());
      expect(plan.content, contains('diary_images'));
      expect(
        (jsonDecode(plan.metadata) as Map)['import']['source'],
        'xiaomiNotes',
      );

      final markdown = await JournalImportService.prepare(
        database: fixture.database,
        source: JournalImportSource.xiaomiNotes,
        filePath: (await noteBridgeZip('md')).path,
      );
      expect(markdown.preview.existingDiaryCount, 2);
      await markdown.dispose();
      expect(stagingDirectories(), isEmpty);

      // 文件标注的是小米笔记，选成华为备忘录时提示格式不符。
      await expectLater(
        JournalImportService.prepare(
          database: fixture.database,
          source: JournalImportSource.huaweiNotepad,
          filePath: (await noteBridgeZip('md')).path,
        ),
        throwsA(isA<JournalImportFormatException>()),
      );
    },
  );

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
