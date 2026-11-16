import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/core/services/journal_import_markdown_files.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_note_links.dart';
import 'package:node_diary/core/services/journal_import_payload.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];

/// 导入后那篇笔记的日记链接地址（Markdown 来源的稳定键是相对路径）。
String _href(String sourceKey) => DiaryLinkTarget.diary(
  journalImportDiaryId(JournalImportSource.markdown, sourceKey),
).toHref();

/// 正文里的行内片段：（文字，日记链接地址或 null）。
List<(String, String?)> _runs(JournalImportEntry entry) => [
  for (final (node, _) in walkDiaryBlocks(
    jsonDecode(entry.contentJson) as Map<String, Object?>,
  ))
    for (final op in diaryBlockDelta(node))
      (
        op['insert'] as String,
        (op['attributes'] as Map?)?[kDiaryInlineHref] as String?,
      ),
];

/// 带链接的片段：文字 → 地址。
Map<String, String> _links(JournalImportEntry entry) => {
  for (final (text, href) in _runs(entry))
    if (href != null) text: href,
};

List<Map<String, Object?>> _cards(JournalImportEntry entry) => [
  for (final (node, _) in walkDiaryBlocks(
    jsonDecode(entry.contentJson) as Map<String, Object?>,
  ))
    if (node[kDiaryBlockTypeKey] == kDiaryBlockLinkCard) diaryBlockData(node),
];

void main() {
  late Directory temp;
  late Directory export;
  late JournalMediaStager media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('note_links_test');
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

  Map<String, JournalImportEntry> parse() => {
    for (final entry in parseMarkdownFilesExport(
      JournalImportInput(filePath: export.path, extractedPath: export.path),
      media,
    ).entries)
      entry.sourceKey: entry,
  };

  group('Obsidian wiki links', () {
    test('become diary links to the imported notes', () {
      write('Vault/Travel/Kyoto.md', '''
See [[Packing list]], [[packing LIST.md|the list]] and [[Packing list#Shoes]].
Also [[Daily/2024-01-15|that morning]] and [[../Daily/2024-01-15]].
Back to [[#Plan]] and [[Nowhere]]; ![[photo.jpg|300]]
''');
      write('Vault/Travel/Packing list.md', 'shoes');
      write('Vault/Daily/2024-01-15.md', 'walk');
      write('Vault/attachments/photo.jpg', _jpeg);

      final entries = parse();
      final kyoto = entries['Vault/Travel/Kyoto.md']!;

      final packing = _href('Vault/Travel/Packing list.md');
      final morning = _href('Vault/Daily/2024-01-15.md');
      expect(_runs(kyoto).where((run) => run.$2 == packing).map((r) => r.$1), [
        'Packing list',
        'the list',
        'Packing list',
      ]);
      expect(_links(kyoto)['that morning'], morning);
      expect(_links(kyoto)['../Daily/2024-01-15'], morning);
      // 指向本篇标题与库里没有的笔记只留文字；附件照常嵌入。
      expect(kyoto.contentText, contains('Back to Plan and Nowhere;'));
      expect(_links(kyoto).keys, isNot(contains('Plan')));
      expect(_links(kyoto).keys, isNot(contains('Nowhere')));
      expect(media.missingCount, 0);
    });

    test('a link into the import resolves to that diary in the payload', () {
      write('Notes/A.md', 'to [[B]]');
      write('Notes/sub/B.md', 'to [[A|back]]');

      final entries = parse().values.toList();
      final payload = buildJournalImportPayload(
        JournalImportSource.markdown,
        entries,
      );

      final ids = {
        for (final diary in payload.diaries) diary.title: diary.diaryId,
      };
      final a = entries.firstWhere((entry) => entry.title == 'A');
      final b = entries.firstWhere((entry) => entry.title == 'B');
      expect(_links(a), {'B': DiaryLinkTarget.diary(ids['B']!).toHref()});
      expect(_links(b), {'back': DiaryLinkTarget.diary(ids['A']!).toHref()});
    });

    test('![[note]] embeds become link cards on their own line', () {
      write('Vault/Index.md', 'Before\n![[Recipes#Soup]] after');
      write('Vault/Recipes.md', 'soup');

      final index = parse()['Vault/Index.md']!;

      expect(_cards(index), [
        {
          kDiaryLinkCardTargetKey: _href('Vault/Recipes.md'),
          kDiaryLinkCardTitleKey: 'Recipes',
        },
      ]);
      expect(index.contentText, 'Before\n\nafter');
    });

    test(
      'same-name notes prefer the linking folder, then the shortest path',
      () {
        write('Vault/Work/Ideas.md', 'work ideas');
        write('Vault/Home/Ideas.md', 'home ideas');
        write('Vault/Home/Log.md', '[[Ideas]]');
        write('Vault/Ideas.md', 'root ideas');
        write('Vault/Other/Log2.md', '[[ideas]] and [[Work/Ideas|work]]');

        final entries = parse();

        expect(_links(entries['Vault/Home/Log.md']!), {
          'Ideas': _href('Vault/Home/Ideas.md'),
        });
        expect(_links(entries['Vault/Other/Log2.md']!), {
          'ideas': _href('Vault/Ideas.md'),
          'work': _href('Vault/Work/Ideas.md'),
        });
      },
    );

    test('code stays literal and table cells keep their aliases', () {
      write('Vault/Table.md', '''
`[[Target]]` and [[Target]]
| Link | Note |
| --- | --- |
| [[Target\\|alias]] | x |
```
[[Target]]
```
''');
      write('Vault/Target.md', 'target');

      final table = parse()['Vault/Table.md']!;
      final target = _href('Vault/Target.md');

      expect(_runs(table).first, ('[[Target]]', null));
      expect(_links(table), {'Target': target, 'alias': target});
      final nodes = walkDiaryBlocks(
        jsonDecode(table.contentJson) as Map<String, Object?>,
      ).map((entry) => entry.$1[kDiaryBlockTypeKey]).toList();
      expect(nodes, containsAll([kDiaryBlockTable, 'code']));
      expect(table.contentText, contains('[[Target]]'));
    });

    test('a heading title with a wiki link keeps only its text', () {
      write('Vault/Trip.md', '# Trip to [[Kyoto|Kyoto city]]\nday one');
      write('Vault/Kyoto.md', 'temple');

      expect(parse()['Vault/Trip.md']!.title, 'Trip to Kyoto city');
    });
  });

  group('Markdown links to notes', () {
    test('relative .md links (Obsidian, Notion) become diary links', () {
      write(
        'Export/Home 0123456789abcdef0123456789abcdef.md',
        '[Trip](Trip%20abcdefabcdefabcdefabcdefabcdefabcd.md) and '
            '[Soup](Recipes/Soup.md#Steps) and [Gone](Missing.md)',
      );
      write('Export/Trip abcdefabcdefabcdefabcdefabcdefabcd.md', 'trip');
      write('Export/Recipes/Soup.md', 'soup');

      final home = parse()['Export/Home 0123456789abcdef0123456789abcdef.md']!;

      expect(_links(home), {
        'Trip': _href('Export/Trip abcdefabcdefabcdefabcdefabcdefabcd.md'),
        'Soup': _href('Export/Recipes/Soup.md'),
      });
      expect(home.contentText, 'Trip and Soup and Gone');
      expect(media.missingCount, 0);
    });

    test('an internal address not from this import is not kept', () {
      write('Vault/Note.md', '[forged](jotsy://diary/somebody-else)');

      final note = parse()['Vault/Note.md']!;

      expect(_links(note), isEmpty);
      expect(note.contentText, 'forged');
    });
  });

  group('rewriteJournalWikiLinks', () {
    test('without a resolver every link is plain text', () {
      expect(
        rewriteJournalWikiLinks(
          '[[A|alias]] [[B#H]] [[#Only]] ![[C]] ![[pic.png|200]]',
        ),
        'alias B Only C ![](pic.png)',
      );
    });

    test('link text keeps backslashes; bracketed text is not a link', () {
      final target = const DiaryLinkTarget.diary('x');
      expect(
        rewriteJournalWikiLinks('[[A|see [1]]]', resolve: (_) => target),
        '[[A|see [1]]]',
      );
      expect(
        rewriteJournalWikiLinks(r'[[A|a\b]]', resolve: (_) => target),
        r'[a\\b](jotsy://diary/x)',
      );
    });
  });
}
