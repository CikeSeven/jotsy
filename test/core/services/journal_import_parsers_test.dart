import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_apple_journal.dart';
import 'package:node_diary/core/services/journal_import_day_one.dart';
import 'package:node_diary/core/services/journal_import_daylio.dart';
import 'package:node_diary/core/services/journal_import_diarium.dart';
import 'package:node_diary/core/services/journal_import_diaro.dart';
import 'package:node_diary/core/services/journal_import_journey.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../../support/diary_content_test_helpers.dart';

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];

void main() {
  late Directory temp;
  late Directory export;
  late JournalMediaStager media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('journal_import_test_');
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
      file.writeAsStringSync(content is String ? content : jsonEncode(content));
    }
  }

  JournalImportInput extracted() =>
      JournalImportInput(filePath: export.path, extractedPath: export.path);

  List<Object?> ops(JournalImportEntry entry) =>
      diaryContentQuillOps(entry.contentJson);

  Map<String, Object?> embedOf(JournalImportEntry entry, int index) =>
      (ops(entry).where((op) => (op as Map)['insert'] is Map).toList()[index]
              as Map)['insert']
          as Map<String, Object?>;

  group('Day One', () {
    test('maps text, title, inline and trailing media, place and weather', () {
      write('Journal.json', {
        'metadata': {'version': '1.0'},
        'entries': [
          {
            'uuid': 'E1',
            'creationDate': '2024-03-01T02:30:00Z',
            'modifiedDate': '2024-03-02T00:00:00Z',
            'text': '# Trip\nHello **world**\n![](dayone-moment://P1)\nBye\\!',
            'tags': ['travel'],
            'isPinned': true,
            'location': {
              'placeName': 'West Lake',
              'latitude': 30.25,
              'longitude': 120.15,
            },
            'weather': {
              'conditionsDescription': 'Sunny',
              'temperatureCelsius': 21.6,
            },
            'photos': [
              {'identifier': 'P1', 'md5': 'aaa', 'type': 'jpeg'},
              {'identifier': 'P2', 'md5': 'gone', 'type': 'jpeg'},
            ],
            'audios': [
              {'identifier': 'A1', 'md5': 'ccc', 'duration': 3.5},
            ],
          },
        ],
      });
      write('photos/aaa.jpeg', _jpeg);
      write('audios/ccc.m4a', [1, 2, 3]);

      final result = parseDayOneExport(extracted(), media);

      final entry = result.entries.single;
      expect(entry.title, 'Trip');
      expect(entry.contentText, 'Hello world\n\nBye!');
      expect(entry.createdAt, DateTime.utc(2024, 3, 1, 2, 30).toLocal());
      expect(entry.updatedAt, DateTime.utc(2024, 3, 2).toLocal());
      expect(entry.tags, ['travel']);
      expect(entry.pinned, isTrue);
      expect(entry.location, 'West Lake');
      expect((entry.latitude, entry.longitude), (30.25, 120.15));
      expect(entry.weather, 'Sunny 22℃');
      expect(entry.moodLevel, isNull);
      final image = embedOf(entry, 0)['image'] as String;
      expect(p.split(image), containsAllInOrder(['diary_images', 'aaa.jpeg']));
      expect(File(image).existsSync(), isTrue);
      final audio = jsonDecode(embedOf(entry, 1)['audio'] as String) as Map;
      expect(audio['durationMs'], 3500);
      expect(p.split(audio['path'] as String), contains('diary_recordings'));
      // P2 被引用但文件不在包内。
      expect(result.missingMediaCount, 1);
    });

    test('records the journal name when there are several', () {
      for (final name in ['Work', 'Home']) {
        write('$name.json', {
          'entries': [
            {'uuid': name, 'creationDate': '2024-01-01T00:00:00Z'},
          ],
        });
      }
      final result = parseDayOneExport(extracted(), media);
      expect(result.entries.map((entry) => entry.notebooks), [
        ['Home'],
        ['Work'],
      ]);
      expect(result.entries.map((entry) => entry.tags), [isEmpty, isEmpty]);
    });

    test('rejects files that are not Day One exports', () {
      write('notes.json', {'hello': 'world'});
      expect(
        () => parseDayOneExport(extracted(), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });

  group('Journey', () {
    test('maps an HTML entry with photo, address, weather and tags', () {
      write('1571425138176-abc.json', {
        'id': '1571425138176-abc',
        'date_journal': 1571386059000,
        'date_modified': 1571425361000,
        'type': 'html',
        'text': '<p dir="auto">Rode my new bike!&nbsp;</p>\n<p dir="auto"></p>',
        'photos': ['1571425138176-abc-photo.jpeg'],
        'tags': ['bike'],
        'address': 'London road, Croydon',
        'lat': 51.379372,
        'lon': -0.104888,
        'weather': {'degree_c': 9.4, 'description': 'Overcast clouds'},
        'mood': 5,
      });
      write('1571425138176-abc-photo.jpeg', _jpeg);
      write('1571425138177-def.json', {
        'id': '1571425138177-def',
        'date_journal': 1571386059001,
        'text': 'Plain *markdown*\nsecond line',
        'lat': 1.7976931348623157e308,
        'lon': 1.7976931348623157e308,
        'weather': {'degree_c': 1.7976931348623157e308, 'description': ''},
      });

      final entries = parseJourneyExport(extracted(), media).entries;

      final html = entries.firstWhere((e) => e.sourceKey.endsWith('abc'));
      expect(html.contentText, 'Rode my new bike!');
      expect(
        html.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1571386059000),
      );
      expect(html.location, 'London road, Croydon');
      expect(html.latitude, closeTo(51.379372, 1e-9));
      expect(html.weather, 'Overcast clouds 9℃');
      expect(html.tags, ['bike']);
      expect(embedOf(html, 0)['image'], endsWith('photo.jpeg'));

      final markdown = entries.firstWhere((e) => e.sourceKey.endsWith('def'));
      expect(markdown.contentText, 'Plain markdown\nsecond line');
      expect(markdown.latitude, isNull);
      expect(markdown.weather, isNull);
    });
  });

  group('Diarium', () {
    const wallClock = (2022, 4, 13, 10, 15);

    test('reads the JSON export', () {
      write('Diarium.json', [
        {
          'date': '2022-04-13T10:15:00',
          'heading': '<b>Hi</b> there',
          'html': '<p>Body <i>text</i></p>',
          'rating': 4,
          'location': [47.1, 8.5],
          'tags': ['a'],
          'people': ['Bob'],
          'weather': '23°C, Partly cloudy.',
        },
      ]);
      final entry = parseDiariumExport(
        JournalImportInput(filePath: p.join(export.path, 'Diarium.json')),
        media,
      ).entries.single;
      expect(entry.title, 'Hi there');
      expect(entry.contentText, 'Body text');
      expect(entry.createdAt, DateTime(2022, 4, 13, 10, 15));
      expect(entry.moodLevel, 4);
      expect(entry.tags, ['a', 'Bob']);
      expect(entry.weather, '23°C, Partly cloudy');
      expect((entry.latitude, entry.longitude), (47.1, 8.5));
    });

    test('reads the .diary SQLite backup with media, tags and weather', () {
      final path = p.join(export.path, 'Diarium.diary');
      final ticks =
          621355968000000000 +
          DateTime.utc(
                wallClock.$1,
                wallClock.$2,
                wallClock.$3,
                wallClock.$4,
                wallClock.$5,
              ).microsecondsSinceEpoch *
              10;
      final database = sqlite3.open(path);
      database
        ..execute(
          'CREATE TABLE Entries (DiaryEntryId INTEGER PRIMARY KEY, '
          'Heading TEXT, Text TEXT, Rating INTEGER, Latitude REAL, '
          'Longitude REAL)',
        )
        ..execute(
          'CREATE TABLE Media (DiaryMediaId INTEGER PRIMARY KEY, '
          'DiaryEntryId INTEGER, Type INTEGER, Data BLOB, Name TEXT, '
          'FileEnding TEXT, "Index" INTEGER)',
        )
        ..execute(
          'CREATE TABLE Tags (DiaryTagId INTEGER PRIMARY KEY, Value TEXT, '
          'Type INTEGER, Color TEXT)',
        )
        ..execute(
          'CREATE TABLE EntryTags (DiaryEntryId INTEGER, DiaryTagId INTEGER, '
          'TrackingValue TEXT)',
        )
        ..execute(
          'CREATE TABLE Events (DiaryEventId INTEGER PRIMARY KEY, '
          'DiaryEntryId INTEGER, Type INTEGER, Content TEXT)',
        )
        ..execute('INSERT INTO Entries VALUES (?, ?, ?, ?, ?, ?)', [
          ticks,
          'Title',
          '<p>Body</p>',
          5,
          0.0,
          0.0,
        ])
        ..execute('INSERT INTO Media VALUES (1, ?, 0, ?, ?, ?, 0)', [
          ticks,
          _jpeg,
          'IMG_1',
          '.jpg',
        ])
        ..execute("INSERT INTO Tags VALUES (1, 'Family', 0, NULL)")
        ..execute("INSERT INTO Tags VALUES (2, 'Weight', 2, NULL)")
        ..execute('INSERT INTO EntryTags VALUES (?, 1, NULL)', [ticks])
        ..execute("INSERT INTO EntryTags VALUES (?, 2, '70')", [ticks])
        ..execute("INSERT INTO Events VALUES (1, ?, 0, '18°C, Clear.')", [
          ticks,
        ])
        ..close();

      final entry = parseDiariumExport(
        JournalImportInput(filePath: path),
        media,
      ).entries.single;
      expect(entry.createdAt, DateTime(2022, 4, 13, 10, 15));
      expect(entry.title, 'Title');
      expect(entry.contentText, 'Body');
      expect(entry.tags, ['Family']);
      expect(entry.weather, '18°C, Clear');
      expect(entry.moodLevel, 5);
      expect(entry.latitude, isNull);
      expect(embedOf(entry, 0)['image'], endsWith('IMG_1.jpg'));
      // 与 JSON 导出中同一时刻的日记是同一个键，先后导入能识别重复。
      expect(
        entry.sourceKey,
        journalWallClockKey(entry.createdAt, seconds: true),
      );
    });
  });

  group('Daylio', () {
    test('backup and CSV export of the same entry share a key', () {
      final backup = {
        'customMoods': [
          {'id': 1, 'mood_group_id': 1},
          {'id': 7, 'custom_name': 'tired', 'mood_group_id': 4},
        ],
        'tags': [
          {'id': 1, 'name': 'work'},
        ],
        'assets': [
          {'id': 3, 'checksum': 'abc123', 'type': 1},
        ],
        'dayEntries': [
          {
            'year': 2024,
            'month': 2,
            'day': 5,
            'hour': 21,
            'minute': 30,
            'mood': 7,
            'note': 'Line<br>two',
            'note_title': 'T',
            'tags': [1],
            'assets': [3],
          },
        ],
      };
      write('backup.daylio', base64.encode(utf8.encode(jsonEncode(backup))));
      write('assets/photos/2024/3/abc123', _jpeg);
      final fromBackup = parseDaylioExport(extracted(), media).entries.single;
      expect(fromBackup.createdAt, DateTime(2024, 3, 5, 21, 30));
      expect(fromBackup.title, 'T');
      expect(fromBackup.contentText, 'Line\ntwo');
      expect(fromBackup.tags, ['work']);
      expect(fromBackup.moodLevel, 2);
      expect(embedOf(fromBackup, 0)['image'], endsWith('abc123.jpg'));

      final csv = File(p.join(temp.path, 'daylio_export.csv'))
        ..writeAsStringSync(
          '﻿full_date,date,weekday,time,mood,activities,note_title,note\n'
          '2024-03-05,5 March,Tuesday,9:30 pm,bad,"work | gym",T,'
          '"Line<br>two"\n'
          '2024-03-04,4 March,Monday,08:05,rad,,,"Hello, ""world"""\n',
        );
      final fromCsv = parseDaylioExport(
        JournalImportInput(filePath: csv.path),
        media,
      ).entries;
      final same = fromCsv.firstWhere((e) => e.title == 'T');
      expect(same.sourceKey, fromBackup.sourceKey);
      expect(same.moodLevel, 2);
      expect(same.tags, ['work', 'gym']);
      final other = fromCsv.firstWhere((e) => e.title.isEmpty);
      expect(other.createdAt, DateTime(2024, 3, 4, 8, 5));
      expect(other.contentText, 'Hello, "world"');
      expect(other.moodLevel, 5);
    });

    test('rejects a CSV without Daylio columns', () {
      final csv = File(p.join(temp.path, 'other.csv'))
        ..writeAsStringSync('name,value\na,1\n');
      expect(
        () => parseDaylioExport(JournalImportInput(filePath: csv.path), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });

  group('Apple Journal', () {
    String page(String title, String body, {String assets = ''}) =>
        '<!DOCTYPE html><html dir="auto"><head><meta charset="UTF-8"></head>'
        '<body><p class="p1"><span class="s1"><div class=\'pageContainer\'>'
        '<div class="pageHeader">Sunday, 3 November 2024</div>'
        '<div class="assetGrid">$assets</div>'
        "<div class='title'>$title</div><div class='bodyText'></span></p>"
        '$body<p class="p1"><span class="s1"></div></div></span></p>'
        '</body></html>';

    test('orders same-day entries by the index and keeps photos', () {
      write(
        'AppleJournalEntries/index.html',
        '<a href="Entries/2024-11-03_2.html">later</a>'
            '<a href="Entries/2024-11-03.html">earlier</a>',
      );
      write(
        'AppleJournalEntries/Entries/2024-11-03.html',
        page(
          'Youve Connected',
          '<p class="p2"><span class="s2">Paragraph one.</span></p>'
              '<p class="p2"><span class="s2">Paragraph two.</span></p>',
          assets:
              '<div id="IMG1" class="gridItem assetType_stateOfMind">'
              '<img src="../Resources/IMG1.heic"/></div>'
              '<div id="LOC1" class="gridItem assetType_multiPinMap">'
              '<div class="gridItemOverlayFooter">Old Town</div></div>'
              '<div id="IMG2" class="gridItem assetType_photo">'
              '<img src="../Resources/IMG2.heic" class="asset_image"/></div>',
        ),
      );
      write(
        'AppleJournalEntries/Entries/2024-11-03_2.html',
        page('Second', '<p class="p2">Later that day.</p>'),
      );
      write('AppleJournalEntries/Resources/IMG1.heic', [0]);
      write('AppleJournalEntries/Resources/IMG2.heic', [0, 0, 0, 0]);

      final entries = parseAppleJournalExport(extracted(), media).entries;

      expect(entries.map((e) => (e.title, e.createdAt)), [
        ('Youve Connected', DateTime(2024, 11, 3, 12)),
        ('Second', DateTime(2024, 11, 3, 12, 1)),
      ]);
      final first = entries.first;
      // 照片独占首行，纯文本镜像与编辑器的规则一致（嵌入物只留换行）。
      expect(first.contentText, '\nParagraph one.\nParagraph two.');
      expect(first.location, 'Old Town');
      // 心境附件的图标不是照片，只导入真正的照片。
      expect(embedOf(first, 0)['image'], endsWith('IMG2.heic'));
      expect(
        ops(first).where((op) => (op as Map)['insert'] is Map),
        hasLength(1),
      );
      expect(first.sourceKey, 'AppleJournalEntries/Entries/2024-11-03.html');
    });

    test('requires the exported folder archive', () {
      expect(
        () => parseAppleJournalExport(
          JournalImportInput(filePath: p.join(export.path, 'x.html')),
          media,
        ),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });

  group('Diaro', () {
    // 据 Diaro 2025 年真实备份精简：可选表按名称查找，tags 首尾带逗号，
    // date 为 UTC 毫秒、tz_offset 为写日记时所在时区。
    const backup = '''<data version="2">
<table name="diaro_folders">
<r>
   <uid>f1</uid>
   <title>Vacations</title>
   <color>#FF9800</color>
   <pattern></pattern>
</r>
</table>
<table name="diaro_tags">
<r>
   <uid>t1</uid>
   <title>Idea</title>
</r>
<r>
   <uid>t2</uid>
   <title>Dream</title>
</r>
</table>
<table name="diaro_moods">
<r>
   <uid>2</uid>
   <title>Happy</title>
   <weight>4</weight>
</r>
</table>
<table name="diaro_locations">
<r>
   <uid>l1</uid>
   <title></title>
   <address>Male, Maldives</address>
   <lat>3.91786</lat>
   <lng>73.4676353</lng>
</r>
</table>
<table name="diaro_entries">
<r>
   <uid>e1</uid>
   <date>1754923517768</date>
   <tz_offset>-04:00</tz_offset>
   <title>Some note</title>
   <text>- With metadata
- 16:46</text>
   <folder_uid>f1</folder_uid>
   <location_uid>l1</location_uid>
   <tags>,t1,t2,</tags>
   <weather_temperature>20</weather_temperature>
   <weather_icon>day-sunny</weather_icon>
   <weather_description>clear sky</weather_description>
   <mood>2</mood>
</r>
<r>
   <uid>e2</uid>
   <date>1755787474567</date>
   <tz_offset>+02:00</tz_offset>
   <title></title>
   <text>Only text &amp; -&gt; arrow</text>
   <folder_uid>missing</folder_uid>
   <tags></tags>
   <weather_temperature>null</weather_temperature>
   <weather_icon></weather_icon>
   <weather_description></weather_description>
   <mood>5</mood>
</r>
</table>
<table name="diaro_attachments">
<r>
   <uid>a2</uid>
   <entry_uid>e1</entry_uid>
   <type>photo</type>
   <filename>second.jpg</filename>
   <position>2</position>
</r>
<r>
   <uid>a1</uid>
   <entry_uid>e1</entry_uid>
   <type>photo</type>
   <filename>first.jpg</filename>
   <position>1</position>
</r>
</table>
</data>''';

    test('maps entries with tags, folder, mood, place, weather and photos', () {
      write('DiaroBackup.xml', backup);
      write('media/photo/first.jpg', _jpeg);

      final result = parseDiaroExport(extracted(), media);

      final [entry, plain] = result.entries;
      expect(entry.sourceKey, 'e1');
      expect(entry.title, 'Some note');
      // 2025-08-11T14:45:17.768Z 在 -04:00 是 10:45:17。
      expect(entry.createdAt, DateTime(2025, 8, 11, 10, 45, 17, 768));
      expect(entry.contentText, '\n- With metadata\n- 16:46');
      expect(entry.tags, ['Idea', 'Dream']);
      expect(entry.notebooks, ['Vacations']);
      expect(entry.moodLevel, 4);
      expect(entry.weather, 'clear sky 20℃');
      expect(entry.location, 'Male, Maldives');
      expect((entry.latitude, entry.longitude), (3.91786, 73.4676353));
      final image = embedOf(entry, 0)['image'] as String;
      expect(p.basename(image), 'first.jpg');
      // second.jpg 在备份里缺失。
      expect(result.missingMediaCount, 1);

      expect(plain.title, isEmpty);
      expect(plain.contentText, 'Only text & -> arrow');
      expect(plain.tags, isEmpty);
      expect(plain.weather, isNull);
      // 没有心情表的旧刻度：1 最好、5 最差。
      expect(plain.moodLevel, 1);
    });

    test('explains that encrypted backups cannot be imported', () {
      write('DiaroBackup.denc', 'U2FsdGVk');
      write('media/photo/a.jpg', _jpeg);
      expect(
        () => parseDiaroExport(extracted(), media),
        throwsA(
          isA<JournalImportFormatException>().having(
            (error) => error.encrypted,
            'encrypted',
            isTrue,
          ),
        ),
      );
    });
  });
}
