import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'journal_import_fixture.dart';

/// 各文件来源的最小有效导出：含中文、表情、已知日期和一份字节可比对的
/// 媒体，用于验证解析、预检、事务落库、再次导入和媒体重绑的完整链路。
Future<File> writeJournalExportSample(
  Directory directory,
  JournalImportSource source,
) async {
  const body = '正文 😀';
  const date = '2024-02-29T08:30:00Z';
  const noteId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const resourceId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  final millis = DateTime.utc(2024, 2, 29, 8, 30).millisecondsSinceEpoch;
  final files = <String, Object>{};
  void photo([String path = 'photo.jpg']) =>
      files[path] = JournalImportFixture.jpeg;
  var extension = 'zip';
  List<int>? raw;
  switch (source) {
    case JournalImportSource.dayOne:
      files['Journal.json'] = {
        'entries': [
          {
            'uuid': 'one',
            'creationDate': date,
            'text': '$body\n![](dayone-moment://p)',
            'photos': [
              {'identifier': 'p', 'md5': 'photo'},
            ],
            'tags': ['标签'],
          },
        ],
      };
      photo('photos/photo.jpg');
    case JournalImportSource.journey:
      files['one.json'] = {
        'id': 'one',
        'date_journal': millis,
        'text': body,
        'photos': ['photo.jpg'],
        'tags': ['标签'],
      };
      photo();
    case JournalImportSource.diarium:
      final file = File(p.join(directory.path, 'sample.diary'));
      final database = sqlite3.open(file.path);
      final ticks =
          621355968000000000 +
          DateTime.utc(2024, 2, 29, 8, 30).microsecondsSinceEpoch * 10;
      try {
        database.execute(
          'CREATE TABLE Entries (DiaryEntryId INTEGER PRIMARY KEY, Text TEXT)',
        );
        database.execute(
          'CREATE TABLE Media (DiaryEntryId INTEGER, Data BLOB, Name TEXT, FileEnding TEXT)',
        );
        database.execute('INSERT INTO Entries VALUES (?, ?)', [ticks, body]);
        database.execute('INSERT INTO Media VALUES (?, ?, ?, ?)', [
          ticks,
          JournalImportFixture.jpeg,
          'photo',
          'jpg',
        ]);
      } finally {
        database.close();
      }
      return file;
    case JournalImportSource.daylio:
      files['backup.daylio'] = base64.encode(
        utf8.encode(
          jsonEncode({
            'dayEntries': [
              {
                'year': 2024,
                'month': 1,
                'day': 29,
                'hour': 8,
                'minute': 30,
                'note': body,
                'assets': [1],
              },
            ],
            'assets': [
              {'id': 1, 'checksum': 'photo', 'type': 1},
            ],
          }),
        ),
      );
      photo('assets/photo.jpg');
    case JournalImportSource.appleJournal:
      files['Entries/2024-02-29.html'] =
          '<div class="pageHeader">29 February 2024</div>'
          '<div class="assetGrid"><div class="gridItem assetType_photo"><img src="../Resources/photo.jpg"></div></div>'
          '<div class="bodyText"><p>$body</p></div>';
      photo('Resources/photo.jpg');
    case JournalImportSource.diaro:
      files['DiaroBackup.xml'] =
          '<data><table name="diaro_entries"><r><uid>one</uid><date>$millis</date><text>$body</text></r></table>'
          '<table name="diaro_attachments"><r><entry_uid>one</entry_uid><filename>photo.jpg</filename><type>photo</type></r></table></data>';
      photo('media/photo/photo.jpg');
    case JournalImportSource.evernote:
      extension = 'enex';
      raw = utf8.encode(
        '<en-export><note><title>标题</title><created>20240229T083000Z</created>'
        '<content><![CDATA[<en-note>$body</en-note>]]></content>'
        '<resource><data encoding="base64">${base64.encode(JournalImportFixture.jpeg)}</data>'
        '<mime>image/jpeg</mime></resource></note></en-export>',
      );
    case JournalImportSource.googleKeep:
      files['Takeout/Keep/one.json'] = {
        'title': '标题',
        'createdTimestampUsec': millis * 1000,
        'textContent': body,
        'attachments': [
          {'filePath': 'photo.jpg', 'mimetype': 'image/jpeg'},
        ],
      };
      photo('Takeout/Keep/photo.jpg');
    case JournalImportSource.joplin:
      extension = 'jex';
      files['$noteId.md'] =
          '标题\n\n$body\n![](:/$resourceId)\n\nid: $noteId\ncreated_time: $date\nmarkup_language: 1\ntype_: 1';
      files['$resourceId.md'] =
          'photo.jpg\n\nid: $resourceId\nmime: image/jpeg\ntype_: 4';
      photo('resources/$resourceId.jpg');
    case JournalImportSource.memos:
      files['manifest.json'] = {
        'format': 'memos-export',
        'formatVersion': '1.0',
      };
      files['memos/one.json'] = {
        'uid': 'one',
        'createTime': date,
        'contentPath': 'memos/one.md',
        'attachments': [
          {
            'uid': 'photo',
            'filename': 'photo.jpg',
            'path': 'attachments/photo.jpg',
          },
        ],
      };
      files['memos/one.md'] = '$body\n![](/file/attachments/photo)';
      photo('attachments/photo.jpg');
    case JournalImportSource.markdown:
      files['note.md'] =
          '---\ndate: $date\ntags: [标签]\n---\n$body\n![](photo.jpg)';
      photo();
    default:
      throw ArgumentError.value(source);
  }
  if (raw == null) {
    final archive = Archive();
    for (final entry in files.entries) {
      final content = entry.value;
      final bytes = content is List<int>
          ? content
          : utf8.encode(content is String ? content : jsonEncode(content));
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    // gzip 外壳同样出现在用户保存的 JEX 中，验证解压不会把整包留在内存。
    raw = extension == 'jex'
        ? gzip.encode(TarEncoder().encode(archive))
        : ZipEncoder().encode(archive)!;
  }
  return File(
    p.join(directory.path, '${source.name}.$extension'),
  ).writeAsBytes(raw);
}
