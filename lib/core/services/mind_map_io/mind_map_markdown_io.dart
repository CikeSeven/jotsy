import '../../database/diary_blocks/diary_link_target.dart';
import '../../database/mind_map/mind_map_document.dart';

/// 导图 ↔ Markdown 大纲（纯函数）。
///
/// 导出：中心主题为一级标题，其余为逐级缩进两格的无序列表；待办写成
/// `- [ ]` / `- [x]`，网址链接写成 `[文字](网址)`（日记链接只留文字，应用外
/// 打不开），备注写成下一行缩进的引用。
/// 导入：标题定层级（只有一个一级标题时它是中心主题），列表按缩进挂在最近的
/// 标题下，普通段落成为最近标题的子主题；`- [ ]` / `- [x]` 还原为待办，
/// `[文字](网址)` 还原为链接。

String mindMapToMarkdown(MindMapDocument document, {String untitled = ''}) {
  final buffer = StringBuffer();
  final root = document.root;
  buffer
    ..write('# ')
    ..writeln(_line(root.text).isEmpty ? untitled : _line(root.text))
    ..writeln();
  void visit(MindMapNode node, int depth) {
    final indent = '  ' * depth;
    final text = _line(node.text);
    final href = node.href?.trim() ?? '';
    final body = href.isNotEmpty && !DiaryLinkTarget.isLink(href)
        ? '[${text.isEmpty ? href : text}]($href)'
        : text;
    final task = node.isTask ? (node.taskDone ? '[x] ' : '[ ] ') : '';
    buffer.writeln('$indent- $task$body');
    final note = node.note?.trim() ?? '';
    if (note.isNotEmpty) {
      for (final line in note.split('\n')) {
        buffer.writeln('$indent  > ${line.trimRight()}');
      }
    }
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  for (final child in root.children) {
    visit(child, 0);
  }
  return buffer.toString().trimRight();
}

String _line(String text) => text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _bullet = RegExp(r'^(\s*)(?:[-*+]|\d+[.)])\s+(.*)$');
final RegExp _task = RegExp(r'^\[( |x|X)\]\s+(.*)$');
final RegExp _link = RegExp(r'^\[([^\]]*)\]\((\S+?)\)$');

/// 解析 Markdown 大纲；没有任何文字时为 null。[fallbackTitle] 为没有唯一
/// 一级标题时中心主题的文字（通常是文件名）。
MindMapNode? mindMapFromMarkdown(String markdown, {String fallbackTitle = ''}) {
  final lines = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final headings = <int>[
    for (final line in lines)
      if (_heading.firstMatch(line) case final match?) match.group(1)!.length,
  ];
  final topLevel = headings.isEmpty
      ? 0
      : headings.reduce((a, b) => a < b ? a : b);
  final singleTop = headings.where((level) => level == topLevel).length == 1;
  var counter = 0;
  _Draft draft(String text) => _Draft('m${counter++}', text);
  final root = draft(fallbackTitle);
  // 标题栈：(层级, 节点)；层级 0 为中心主题。
  final headingStack = <(int, _Draft)>[(0, root)];
  // 当前标题下的列表栈：(缩进, 节点)。
  final listStack = <(int, _Draft)>[];
  var rootFromHeading = false;
  var inFence = false;

  for (final raw in lines) {
    if (raw.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence || raw.trim().isEmpty) continue;
    final heading = _heading.firstMatch(raw);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final text = heading.group(2)!.trim();
      listStack.clear();
      if (singleTop && level == topLevel && !rootFromHeading) {
        root.text = text;
        rootFromHeading = true;
        continue;
      }
      final depth = level - topLevel + (singleTop ? 0 : 1);
      while (headingStack.length > 1 && headingStack.last.$1 >= depth) {
        headingStack.removeLast();
      }
      final node = draft(text);
      headingStack.last.$2.children.add(node);
      headingStack.add((depth, node));
      continue;
    }
    final quote = raw.trimLeft();
    if (quote.startsWith('>')) {
      // 引用跟在一个主题后面：作为它的备注。
      final target = listStack.isNotEmpty
          ? listStack.last.$2
          : headingStack.last.$2;
      final line = quote.substring(1).trim();
      target.note = target.note == null ? line : '${target.note}\n$line';
      continue;
    }
    final bullet = _bullet.firstMatch(raw);
    final parentHeading = headingStack.last.$2;
    if (bullet != null) {
      final indent = bullet.group(1)!.replaceAll('\t', '  ').length;
      final node = _withInline(draft(''), bullet.group(2)!.trim());
      while (listStack.isNotEmpty && listStack.last.$1 >= indent) {
        listStack.removeLast();
      }
      (listStack.isEmpty ? parentHeading : listStack.last.$2).children.add(
        node,
      );
      listStack.add((indent, node));
      continue;
    }
    listStack.clear();
    parentHeading.children.add(_withInline(draft(''), raw.trim()));
  }
  if (root.text.trim().isEmpty && root.children.isEmpty) return null;
  return root.build();
}

_Draft _withInline(_Draft node, String text) {
  var body = text;
  final task = _task.firstMatch(body);
  if (task != null) {
    node.done = task.group(1)!.toLowerCase() == 'x';
    body = task.group(2)!;
  }
  final link = _link.firstMatch(body);
  if (link != null) {
    body = link.group(1)!;
    node.href = link.group(2);
  }
  node.text = body.replaceAll(RegExp(r'\*\*|__|`'), '');
  return node;
}

final class _Draft {
  _Draft(this.id, this.text);

  final String id;
  String text;
  String? note;
  String? href;
  bool? done;
  final List<_Draft> children = <_Draft>[];

  MindMapNode build() => MindMapNode(
    id: id,
    text: text,
    note: note,
    href: href,
    task: done == null ? null : <String, Object?>{'done': done},
    children: <MindMapNode>[for (final child in children) child.build()],
  );
}
