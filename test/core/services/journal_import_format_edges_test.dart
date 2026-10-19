import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_apple_journal.dart';
import 'package:node_diary/core/services/journal_import_daylio.dart';
import 'package:node_diary/core/services/journal_import_diarium.dart';
import 'package:node_diary/core/services/journal_import_evernote.dart';
import 'package:node_diary/core/services/journal_import_memos.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

import '../../support/journal_import_fixture.dart';

void main() {
  late JournalImportFixture fixture;
  setUp(() async => fixture = await JournalImportFixture.create());
  tearDown(() => fixture.dispose());

  test('ENEX note markers in CDATA and comments cannot truncate a note', () {
    final file = fixture.write('Notes.enex', '''<en-export>
<!-- <note><title>Not a note</title></note> -->
<note><title>Real</title><created>20240101T000000Z</created>
<content><![CDATA[<en-note><div>Before</div><!-- </note> -->
<div>After</div></en-note>]]></content></note>
<note custom="value"><title>Next</title><created>20240102T000000Z</created>
<content><![CDATA[<en-note>Next body</en-note>]]></content></note>
</en-export>''');
    final result = parseEvernoteExport(
      JournalImportInput(filePath: file.path),
      fixture.media,
    );
    expect(result.entries.map((entry) => entry.title), ['Real', 'Next']);
    expect(result.entries.map((entry) => entry.contentText), [
      'Before\nAfter',
      'Next body',
    ]);
  });

  test('truncated ENEX is rejected before any partial import', () {
    final file = fixture.write(
      'Broken.enex',
      '<en-export><note><title>One</title></note><note><title>Lost',
    );
    expect(
      () => parseEvernoteExport(
        JournalImportInput(filePath: file.path),
        fixture.media,
      ),
      throwsA(isA<JournalImportFormatException>()),
    );
  });

  test('encrypted ENEX fragments remain in metadata and are reported', () {
    final file = fixture.write('Locked.enex', '''<en-export><note>
<title>Mixed</title><created>20240101T000000Z</created>
<content><![CDATA[<en-note><div>Visible</div><en-crypt hint="passphrase"
cipher="AES">c2VjcmV0</en-crypt></en-note>]]></content></note></en-export>''');
    final result = parseEvernoteExport(
      JournalImportInput(filePath: file.path),
      fixture.media,
    );
    expect(result.entries.single.contentText, 'Visible');
    expect(result.partialContentCount, 1);
    expect(
      jsonEncode(result.entries.single.sourceMetadata),
      contains('c2VjcmV0'),
    );
    expect(
      jsonEncode(result.entries.single.sourceMetadata),
      contains('passphrase'),
    );
  });

  test('Daylio rejects invalid rows and reports how many were skipped', () {
    fixture.write(
      'backup.daylio',
      base64.encode(
        utf8.encode(
          jsonEncode({
            'dayEntries': [
              {'year': 2024, 'month': 1, 'day': 30, 'note': 'Invalid'},
              {'year': 2024, 'month': 1, 'day': 29, 'note': 'Leap day'},
            ],
          }),
        ),
      ),
    );
    final result = parseDaylioExport(fixture.input, fixture.media);
    expect(result.entries.single.contentText, 'Leap day');
    expect(result.skippedNotes, {JournalSkipReason.unreadable: 1});
  });

  test('Daylio CSV supports semicolons and quoted multiline notes', () {
    final file = fixture.write(
      'Daylio.csv',
      'full_date;date;weekday;time;mood;activities;note_title;note\r\n'
          '2024-02-29;29 February;Thursday;9:30 pm;good;work | rest;Leap;"a; b\nnext"\r\n'
          '2024-02-30;30 February;Friday;12:00;rad;;;Invalid\r\n',
    );
    final result = parseDaylioExport(
      JournalImportInput(filePath: file.path),
      fixture.media,
    );
    expect(result.entries.single.contentText, 'a; b\nnext');
    expect(result.entries.single.createdAt, DateTime(2024, 2, 29, 21, 30));
    expect(result.skippedNotes, {JournalSkipReason.unreadable: 1});
  });

  test(
    'Daylio cannot silently consume later rows after a broken CSV quote',
    () {
      final file = fixture.write(
        'Broken.csv',
        'full_date,time,mood,note\n2024-02-29,12:00,good,"unterminated',
      );
      expect(
        () => parseDaylioExport(
          JournalImportInput(filePath: file.path),
          fixture.media,
        ),
        throwsA(isA<JournalImportFormatException>()),
      );
    },
  );

  test('Diarium reports invalid dates while preserving valid JSON records', () {
    fixture.write('Diarium.json', [
      {'date': '2024-02-30T08:00:00', 'html': '<p>Bad</p>'},
      {'date': '2024-02-29T08:00:00', 'html': '<p>Good</p>'},
    ]);
    final result = parseDiariumExport(fixture.input, fixture.media);
    expect(result.entries.single.contentText, 'Good');
    expect(result.skippedNotes, {JournalSkipReason.unreadable: 1});
  });

  test('Diarium historical dates and microseconds survive SQLite backups', () {
    final path = p.join(fixture.export.path, 'Historical.diary');
    final wall = DateTime.utc(1965, 5, 4, 3, 2, 1, 123, 456);
    final ticks = 621355968000000000 + wall.microsecondsSinceEpoch * 10;
    final database = sqlite3.open(path);
    try {
      database.execute(
        'CREATE TABLE Entries (DiaryEntryId INTEGER PRIMARY KEY, Text TEXT)',
      );
      database.execute('INSERT INTO Entries VALUES (?, ?)', [
        ticks,
        'Historical',
      ]);
    } finally {
      database.close();
    }
    final result = parseDiariumExport(
      JournalImportInput(filePath: path),
      fixture.media,
    );
    expect(
      result.entries.single.createdAt,
      DateTime(1965, 5, 4, 3, 2, 1, 123, 456),
    );
  });

  void memosManifest() => fixture.write('manifest.json', {
    'format': 'memos-export',
    'formatVersion': '1.0',
  });

  test(
    'Memos missing Markdown is reported instead of importing an empty note',
    () {
      memosManifest();
      fixture.write('memos/missing.json', {
        'uid': 'missing',
        'createTime': '2024-02-01T00:00:00Z',
        'contentPath': 'memos/missing.md',
      });
      fixture.write('memos/good.json', {
        'uid': 'good',
        'createTime': '2024-02-01T00:00:00Z',
        'contentPath': 'memos/good.md',
      });
      fixture.write('memos/good.md', 'Good');
      final result = parseMemosExport(fixture.input, fixture.media);
      expect(result.entries.single.contentText, 'Good');
      expect(result.skippedNotes, {JournalSkipReason.unreadable: 1});
    },
  );

  test('Memos preserves external attachment URLs referenced inline', () {
    memosManifest();
    fixture.write('memos/one.json', {
      'uid': 'one',
      'createTime': '2024-02-01T00:00:00Z',
      'contentPath': 'memos/one.md',
      'attachments': [
        {
          'uid': 'external',
          'filename': 'Report.pdf',
          'externalLink': 'https://example.com/report.pdf',
        },
      ],
    });
    fixture.write('memos/one.md', 'See [Report](/file/attachments/external)');
    final result = parseMemosExport(fixture.input, fixture.media);
    expect(
      result.entries.single.contentJson,
      contains('https://example.com/report.pdf'),
    );
    expect(result.missingMediaCount, 0);
  });

  test('Apple Journal chooses a video source before its poster image', () {
    fixture.write(
      'Entries/2024-02-29.html',
      '''<div class="pageHeader">29 February 2024</div>
<div class="assetGrid"><div class="gridItem assetType_video">
<img src="../Resources/poster.jpg"><video src="../Resources/movie.mov"></video>
</div></div><div class="bodyText"><p>Movie day</p></div>''',
    );
    fixture.write('Resources/poster.jpg', JournalImportFixture.jpeg);
    fixture.write('Resources/movie.mov', [1, 2, 3]);
    final result = parseAppleJournalExport(fixture.input, fixture.media);
    final embeds = JournalImportFixture.embeds(result.entries.single);
    expect(embeds.single.keys, ['video']);
    expect(embeds.single['video'], endsWith('movie.mov'));
  });
}
