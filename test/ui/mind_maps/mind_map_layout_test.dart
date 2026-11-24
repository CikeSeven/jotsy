import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_schema.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_layout.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_scene.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_text_cache.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_options.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_themes.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_drop_planner.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_frame.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_hit_test.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_palette.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_visuals.dart';

/// 布局引擎：七种结构在随机树上都不重叠、结果确定；横向结构里父节点对齐
/// 到子节点整体的中间；收起的子孙不布局。另测落点规划、命中测试、转场
/// 插值与编辑会话的撤销合并。
void main() {
  final texts = MindMapTextCache();
  tearDownAll(texts.dispose);

  MindMapLayoutConfig config(
    MindMapStructure structure, {
    MindMapThemeId theme = MindMapThemeId.rainbow,
  }) {
    final spec = MindMapThemeSpec.of(theme);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    return MindMapLayoutConfig(
      structure: structure,
      spacing: MindMapSpacing.standard,
      line: MindMapLineStyle.curve,
      styles: MindMapStyleResolver(
        spec: spec,
        palette: MindMapPalette.of(spec, scheme),
        rainbow: true,
        baseText: const TextStyle(fontSize: 14),
      ),
      texts: texts,
      rootPlaceholder: 'Central topic',
      nodePlaceholder: 'Topic',
    );
  }

  /// 随机树：节点数、层数与文字长度都随种子变化。
  MindMapDocument randomTree(int seed, {int nodes = 60}) {
    final random = math.Random(seed);
    var document = MindMapDocument.blank(text: 'Root $seed');
    for (var i = 0; i < nodes; i++) {
      final ids = document.index.preorder;
      final parent = ids[random.nextInt(ids.length)];
      if (document.index.depthOf(parent) >= 5) continue;
      final words = List<String>.generate(
        1 + random.nextInt(4),
        (_) => 'w${random.nextInt(999)}',
      ).join(' ');
      (document, _) = MindMapOps.addChild(
        document,
        parent,
        text: words,
        random: random,
      );
    }
    return document;
  }

  void expectNoOverlap(MindMapScene scene) {
    final nodes = scene.nodes;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final a = nodes[i].rect.deflate(0.5);
        final b = nodes[j].rect.deflate(0.5);
        expect(
          a.overlaps(b),
          isFalse,
          reason: '${nodes[i].node.text} overlaps ${nodes[j].node.text}',
        );
      }
    }
  }

  for (final structure in MindMapStructure.values) {
    test('${structure.id}: random trees never overlap and lay out the same '
        'way every time', () {
      for (var seed = 0; seed < 12; seed++) {
        final document = randomTree(seed);
        final first = layoutMindMap(document, config(structure));
        final second = layoutMindMap(document, config(structure));
        expect(first.nodes, hasLength(document.index.length));
        expectNoOverlap(first);
        expect(
          <Rect>[for (final n in second.nodes) n.rect],
          <Rect>[for (final n in first.nodes) n.rect],
        );
      }
    });
  }

  test('logic chart: each parent sits within the span of its children and '
      'they grow to its right', () {
    final document = randomTree(3, nodes: 40);
    final scene = layoutMindMap(
      document,
      config(MindMapStructure.logicRight, theme: MindMapThemeId.ocean),
    );
    for (final node in scene.nodes) {
      final children = document.index[node.id]!.children;
      if (children.isEmpty) continue;
      final rects = [for (final c in children) scene.byId[c.id]!.rect];
      final top = rects.map((r) => r.center.dy).reduce(math.min);
      final bottom = rects.map((r) => r.center.dy).reduce(math.max);
      final anchor = node.visual.underline
          ? node.rect.bottom
          : node.rect.center.dy;
      expect(anchor, inInclusiveRange(top - 1e-6, bottom + 1e-6));
      // 子节点都在父节点右边。
      for (final rect in rects) {
        expect(rect.left, greaterThan(node.rect.right));
      }
    }
  });

  test('mind map: branches fill the right side first and honour a fixed '
      'side', () {
    var document = randomTree(5, nodes: 30);
    final first = document.root.children.first.id;
    final last = document.root.children.last.id;
    var scene = layoutMindMap(document, config(MindMapStructure.mindMap));
    final root = scene.byId[document.root.id]!.rect;
    expect(scene.byId[first]!.rect.left, greaterThan(root.right));
    document = MindMapOps.updateNode(
      document,
      first,
      (node) => node.copyWith(side: kMindMapSideLeft),
    );
    scene = layoutMindMap(document, config(MindMapStructure.mindMap));
    expect(scene.byId[first]!.rect.right, lessThan(root.left));
    expect(scene.byId[last], isNotNull);
  });

  group('choosing a side in the balanced layout', () {
    /// 中心主题下四个一样高的分支：自动分配时 A、B 在右，C、D 在左。
    MindMapEditingController fourBranches() {
      var document = MindMapDocument.blank(text: 'Root');
      for (final text in <String>['A', 'B', 'C', 'D']) {
        (document, _) = MindMapOps.addChild(
          document,
          document.root.id,
          text: text,
          random: math.Random(text.codeUnitAt(0)),
        );
      }
      final controller = MindMapEditingController(document);
      controller.placedRootSides = () => layoutMindMap(
        controller.document,
        config(MindMapStructure.mindMap),
      ).rootSides;
      return controller;
    }

    String idOf(MindMapEditingController controller, String text) =>
        controller.document.root.children.firstWhere((n) => n.text == text).id;

    Map<String, String> sidesByText(MindMapEditingController controller) {
      final sides = layoutMindMap(
        controller.document,
        config(MindMapStructure.mindMap),
      ).rootSides;
      return <String, String>{
        for (final child in controller.document.root.children)
          child.text: sides[child.id]!,
      };
    }

    test('scene reports each branch side, only for the balanced layout', () {
      final controller = fourBranches();
      expect(sidesByText(controller), <String, String>{
        'A': kMindMapSideRight,
        'B': kMindMapSideRight,
        'C': kMindMapSideLeft,
        'D': kMindMapSideLeft,
      });
      final logic = layoutMindMap(
        controller.document,
        config(MindMapStructure.logicRight),
      );
      expect(logic.rootSides, isEmpty);
      controller.dispose();
    });

    test('add left puts the new branch on the left and no branch jumps', () {
      final controller = fourBranches();
      // 对照：只固定新分支、其余不固定时，C 会被重新平衡到右边。
      final (control, _) = MindMapOps.addChild(
        controller.document,
        controller.document.root.id,
        text: 'E',
        side: kMindMapSideLeft,
      );
      final controlScene = layoutMindMap(
        control,
        config(MindMapStructure.mindMap),
      );
      expect(controlScene.rootSides[idOf(controller, 'C')], kMindMapSideRight);

      final id = controller.addBranch(kMindMapSideLeft, edit: false)!;
      controller.setText(id, 'E');
      expect(sidesByText(controller), <String, String>{
        'A': kMindMapSideRight,
        'B': kMindMapSideRight,
        'C': kMindMapSideLeft,
        'D': kMindMapSideLeft,
        'E': kMindMapSideLeft,
      });
      expect(controller.selectedId, id);
      // 固定与加分支是一步撤销。
      controller.undo();
      controller.undo();
      expect(controller.document.root.children.length, 4);
      expect(
        controller.document.root.children.every((n) => n.side == null),
        isTrue,
      );
      controller.dispose();
    });

    test('a sibling of a left branch stays on the left', () {
      final controller = fourBranches();
      controller.select(idOf(controller, 'D'));
      final id = controller.addSibling(edit: false)!;
      controller.setText(id, 'E');
      expect(sidesByText(controller), <String, String>{
        'A': kMindMapSideRight,
        'B': kMindMapSideRight,
        'C': kMindMapSideLeft,
        'D': kMindMapSideLeft,
        'E': kMindMapSideLeft,
      });
      controller.dispose();
    });

    test('dragging a branch across moves only that branch', () {
      final controller = fourBranches();
      final a = idOf(controller, 'A');
      controller.move(
        a,
        MindMapDropTarget(
          parentId: controller.document.root.id,
          index: 3,
          side: kMindMapSideLeft,
        ),
      );
      expect(sidesByText(controller), <String, String>{
        'B': kMindMapSideRight,
        'C': kMindMapSideLeft,
        'D': kMindMapSideLeft,
        'A': kMindMapSideLeft,
      });
      controller.dispose();
    });

    test('without a canvas nothing is pinned', () {
      final controller = fourBranches()..placedRootSides = () => null;
      controller.select(idOf(controller, 'D'));
      controller.addSibling(edit: false);
      expect(
        controller.document.root.children.every((n) => n.side == null),
        isTrue,
      );
      controller.dispose();
    });
  });

  test('collapsed branches are not laid out and show a hidden count', () {
    final document = randomTree(7, nodes: 30);
    final branch = document.root.children.firstWhere(
      (child) => child.children.isNotEmpty,
    );
    final collapsed = MindMapOps.setCollapsed(document, branch.id, true);
    final scene = layoutMindMap(collapsed, config(MindMapStructure.mindMap));
    expect(scene.byId[branch.children.first.id], isNull);
    expect(
      scene.byId[branch.id]!.hiddenCount,
      document.index.descendantCountOf(branch.id),
    );
  });

  test('drop planner: onto a node appends, beside a node inserts, never '
      'into its own subtree', () {
    var document = MindMapDocument.blank(text: 'R');
    String add(String parent, String text) {
      final (next, id) = MindMapOps.addChild(document, parent, text: text);
      document = next;
      return id!;
    }

    final a = add(document.root.id, 'A');
    final a1 = add(a, 'A1');
    final b = add(document.root.id, 'B');
    final b1 = add(b, 'B1');
    add(b, 'B2');
    final scene = layoutMindMap(document, config(MindMapStructure.logicRight));
    // 拖 A1 落到 B 上：成为 B 的最后一个子节点。
    final onto = planMindMapDrop(
      scene: scene,
      document: document,
      dragId: a1,
      point: scene.byId[b]!.rect.center,
    );
    expect(onto?.parentId, b);
    expect(onto?.index, 2);
    expect(onto?.indicator, isNull);
    // 拖 A1 到 B1 正下方：插在 B1 后面。
    final beside = planMindMapDrop(
      scene: scene,
      document: document,
      dragId: a1,
      point: scene.byId[b1]!.rect.bottomCenter + const Offset(0, 3),
    );
    expect(beside?.parentId, b);
    expect(beside?.index, 1);
    expect(beside?.indicator, isNotNull);
    // A 不能落进自己的子树。
    final own = planMindMapDrop(
      scene: scene,
      document: document,
      dragId: a,
      point: scene.byId[a1]!.rect.center,
    );
    expect(own?.parentId, isNot(a1));
  });

  test('hit test finds nodes and collapse badges', () {
    final document = MindMapOps.setCollapsed(
      randomTree(11, nodes: 25),
      randomTree(11, nodes: 25).root.children.first.id,
      true,
    );
    final frame = MindMapFrame.still(
      layoutMindMap(document, config(MindMapStructure.mindMap)),
    );
    final first = frame.byId[document.root.children.first.id]!;
    expect(
      hitTestMindMap(frame, first.rect.center),
      isA<MindMapNodeHit>().having((hit) => hit.id, 'id', first.id),
    );
    if (first.scene.hiddenCount > 0) {
      expect(
        hitTestMindMap(frame, first.scene.toggleCenter),
        isA<MindMapToggleHit>(),
      );
    }
    expect(
      hitTestMindMap(frame, const Offset(-99999, -99999)),
      isA<MindMapEmptyHit>(),
    );
  });

  test('a transition grows new nodes out of their parent', () {
    final before = randomTree(13, nodes: 10);
    final (after, id) = MindMapOps.addChild(before, before.root.id);
    final from = layoutMindMap(before, config(MindMapStructure.mindMap));
    final to = layoutMindMap(after, config(MindMapStructure.mindMap));
    final start = MindMapFrame.lerp(from, to, 0);
    final end = MindMapFrame.lerp(from, to, 1);
    expect(start.byId[id]!.opacity, 0);
    expect(start.byId[id]!.rect.center, from.byId[before.root.id]!.rect.center);
    expect(end.byId[id]!.rect, to.byId[id]!.rect);
  });

  test('editing controller: undo, redo and coalesced typing', () {
    final controller = MindMapEditingController(MindMapDocument.blank());
    final changes = <MindMapDocument>[];
    controller.onChanged = changes.add;
    final id = controller.addChild(edit: false)!;
    controller.setText(id, 'H');
    controller.setText(id, 'Hi');
    expect(controller.document.index[id]!.text, 'Hi');
    controller.undo();
    // 连续输入合并成一步：撤销回到加节点之后、打字之前。
    expect(controller.document.index[id]!.text, '');
    controller.undo();
    expect(controller.document.index.contains(id), isFalse);
    controller.redo();
    controller.redo();
    expect(controller.document.index[id]!.text, 'Hi');
    expect(changes, isNotEmpty);
    controller.select(id);
    controller.deleteSelected();
    expect(controller.selectedId, controller.document.root.id);
    controller.dispose();
  });
}
