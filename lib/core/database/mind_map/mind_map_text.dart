import 'mind_map_document.dart';
import 'mind_map_schema.dart';

/// 导图的文字形态（纯函数）：纯文本镜像与大纲文本。
///
/// 纯文本镜像进 `content_text`，搜索、字数、AI 读日记与列表摘要都用它，
/// 所以收起的分支、备注、标签同样写进去（搜得到）；大纲文本用于分享文字、
/// 复制与 Markdown 导出，按层级缩进。

/// 纯文本镜像：先序遍历，每个节点一行（节点里的换行原样保留），备注跟在
/// 节点后面另起一行；空节点不占行；概要与关系线的文字写在最后。
String mindMapPlainText(MindMapDocument document) {
  final lines = <String>[];
  void visit(MindMapNode node) {
    final text = node.text.trim();
    if (text.isNotEmpty) lines.add(text);
    if (node.labels.isNotEmpty) lines.add(node.labels.join(' '));
    final note = node.note?.trim();
    if (note != null && note.isNotEmpty) lines.add(note);
    final boundary = node.boundary?['text'];
    if (boundary is String && boundary.trim().isNotEmpty) {
      lines.add(boundary.trim());
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(document.root);
  for (final summary in document.summaries) {
    final topic = summary['topic'];
    if (topic is! Map) continue;
    if (topic[kMindMapNodeTextKey] case final String text
        when text.trim().isNotEmpty) {
      lines.add(text.trim());
    }
  }
  for (final relation in document.relations) {
    if (relation['label'] case final String label
        when label.trim().isNotEmpty) {
      lines.add(label.trim());
    }
  }
  return lines.join('\n');
}

/// 大纲里的一行：文字（节点内换行压成空格）与深度（根为 0）。
typedef MindMapOutlineLine = ({String text, int depth, MindMapNode node});

/// 按先序列出全部节点（含收起的），用于导出与分享。
List<MindMapOutlineLine> mindMapOutlineLines(MindMapDocument document) {
  final out = <MindMapOutlineLine>[];
  void visit(MindMapNode node, int depth) {
    out.add((
      text: node.text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim(),
      depth: depth,
      node: node,
    ));
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  visit(document.root, 0);
  return out;
}

/// 大纲文本：根为第一行，其余为按层级缩进的列表（`- `，每级两个空格）。
/// [untitled] 为根没有文字时的替代文字。
String mindMapOutlineText(MindMapDocument document, {String untitled = ''}) {
  final buffer = StringBuffer();
  for (final line in mindMapOutlineLines(document)) {
    if (line.depth == 0) {
      buffer.writeln(line.text.isEmpty ? untitled : line.text);
      continue;
    }
    buffer
      ..write('  ' * (line.depth - 1))
      ..write('- ')
      ..writeln(line.text);
  }
  return buffer.toString().trimRight();
}

/// 一棵子树的大纲文本（[node] 在第一行，子主题逐级缩进成 `- ` 列表）：
/// 复制主题时写进系统剪贴板，别的应用里也能贴成大纲。
String mindMapSubtreeOutline(MindMapNode node) {
  final buffer = StringBuffer();
  void visit(MindMapNode current, int depth) {
    final text = current.text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    if (depth == 0) {
      buffer.writeln(text);
    } else {
      buffer
        ..write('  ' * (depth - 1))
        ..write('- ')
        ..writeln(text);
    }
    for (final child in current.children) {
      visit(child, depth + 1);
    }
  }

  visit(node, 0);
  return buffer.toString().trimRight();
}

/// 把多行文字解析成若干棵子树：缩进最浅的每一行各是一棵（粘贴到导图时
/// 成为选中主题的几个子主题）。没有文字时为空列表。
List<MindMapNode> mindMapNodesFromOutline(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const <MindMapNode>[];
  final wrapped = StringBuffer('_');
  for (final line in lines) {
    wrapped
      ..write('\n  ')
      ..write(line.replaceAll('\t', '  '));
  }
  return mindMapNodeFromOutline(wrapped.toString())?.children ??
      const <MindMapNode>[];
}

/// 是否为“什么都没写”的导图：只有一个根节点，根上没有文字、备注、图片等
/// 任何内容。新建的空导图据此不算草稿、不算正文内容。
bool mindMapIsBlank(MindMapDocument document) {
  final root = document.root;
  return root.children.isEmpty &&
      root.text.trim().isEmpty &&
      (root.note ?? '').trim().isEmpty &&
      root.image == null &&
      root.icons.isEmpty &&
      root.labels.isEmpty &&
      (root.href ?? '').isEmpty &&
      document.summaries.isEmpty &&
      document.relations.isEmpty;
}

/// 是否只有一个中心主题（可以写了字）：起步卡与“转回文字日记”据此出现——
/// 中心主题的文字就是标题，转回文字也不丢东西。
bool mindMapHasOnlyRoot(MindMapDocument document) {
  final root = document.root;
  return root.children.isEmpty &&
      (root.note ?? '').trim().isEmpty &&
      root.image == null &&
      root.icons.isEmpty &&
      root.labels.isEmpty &&
      (root.href ?? '').isEmpty &&
      document.summaries.isEmpty &&
      document.relations.isEmpty;
}

/// 节点总数（含收起的）。
int mindMapNodeCount(MindMapDocument document) => document.index.length;

/// 日记卡片摘要用的大纲：中心主题是卡片标题，所以从一级主题（深度 1）
/// 排起，最多 [maxLines] 行、最深到 [maxDepth] 级。
///
/// 行数有限时先保住全貌：按层挑选（先放一级主题，还有余量再按先序放二级，
/// 再三级），再按先序排出——挑中的主题的父主题一定已经挑中，缩进不会断层；
/// 余量不够一整层时排在前面的分支先得。收起的主题不往下展开（与画布上看到
/// 的一致）；中心主题例外，它的一级主题总是列出（不然卡片上什么都没有）。
/// 空主题照样占一行（文字为空串，由界面显示占位文字），与画布上一致。
List<MindMapOutlineLine> mindMapCardOutline(
  MindMapDocument document, {
  required int maxLines,
  int maxDepth = 3,
}) {
  if (maxLines <= 0 || maxDepth <= 0) return const <MindMapOutlineLine>[];
  final picked = Set<MindMapNode>.identity();
  var level = document.root.children;
  for (var depth = 1; depth <= maxDepth && level.isNotEmpty; depth++) {
    final next = <MindMapNode>[];
    for (final node in level) {
      if (picked.length >= maxLines) break;
      picked.add(node);
      if (!node.collapsed) next.addAll(node.children);
    }
    if (picked.length >= maxLines) break;
    level = next;
  }
  final out = <MindMapOutlineLine>[];
  void visit(MindMapNode parent, int depth) {
    for (final child in parent.children) {
      if (!picked.contains(child)) continue;
      out.add((
        text: child.text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim(),
        depth: depth,
        node: child,
      ));
      visit(child, depth + 1);
    }
  }

  visit(document.root, 1);
  return out;
}

/// 把缩进大纲（每级两个空格或一个 Tab，行首的 `-` / `*` / `+` / `1.`
/// 列表记号去掉）解析成节点树：第一行是根，之后按缩进挂到上一行或其祖先
/// 下面；空行跳过。模板、粘贴多行文字与导入 Markdown 大纲共用。没有文字
/// 时为 null。节点 id 只是临时的，插入文档时经 `MindMapOps` 换成新 id。
MindMapNode? mindMapNodeFromOutline(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final stack = <({int indent, _OutlineNode node})>[];
  _OutlineNode? root;
  var counter = 0;
  final bullet = RegExp(r'^(?:[-*+•]|\d+[.)])\s+');
  for (final raw in lines) {
    if (raw.trim().isEmpty) continue;
    final expanded = raw.replaceAll('\t', '  ');
    final indent = expanded.length - expanded.trimLeft().length;
    final content = expanded.trimLeft().replaceFirst(bullet, '').trimRight();
    final node = _OutlineNode('o${counter++}', content);
    if (root == null) {
      root = node;
      stack.add((indent: -1, node: node));
      continue;
    }
    while (stack.length > 1 && stack.last.indent >= indent) {
      stack.removeLast();
    }
    stack.last.node.children.add(node);
    stack.add((indent: indent, node: node));
  }
  return root?.build();
}

final class _OutlineNode {
  _OutlineNode(this.id, this.text);

  final String id;
  final String text;
  final List<_OutlineNode> children = <_OutlineNode>[];

  MindMapNode build() => MindMapNode(
    id: id,
    text: text,
    children: <MindMapNode>[for (final child in children) child.build()],
  );
}
