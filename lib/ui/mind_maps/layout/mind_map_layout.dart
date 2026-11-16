import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_visuals.dart';
import 'mind_map_node_content.dart';
import 'mind_map_scene.dart';
import 'mind_map_text_cache.dart';

/// 导图布局引擎：文档 + 外观 → [MindMapScene]（每个可见节点的矩形与连线）。
///
/// 流程：先按主题解析每个可见节点的外观并测量尺寸（[MindMapTextCache] 排版
/// 文字），再按结构摆放。收起节点的子孙不参与布局。各结构都是“块堆叠”：
/// 每棵子树占一条带（横向结构按高度、纵向结构按宽度），兄弟依次排开，父节点
/// 对齐到子节点整体的中间——结果确定、不重叠，节点改字只影响它所在的那几条
/// 带。纯计算，除文字排版外无副作用；同一输入总得到同一结果（测试兜底）。

/// 布局参数。
final class MindMapLayoutConfig {
  const MindMapLayoutConfig({
    required this.structure,
    required this.spacing,
    required this.line,
    required this.styles,
    required this.texts,
    required this.rootPlaceholder,
    required this.nodePlaceholder,
  });

  final MindMapStructure structure;
  final MindMapSpacing spacing;
  final MindMapLineStyle line;
  final MindMapStyleResolver styles;
  final MindMapTextCache texts;

  /// 根节点 / 其他节点没写字时显示的占位文字。
  final String rootPlaceholder;
  final String nodePlaceholder;
}

/// 按 [config] 布局 [document]。
MindMapScene layoutMindMap(
  MindMapDocument document,
  MindMapLayoutConfig config,
) {
  config.texts.beginGeneration();
  final engine = _Engine(document, config);
  return engine.run();
}

/// 结构缺省用的连线样式（文档与主题都没指定时）。
MindMapLineStyle defaultLineFor(
  MindMapStructure structure,
  MindMapLineStyle themeLine,
) => switch (structure) {
  MindMapStructure.orgDown ||
  MindMapStructure.treeRight ||
  MindMapStructure.timeline => MindMapLineStyle.rounded,
  _ => themeLine,
};

final class _Box {
  _Box({
    required this.node,
    required this.depth,
    required this.parent,
    required this.visual,
    required this.text,
    required this.placeholder,
    required this.size,
    required this.hidden,
    required this.content,
  });

  final MindMapNode node;
  final int depth;
  final _Box? parent;
  final MindMapNodeVisual visual;
  final TextPainter text;
  final bool placeholder;
  final Size size;
  final int hidden;
  final MindMapNodeContent content;
  final List<_Box> children = <_Box>[];
  Rect rect = Rect.zero;
  MindMapFlow flow = MindMapFlow.right;
  ({double above, double below})? _extent;
  double? _blockW;
}

final class _Engine {
  _Engine(this.document, this.config) : factor = config.spacing.factor;

  final MindMapDocument document;
  final MindMapLayoutConfig config;
  final double factor;
  final List<_Box> _order = <_Box>[];
  final List<MindMapSceneGuide> _guides = <MindMapSceneGuide>[];
  final Map<String, MindMapEdgeRoute> _routeOverrides =
      <String, MindMapEdgeRoute>{};
  final Set<String> _noEdge = <String>{};

  late final Map<String, ({int done, int total})> _progress =
      mindMapTaskProgress(document.root);

  MindMapScene run() {
    final index = document.index;
    final root = _measure(index, document.root, 0, null);
    switch (config.structure) {
      case MindMapStructure.mindMap:
        _placeBalanced(root);
      case MindMapStructure.logicRight:
        _placeHorizontal(root, 0, 0, 1);
      case MindMapStructure.logicLeft:
        _placeHorizontal(root, 0, 0, -1);
      case MindMapStructure.orgDown:
        _placeDown(root, 0, 0);
      case MindMapStructure.treeRight:
        _placeIndented(root, 0, 0);
      case MindMapStructure.timeline:
        _placeTimeline(root);
      case MindMapStructure.fishbone:
        _placeFishbone(root);
    }
    final nodes = <MindMapSceneNode>[
      for (final box in _order)
        MindMapSceneNode(
          node: box.node,
          parentId: box.parent?.node.id,
          depth: box.depth,
          rect: box.rect,
          visual: box.visual,
          text: box.text,
          placeholder: box.placeholder,
          flow: box.flow,
          hiddenCount: box.hidden,
          content: box.content,
        ),
    ];
    final edges = <MindMapSceneEdge>[
      for (final box in _order)
        if (box.parent case final parent?)
          if (!_noEdge.contains(box.node.id))
            MindMapSceneEdge(
              parentId: parent.node.id,
              childId: box.node.id,
              route: _routeOverrides[box.node.id] ?? _routeFor(parent),
              color: box.visual.branchColor,
              width: box.visual.lineWidth,
              taper: box.depth == 1,
            ),
    ];
    return MindMapScene(
      nodes: nodes,
      edges: edges,
      guides: _guides,
      structure: config.structure,
      line: config.line,
    );
  }

  MindMapEdgeRoute _routeFor(_Box parent) => switch (parent.flow) {
    MindMapFlow.right || MindMapFlow.left => MindMapEdgeRoute.horizontal,
    MindMapFlow.down || MindMapFlow.up => MindMapEdgeRoute.vertical,
    MindMapFlow.indentDown || MindMapFlow.indentUp => MindMapEdgeRoute.indent,
  };

  // ---------------- 测量 ----------------

  _Box _measure(MindMapIndex index, MindMapNode node, int depth, _Box? parent) {
    final visual = config.styles.visualOf(index, node);
    final empty = node.text.trim().isEmpty;
    final display = empty
        ? (depth == 0 ? config.rootPlaceholder : config.nodePlaceholder)
        : node.text;
    // 有字时按局部样式排（完成的待办整段变淡并划掉，见
    // MindMapStyleResolver.textSpanOf），占位文字是一段纯文字。
    final span = empty
        ? TextSpan(
            text: display,
            style: visual.textStyle.copyWith(
              color: config.styles.placeholderColor(visual),
            ),
          )
        : config.styles.textSpanOf(
            visual,
            mindMapRunsOf(node),
            taskDone: node.taskDone,
          );
    final text = config.texts.painterForSpan(
      span,
      maxWidth: visual.maxTextWidth,
      align: visual.textAlign,
    );
    final minText = switch (depth) {
      0 => 72.0,
      1 => 44.0,
      _ => 20.0,
    };
    final content = measureMindMapNodeContent(
      node: node,
      visual: visual,
      text: text,
      minTextWidth: minText,
      texts: config.texts,
      progress: _progress[node.id],
    );
    final hidden = node.collapsed && node.children.isNotEmpty
        ? index.descendantCountOf(node.id)
        : 0;
    final box = _Box(
      node: node,
      depth: depth,
      parent: parent,
      visual: visual,
      text: text,
      placeholder: empty,
      size: content.size,
      hidden: hidden,
      content: content,
    );
    _order.add(box);
    if (!node.collapsed) {
      for (final child in node.children) {
        box.children.add(_measure(index, child, depth + 1, box));
      }
    }
    return box;
  }

  // ---------------- 间距 ----------------

  /// 父子之间（沿展开方向）的距离。
  double _levelGap(int parentDepth) =>
      factor *
      switch (parentDepth) {
        0 => 68.0,
        1 => 46.0,
        _ => 32.0,
      };

  /// 兄弟之间（垂直于展开方向）的距离。
  double _siblingGap(int depth) =>
      factor *
      switch (depth) {
        1 => 22.0,
        2 => 12.0,
        _ => 8.0,
      };

  /// 纵向结构里父子之间的距离。
  double _verticalLevelGap(int parentDepth) =>
      factor * (parentDepth == 0 ? 56.0 : 40.0);

  /// 纵向结构里兄弟之间的距离。
  double _verticalSiblingGap(int depth) => factor * (depth <= 1 ? 22.0 : 14.0);

  double get _indent => 30 * factor.clamp(0.85, 1.2);

  double _treeGap(int depth) => factor * (depth <= 1 ? 14.0 : 9.0);

  // ---------------- 横向（逻辑图） ----------------

  /// 子树在“锚线”上下各占多高（横向结构）。锚线是连线接进这个节点的
  /// 高度：框形节点是中线，下划线节点是下划线；子节点整体以锚线为中线排开。
  /// 上下分开算，下划线节点（文字全在锚线之上）才不会和相邻的带重叠。
  ({double above, double below}) _extent(_Box box) {
    final cached = box._extent;
    if (cached != null) return cached;
    final height = box.size.height;
    var above = box.visual.underline ? height : height / 2;
    var below = box.visual.underline ? 0.0 : height / 2;
    if (box.children.isNotEmpty) {
      final half = _stackHeight(box.children, box.depth + 1) / 2;
      above = math.max(above, half);
      below = math.max(below, half);
    }
    return box._extent = (above: above, below: below);
  }

  /// 一列兄弟子树叠起来的总高（含间距）。
  double _stackHeight(List<_Box> children, int depth) {
    var total = _siblingGap(depth) * (children.length - 1);
    for (final child in children) {
      final extent = _extent(child);
      total += extent.above + extent.below;
    }
    return total;
  }

  /// 子树占的总高（横向结构的“带宽”）。
  double _blockHeight(_Box box) {
    final extent = _extent(box);
    return extent.above + extent.below;
  }

  /// 把 [box] 摆在 x = [x]（[dir] 为 1 时是左边、-1 时是右边），锚线在
  /// [anchorY]，子树依次排开。
  void _placeHorizontal(_Box box, double x, double anchorY, int dir) {
    final size = box.size;
    final top = box.visual.underline
        ? anchorY - size.height
        : anchorY - size.height / 2;
    box.rect = Rect.fromLTWH(
      dir > 0 ? x : x - size.width,
      top,
      size.width,
      size.height,
    );
    box.flow = dir > 0 ? MindMapFlow.right : MindMapFlow.left;
    _stackHorizontal(box, box.children, dir);
  }

  void _stackHorizontal(_Box parent, List<_Box> children, int dir) {
    if (children.isEmpty) return;
    final gap = _siblingGap(parent.depth + 1);
    final total = _stackHeight(children, parent.depth + 1);
    // 下划线父节点的连线从下划线出发：子节点整体对齐到下划线而不是中线。
    final anchorY = parent.visual.underline
        ? parent.rect.bottom
        : parent.rect.center.dy;
    var y = anchorY - total / 2;
    final childX = dir > 0
        ? parent.rect.right + _levelGap(parent.depth)
        : parent.rect.left - _levelGap(parent.depth);
    for (final child in children) {
      final extent = _extent(child);
      _placeHorizontal(child, childX, y + extent.above, dir);
      y += extent.above + extent.below + gap;
    }
  }

  // ---------------- 左右平衡（思维导图） ----------------

  void _placeBalanced(_Box root) {
    final size = root.size;
    root.rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    root.flow = MindMapFlow.right;
    final right = <_Box>[];
    final left = <_Box>[];
    final free = <_Box>[];
    for (final child in root.children) {
      switch (child.node.side) {
        case kMindMapSideLeft:
          left.add(child);
        case kMindMapSideRight:
          right.add(child);
        default:
          free.add(child);
      }
    }
    // 没固定一侧的分支按顺序先放右边，直到右边的高度达到总高的一半（至少
    // 一个），其余放左边：结果确定，大纲顺序与画布上的阅读顺序一致。
    var total = 0.0;
    for (final child in root.children) {
      total += _blockHeight(child);
    }
    var rightHeight = 0.0;
    for (final child in right) {
      rightHeight += _blockHeight(child);
    }
    for (final child in free) {
      if (rightHeight < total / 2 || right.isEmpty) {
        right.add(child);
        rightHeight += _blockHeight(child);
      } else {
        left.add(child);
      }
    }
    // 固定了一侧的与自动分配的按原顺序排。
    int order(_Box box) => root.children.indexOf(box);
    right.sort((a, b) => order(a).compareTo(order(b)));
    left.sort((a, b) => order(a).compareTo(order(b)));
    _stackHorizontal(root, right, 1);
    _stackHorizontal(root, left, -1);
  }

  // ---------------- 向下（组织结构图） ----------------

  double _blockWidth(_Box box) {
    final cached = box._blockW;
    if (cached != null) return cached;
    if (box.children.isEmpty) return box._blockW = box.size.width;
    var total = 0.0;
    for (final child in box.children) {
      total += _blockWidth(child);
    }
    total += _verticalSiblingGap(box.depth + 1) * (box.children.length - 1);
    return box._blockW = math.max(box.size.width, total);
  }

  void _placeDown(_Box box, double centerX, double top) {
    final size = box.size;
    box.rect = Rect.fromLTWH(
      centerX - size.width / 2,
      top,
      size.width,
      size.height,
    );
    box.flow = MindMapFlow.down;
    if (box.children.isEmpty) return;
    final gap = _verticalSiblingGap(box.depth + 1);
    var total = 0.0;
    for (final child in box.children) {
      total += _blockWidth(child);
    }
    total += gap * (box.children.length - 1);
    var x = centerX - total / 2;
    final childTop = box.rect.bottom + _verticalLevelGap(box.depth);
    for (final child in box.children) {
      final block = _blockWidth(child);
      _placeDown(child, x + block / 2, childTop);
      x += block + gap;
    }
  }

  // ---------------- 缩进（树形目录） ----------------

  /// 自 [top] 起往下排 [box] 及其子树，返回排完后的下一行纵坐标。
  double _placeIndented(_Box box, double left, double top) {
    final size = box.size;
    box.rect = Rect.fromLTWH(left, top, size.width, size.height);
    box.flow = MindMapFlow.indentDown;
    var y = box.rect.bottom + _treeGap(box.depth + 1);
    for (final child in box.children) {
      y = _placeIndented(child, left + _indent, y);
    }
    return box.children.isEmpty ? box.rect.bottom + _treeGap(box.depth) : y;
  }

  /// 缩进式子树的宽度（相对它自己的左边）。
  double _indentedWidth(_Box box) {
    var width = box.size.width;
    for (final child in box.children) {
      width = math.max(width, _indent + _indentedWidth(child));
    }
    return width;
  }

  // ---------------- 时间线 ----------------

  void _placeTimeline(_Box root) {
    final size = root.size;
    root.rect = Rect.fromLTWH(0, -size.height / 2, size.width, size.height);
    root.flow = MindMapFlow.right;
    var x = root.rect.right + _levelGap(0);
    final gap = factor * 36;
    for (var i = 0; i < root.children.length; i++) {
      final item = root.children[i];
      _noEdge.add(item.node.id);
      final above = i.isOdd;
      item.rect = Rect.fromLTWH(
        x,
        -item.size.height / 2,
        item.size.width,
        item.size.height,
      );
      item.flow = above ? MindMapFlow.indentUp : MindMapFlow.indentDown;
      var footprint = item.size.width;
      if (item.children.isNotEmpty) {
        for (final child in item.children) {
          footprint = math.max(footprint, _indent + _indentedWidth(child));
        }
        // 列表一律自上而下排（阅读顺序不变）；上方的列表排好后整体挪到
        // 节点上方，最后一行的底边贴着节点。
        var y = above ? 0.0 : item.rect.bottom + factor * 18;
        for (final child in item.children) {
          y = _placeIndented(child, x + _indent, y);
        }
        if (above) {
          var bottom = double.negativeInfinity;
          for (final child in item.children) {
            bottom = math.max(bottom, _subtreeBottom(child));
          }
          final dy = item.rect.top - factor * 18 - bottom;
          for (final child in item.children) {
            _shift(child, dy);
          }
        }
      }
      x += footprint + gap;
    }
    final end = math.max(x - gap + factor * 28, root.rect.right + 48);
    _guides.add(
      MindMapSceneGuide(
        from: Offset(root.rect.right, 0),
        to: Offset(end, 0),
        color: root.visual.branchColor,
        width: MindMapStyleResolver.rootLineWidth,
        arrow: true,
      ),
    );
  }

  // ---------------- 鱼骨图 ----------------

  void _placeFishbone(_Box root) {
    final size = root.size;
    root.rect = Rect.fromLTWH(
      -size.width,
      -size.height / 2,
      size.width,
      size.height,
    );
    root.flow = MindMapFlow.left;
    const slope = MindMapScene.boneSlope;
    final gap = factor * 14;
    // 上下两排各自往左推进；同一位置上下各一根大骨，成对排开。
    var topCursor = root.rect.left - factor * 36;
    var bottomCursor = topCursor;
    var leftmost = root.rect.left;
    for (var i = 0; i < root.children.length; i++) {
      final bone = root.children[i];
      final top = i.isEven;
      final cursor = top ? topCursor : bottomCursor;
      bone.flow = top ? MindMapFlow.down : MindMapFlow.up;
      _routeOverrides[bone.node.id] = MindMapEdgeRoute.boneMain;
      // 小骨（二级主题）沿大骨从主骨往外依次排开，各自的子树向左展开。
      // 每根小骨所在的高度是它子树的锚线：上方的大骨从主骨往上数，锚线
      // 之下的部分离主骨更近；下方的大骨反过来。
      var distance = gap + factor * 8;
      final distances = <double>[];
      for (final kid in bone.children) {
        final extent = _extent(kid);
        final near = top ? extent.below : extent.above;
        final far = top ? extent.above : extent.below;
        distances.add(distance + near);
        distance += near + far + gap;
      }
      final vertical = math.max(factor * 56, distance + gap);
      final boneSize = bone.size;
      // 这根大骨的所有内容都要在 cursor 左边：主骨上的起点，以及大骨末端
      // 居中放着的一级主题（它的右半边可能比起点更靠右）。
      final attachX =
          cursor - math.max(0.0, boneSize.width / 2 - vertical * slope);
      final endX = attachX - vertical * slope;
      bone.rect = top
          ? Rect.fromLTWH(
              endX - boneSize.width / 2,
              -vertical - boneSize.height,
              boneSize.width,
              boneSize.height,
            )
          : Rect.fromLTWH(
              endX - boneSize.width / 2,
              vertical,
              boneSize.width,
              boneSize.height,
            );
      var minLeft = bone.rect.left;
      for (var k = 0; k < bone.children.length; k++) {
        final kid = bone.children[k];
        final d = distances[k];
        final cy = top ? -d : d;
        final boneX = attachX - d * slope;
        _placeHorizontal(kid, boneX - factor * 12, cy, -1);
        _routeOverrides[kid.node.id] = MindMapEdgeRoute.boneBranch;
        minLeft = math.min(minLeft, _subtreeLeft(kid));
      }
      leftmost = math.min(leftmost, minLeft);
      final next = minLeft - factor * 28;
      if (top) {
        topCursor = next;
      } else {
        bottomCursor = next;
      }
      // 成对的上下大骨：下一对从两排里更靠左的位置开始，避免交错的大骨
      // 互相穿过对方的小骨。
      if (!top) {
        final cursor = math.min(topCursor, bottomCursor);
        topCursor = cursor;
        bottomCursor = cursor;
      }
    }
    _guides.add(
      MindMapSceneGuide(
        from: Offset(leftmost - factor * 24, 0),
        to: Offset(root.rect.left, 0),
        color: root.visual.branchColor,
        width: MindMapStyleResolver.rootLineWidth,
      ),
    );
  }

  double _subtreeBottom(_Box box) {
    var bottom = box.rect.bottom;
    for (final child in box.children) {
      bottom = math.max(bottom, _subtreeBottom(child));
    }
    return bottom;
  }

  void _shift(_Box box, double dy) {
    box.rect = box.rect.translate(0, dy);
    for (final child in box.children) {
      _shift(child, dy);
    }
  }

  double _subtreeLeft(_Box box) {
    var left = box.rect.left;
    for (final child in box.children) {
      left = math.min(left, _subtreeLeft(child));
    }
    return left;
  }
}
