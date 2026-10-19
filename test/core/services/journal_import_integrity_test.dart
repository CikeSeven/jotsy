import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_day_one.dart';
import 'package:node_diary/core/services/journal_import_daylio.dart';
import 'package:node_diary/core/services/journal_import_front_matter.dart';
import 'package:node_diary/core/services/journal_import_google_keep.dart';
import 'package:node_diary/core/services/journal_import_journey.dart';
import 'package:node_diary/core/services/journal_import_markdown_files.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_payload.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;

import '../../support/journal_import_fixture.dart';

void main() {
  late JournalImportFixture fixture;
  setUp(() async => fixture = await JournalImportFixture.create());
  tearDown(() => fixture.dispose());

  test('duplicate and suffixed source keys never discard a diary', () {
    JournalImportEntry entry(String key) => JournalImportEntry(
      sourceKey: key,
      contentJson: '[{"insert":"$key\\n"}]',
      contentText: key,
      createdAt: DateTime(2024),
    );
    final payload = buildJournalImportPayload(JournalImportSource.memos, [
      entry('memo'),
      entry('memo'),
      entry('memo#2'),
      entry('memo'),
    ]);
    expect(payload.diaries, hasLength(4));
    expect(payload.diaries.map((diary) => diary.diaryId).toSet(), hasLength(4));
    expect(payload.diaries.map((diary) => diary.contentText), [
      'memo',
      'memo',
      'memo#2',
      'memo',
    ]);
    final keys = JournalKeyRegistry();
    expect(['x', 'x', 'x#2', 'x'].map(keys.unique).toSet(), hasLength(4));
  });

  test('long titles and normalized tags retain their original values', () {
    final title = '😀' * 120;
    final tag = '标签' * 25;
    final entry = JournalImportEntry(
      sourceKey: 'one',
      title: title,
      tags: [tag, '  个人\t标签  '],
      contentJson: '[{"insert":"Body\\n"}]',
      contentText: 'Body',
      createdAt: DateTime(2024),
    );
    final payload = buildJournalImportPayload(JournalImportSource.markdown, [
      entry,
    ]);
    final diary = payload.diaries.single;
    final imported = (jsonDecode(diary.metadata) as Map)['import'] as Map;
    expect(diary.title.length, lessThanOrEqualTo(200));
    expect(diary.title.runes.last, 0x1F600);
    expect(imported['originalTitle'], title);
    expect(imported['originalTags'], entry.tags);
    expect(payload.tags.map((tag) => tag.name), [
      tag.substring(0, 40),
      '个人 标签',
    ]);
  });

  test('Day One journals sharing media retain every reference', () {
    for (final journal in ['A', 'B']) {
      fixture.write('$journal.json', {
        'entries': [
          {
            'uuid': journal,
            'creationDate': '2024-02-01T08:00:00Z',
            'text': '![](dayone-moment://photo)',
            'photos': [
              {'identifier': 'photo', 'md5': 'shared'},
            ],
          },
        ],
      });
    }
    fixture.write('photos/shared.jpg', JournalImportFixture.jpeg);
    final result = parseDayOneExport(fixture.input, fixture.media);
    expect(result.missingMediaCount, 0);
    expect(
      result.entries.map(JournalImportFixture.embeds),
      everyElement(hasLength(1)),
    );
  });

  test('Journey keeps nested attachments and numeric optional fields', () {
    fixture.write('entry.json', {
      'id': 'journey',
      'date_journal': 1706788800000,
      'text': '<p>Body</p><a href="media/report.pdf">Report</a>',
      'type': 'html',
      'photos': ['media/photo%20one.jpg'],
      'weather': {'description': 'Sunny', 'degree_c': '21.5'},
    });
    fixture.write('media/report.pdf', utf8.encode('%PDF-1.4'));
    fixture.write('media/photo one.jpg', JournalImportFixture.jpeg);
    final result = parseJourneyExport(fixture.input, fixture.media);
    final entry = result.entries.single;
    expect(entry.weather, 'Sunny 22℃');
    expect(JournalImportFixture.embeds(entry), hasLength(2));
    expect(result.missingMediaCount, 0);
  });

  test('Keep shares swapped-extension photos between notes', () {
    for (final title in ['First', 'Second']) {
      fixture.write('Keep/$title.json', {
        'title': title,
        'createdTimestampUsec': 1706788800000000,
        'textContent': title,
        'attachments': [
          {'filePath': 'shared.jpeg', 'mimetype': 'image/jpeg'},
        ],
      });
    }
    fixture.write('Keep/shared.jpg', JournalImportFixture.jpeg);
    final result = parseGoogleKeepExport(fixture.input, fixture.media);
    expect(result.missingMediaCount, 0);
    final images = result.entries
        .map((entry) => JournalImportFixture.embeds(entry).single['image'])
        .toSet();
    expect(images, hasLength(1));
    expect(File(images.single as String).existsSync(), isTrue);
  });

  test('Markdown resolves encoded paths after a shared file has moved', () {
    for (final title in ['A', 'B']) {
      fixture.write('Notes/$title.md', '![](../media/picture%231.jpg)');
    }
    fixture.write('media/picture#1.jpg', JournalImportFixture.jpeg);
    final result = parseMarkdownFilesExport(fixture.input, fixture.media);
    expect(result.missingMediaCount, 0);
    expect(
      result.entries.map(JournalImportFixture.embeds),
      everyElement(hasLength(1)),
    );
  });

  test('ambiguous attachment names cannot bind to the wrong notebook', () {
    fixture.write('Notes/note.md', '![[same.jpg]]');
    fixture.write('A/same.jpg', [1]);
    fixture.write('B/same.jpg', [2]);
    final result = parseMarkdownFilesExport(fixture.input, fixture.media);
    expect(JournalImportFixture.embeds(result.entries.single), isEmpty);
    expect(result.missingMediaCount, 1);
  });

  test(
    'reference-style Markdown images resolve without importing their definitions',
    () {
      fixture.write(
        'Note.md',
        'Before\n![Photo][picture]\nAfter\n\n[picture]: media/photo.jpg "Picture"\n',
      );
      fixture.write('media/photo.jpg', JournalImportFixture.jpeg);
      final result = parseMarkdownFilesExport(fixture.input, fixture.media);
      expect(JournalImportFixture.embeds(result.entries.single), hasLength(1));
      expect(result.entries.single.contentText, 'Before\n\nAfter');
      expect(result.missingMediaCount, 0);
    },
  );

  test('encoded links to another note do not move or consume that note', () {
    fixture.write(
      'A.md',
      '[Other](B%2Emd)\n```\n![literal][x]\n[x]: missing.png\n```',
    );
    fixture.write('B.md', 'Other body');
    final result = parseMarkdownFilesExport(fixture.input, fixture.media);
    expect(result.entries, hasLength(2));
    expect(
      result.entries.first.contentText,
      'Other\n![literal][x]\n[x]: missing.png',
    );
    expect(result.entries.last.contentText, 'Other body');
    expect(result.missingMediaCount, 0);
  });

  test('plain text preserves literal syntax, front matter and whitespace', () {
    const text =
        '---\ntitle: literal\n---\n# Heading\n  **keep**  \n![[x.jpg]]\n';
    final file = fixture.write('Plain.txt', text);
    final entry = parseMarkdownFilesExport(
      JournalImportInput(filePath: file.path),
      fixture.media,
    ).entries.single;
    expect(entry.title, 'Plain');
    expect(jsonDecode(entry.contentJson), [
      {'insert': text},
    ]);
  });

  test('UTF-16 text exports retain Chinese and emoji', () {
    const text = '正文 😀\n下一行';
    final bytes = [
      0xFF,
      0xFE,
      for (final unit in text.codeUnits) ...[unit & 255, unit >> 8],
    ];
    final file = fixture.write('文字.txt', bytes);
    final entry = parseMarkdownFilesExport(
      JournalImportInput(filePath: file.path),
      fixture.media,
    ).entries.single;
    expect(entry.contentText, text);
  });

  test('JSON with a UTF-8 BOM is recognised', () {
    final file = fixture.write(
      'Journal.json',
      '\uFEFF${jsonEncode({
        'entries': [
          {'uuid': 'one', 'creationDate': '2024-02-01T08:00:00Z', 'text': '正文'},
        ],
      })}',
    );
    final result = parseDayOneExport(
      JournalImportInput(filePath: file.path),
      fixture.media,
    );
    expect(result.entries.single.contentText, '正文');
  });

  test(
    'invalid calendar dates are rejected instead of silently rolling over',
    () {
      expect(parseJournalDateTime('2024-02-30T12:00:00Z'), isNull);
      expect(parseLooseJournalDate('2023/2/29 8:30'), isNull);
      expect(parseLooseJournalDate('2024-01-01T12:00:00+25:00'), isNull);
      expect(
        parseLooseJournalDate('2024-02-29T12:00:00.123456Z'),
        DateTime.utc(2024, 2, 29, 12, 0, 0, 123, 456).toLocal(),
      );
    },
  );

  test('nested Daylio backups find their assets beside the backup', () {
    fixture.write(
      'Export/backup.daylio',
      base64.encode(
        utf8.encode(
          jsonEncode({
            'dayEntries': [
              {
                'year': 2024,
                'month': 1,
                'day': 1,
                'note': 'Body',
                'assets': [1],
              },
            ],
            'assets': [
              {'id': 1, 'checksum': 'photo'},
            ],
          }),
        ),
      ),
    );
    fixture.write('Export/assets/photo.jpg', JournalImportFixture.jpeg);
    final result = parseDaylioExport(fixture.input, fixture.media);
    expect(result.entries.single.contentText, 'Body');
    expect(JournalImportFixture.embeds(result.entries.single), hasLength(1));
    expect(result.missingMediaCount, 0);
  });

  test('a source attachment stays within the selected export', () {
    final outside = File(p.join(fixture.temporary.path, 'private.jpg'))
      ..writeAsBytesSync(JournalImportFixture.jpeg);
    fixture.write('note.md', '![](${outside.path})\n![](../../private.jpg)');
    final result = parseMarkdownFilesExport(fixture.input, fixture.media);
    expect(JournalImportFixture.embeds(result.entries.single), isEmpty);
    expect(outside.existsSync(), isTrue);
  });
}
