import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_schema.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';

/// 导图文档的编解码与编辑操作：坏数据容错、认不出的键原样写回、id 确定，
/// 编辑只沿路径复制、做不到的操作原样返回。
void main() {
  MindMapDocument sample() => MindMapDocument.decode(<String, Object?>{
    'v': 1,
    'root': <String, Object?>{
      'id': 'root',
      'text': 'Trip',
      'children': <Object?>[
        <String, Object?>{
          'id': 'a',
          'text': 'Plan',
          'children': <Object?>[
            <String, Object?>{'id': 'a1', 'text': 'Tickets'},
            <String, Object?>{'id': 'a2', 'text': 'Hotel'},
          ],
        },
        <String, Object?>{'id': 'b', 'text': 'Pack'},
      ],
    },
  });

  group('MindMapDocument.decode', () {
    test('keeps unknown keys and enum ids when writing back', () {
      final raw = <String, Object?>{
        'v': 1,
        'future': <String, Object?>{'x': 1},
        'structure': 'spiral',
        'root': <String, Object?>{
          'id': 'root',
          'text': 'R',
          'glow': true,
          'children': <Object?>[
            <String, Object?>{
              'id': 'c',
              'text': 'C',
              'icons': <Object?>['p1'],
            },
          ],
        },
      };
      final document = MindMapDocument.decode(raw);
      expect(document.structure, 'spiral');
      final json = document.toJson();
      expect(json['future'], <String, Object?>{'x': 1});
      expect(json['structure'], 'spiral');
      final root = json['root']! as Map<String, Object?>;
      expect(root['glow'], isTrue);
      expect((root['children']! as List).single, <String, Object?>{
        'id': 'c',
        'text': 'C',
        'icons': <String>['p1'],
      });
    });

    test('tolerates wrong types and gives missing or duplicate ids a '
        'position-based id that is the same on every read', () {
      final raw = jsonDecode(
        '{"root":{"text":7,"children":[{"text":"x"},{"id":"d","text":"y"},'
        '{"id":"d","text":"z"},"bad",{"collapsed":"yes","children":{}}]}}',
      );
      final first = MindMapDocument.decode(raw);
      final second = MindMapDocument.decode(raw);
      expect(first.root.text, '');
      final ids = first.index.preorder;
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, second.index.preorder);
      expect(first.root.children, hasLength(4));
      expect(first.root.children[3].collapsed, isFalse);
    });

    test('does not recurse past the depth limit but keeps the rest', () {
      Map<String, Object?> chain(int depth) => depth == 0
          ? <String, Object?>{'id': 'leaf', 'text': 'leaf'}
          : <String, Object?>{
              'id': 'n$depth',
              'text': '$depth',
              'children': <Object?>[chain(depth - 1)],
            };
      final raw = <String, Object?>{'root': chain(kMindMapParseDepthLimit + 5)};
      final document = MindMapDocument.decode(raw);
      expect(document.index.length, kMindMapParseDepthLimit + 1);
      // 过深的部分原样写回。
      expect(jsonEncode(document.toJson()['root']), contains('"leaf"'));
    });

    test('a non-object decodes to a blank map', () {
      final document = MindMapDocument.decode('nope');
      expect(mindMapIsBlank(document), isTrue);
    });
  });

  group('MindMapOps', () {
    test(
      'addChild and addSibling insert at the right place with fresh ids',
      () {
        final random = math.Random(1);
        var document = sample();
        final (afterChild, childId) = MindMapOps.addChild(
          document,
          'a',
          text: 'Visa',
          random: random,
        );
        expect(childId, isNotNull);
        expect(afterChild.index['a']!.children.last.text, 'Visa');
        final (afterSibling, siblingId) = MindMapOps.addSibling(
          afterChild,
          'a1',
          random: random,
        );
        expect(afterSibling.index.positionOf(siblingId!), 1);
        // 未改动的子树原样共享。
        expect(identical(afterSibling.index['b'], document.index['b']), isTrue);
        // 根没有同级：加成子节点。
        final (rootSibling, id) = MindMapOps.addSibling(document, 'root');
        expect(rootSibling.index.parentOf(id!), 'root');
        document = afterSibling;
        expect(document.index.length, 7);
      },
    );

    test('addChild fixes the side only for branches of the root', () {
      final document = sample();
      final (onRoot, branch) = MindMapOps.addChild(
        document,
        'root',
        side: kMindMapSideLeft,
      );
      expect(onRoot.index[branch!]!.side, kMindMapSideLeft);
      // 更深的层级没有一侧之分，传了也不写。
      final (deeper, child) = MindMapOps.addChild(
        document,
        'a',
        side: kMindMapSideLeft,
      );
      expect(deeper.index[child!]!.side, isNull);
      // 认不出的一侧按没指定处理。
      final (odd, oddId) = MindMapOps.addChild(document, 'root', side: 'x');
      expect(odd.index[oddId!]!.side, isNull);
    });

    test('pinRootSides fixes only unpinned root branches it knows about', () {
      final document = MindMapOps.updateNode(
        sample(),
        'b',
        (node) => node.copyWith(side: kMindMapSideLeft),
      );
      final pinned = MindMapOps.pinRootSides(document, <String, String>{
        'a': kMindMapSideRight,
        // 已经固定的不改、不是根的分支不管、认不出的一侧忽略。
        'b': kMindMapSideRight,
        'a1': kMindMapSideLeft,
      });
      expect(pinned.index['a']!.side, kMindMapSideRight);
      expect(pinned.index['b']!.side, kMindMapSideLeft);
      expect(pinned.index['a1']!.side, isNull);
      // 无事可做时原样返回。
      expect(
        identical(MindMapOps.pinRootSides(pinned, const {}), pinned),
        isTrue,
      );
      expect(
        identical(
          MindMapOps.pinRootSides(document, <String, String>{'a': 'x'}),
          document,
        ),
        isTrue,
      );
    });

    test('moveNode refuses moving into its own subtree and keeps order', () {
      final document = sample();
      expect(
        identical(MindMapOps.moveNode(document, 'a', 'a1', 0), document),
        isTrue,
      );
      final moved = MindMapOps.moveNode(document, 'b', 'a', 1);
      expect(moved.index['a']!.children.map((n) => n.id), <String>[
        'a1',
        'b',
        'a2',
      ]);
      // 同一父节点里往后挪：下标按挪走之后计。
      final within = MindMapOps.moveNode(document, 'a1', 'a', 1);
      expect(within.index['a']!.children.map((n) => n.id), <String>[
        'a2',
        'a1',
      ]);
    });

    test('removeNodes never removes the root', () {
      final document = sample();
      final removed = MindMapOps.removeNodes(document, <String>['root', 'a']);
      expect(removed.root.id, 'root');
      expect(removed.index.preorder, <String>['root', 'b']);
    });

    test('insertSubtree and replaceRoot re-id every node', () {
      final document = sample();
      final subtree = mindMapNodeFromOutline('X\n  Y\n  Z')!;
      final (inserted, id) = MindMapOps.insertSubtree(document, 'b', subtree);
      expect(inserted.index[id!]!.children.map((n) => n.text), ['Y', 'Z']);
      expect(inserted.index.contains('o0'), isFalse);
      final replaced = MindMapOps.replaceRoot(document, subtree);
      expect(replaced.root.id, 'root');
      expect(replaced.root.text, 'X');
    });

    test('collapsing hides descendants from the visible order', () {
      final collapsed = MindMapOps.setCollapsed(sample(), 'a', true);
      expect(MindMapOps.visibleOrder(collapsed), <String>['root', 'a', 'b']);
      expect(collapsed.index.descendantCountOf('a'), 2);
      // 没有子节点的节点不能收起。
      expect(
        identical(MindMapOps.setCollapsed(collapsed, 'b', true), collapsed),
        isTrue,
      );
    });
  });

  group('text', () {
    test('plain text mirror lists every topic, notes and labels included', () {
      final document = MindMapOps.updateNode(
        MindMapOps.setCollapsed(sample(), 'a', true),
        'b',
        (node) => node.copyWith(note: 'Socks', labels: <String>['todo']),
      );
      expect(
        mindMapPlainText(document),
        'Trip\nPlan\nTickets\nHotel\nPack\ntodo\nSocks',
      );
    });

    test('outline text indents by level and parses back', () {
      final outline = mindMapOutlineText(sample());
      expect(outline, 'Trip\n- Plan\n  - Tickets\n  - Hotel\n- Pack');
      final parsed = mindMapNodeFromOutline(outline)!;
      expect(parsed.text, 'Trip');
      expect(parsed.children.map((n) => n.text), ['Plan', 'Pack']);
      expect(parsed.children.first.children, hasLength(2));
    });

    test('outline parsing accepts tabs, numbers and blank lines', () {
      final parsed = mindMapNodeFromOutline('Goals\n\n\t1. Health\n\t\t* Run')!;
      expect(parsed.children.single.text, 'Health');
      expect(parsed.children.single.children.single.text, 'Run');
      expect(mindMapNodeFromOutline('   \n  '), isNull);
    });

    test('only an untouched root counts as blank', () {
      expect(mindMapIsBlank(MindMapDocument.blank()), isTrue);
      expect(mindMapIsBlank(MindMapDocument.blank(text: 'T')), isFalse);
      expect(mindMapIsBlank(sample()), isFalse);
    });
  });
}
