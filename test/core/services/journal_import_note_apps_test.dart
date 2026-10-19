import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_joplin.dart';
import 'package:node_diary/core/services/journal_import_markdown_files.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];

const _folderId = '5b9f1c2e8d0a4f6b9c3e7a1d2f4b6c8e';
const _noteId = 'a1e4c7b2d5f84e0b9a3c6d1f2e5b8c4a';
const _resourceId = 'c3d9e2f1a7b64c8d9e0f1a2b3c4d5e6f';
const _tagId = 'e7f2a9c4b1d84f3e8a6c0b5d2e9f1a7c';

/// 与 Joplin `BaseItem.serialize` 输出一致：空值行带一个尾随空格，文件末尾
/// 没有换行。
Map<String, String> _joplinItems({String noteExtra = ''}) => {
  '$_folderId.md': [
    'Travel Journal',
    '',
    'id: $_folderId',
    'created_time: 2026-03-01T09:00:00.000Z',
    'parent_id: ',
    'type_: 2',
  ].join('\n'),
  '$_noteId.md': [
    'Day 1 in Kyoto',
    '',
    'Arrived at Kyoto station around noon.',
    '',
    '![kyoto.jpg](:/$_resourceId)',
    '',
    '- [x] Check in at the hotel',
    'See also [Packing list](:/0f3c2b1a9e8d4c7b6a5f4e3d2c1b0a9f) <u>today</u>',
    '',
    'id: $_noteId',
    'parent_id: $_folderId',
    'created_time: 2026-03-14T01:23:45.678Z',
    'updated_time: 2026-03-14T09:41:02.115Z',
    'is_conflict: 0',
    'latitude: 35.01160000',
    'longitude: 135.76810000',
    'author: ',
    'user_created_time: 2026-03-10T01:00:00.000Z',
    'user_updated_time: 2026-03-14T09:41:02.115Z',
    'encryption_applied: 0',
    'markup_language: 1',
    'deleted_time: 0',
    if (noteExtra.isNotEmpty) noteExtra,
    'type_: 1',
  ].join('\n'),
  '$_resourceId.md': [
    'kyoto.jpg',
    '',
    'id: $_resourceId',
    'mime: image/jpeg',
    'filename: ',
    'file_extension: jpg',
    'type_: 4',
  ].join('\n'),
  '$_tagId.md': ['travel', '', 'id: $_tagId', 'type_: 5'].join('\n'),
  '9d4b6e1f3a2c4e8b7f0a5c9d1e3b6f2a.md': [
    'id: 9d4b6e1f3a2c4e8b7f0a5c9d1e3b6f2a',
    'note_id: $_noteId',
    'tag_id: $_tagId',
    'type_: 6',
  ].join('\n'),
  'ffffffffffffffffffffffffffffffff.md': [
    'Secret',
    '',
    'id: ffffffffffffffffffffffffffffffff',
    'encryption_applied: 1',
    'type_: 1',
  ].join('\n'),
};

void main() {
  late Directory temp;
  late Directory export;
  late JournalMediaStager media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('note_apps_test_');
    export = await Directory(p.join(temp.path, 'export')).create();
    media = JournalMediaStager(
      (await Directory(p.join(temp.path, 'staging')).create()).path,
    );
  });

  tearDown(() => temp.delete(recursive: true));

  void write(String relative, Object content) {
    final file = File(p.join(export.path, relative));
    file.parent.createSync(recursive: true);
    if (content is List<int>) {
      file.writeAsBytesSync(content);
    } else {
      file.writeAsStringSync(content as String);
    }
  }

  JournalImportInput extracted() =>
      JournalImportInput(filePath: export.path, extractedPath: export.path);

  List<Map<String, Object?>> embeds(JournalImportEntry entry) => [
    for (final op in jsonDecode(entry.contentJson) as List<Object?>)
      if ((op as Map)['insert'] case final Map<String, Object?> data) data,
  ];

  group('Joplin', () {
    test('reads a JEX tar: dates, tags, resources and note links', () {
      final archive = Archive();
      for (final MapEntry(:key, :value) in _joplinItems().entries) {
        final bytes = utf8.encode(value);
        archive.addFile(ArchiveFile(key, bytes.length, bytes));
      }
      archive.addFile(
        ArchiveFile('resources/$_resourceId.jpg', _jpeg.length, _jpeg),
      );
      final jex = File(p.join(temp.path, 'Travel.jex'))
        ..writeAsBytesSync(TarEncoder().encode(archive));

      final result = parseJoplinExport(
        JournalImportInput(filePath: jex.path),
        media,
      );

      final entry = result.entries.single;
      expect(entry.sourceKey, _noteId);
      expect(entry.title, 'Day 1 in Kyoto');
      // 用户可改的 user_created_time，而不是系统的 created_time。
      expect(entry.createdAt, DateTime.utc(2026, 3, 10, 1).toLocal());
      expect(
        entry.updatedAt,
        DateTime.utc(2026, 3, 14, 9, 41, 2, 115).toLocal(),
      );
      expect(entry.tags, ['travel']);
      expect((entry.latitude, entry.longitude), (35.0116, 135.7681));
      expect(
        entry.contentText,
        'Arrived at Kyoto station around noon.\n\n\n\n'
        'Check in at the hotel\nSee also Packing list today',
      );
      final image = embeds(entry).single['image'] as String;
      expect(p.basename(image), 'kyoto.jpg');
      expect(entry.contentJson, contains('"underline":true'));
      expect(result.missingMediaCount, 0);
    });

    test('reads a zipped RAW export folder and skips locked notes', () {
      for (final MapEntry(:key, :value) in _joplinItems(
        noteExtra: 'is_locked: 1',
      ).entries) {
        write('raw/$key', value);
      }
      write(
        'raw/0000000000000000000000000000000a.md',
        [
          'Plain',
          '',
          '<p>Hello <b>HTML</b></p>',
          '',
          'id: 0000000000000000000000000000000a',
          'parent_id: 1111111111111111111111111111111b',
          'created_time: 2025-01-01T00:00:00.000Z',
          'user_created_time: ',
          'markup_language: 2',
          'type_: 1',
        ].join('\n'),
      );

      final result = parseJoplinExport(extracted(), media);

      final entry = result.entries.single;
      expect(entry.title, 'Plain');
      expect(entry.contentText, 'Hello HTML');
      expect(entry.createdAt, DateTime.utc(2025).toLocal());
      // 两篇分属两个笔记本，但被锁的那篇不导入，只剩一个笔记本，不记笔记本。
      expect(entry.tags, isEmpty);
      expect(entry.notebooks, isEmpty);
      expect(result.skippedNotes, {JournalSkipReason.encrypted: 2});
    });

    test('keeps conflict copies and does not import deleted notes', () {
      for (final MapEntry(:key, :value) in _joplinItems().entries) {
        write(
          'raw/$key',
          value.replaceFirst('is_conflict: 0', 'is_conflict: 1'),
        );
      }
      write('raw/resources/$_resourceId.jpg', _jpeg);
      final result = parseJoplinExport(extracted(), media);
      expect(result.entries.single.title, 'Day 1 in Kyoto');
      expect(result.entries.single.sourceMetadata['conflict'], isTrue);
      write(
        'raw/$_noteId.md',
        _joplinItems()['$_noteId.md']!.replaceFirst(
          'deleted_time: 0',
          'deleted_time: 1700000000000',
        ),
      );
      expect(parseJoplinExport(extracted(), media).entries, isEmpty);
    });

    test('corrupted or truncated JEX cannot silently import a prefix', () {
      final archive = Archive();
      for (final MapEntry(:key, :value) in _joplinItems().entries) {
        final bytes = utf8.encode(value);
        archive.addFile(ArchiveFile(key, bytes.length, bytes));
      }
      final bytes = TarEncoder().encode(archive);
      for (final bad in [
        bytes.sublist(0, bytes.length - 1024),
        bytes.sublist(0, 600),
        [...bytes]..[100] ^= 1,
      ]) {
        final file = File(p.join(temp.path, 'broken.jex'))
          ..writeAsBytesSync(bad);
        expect(
          () =>
              parseJoplinExport(JournalImportInput(filePath: file.path), media),
          throwsA(isA<JournalImportFormatException>()),
        );
      }
    });

    test('rejects files that are not Joplin exports', () {
      final file = File(p.join(temp.path, 'x.jex'))..writeAsStringSync('hello');
      expect(
        () => parseJoplinExport(JournalImportInput(filePath: file.path), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });

  group('Markdown files', () {
    test('maps front matter, headings, folders and Obsidian embeds', () {
      write('Vault/Travel/Kyoto.md', '''---
title: "Day 1"
created: 2026-03-14 01:23:45Z
tags:
  - travel
  - '#japan'
latitude: 35.01160000
longitude: 135.76810000
---

Arrived **early**.
![[photo.jpg|300]] and [[Packing list|my list]]
![alt](../attachments/doc.pdf)
''');
      write('Vault/attachments/photo.jpg', _jpeg);
      write('Vault/attachments/doc.pdf', utf8.encode('%PDF'));
      write('Vault/Daily/2024-01-15.md', '# Morning\nline one\nline two');
      write('Vault/Daily/2024-01-16 0830 Run.md', 'ran 5k');
      write('Vault/.obsidian/workspace.md', 'ignored');

      final result = parseMarkdownFilesExport(extracted(), media);

      final byKey = {for (final e in result.entries) e.sourceKey: e};
      expect(byKey.keys, {
        'Vault/Daily/2024-01-15.md',
        'Vault/Daily/2024-01-16 0830 Run.md',
        'Vault/Travel/Kyoto.md',
      });
      final kyoto = byKey['Vault/Travel/Kyoto.md']!;
      expect(kyoto.title, 'Day 1');
      expect(kyoto.createdAt, DateTime.utc(2026, 3, 14, 1, 23, 45).toLocal());
      expect(kyoto.tags, ['travel', 'japan']);
      expect(kyoto.notebooks, ['Travel']);
      expect((kyoto.latitude, kyoto.longitude), (35.0116, 135.7681));
      expect(kyoto.contentText, 'Arrived early.\n\nand my list');
      final [photo, pdf] = embeds(kyoto);
      expect(p.basename(photo['image'] as String), 'photo.jpg');
      expect(pdf.keys, ['attachment']);

      final daily = byKey['Vault/Daily/2024-01-15.md']!;
      expect(daily.title, 'Morning');
      expect(daily.contentText, 'line one\nline two');
      expect(daily.createdAt, DateTime(2024, 1, 15));
      expect(daily.tags, isEmpty);
      expect(daily.notebooks, ['Daily']);
      final run = byKey['Vault/Daily/2024-01-16 0830 Run.md']!;
      expect(run.title, 'Run');
      expect(run.createdAt, DateTime(2024, 1, 16, 8, 30));
      expect(result.missingMediaCount, 0);
    });

    test('plain .txt notes record their top folder as a notebook too', () {
      write('Vault/Travel/Kyoto.md', 'temple');
      write('Vault/Daily/2024-01-15 Walk.txt', 'park');

      final result = parseMarkdownFilesExport(extracted(), media);

      final byKey = {for (final e in result.entries) e.sourceKey: e};
      final walk = byKey['Vault/Daily/2024-01-15 Walk.txt']!;
      expect(walk.title, 'Walk');
      expect(walk.contentText, 'park');
      expect(walk.tags, isEmpty);
      expect(walk.notebooks, ['Daily']);
      expect(byKey['Vault/Travel/Kyoto.md']!.notebooks, ['Travel']);
    });

    test('reads a single picked .md file', () {
      final file = File(p.join(temp.path, 'Shopping.md'))
        ..writeAsStringSync('- [ ] milk\n- [x] eggs\n![](missing.png)');

      final result = parseMarkdownFilesExport(
        JournalImportInput(filePath: file.path),
        media,
      );

      final entry = result.entries.single;
      expect(entry.title, 'Shopping');
      expect(entry.sourceKey, 'Shopping.md');
      expect(entry.contentText, 'milk\neggs');
      expect(entry.tags, isEmpty);
      expect(result.missingMediaCount, 1);
    });

    test('rejects an archive without Markdown or text files', () {
      write('photo.jpg', _jpeg);
      expect(
        () => parseMarkdownFilesExport(extracted(), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });
}
