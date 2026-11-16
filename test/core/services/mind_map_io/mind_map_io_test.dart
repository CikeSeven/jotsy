import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_schema.dart';
import 'package:node_diary/core/services/mind_map_io/mind_map_file_formats.dart';
import 'package:node_diary/core/services/mind_map_io/mind_map_markdown_io.dart';
import 'package:node_diary/core/services/mind_map_io/mind_map_xml_formats.dart';
import 'package:node_diary/core/services/mind_map_io/mind_map_xmind_io.dart';

/// 导图的文件格式：Markdown / OPML / FreeMind / XMind 的往返与容错，以及按
/// 扩展名分派的导入入口。
void main() {
  // 一张覆盖各种节点内容的导图：待办、网址、日记链接、备注、图标、标签、
  // 收起与左右分侧。
  final sample = MindMapDocument.blank(text: 'Trip').copyWith(
    structure: 'logic_right',
    root: const MindMapNode(
      id: 'root',
      text: 'Trip',
      children: <MindMapNode>[
        MindMapNode(
          id: 'a',
          text: 'Packing',
          side: 'l',
          icons: <String>['priority:1', 'flag:green'],
          labels: <String>['todo'],
          note: 'Check the weather\nfirst',
          children: <MindMapNode>[
            MindMapNode(
              id: 'a1',
              text: 'Passport',
              task: <String, Object?>{'done': true},
            ),
            MindMapNode(
              id: 'a2',
              text: 'Charger',
              task: <String, Object?>{'done': false},
            ),
          ],
        ),
        MindMapNode(
          id: 'b',
          text: 'Hotel',
          href: 'https://example.com/hotel',
          collapsed: true,
          children: <MindMapNode>[MindMapNode(id: 'b1', text: 'Check-in 3pm')],
        ),
        MindMapNode(id: 'c', text: 'Day 1', href: 'jotsy://diary/42'),
      ],
    ),
  );

  List<String> texts(MindMapNode node) => <String>[
    node.text,
    for (final child in node.children) ...texts(child),
  ];

  MindMapNode child(MindMapNode node, String text) =>
      node.children.firstWhere((candidate) => candidate.text == text);

  group('Markdown', () {
    test('round-trips topics, tasks, web links and notes', () {
      final markdown = mindMapToMarkdown(sample);
      expect(markdown, startsWith('# Trip\n'));
      expect(markdown, contains('- [x] Passport'));
      expect(markdown, contains('[Hotel](https://example.com/hotel)'));
      // 日记链接在应用外打不开：只留文字。
      expect(markdown, isNot(contains('jotsy://')));

      final back = mindMapFromMarkdown(markdown)!;
      expect(texts(back), texts(sample.root));
      final packing = child(back, 'Packing');
      expect(packing.note, 'Check the weather\nfirst');
      expect(child(packing, 'Passport').taskDone, isTrue);
      expect(child(packing, 'Charger').isTask, isTrue);
      expect(child(packing, 'Charger').taskDone, isFalse);
      expect(child(back, 'Hotel').href, 'https://example.com/hotel');
    });

    test('several top-level headings hang under the fallback title; code '
        'fences and blank lines are skipped', () {
      final root = mindMapFromMarkdown(
        '# One\n\nIntro line\n\n```\n# not a heading\n```\n'
        '## Sub\n1. first\n   2) nested\n# Two\n* item',
        fallbackTitle: 'notes',
      )!;
      expect(root.text, 'notes');
      expect(root.children.map((node) => node.text), <String>['One', 'Two']);
      final one = root.children.first;
      expect(one.children.map((node) => node.text), <String>[
        'Intro line',
        'Sub',
      ]);
      final sub = child(one, 'Sub');
      expect(sub.children.single.text, 'first');
      expect(sub.children.single.children.single.text, 'nested');
      expect(root.children.last.children.single.text, 'item');
    });

    test('text without any content reads as nothing', () {
      expect(mindMapFromMarkdown('\n\n  \n'), isNull);
      expect(mindMapFromMarkdown('```\ncode\n```'), isNull);
    });
  });

  group('OPML', () {
    test('round-trips topics, notes and web links', () {
      final opml = mindMapToOpml(sample);
      expect(opml, contains('<opml version="2.0">'));
      expect(opml, isNot(contains('jotsy://')));
      final back = mindMapFromOpml(opml)!;
      expect(texts(back), texts(sample.root));
      expect(child(back, 'Packing').note, 'Check the weather\nfirst');
      expect(child(back, 'Hotel').href, 'https://example.com/hotel');
    });

    test('several top outlines hang under the head title; broken files are '
        'null', () {
      final root = mindMapFromOpml(
        '<opml version="2.0"><head><title>Ideas</title></head><body>'
        '<outline text="A"/><outline title="B"><outline text="B1"/></outline>'
        '</body></opml>',
      )!;
      expect(root.text, 'Ideas');
      expect(texts(root), <String>['Ideas', 'A', 'B', 'B1']);
      expect(mindMapFromOpml('<opml><body>'), isNull);
      expect(mindMapFromOpml('<opml><body></body></opml>'), isNull);
    });
  });

  group('FreeMind', () {
    test('round-trips icons, sides, folding, notes and links', () {
      final mm = mindMapToFreeMind(sample);
      expect(mm, contains('POSITION="left"'));
      expect(mm, contains('BUILTIN="full-1"'));
      expect(mm, isNot(contains('jotsy://')));
      final back = mindMapFromFreeMind(mm)!;
      expect(texts(back), texts(sample.root));
      final packing = child(back, 'Packing');
      expect(packing.side, 'l');
      expect(packing.icons, <String>['priority:1', 'flag:green']);
      expect(packing.note, 'Check the weather\nfirst');
      final hotel = child(back, 'Hotel');
      expect(hotel.side, 'r');
      expect(hotel.collapsed, isTrue);
      expect(hotel.href, 'https://example.com/hotel');
      expect(back.side, isNull);
    });

    test('reads rich-text topics and skips internal links; broken files '
        'are null', () {
      final root = mindMapFromFreeMind(
        '<map version="1.0.1"><node TEXT="Root">'
        '<node LINK="#ID_1"><richcontent TYPE="NODE"><html><body>'
        '<p>Rich</p><p>topic</p></body></html></richcontent></node>'
        '</node></map>',
      )!;
      expect(root.children.single.text, 'Rich\ntopic');
      expect(root.children.single.href, isNull);
      expect(mindMapFromFreeMind('<map>'), isNull);
      expect(mindMapFromFreeMind('<map></map>'), isNull);
    });
  });

  group('XMind', () {
    test('round-trips topics, markers, labels, notes, folding and the '
        'structure', () {
      final bytes = mindMapToXmind(sample, sheetTitle: 'Sheet');
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        archive.files.map((file) => file.name),
        containsAll(<String>['content.json', 'metadata.json', 'manifest.json']),
      );
      final back = mindMapFromXmind(bytes)!;
      expect(back.structure, 'logic_right');
      expect(texts(back.root), texts(sample.root));
      final packing = child(back.root, 'Packing');
      expect(packing.icons, <String>['priority:1', 'flag:green']);
      expect(packing.labels, <String>['todo']);
      expect(packing.note, 'Check the weather\nfirst');
      final hotel = child(back.root, 'Hotel');
      expect(hotel.collapsed, isTrue);
      expect(hotel.href, 'https://example.com/hotel');
      expect(child(back.root, 'Day 1').href, isNull);
    });

    test('an unknown structure is left out of the file', () {
      final bytes = mindMapToXmind(sample.copyWith(structure: 'spiral'));
      final content = ZipDecoder()
          .decodeBytes(bytes)
          .files
          .firstWhere((file) => file.name == 'content.json');
      final json = jsonDecode(utf8.decode(content.content)) as List<Object?>;
      final root = (json.single! as Map<String, Object?>)['rootTopic']!;
      expect(
        (root as Map<String, Object?>).containsKey('structureClass'),
        isFalse,
      );
    });

    test('reads XMind 8 content.xml', () {
      const xml =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<xmap-content xmlns="urn:xmind:xmap:xmlns:content:2.0" '
          'xmlns:xlink="http://www.w3.org/1999/xlink">'
          '<sheet id="s"><topic id="r" structure-class="org.xmind.ui.org-chart.down">'
          '<title>Plan</title><children><topics type="attached">'
          '<topic id="t1" xlink:href="https://example.com"><title>Site</title>'
          '<marker-refs><marker-ref marker-id="star-red"/></marker-refs>'
          '<labels><label>web</label></labels>'
          '<notes><plain>Remember</plain></notes></topic>'
          '<topic id="t2" branch="folded"><title>Budget</title>'
          '<children><topics type="attached"><topic id="t3"><title>Food</title>'
          '</topic></topics></children></topic>'
          '</topics><topics type="detached"><topic id="d"><title>Floating</title>'
          '</topic></topics></children></topic></sheet></xmap-content>';
      final archive = Archive()
        ..addFile(ArchiveFile('content.xml', xml.length, utf8.encode(xml)));
      final back = mindMapFromXmind(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      )!;
      expect(back.structure, 'org_down');
      expect(texts(back.root), <String>['Plan', 'Site', 'Budget', 'Food']);
      final site = back.root.children.first;
      expect(site.href, 'https://example.com');
      expect(site.icons, <String>['star:red']);
      expect(site.labels, <String>['web']);
      expect(site.note, 'Remember');
      expect(back.root.children.last.collapsed, isTrue);
    });

    test('broken files are null instead of throwing', () {
      expect(mindMapFromXmind(Uint8List.fromList(<int>[1, 2, 3])), isNull);
      final empty = Archive()
        ..addFile(ArchiveFile('content.json', 2, utf8.encode('[]')));
      expect(
        mindMapFromXmind(Uint8List.fromList(ZipEncoder().encode(empty))),
        isNull,
      );
    });
  });

  group('importMindMapFile', () {
    Uint8List text(String value) => Uint8List.fromList(utf8.encode(value));

    test('dispatches by extension and strips a byte order mark', () {
      expect(
        importMindMapFile('a.OPML', text(mindMapToOpml(sample)))?.root.text,
        'Trip',
      );
      expect(
        importMindMapFile('a.mm', text(mindMapToFreeMind(sample)))?.root.text,
        'Trip',
      );
      final xmind = importMindMapFile('a.xmind', mindMapToXmind(sample));
      expect(xmind?.structure, 'logic_right');
      final markdown = importMindMapFile(
        'Weekend plan.txt',
        text('﻿- Hike\n  - Snacks\n- Movie'),
      )!;
      expect(markdown.root.text, 'Weekend plan');
      expect(texts(markdown.root), <String>[
        'Weekend plan',
        'Hike',
        'Snacks',
        'Movie',
      ]);
      expect(markdown.structure, isNull);
    });

    test('files without a map read as nothing', () {
      expect(importMindMapFile('a.xmind', text('not a zip')), isNull);
      expect(importMindMapFile('a.opml', text('<opml>')), isNull);
    });
  });

  test('replacing the root with an imported tree assigns fresh unique ids '
      'and caps topic text', () {
    final imported = MindMapNode(
      id: 'x0',
      text: 'r' * (kMindMapMaxTextLength + 50),
      children: const <MindMapNode>[
        MindMapNode(id: 'x1', text: 'a'),
        MindMapNode(id: 'x1', text: 'b'),
      ],
    );
    final next = MindMapOps.replaceRoot(MindMapDocument.blank(), imported);
    expect(next.root.id, 'root');
    expect(next.root.text.length, kMindMapMaxTextLength);
    final ids = next.root.children.map((node) => node.id).toSet();
    expect(ids, hasLength(2));
    expect(ids, isNot(contains('x1')));
  });
}
