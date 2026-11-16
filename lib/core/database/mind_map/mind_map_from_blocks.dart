import '../diary_blocks/diary_blocks_schema.dart';
import '../diary_blocks/diary_blocks_walk.dart';
import 'mind_map_document.dart';
import 'mind_map_ops.dart';

/// 把一篇文字日记的结构转成导图（纯函数，确定）：
/// - 标题定层级：一级标题挂在中心主题下，二级挂在最近的一级下，依此类推；
/// - 列表（有序、无序、待办、折叠）按嵌套挂在最近的标题下，待办保留勾选；
/// - 正文段落、引用、提示块各成一个主题，挂在最近的标题下；
/// - 代码块、表格、媒体与分隔线不进导图。
/// 中心主题为 [title]（没有时取第一个标题）。导图里已经有的嵌入导图原样
/// 并进来（作为它所在位置的子树）。节点数受 `MindMapOps` 的上限约束。
MindMapDocument mindMapFromDiaryBlocks(
  Map<String, Object?> document, {
  required String title,
}) {
  final root = diaryBlocksRoot(document);
  var counter = 0;
  _Draft draft(String text, {bool? done}) =>
      _Draft('d${counter++}', text, done: done);
  final top = draft(title.trim());
  // 标题栈：(级别, 节点)；级别 0 为中心主题。
  final headings = <(int, _Draft)>[(0, top)];

  void addList(Map<String, Object?> node, _Draft parent) {
    final type = node[kDiaryBlockTypeKey];
    final text = _clean(diaryBlockText(node));
    final data = diaryBlockData(node);
    final created = draft(
      text,
      done: type == kDiaryBlockTodoList
          ? data[kDiaryBlockCheckedKey] == true
          : null,
    );
    if (text.isNotEmpty) parent.children.add(created);
    for (final child in diaryBlockChildren(node)) {
      addList(child, text.isNotEmpty ? created : parent);
    }
  }

  for (final node
      in root == null
          ? const <Map<String, Object?>>[]
          : diaryBlockChildren(root)) {
    final type = node[kDiaryBlockTypeKey];
    final text = _clean(diaryBlockText(node));
    switch (type) {
      case kDiaryBlockHeading:
        if (text.isEmpty) continue;
        final level = switch (diaryBlockData(node)[kDiaryBlockLevelKey]) {
          final num value => value.toInt().clamp(1, 6),
          _ => 1,
        };
        if (top.text.isEmpty && headings.length == 1) {
          top.text = text;
          continue;
        }
        while (headings.length > 1 && headings.last.$1 >= level) {
          headings.removeLast();
        }
        final created = draft(text);
        headings.last.$2.children.add(created);
        headings.add((level, created));
      case kDiaryBlockBulletedList ||
          kDiaryBlockNumberedList ||
          kDiaryBlockTodoList ||
          kDiaryBlockToggleList:
        addList(node, headings.last.$2);
      case kDiaryBlockParagraph || kDiaryBlockQuote || kDiaryBlockCallout:
        if (text.isNotEmpty) headings.last.$2.children.add(draft(text));
        for (final child in diaryBlockChildren(node)) {
          addList(child, headings.last.$2);
        }
      case kDiaryBlockMindMap:
        final embedded = MindMapDocument.decode(
          diaryBlockData(node)['map'],
        ).root;
        headings.last.$2.children.add(_Draft.fromNode(embedded, draft));
      default:
        continue;
    }
  }
  return MindMapOps.replaceRoot(MindMapDocument.blank(), top.build());
}

String _clean(String text) => text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

final class _Draft {
  _Draft(this.id, this.text, {this.done});

  factory _Draft.fromNode(
    MindMapNode node,
    _Draft Function(String text, {bool? done}) draft,
  ) {
    final created = draft(node.text, done: node.isTask ? node.taskDone : null);
    for (final child in node.children) {
      created.children.add(_Draft.fromNode(child, draft));
    }
    return created;
  }

  final String id;
  String text;
  final bool? done;
  final List<_Draft> children = <_Draft>[];

  MindMapNode build() => MindMapNode(
    id: id,
    text: text.length > 2000 ? text.substring(0, 2000) : text,
    task: done == null ? null : <String, Object?>{'done': done},
    children: <MindMapNode>[for (final child in children) child.build()],
  );
}
