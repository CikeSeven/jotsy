import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_note_bridge.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];

/// 与「笔记互迁」1.0.0 实际导出一致的片段（由参考项目的 exporter 生成后精简）。
const _noteHtml =
    '<h2>周末计划</h2><div class="meta">创建时间：2024-11-03 08:30:05+08:00'
    '<br>修改时间：2024-11-04 10:00:00+08:00</div>'
    '<h2>安排</h2><p>早上<strong>跑步</strong> 5 公里 &lt;tag&gt;</p>'
    '<p><br></p>'
    '<ul style="margin-left:0.0em"><li>苹果</li></ul>'
    '<ul style="margin-left:1.4em"><li>红富士</li></ul>'
    '<p class="todo">☑ 已完成</p><p class="todo">☐ 未完成</p>'
    '<figure><img src="resources/eb7e0381d519c6a2-%E7%85%A7%E7%89%87%201.jpg" '
    'alt="照片 1.jpg" loading="lazy"><figcaption>照片 1.jpg</figcaption></figure>'
    '<p>📎 <a href="resources/e5c62df5dab5c87b-%E8%AF%B4%E6%98%8E%E4%B9%A6.pdf" '
    'download>说明书.pdf</a></p>'
    '<p class="warning">附件未获取</p>'
    '<p class="warning">原笔记的文字颜色、字号、字体或对齐方式已转换为默认排版。</p>';

const _untitledHtml =
    '<h2>买菜清单</h2><div class="meta">创建时间：未知<br>'
    '修改时间：2023-01-02 03:04:05+00:00</div><p>买菜清单</p><p>鸡蛋</p>';

String _mergedHtml(String label, List<String> notes) {
  final data = jsonEncode([
    for (final html in notes)
      {'title': 't', 'text': '', 'summary': '', 'created': '', 'html': html},
  ]).replaceAll('<', r'<').replaceAll('>', r'>');
  return '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
      '<title>$label · 笔记互迁</title></head><body><header></header>'
      '<script id="note-data" type="application/json">$data</script>'
      '<script>/* reader */</script></body></html>';
}

const _markdown = '''# 周末计划

创建时间：2024-11-03 08:30:05+08:00
修改时间：2024-11-04 10:00:00+08:00

## 安排

早上**跑步** 5 公里 \\*不\\* &lt;tag&gt;

<strong> 空格粗体 </strong><u>下划线</u><mark>高亮</mark>



# 不是标题

- 苹果

  - 红富士

- [x] 已完成

```
print(1)

print(2)
```

| 名称 | 数量 |
| --- | --- |
| 苹果 | 3 |

![照片 1.jpg](resources/eb7e0381d519c6a2-%E7%85%A7%E7%89%87%201.jpg)

<audio controls src="resources/0534b3d33a669441-%E5%BD%95%E9%9F%B3.m4a"></audio>

[附件：说明书.pdf](resources/e5c62df5dab5c87b-%E8%AF%B4%E6%98%8E%E4%B9%A6.pdf)

[附件未获取：丢失.png]

---

# 买菜清单

创建时间：2024-11-03 08:30:05+08:00
修改时间：未知

买菜清单

---
''';

final _text =
    '﻿周末计划\n'
    '创建时间：2024-11-03 08:30:05+08:00\n'
    '修改时间：2024-11-04 10:00:00+08:00\n'
    '\n'
    '早上跑步\n'
    '• 苹果\n'
    '  • 红富士\n'
    '☑ 已完成\n'
    '${'─' * 20}\n'
    '[提示] 不是附件的提示行留在正文\n'
    '[附件] 照片 1.jpg：resources/eb7e0381d519c6a2-%E7%85%A7%E7%89%87%201.jpg\n'
    '[附件] 丢失.png：未获取\n'
    '[提示] 原笔记的文字颜色、字号、字体或对齐方式已转换为默认排版。'
    '\n\n${'═' * 40}\n\n'
    '买菜清单\n'
    '创建时间：2024-11-03 08:30:05+08:00\n'
    '修改时间：未知\n'
    '\n'
    '买菜清单';

void main() {
  late Directory temp;
  late Directory export;
  late JournalMediaStager media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('note_bridge_test_');
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

  void writeResources() {
    write('resources/eb7e0381d519c6a2-照片 1.jpg', _jpeg);
    write('resources/0534b3d33a669441-录音.m4a', [0, 0, 0, 0x18]);
    write('resources/e5c62df5dab5c87b-说明书.pdf', utf8.encode('%PDF-1.4'));
  }

  JournalImportParseResult parse(
    JournalImportSource source, {
    String zipName = 'export.zip',
  }) => parseNoteBridgeExport(
    source,
    JournalImportInput(
      filePath: p.join(temp.path, zipName),
      extractedPath: export.path,
    ),
    media,
  );

  List<Object?> ops(JournalImportEntry entry) =>
      jsonDecode(entry.contentJson) as List<Object?>;

  List<Map<String, Object?>> embeds(JournalImportEntry entry) => [
    for (final op in ops(entry))
      if ((op as Map)['insert'] case final Map<String, Object?> data) data,
  ];

  group('HTML export', () {
    test('maps the reader data, block markup and resources', () {
      write('小米笔记.html', _mergedHtml('小米笔记', [_noteHtml, _untitledHtml]));
      write('导出说明.json', '{"application": "笔记互迁"}');
      writeResources();

      final result = parse(JournalImportSource.xiaomiNotes);

      final [note, untitled] = result.entries;
      expect(note.title, '周末计划');
      expect(note.createdAt, DateTime.utc(2024, 11, 3, 0, 30, 5).toLocal());
      expect(note.updatedAt, DateTime.utc(2024, 11, 4, 2).toLocal());
      expect(note.tags, isEmpty);
      expect(note.contentText, '安排\n早上跑步 5 公里 <tag>\n\n苹果\n红富士\n已完成\n未完成');
      final lines = ops(note);
      expect(lines[1], {
        'insert': '\n',
        'attributes': {'header': 1},
      });
      expect(
        lines,
        containsAllInOrder([
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': '红富士'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
          {'insert': '已完成'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
        ]),
      );
      final [image, file] = embeds(note);
      expect(p.basename(image['image'] as String), '照片 1.jpg');
      final attachment = jsonDecode(file['attachment'] as String) as Map;
      expect(attachment['name'], '说明书.pdf');
      expect(File(attachment['path'] as String).existsSync(), isTrue);
      // 正文注明“附件未获取”的一项。
      expect(result.missingMediaCount, 1);

      // 无标题笔记由正文首行充当的标题被还原；创建时间未知时取修改时间。
      expect(untitled.title, isEmpty);
      expect(untitled.contentText, '买菜清单\n鸡蛋');
      expect(untitled.createdAt, DateTime.utc(2023, 1, 2, 3, 4, 5).toLocal());
      expect(note.sourceKey, '2024-11-03T00:30:05.000Z|周末计划');
    });

    test('reads one-note-per-file pages of a multi-file export', () {
      write(
        '0001、周末计划.html',
        '<html><head><title>小米笔记 · 笔记互迁</title></head><body>'
            '<main class="single"><article>$_noteHtml</article></main>'
            '</body></html>',
      );
      writeResources();

      final entry = parse(JournalImportSource.xiaomiNotes).entries.single;

      expect(entry.title, '周末计划');
      expect(embeds(entry), hasLength(2));
    });
  });

  group('Markdown export', () {
    test('restores one line per block, inline HTML and media', () {
      write('小米笔记.md', _markdown);
      writeResources();

      final result = parse(JournalImportSource.xiaomiNotes);

      final [note, untitled] = result.entries;
      expect(note.title, '周末计划');
      expect(
        note.contentText,
        '安排\n早上跑步 5 公里 *不* <tag>\n空格粗体 下划线高亮\n\n# 不是标题\n'
        '苹果\n红富士\n已完成\nprint(1)\n\nprint(2)\n名称 数量\n苹果 3',
      );
      expect(
        ops(note),
        containsAllInOrder([
          {
            'insert': '空格粗体 ',
            'attributes': {'bold': true},
          },
          {
            'insert': '下划线',
            'attributes': {'underline': true},
          },
          {'insert': '高亮\n\n# 不是标题\n苹果'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': '红富士'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
        ]),
      );
      final [image, audio, file] = embeds(note);
      expect(p.basename(image['image'] as String), '照片 1.jpg');
      expect(audio.keys, ['audio']);
      expect(
        (jsonDecode(file['attachment'] as String) as Map)['name'],
        '说明书.pdf',
      );
      expect(result.missingMediaCount, 1);
      expect(untitled.title, isEmpty);
      expect(untitled.contentText, '买菜清单');
      expect(untitled.updatedAt, untitled.createdAt);
    });

    test('prefers the HTML copy when several formats are packed together', () {
      write(
        '小米笔记-20261016-030104-html/小米笔记.html',
        _mergedHtml('小米笔记', [_noteHtml]),
      );
      write('小米笔记-20261016-030104-md/小米笔记.md', _markdown);

      final result = parse(JournalImportSource.xiaomiNotes);

      expect(result.entries.map((entry) => entry.title), ['周末计划']);
    });
  });

  group('TXT export', () {
    test('maps list markers and trailing attachments, drops notices', () {
      write('小米笔记.txt', _text);
      writeResources();

      final result = parse(JournalImportSource.xiaomiNotes);

      final [note, untitled] = result.entries;
      expect(note.contentText, '早上跑步\n苹果\n红富士\n已完成\n[提示] 不是附件的提示行留在正文');
      expect(
        ops(note),
        containsAllInOrder([
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
          {'insert': '已完成'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
        ]),
      );
      expect(p.basename(embeds(note).single['image'] as String), '照片 1.jpg');
      expect(result.missingMediaCount, 1);
      expect(untitled.title, isEmpty);
    });
  });

  group('platform and safety checks', () {
    test('rejects an export labelled with another platform', () {
      write('华为备忘录.md', _markdown);
      expect(
        () => parse(JournalImportSource.xiaomiNotes),
        throwsA(isA<JournalImportFormatException>()),
      );
      expect(parse(JournalImportSource.huaweiNotepad).entries, hasLength(2));
    });

    test('uses the packed folder name when the files are unlabelled', () {
      write('0001、周末计划.md', _markdown.split('---\n\n').first);
      expect(
        () => parse(
          JournalImportSource.oppoNotes,
          zipName: '荣耀笔记-20261016-030104-md-多文件.zip',
        ),
        throwsA(isA<JournalImportFormatException>()),
      );
      expect(parse(JournalImportSource.oppoNotes).entries, hasLength(1));
    });

    test('never reads files outside the export folder', () {
      File(p.join(temp.path, 'secret.jpg')).writeAsBytesSync(_jpeg);
      write(
        '小米笔记.html',
        _mergedHtml('小米笔记', [
          '<h2>t</h2><div class="meta">创建时间：未知<br>修改时间：未知</div>'
              '<p>正文</p><figure><img src="../secret.jpg"></figure>',
        ]),
      );

      final result = parse(JournalImportSource.xiaomiNotes);

      expect(embeds(result.entries.single), isEmpty);
      expect(result.missingMediaCount, 1);
    });

    test('shares one resource between notes that reference it', () {
      // 资源按内容摘要命名，同一张图被两篇引用时共用一个文件；暂存时文件被
      // 移走，第二篇必须从缓存取，不能算作缺失。
      const shared =
          '<figure><img src="resources/eb7e0381d519c6a2-%E7%85%A7%E7%89%87%201.jpg">'
          '</figure>';
      write(
        '小米笔记.html',
        _mergedHtml('小米笔记', [
          '<h2>a</h2><div class="meta">创建时间：未知<br>修改时间：未知</div>'
              '<p>一</p>$shared',
          '<h2>b</h2><div class="meta">创建时间：未知<br>修改时间：未知</div>'
              '<p>二</p>$shared',
        ]),
      );
      writeResources();

      // 与真实流程一致：解压目录在暂存区内，暂存媒体是移动而不是复制。
      final result = parseNoteBridgeExport(
        JournalImportSource.xiaomiNotes,
        JournalImportInput(filePath: export.path, extractedPath: export.path),
        JournalMediaStager(temp.path),
      );

      final images = [
        for (final entry in result.entries) embeds(entry).single['image'],
      ];
      expect(images[0], images[1]);
      expect(File(images[0] as String).existsSync(), isTrue);
      expect(result.missingMediaCount, 0);
    });

    test('rejects files that are not Note Bridge exports', () {
      write('notes.md', '# Hello\n\nworld');
      write(
        'page.html',
        '<html><body><article><h2>x</h2></article></body></html>',
      );
      expect(
        () => parse(JournalImportSource.wpsNotes),
        throwsA(isA<JournalImportFormatException>()),
      );
    });
  });
}
