import 'package:flutter_quill/flutter_quill.dart'
    show Attribute, Block, Document, Line, Node;
import 'package:flutter_quill/quill_delta.dart';

// 代码块里按回车的改写计划，以及读取代码块的公共工具（纯函数，不碰控件）。
//
// 输入：文档、编辑器发来的替换（index / len / data）。
// 输出：要整体组合进文档的一个 Delta 与改写后的光标位置；不该接管时返回
// null，交还 flutter_quill 的默认链路。
// 副作用：无（落地由 controllers/diary_code_block_editing.dart 负责）。
//
// 为什么要改写：flutter_quill 的 AutoExitBlockRule 在任何块的“最后一行为空
// 行”时按回车就移除块属性，写代码时习惯性地空一行再继续写，代码块就断了。
// 代码块因此单独定规则（列表、引用等其他块仍走默认行为）：
// - 空白行（只有空格 / Tab 或为空）允许出现在代码中间；
// - 退出：光标所在行是本块最后一行、是空白行，且上一行（同块）也是空白行
//   时，把块尾连续的空白行全部收掉，只留下一个换行并去掉 `code-block`，
//   代码块止于最后一行内容，光标落在块后新的普通空行上；整块都是空白行时
//   收成一个普通空行；
// - 其余回车留在块内并自动缩进：沿用当前行的行首空白，光标在缩进中间时
//   只取光标之前的部分。
// 只接管“插入单个换行、没有选区”的情况；替换选区、粘贴多行与嵌入一律交还
// 默认链路，保持与正文其他位置一致的行为。

/// 回车改写计划：整体组合进文档的 [delta]，以及组合后光标应在的 [caret]。
typedef DiaryCodeNewlinePlan = ({Delta delta, int caret});

final RegExp _leadingWhitespace = RegExp(r'^[ \t]*');
final RegExp _blankLine = RegExp(r'^[ \t]*$');

/// [node] 是否为代码块（`code-block` 属性值为 true / 'plain' / 语言 id）。
///
/// 值为 null 或 false 视为不是代码块：quill 的“取消块样式”会短暂写入 null，
/// 手改数据里也可能出现 false。
bool isDiaryCodeBlock(Node? node) {
  if (node is! Block) {
    return false;
  }
  final value = node.style.attributes[Attribute.codeBlock.key]?.value;
  return value != null && value != false;
}

/// 文档偏移 [offset] 所在行所属的代码块；该行不在代码块里时返回 null。
Block? diaryCodeBlockAt(Document document, int offset) {
  final line = _lineAt(document, offset);
  final parent = line?.parent;
  return isDiaryCodeBlock(parent) ? parent as Block : null;
}

/// 范围 [start, end] 触及的全部代码块，按文档顺序、去重。
///
/// 折叠选区（start == end）只取光标所在行的代码块：光标停在块后一行的行首
/// 时不算触及上面的块。有选区时终点按开区间处理：整行选中（选区止于下一行
/// 行首）不会把下一行的代码块也算进来。
List<Block> diaryCodeBlocksInRange(Document document, int start, int end) {
  final from = start <= end ? start : end;
  final to = start <= end ? end : start;
  final blocks = <Block>[];
  // Quill 的块只出现在根节点下一层（块不嵌套），按根节点顺序扫一遍即可。
  for (final node in document.root.children) {
    if (!isDiaryCodeBlock(node)) {
      continue;
    }
    final nodeStart = node.documentOffset;
    final nodeEnd = nodeStart + node.length;
    final touched = from == to
        ? nodeStart <= from && from < nodeEnd
        : nodeStart < to && nodeEnd > from;
    if (touched) {
      blocks.add(node as Block);
    }
  }
  return blocks;
}

/// 代码块的纯文本（各行以 `\n` 相连，不含最后一行的换行）。
String diaryCodeBlockText(Block block) {
  final text = block.toPlainText();
  return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
}

/// 计算代码块内回车的改写；不该接管时返回 null（走 flutter_quill 默认链路）。
///
/// 只处理 [len] 为 0、[data] 恰为 `'\n'` 的插入，且插入点所在行属于代码块。
DiaryCodeNewlinePlan? planDiaryCodeBlockNewline(
  Document document,
  int index,
  int len,
  Object? data,
) {
  if (len != 0 || data is! String || data != '\n') {
    return null;
  }
  final query = document.queryChild(index);
  final line = query.node;
  if (line is! Line) {
    return null;
  }
  final block = line.parent;
  if (!isDiaryCodeBlock(block)) {
    return null;
  }

  final previous = line.previous;
  if (identical(line, block!.last) &&
      _isBlank(line) &&
      previous is Line &&
      _isBlank(previous)) {
    // 退出：向上找到块尾连续空白行的第一行，收掉它们的空白与除最后一个
    // 之外的全部换行；留下的换行（原光标行的换行）去掉 `code-block`，成为
    // 块后的普通空行。
    var first = previous;
    while (first.previous is Line && _isBlank(first.previous! as Line)) {
      first = first.previous! as Line;
    }
    final start = first.documentOffset;
    final total = line.documentOffset + line.length - start;
    final delta = Delta()
      ..retain(start)
      ..delete(total - 1)
      ..retain(1, <String, dynamic>{Attribute.codeBlock.key: null});
    return (delta: delta, caret: start);
  }

  // 留在块内并自动缩进。新换行带上本行完整的行属性（行自身的样式并上块
  // 样式，与 Line.toDelta 写出的一致），保留语言等取值，不让拆出的前半行
  // 掉出代码块。
  final text = _lineText(line);
  final leading = _leadingWhitespace.stringMatch(text) ?? '';
  final column = query.offset;
  final indent = column < leading.length
      ? leading.substring(0, column)
      : leading;
  final attributes = line.style.mergeAll(block.style).toJson();
  final delta = Delta()
    ..retain(index)
    ..insert('\n', attributes);
  if (indent.isNotEmpty) {
    delta.insert(indent);
  }
  return (delta: delta, caret: index + 1 + indent.length);
}

Line? _lineAt(Document document, int offset) {
  final node = document.queryChild(offset).node;
  return node is Line ? node : null;
}

/// 行文本（不含行尾换行）。嵌入对象会以占位字符出现，因而不算空白行。
String _lineText(Line line) {
  final text = line.toPlainText();
  return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
}

bool _isBlank(Line line) => _blankLine.hasMatch(_lineText(line));
