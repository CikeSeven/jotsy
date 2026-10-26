import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_evernote.dart';
import 'package:node_diary/core/services/journal_import_google_keep.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_memos.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;
import '../../support/diary_content_test_helpers.dart';

const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, //
];
const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];

/// Evernote v10 的导出结构（据官方 DTD 与 yarle/obsidian-importer 的真实
/// 样例精简）：经典 `<en-todo/>` 与 v10 `--en-todo` 列表、`<task>`、代码块、
/// base64 换行的附件、正文未引用的附件、`&nbsp;` 等 HTML 实体。
String _enex() {
  final image = base64.encode(_png);
  final hash = md5.convert(_png).toString();
  final pdf = base64.encode(utf8.encode('%PDF-1.4'));
  return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export4.dtd">
<en-export export-date="20240301T091500Z" application="Evernote" version="10.76.2">
  <note>
    <title>Packing list</title>
    <created>20240228T183012Z</created>
    <updated>20240229T070145Z</updated>
    <tag>travel</tag>
    <note-attributes>
      <latitude>47.49791</latitude>
      <longitude>19.04023</longitude>
    </note-attributes>
    <content>
      <![CDATA[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd"><en-note><div>Before&nbsp;leaving:</div><ul><li><div><en-todo checked="true"/>Passport</div></li></ul><div><en-todo/>Charger</div><ul style="--en-todo:true;"><li style="--en-checked:true;"><div>Print tickets</div></li></ul><div style="--en-task-group:true; --en-id:g1;">Content not supported</div><div><en-media hash="$hash" type="image/png" width="120px" />after image</div><div style="--en-codeblock:true;"><div>void main() {}</div></div><en-crypt hint="h">c2VjcmV0</en-crypt></en-note>      ]]>
    </content>
    <task>
      <title>Second</title><taskStatus>completed</taskStatus>
      <sortWeight>V</sortWeight><taskGroupNoteLevelID>g1</taskGroupNoteLevelID>
    </task>
    <task>
      <title>First</title><taskStatus>open</taskStatus>
      <sortWeight>U</sortWeight><taskGroupNoteLevelID>g1</taskGroupNoteLevelID>
    </task>
    <resource>
      <data encoding="base64">
${image.substring(0, 8)}
${image.substring(8)}
</data>
      <mime>image/png</mime>
      <resource-attributes><file-name>map.png</file-name></resource-attributes>
    </resource>
    <resource>
      <data encoding="base64">$pdf</data>
      <mime>application/pdf</mime>
      <resource-attributes><file-name>ticket.pdf</file-name></resource-attributes>
    </resource>
  </note>
  <note>
    <title>Caption &amp; more</title>
    <created>20180306T91108 PMZ</created>
    <content><![CDATA[<en-note><div>R&amp;D</div></en-note>]]></content>
  </note>
</en-export>''';
}

void main() {
  late Directory temp;
  late Directory export;
  late JournalMediaStager media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cloud_notes_test_');
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

  List<Map<String, Object?>> embeds(JournalImportEntry entry) => [
    for (final op in ops(entry))
      if ((op as Map)['insert'] case final Map<String, Object?> data) data,
  ];

  group('Evernote ENEX', () {
    test('maps checklists, tasks, code, media by MD5 and attributes', () {
      final file = File(p.join(temp.path, 'Travel.enex'))
        ..writeAsStringSync(_enex());

      final result = parseEvernoteExport(
        JournalImportInput(filePath: file.path),
        media,
      );

      final [note, second] = result.entries;
      expect(note.title, 'Packing list');
      expect(note.createdAt, DateTime.utc(2024, 2, 28, 18, 30, 12).toLocal());
      expect(note.updatedAt, DateTime.utc(2024, 2, 29, 7, 1, 45).toLocal());
      expect(note.tags, ['travel']);
      expect((note.latitude, note.longitude), (47.49791, 19.04023));
      expect(
        note.contentText,
        'Before leaving:\nPassport\nCharger\nPrint tickets\nFirst\nSecond\n\n'
        'after image\nvoid main() {}',
      );
      final lists = [
        for (final op in ops(note))
          if (((op as Map)['attributes'] as Map?)?['list'] case final list?)
            list,
      ];
      expect(lists, [
        'checked',
        'unchecked',
        'checked',
        'unchecked',
        'checked',
      ]);
      expect(note.contentJson, contains('"type":"code"'));
      final [image, pdf] = embeds(note);
      expect(p.basename(image['image'] as String), 'map.png');
      expect(
        (jsonDecode(pdf['attachment'] as String) as Map)['name'],
        'ticket.pdf',
      );

      expect(second.title, 'Caption & more');
      expect(second.contentText, 'R&D');
      expect(second.createdAt, DateTime.utc(2018, 3, 6, 21, 11, 8).toLocal());
      // 只有一个笔记本，不额外加笔记本标签。
      expect(second.tags, isEmpty);
      expect(result.missingMediaCount, 0);
    });

    test('records the notebook when several are packed', () {
      write('Work.enex', _enex());
      write('Home.enex', _enex());

      final result = parseEvernoteExport(extracted(), media);

      expect(result.entries.map((entry) => entry.notebooks.single).toSet(), {
        'Home',
        'Work',
      });
      expect(
        result.entries.expand((entry) => entry.tags),
        isNot(anyOf(contains('Home'), contains('Work'))),
      );
      expect(
        result.entries.map((entry) => entry.sourceKey).toSet(),
        hasLength(4),
      );
    });

    test('splits notes whose markers straddle the 1 MB read boundary', () {
      const block = 1 << 20;
      const head = '<en-export>';
      String note(String title, int padding) =>
          '<note><title>$title</title><content><![CDATA[<en-note>$title'
          '</en-note>]]>${' ' * padding}</content></note>';
      // 第一篇的 `</note>` 从第一块末尾前 3 个字符开始。
      final first = note('one', 0);
      final firstPadding = block - 3 - head.length - (first.length - 7);
      final text = StringBuffer(head)..write(note('one', firstPadding));
      // 第二篇的 `<note>` 从第二块末尾前 2 个字符开始。
      text.write(' ' * (2 * block - 2 - text.length));
      text.write(note('two', 0));
      text.write('</en-export>');
      final file = File(p.join(temp.path, 'Big.enex'))
        ..writeAsStringSync(text.toString());

      final result = parseEvernoteExport(
        JournalImportInput(filePath: file.path),
        media,
      );

      expect(result.entries.map((entry) => entry.title), ['one', 'two']);
      expect(result.entries.map((entry) => entry.contentText), ['one', 'two']);
    });

    test('rejects files without notes', () {
      final file = File(p.join(temp.path, 'x.enex'))
        ..writeAsStringSync('<html><body>nope</body></html>');
      expect(
        () =>
            parseEvernoteExport(JournalImportInput(filePath: file.path), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });

  group('Google Keep', () {
    test('maps text, checklists, labels and the .jpeg/.jpg quirk', () {
      write('Takeout/Keep/Shopping list.json', {
        'attachments': [
          {
            'filePath': '1704457312955.1681549363.jpeg',
            'mimetype': 'image/jpeg',
          },
          {'filePath': 'gone.png', 'mimetype': 'image/png'},
        ],
        'color': 'YELLOW',
        'isTrashed': false,
        'isPinned': true,
        'isArchived': true,
        'listContent': [
          {'text': 'Milk', 'isChecked': false},
          {'text': 'Eggs', 'isChecked': true},
        ],
        'annotations': [
          {
            'url': 'https://example.com',
            'title': 'Recipe',
            'source': 'WEBLINK',
          },
        ],
        'title': 'Shopping\nlist',
        'userEditedTimestampUsec': 1704457401123000,
        'createdTimestampUsec': 1704457290456000,
        'labels': [
          {'name': 'Home'},
        ],
      });
      write('Takeout/Keep/1704457312955.1681549363.jpg', _jpeg);
      write('Takeout/Keep/Shopping list.html', '<html></html>');
      write('Takeout/Keep/Labels.txt', 'Home');
      write('Takeout/Keep/2021-08-26T12_50_07.132+05_00.json', {
        'textContentHtml':
            '<p dir="ltr"><span style="font-weight:400">hello</span></p>'
            '<br /><p dir="ltr"><span style="font-weight:700">bold</span></p>',
        'textContent': 'hello\n\nbold',
        'title': '',
        'userEditedTimestampUsec': 1629964346280000,
        'isTrashed': false,
      });
      write('Takeout/Keep/Deleted.json', {
        'textContent': 'gone',
        'title': 'Deleted',
        'userEditedTimestampUsec': 1629964346280000,
        'isTrashed': true,
      });

      final result = parseGoogleKeepExport(extracted(), media);

      final byTitle = {for (final e in result.entries) e.title: e};
      expect(byTitle.keys, {'', 'Shopping list'});
      final list = byTitle['Shopping list']!;
      expect(
        list.createdAt,
        DateTime.utc(2024, 1, 5, 12, 21, 30, 456).toLocal(),
      );
      expect(
        list.updatedAt,
        DateTime.utc(2024, 1, 5, 12, 23, 21, 123).toLocal(),
      );
      expect(list.tags, ['Home']);
      expect(list.pinned, isTrue);
      expect(list.archived, isTrue);
      expect(list.contentText, '\nMilk\nEggs\nRecipe');
      expect(
        p.basename(embeds(list).single['image'] as String),
        endsWith('.jpg'),
      );
      expect(list.contentJson, contains('"href":"https://example.com"'));
      expect(result.missingMediaCount, 1);

      // 2021 年的导出没有创建时间，取编辑时间；富文本保留粗体与段间空行。
      final old = byTitle['']!;
      expect(
        old.createdAt,
        DateTime.utc(2021, 8, 26, 7, 52, 26, 280).toLocal(),
      );
      expect(old.contentText, 'hello\n\nbold');
      expect(old.contentJson, contains('"bold":true'));
    });

    test('rejects JSON that is not a Keep note', () {
      write('Takeout/Keep/x.json', {'hello': 'world'});
      expect(
        () => parseGoogleKeepExport(extracted(), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });

  group('Memos', () {
    test('reads Memos Export Format 1.0 with inline and trailing files', () {
      write('manifest.json', {
        'format': 'memos-export',
        'formatVersion': '1.0',
        'generator': {'name': 'memos', 'version': '0.31.0'},
        'exportTime': '2026-09-16T08:30:00Z',
        'scope': {'kind': 'USER'},
      });
      write('memos/Ab3kZ9q2.json', {
        'uid': 'Ab3kZ9q2',
        'creator': 'steven',
        'createTime': '2026-03-02T14:05:11Z',
        'updateTime': '2026-03-02T14:20:47Z',
        'state': 'ARCHIVED',
        'visibility': 'PRIVATE',
        'pinned': true,
        'contentPath': 'memos/Ab3kZ9q2.md',
        'tags': ['work', 'work/q3'],
        'location': {
          'placeholder': 'Office',
          'latitude': 52.52,
          'longitude': 13.405,
        },
        'attachments': [
          {
            'uid': 'att1',
            'filename': 'whiteboard photo.jpg',
            'type': 'image/jpeg',
            'path': 'attachments/att1/whiteboard photo.jpg',
          },
          {
            'uid': 'att2',
            'filename': 'notes.pdf',
            'type': 'application/pdf',
            'path': 'attachments/att2/notes.pdf',
          },
          {
            'uid': 'att3',
            'filename': 'spec.pdf',
            'externalLink': 'https://files.example.com/spec.pdf',
          },
        ],
      });
      write(
        'memos/Ab3kZ9q2.md',
        '# Whiteboard\n\nSee ![](/file/attachments/att1) #work',
      );
      write('attachments/att1/whiteboard photo.jpg', _jpeg);
      write('attachments/att2/notes.pdf', utf8.encode('%PDF'));

      final entry = parseMemosExport(extracted(), media).entries.single;

      expect(entry.sourceKey, 'Ab3kZ9q2');
      expect(entry.title, 'Whiteboard');
      expect(entry.createdAt, DateTime.utc(2026, 3, 2, 14, 5, 11).toLocal());
      expect(entry.updatedAt, DateTime.utc(2026, 3, 2, 14, 20, 47).toLocal());
      expect(entry.tags, ['work', 'work/q3']);
      expect(entry.pinned, isTrue);
      expect(entry.archived, isTrue);
      expect(entry.location, 'Office');
      expect((entry.latitude, entry.longitude), (52.52, 13.405));
      expect(entry.contentText, 'See\n\n#work\n\nspec.pdf');
      final [photo, pdf] = embeds(entry);
      expect(p.basename(photo['image'] as String), 'whiteboard photo.jpg');
      expect(pdf.keys, ['attachment']);
    });

    test('reads the legacy flat Markdown export', () {
      write('2024-07-19T10:20:30Z-8Q3f-J9c2-PRIVATE.md', 'hello **memos**');
      write('2024-02-03T01:02:03+08:00.md', 'oldest');

      final result = parseMemosExport(extracted(), media);

      final byKey = {for (final e in result.entries) e.sourceKey: e};
      expect(byKey.keys, {'8Q3f-J9c2', '2024-02-03T01:02:03+08:00'});
      expect(
        byKey['8Q3f-J9c2']!.createdAt,
        DateTime.utc(2024, 7, 19, 10, 20, 30).toLocal(),
      );
      expect(byKey['8Q3f-J9c2']!.contentText, 'hello memos');
    });

    test('rejects archives that are not Memos exports', () {
      write('notes.md', 'hello');
      expect(
        () => parseMemosExport(extracted(), media),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });
}
