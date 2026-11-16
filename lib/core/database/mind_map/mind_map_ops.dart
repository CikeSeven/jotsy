import 'dart:math' as math;

import 'mind_map_document.dart';
import 'mind_map_rich_text.dart';
import 'mind_map_schema.dart';

/// 导图的编辑操作（纯函数）：输入文档，返回新文档，不改动输入。
///
/// 只沿被改节点到根的那条路径复制，其余子树原样共享；做不到的操作（节点
/// 不存在、要把节点挪进自己的子树、超出节点上限）原样返回输入文档，调用方
/// 以 `identical` 判断是否真的改了。画布、大纲、导入与 AI 都只经这里改文档。
abstract final class MindMapOps {
  /// 用 [update] 的结果替换 id 为 [id] 的节点。
  static MindMapDocument updateNode(
    MindMapDocument document,
    String id,
    MindMapNode Function(MindMapNode node) update,
  ) {
    final index = document.index;
    final target = index[id];
    if (target == null) return document;
    final replaced = update(target);
    if (identical(replaced, target)) return document;
    return document.copyWith(root: _replaceAlongPath(index, id, replaced));
  }

  /// 改节点文字（超长截断）。有局部样式时按改动把样式挪到新文字上
  /// （[remapRunsAfterEdit]），大纲、粘贴等任何改字路径都不错位。
  static MindMapDocument setText(
    MindMapDocument document,
    String id,
    String text,
  ) {
    final clipped = _clip(text);
    return updateNode(document, id, (node) {
      if (node.text == clipped) return node;
      if (!mindMapHasRichText(node)) {
        return node.copyWith(text: clipped, delta: null);
      }
      return node.copyWith(
        text: clipped,
        delta: encodeInlineDelta(
          remapRunsAfterEdit(mindMapRunsOf(node), clipped),
        ),
      );
    });
  }

  /// 同时改文字与局部样式（输入框里打字、设样式）。[runs] 拼起来必须是
  /// [text]，对不上时只改文字并按 [setText] 挪样式；超长时样式一并截断。
  static MindMapDocument setRichText(
    MindMapDocument document,
    String id,
    String text,
    List<InlineTextRun> runs,
  ) {
    if (inlineRunsText(runs) != text) return setText(document, id, text);
    final clipped = _clip(text);
    final delta = encodeInlineDelta(
      clipped.length == text.length
          ? runs
          : sliceInlineRuns(runs, 0, clipped.length),
    );
    return updateNode(document, id, (node) {
      if (node.text == clipped &&
          _sameDelta(mindMapHasRichText(node) ? node.delta : null, delta)) {
        return node;
      }
      return node.copyWith(text: clipped, delta: delta);
    });
  }

  /// 用 [update] 改节点文字 [start, end) 的局部样式。
  static MindMapDocument formatText(
    MindMapDocument document,
    String id,
    int start,
    int end,
    InlineTextMarks Function(InlineTextMarks marks) update,
  ) {
    final node = document.index[id];
    if (node == null) return document;
    return setRichText(
      document,
      id,
      node.text,
      formatRuns(mindMapRunsOf(node), start, end, update),
    );
  }

  /// 整条样式里与文字有关、局部样式里也有的几项（见 [setStyle]）。
  static const Set<String> textStyleKeys = <String>{
    kMindMapStyleBoldKey,
    kMindMapStyleItalicKey,
    kMindMapStyleUnderlineKey,
    kMindMapStyleStrikeKey,
    kMindMapStyleColorKey,
    kMindMapStyleHighlightKey,
  };

  /// 把节点整条样式里的 [key] 设为 [value]（null 为去掉）。[textStyleKeys]
  /// 里的项同时去掉同名的局部样式：整条设置就是整条生效，不留被局部盖住
  /// 的字。
  static MindMapDocument setStyle(
    MindMapDocument document,
    String id,
    String key,
    Object? value,
  ) => updateNode(document, id, (node) {
    if (node.style[key] == value && !mindMapHasRichText(node)) return node;
    final style = <String, Object?>{...node.style};
    if (value == null) {
      style.remove(key);
    } else {
      style[key] = value;
    }
    if (!textStyleKeys.contains(key) || !mindMapHasRichText(node)) {
      return node.copyWith(style: style);
    }
    return node.copyWith(
      style: style,
      delta: encodeInlineDelta(clearMindMapMark(mindMapRunsOf(node), key)),
    );
  });

  static String _clip(String text) => text.length > kMindMapMaxTextLength
      ? text.substring(0, kMindMapMaxTextLength)
      : text;

  static bool _sameDelta(
    List<Map<String, Object?>>? a,
    List<Map<String, Object?>>? b,
  ) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['insert'] != b[i]['insert'] ||
          InlineTextMarks.fromJson(a[i]['attributes']) !=
              InlineTextMarks.fromJson(b[i]['attributes'])) {
        return false;
      }
    }
    return true;
  }

  static MindMapDocument setCollapsed(
    MindMapDocument document,
    String id,
    bool collapsed,
  ) => updateNode(
    document,
    id,
    (node) => node.collapsed == collapsed || node.children.isEmpty
        ? node
        : node.copyWith(collapsed: collapsed),
  );

  /// 收起或展开整棵子树（含自己）里所有有子节点的节点。
  static MindMapDocument setSubtreeCollapsed(
    MindMapDocument document,
    String id,
    bool collapsed, {
    bool includeSelf = true,
  }) {
    MindMapNode visit(MindMapNode node, bool self) {
      final children = <MindMapNode>[
        for (final child in node.children) visit(child, false),
      ];
      final changedChildren = !_sameList(children, node.children);
      final wantCollapsed = (self && !includeSelf) || node.children.isEmpty
          ? node.collapsed
          : collapsed;
      if (!changedChildren && wantCollapsed == node.collapsed) return node;
      return node.copyWith(
        children: changedChildren ? children : null,
        collapsed: wantCollapsed,
      );
    }

    return updateNode(document, id, (node) => visit(node, true));
  }

  /// 在 [parentId] 下插入一个新节点（[index] 缺省为末尾），返回新文档与新
  /// 节点 id；做不到时 id 为 null。
  static (MindMapDocument, String?) addChild(
    MindMapDocument document,
    String parentId, {
    String text = '',
    int? index,
    math.Random? random,
  }) {
    final idx = document.index;
    final parent = idx[parentId];
    if (parent == null ||
        idx.length >= kMindMapMaxNodes ||
        idx.depthOf(parentId) + 1 > kMindMapMaxDepth) {
      return (document, null);
    }
    final id = newMindMapNodeId(idx.contains, random);
    final node = MindMapNode(id: id, text: text);
    final at = (index ?? parent.children.length).clamp(
      0,
      parent.children.length,
    );
    final updated = updateNode(
      document,
      parentId,
      (p) => p.copyWith(
        collapsed: false,
        children: <MindMapNode>[
          ...p.children.sublist(0, at),
          node,
          ...p.children.sublist(at),
        ],
      ),
    );
    return (updated, id);
  }

  /// 在 [id] 的后面（[before] 为真时前面）插入同级节点；根没有同级，改为
  /// 加一个子节点。
  static (MindMapDocument, String?) addSibling(
    MindMapDocument document,
    String id, {
    bool before = false,
    String text = '',
    math.Random? random,
  }) {
    final idx = document.index;
    final parent = idx.parentOf(id);
    if (parent == null) {
      return addChild(document, id, text: text, random: random);
    }
    final position = idx.positionOf(id) + (before ? 0 : 1);
    final (updated, newId) = addChild(
      document,
      parent,
      text: text,
      index: position,
      random: random,
    );
    if (newId == null) return (updated, null);
    // 平衡结构里新的同级节点跟着当前节点所在的一侧。
    final side = idx[id]?.side;
    if (side == null) return (updated, newId);
    return (
      updateNode(updated, newId, (node) => node.copyWith(side: side)),
      newId,
    );
  }

  /// 删除节点（连同子树）；根不会被删除。
  static MindMapDocument removeNodes(
    MindMapDocument document,
    Iterable<String> ids,
  ) {
    final idx = document.index;
    final doomed = <String>{
      for (final id in ids)
        if (id != idx.root.id && idx.contains(id)) id,
    };
    if (doomed.isEmpty) return document;
    MindMapNode visit(MindMapNode node) {
      var changed = false;
      final children = <MindMapNode>[];
      for (final child in node.children) {
        if (doomed.contains(child.id)) {
          changed = true;
          continue;
        }
        final next = visit(child);
        if (!identical(next, child)) changed = true;
        children.add(next);
      }
      return changed ? node.copyWith(children: children) : node;
    }

    return document.copyWith(root: visit(document.root));
  }

  /// 把 [id] 挪到 [parentId] 的第 [index] 个位置（按挪走之后的下标）。不能
  /// 挪根、不能挪进自己的子树；位置没变时原样返回。
  static MindMapDocument moveNode(
    MindMapDocument document,
    String id,
    String parentId,
    int index, {
    Object? side = _keepSide,
  }) {
    final idx = document.index;
    final node = idx[id];
    final oldParent = idx.parentOf(id);
    if (node == null ||
        oldParent == null ||
        !idx.contains(parentId) ||
        idx.isSelfOrAncestor(id, parentId)) {
      return document;
    }
    final targetSide = identical(side, _keepSide)
        ? (parentId == idx.root.id ? node.side : null)
        : side as String?;
    final oldPosition = idx.positionOf(id);
    if (oldParent == parentId && oldPosition == index) {
      return targetSide == node.side
          ? document
          : updateNode(document, id, (n) => n.copyWith(side: targetSide));
    }
    final removed = removeNodes(document, <String>[id]);
    final moved = targetSide == node.side
        ? node
        : node.copyWith(side: targetSide);
    return updateNode(removed, parentId, (parent) {
      final at = index.clamp(0, parent.children.length);
      return parent.copyWith(
        collapsed: false,
        children: <MindMapNode>[
          ...parent.children.sublist(0, at),
          moved,
          ...parent.children.sublist(at),
        ],
      );
    });
  }

  /// 在 [parentId] 下插入一棵外来的子树（粘贴、模板、导入、AI）：全部节点
  /// 换成新 id，超出节点上限的部分不插入。返回新文档与子树根的新 id。
  static (MindMapDocument, String?) insertSubtree(
    MindMapDocument document,
    String parentId,
    MindMapNode subtree, {
    int? index,
    math.Random? random,
  }) {
    final idx = document.index;
    final parent = idx[parentId];
    if (parent == null) return (document, null);
    var budget = kMindMapMaxNodes - idx.length;
    if (budget <= 0) return (document, null);
    final taken = <String>{};
    bool isTaken(String id) => idx.contains(id) || taken.contains(id);
    final baseDepth = idx.depthOf(parentId) + 1;
    MindMapNode? clone(MindMapNode node, int depth) {
      if (budget <= 0 || depth > kMindMapMaxDepth) return null;
      budget--;
      final id = newMindMapNodeId(isTaken, random);
      taken.add(id);
      final children = <MindMapNode>[];
      for (final child in node.children) {
        final copied = clone(child, depth + 1);
        if (copied != null) children.add(copied);
      }
      return node.copyWith(id: id, children: children);
    }

    final copied = clone(subtree, baseDepth);
    if (copied == null) return (document, null);
    final at = (index ?? parent.children.length).clamp(
      0,
      parent.children.length,
    );
    final updated = updateNode(
      document,
      parentId,
      (p) => p.copyWith(
        collapsed: false,
        children: <MindMapNode>[
          ...p.children.sublist(0, at),
          copied,
          ...p.children.sublist(at),
        ],
      ),
    );
    return (updated, copied.id);
  }

  /// 换掉整个根（模板、导入、AI 生成）：保留文档的结构与主题设置，节点全部
  /// 换新 id，超出上限的部分丢弃。
  static MindMapDocument replaceRoot(
    MindMapDocument document,
    MindMapNode root, {
    math.Random? random,
  }) {
    var budget = kMindMapMaxNodes;
    final taken = <String>{};
    MindMapNode? clone(MindMapNode node, int depth, {bool isRoot = false}) {
      if (budget <= 0 || depth > kMindMapMaxDepth) return null;
      budget--;
      final id = isRoot ? 'root' : newMindMapNodeId(taken.contains, random);
      taken.add(id);
      final children = <MindMapNode>[];
      for (final child in node.children) {
        final copied = clone(child, depth + 1);
        if (copied != null) children.add(copied);
      }
      // 外来的树（导入、粘贴、转换）可能超长：与解码同一口径截断。
      final text = node.text.length > kMindMapMaxTextLength
          ? node.text.substring(0, kMindMapMaxTextLength)
          : node.text;
      return node.copyWith(id: id, text: text, children: children);
    }

    return document.copyWith(root: clone(root, 0, isRoot: true));
  }

  /// 缩进：成为前一个同级节点的最后一个子节点（没有前一个同级时不动）。
  static MindMapDocument indent(MindMapDocument document, String id) {
    final index = document.index;
    final parent = index.parentOf(id);
    final position = index.positionOf(id);
    if (parent == null || position == 0) return document;
    final previous = index[parent]!.children[position - 1];
    if (index.depthOf(id) + 1 > kMindMapMaxDepth) return document;
    return moveNode(document, id, previous.id, previous.children.length);
  }

  /// 取消缩进：提到父节点之后，成为父节点的同级（父节点是根时不动）。
  static MindMapDocument outdent(MindMapDocument document, String id) {
    final index = document.index;
    final parent = index.parentOf(id);
    if (parent == null) return document;
    final grand = index.parentOf(parent);
    if (grand == null) return document;
    return moveNode(document, id, grand, index.positionOf(parent) + 1);
  }

  /// 在同级之间上移 / 下移一位；到头时不动。
  static MindMapDocument shift(
    MindMapDocument document,
    String id, {
    required bool up,
  }) {
    final index = document.index;
    final parent = index.parentOf(id);
    if (parent == null) return document;
    final position = index.positionOf(id);
    final count = index[parent]!.children.length;
    final target = up ? position - 1 : position + 1;
    if (target < 0 || target >= count) return document;
    return moveNode(document, id, parent, target);
  }

  /// 节点 [id] 在先序里的上一个 / 下一个可见节点（跳过收起的子树）。
  static String? visibleNeighbour(
    MindMapDocument document,
    String id, {
    required bool forward,
  }) {
    final visible = visibleOrder(document);
    final at = visible.indexOf(id);
    if (at < 0) return null;
    final next = at + (forward ? 1 : -1);
    if (next < 0 || next >= visible.length) return null;
    return visible[next];
  }

  /// 可见节点的先序（收起节点的子孙不在里面）。
  static List<String> visibleOrder(MindMapDocument document) {
    final out = <String>[];
    void visit(MindMapNode node) {
      out.add(node.id);
      if (node.collapsed) return;
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(document.root);
    return out;
  }

  static MindMapNode _replaceAlongPath(
    MindMapIndex index,
    String id,
    MindMapNode replacement,
  ) {
    var current = replacement;
    var currentId = id;
    var parentId = index.parentOf(currentId);
    while (parentId != null) {
      final parent = index[parentId]!;
      final position = index.positionOf(currentId);
      final children = List<MindMapNode>.of(parent.children);
      children[position] = current;
      current = parent.copyWith(children: children);
      currentId = parentId;
      parentId = index.parentOf(currentId);
    }
    return current;
  }

  static bool _sameList(List<MindMapNode> a, List<MindMapNode> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}

/// [MindMapOps.moveNode] 的 `side` 缺省值：挪到根下时保留原来的一侧，挪到
/// 别处时清掉。
const Object _keepSide = Object();
