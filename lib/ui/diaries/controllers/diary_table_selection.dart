import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_table_editing.dart';

/// 触及表格的选区的删除与粘贴整理：不论选区怎么跨格、跨出表格，表格的
/// 结构都保持有效（每个位置一格、每格至少一个段落）。
///
/// 上游的 `deleteSelection` 只认“一格一段”的表格，跨格时只删首段的一部分、
/// 从表格外选进来时整个表格一起删，所以这里自己处理：
/// - 选区两端都在同一格里：与普通正文相同，末段并进首段、中间的段删掉；
/// - 跨格（或一端在表格外）：被覆盖的格子只清文字——首尾所在的段各删掉
///   覆盖的那一截并留下，整格被覆盖的保留第一段（清空）、删掉其余段；
///   表格外被整个覆盖的块删掉，表格外的首尾文字块各删掉覆盖的那一截，
///   首尾不合并（表格仍夹在中间）；
/// - 从表格外一路选过整个表格（遍历时进入了表格节点而选区末端不在它里面，
///   或选区的两端就是表格块本身）：整个表格删掉。
/// 删完光标停在选区起点。

/// [selection] 是否有一端落在表格里（表格块本身也算）。两端都在表格外时
/// 交给上游（中间整个被覆盖的表格上游会连同其他块一起删掉）。
bool diarySelectionTouchesTable(af.EditorState state, af.Selection selection) {
  final document = state.document;
  return diaryTableOf(document.nodeAtPath(selection.start.path)) != null ||
      diaryTableOf(document.nodeAtPath(selection.end.path)) != null;
}

/// 删除触及表格的非折叠选区（规则见文件顶部）；选区折叠或两端都不在表格
/// 里时不处理、返回 false。一个事务、一步撤销。
Future<bool> deleteDiaryTableSelection(
  af.EditorState state,
  af.Selection selection,
) async {
  if (selection.isCollapsed) return false;
  var normalized = selection.normalized;
  final document = state.document;
  var startNode = document.nodeAtPath(normalized.start.path);
  var endNode = document.nodeAtPath(normalized.end.path);
  if (startNode == null || endNode == null) return false;
  final startTable = diaryTableOf(startNode);
  final endTable = diaryTableOf(endNode);
  if (startTable == null && endTable == null) return false;

  // 起点落在表格块本身、终点在这个表格的格子里：从第一格开始清。其余
  // “表格块本身”的端点都按整个表格被覆盖处理（遍历会进入表格节点）。
  if (startNode.type == kDiaryBlockTable &&
      endTable == startNode &&
      endNode != startNode) {
    final first = _firstParagraph(startNode);
    if (first != null) {
      startNode = first;
      normalized = af.Selection(
        start: af.Position(path: first.path),
        end: normalized.end,
      );
    }
  }
  if (endNode.type == kDiaryBlockTable && startTable == endNode) {
    final last = _lastParagraph(endNode);
    if (last != null && startNode != endNode) {
      endNode = last;
      normalized = af.Selection(
        start: normalized.start,
        end: af.Position(path: last.path, offset: last.delta?.length ?? 0),
      );
    }
  }

  final nodes = state.getNodesInSelection(normalized);
  final transaction = state.transaction;
  final startCell = diaryTableCellOf(startNode);
  final endCell = diaryTableCellOf(endNode);
  final deleted = <af.Node>{};
  bool underDeleted(af.Node node) {
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (deleted.contains(parent)) return true;
    }
    return false;
  }

  if (startCell != null && startCell == endCell) {
    // 同一格里：与普通正文相同。
    if (startNode == endNode) {
      if (startNode.delta != null) {
        transaction.deleteText(
          startNode,
          normalized.startIndex,
          normalized.length,
        );
      }
    } else if (startNode.delta != null && endNode.delta != null) {
      transaction.mergeText(
        startNode,
        endNode,
        leftOffset: normalized.startIndex,
        rightOffset: normalized.endIndex,
      );
      for (final node in nodes) {
        if (node != startNode && node.parent == startCell) {
          transaction.deleteNode(node);
        }
      }
    }
  } else {
    for (final node in nodes) {
      if (underDeleted(node)) continue;
      if (node.type == kDiaryBlockTable) {
        // 遍历进入了表格节点：从表格外选进来的。终点在它里面时只清格子，
        // 否则整个删掉。
        if (endTable != node || endNode == node) {
          transaction.deleteNode(node);
          deleted.add(node);
        }
        continue;
      }
      if (node.type == kDiaryBlockTableCell) continue;
      final cell = diaryTableCellOf(node);
      if (cell != null) {
        // 格内段落（段落下面不该有子块，有也随段落一起处理）。
        if (node.parent != cell) continue;
        _deleteInCell(
          transaction,
          node,
          normalized,
          startNode: startNode,
          endNode: endNode,
          clearOnly:
              cell != startCell &&
              cell != endCell &&
              node == cell.children.first,
        );
        continue;
      }
      // 表格外的块：首尾文字块各删掉覆盖的一截，其余整个删掉。
      final delta = node.delta;
      if (node == startNode && delta != null) {
        transaction.deleteText(
          node,
          normalized.startIndex,
          delta.length - normalized.startIndex,
        );
      } else if (node == endNode && delta != null) {
        transaction.deleteText(node, 0, normalized.endIndex);
      } else {
        transaction.deleteNode(node);
        deleted.add(node);
      }
    }
  }
  transaction.afterSelection = normalized.collapse(atStart: true);
  await state.apply(transaction, skipHistoryDebounce: true);
  return true;
}

/// 格内一段：首尾段删掉覆盖的那一截，整段被覆盖的删掉，[clearOnly]（整格
/// 被覆盖的格子的第一段）只清空、留下段落。
void _deleteInCell(
  af.Transaction transaction,
  af.Node node,
  af.Selection selection, {
  required af.Node startNode,
  required af.Node endNode,
  required bool clearOnly,
}) {
  final delta = node.delta;
  if (delta == null) {
    transaction.deleteNode(node);
    return;
  }
  if (node == startNode && node == endNode) {
    transaction.deleteText(node, selection.startIndex, selection.length);
  } else if (node == startNode) {
    transaction.deleteText(
      node,
      selection.startIndex,
      delta.length - selection.startIndex,
    );
  } else if (node == endNode) {
    transaction.deleteText(node, 0, selection.endIndex);
  } else if (clearOnly) {
    if (delta.isNotEmpty) transaction.deleteText(node, 0, delta.length);
  } else {
    transaction.deleteNode(node);
  }
}

af.Node? _firstParagraph(af.Node table) =>
    table.children.firstOrNull?.children.firstOrNull;

af.Node? _lastParagraph(af.Node table) =>
    table.children.lastOrNull?.children.lastOrNull;

/// 粘贴进格子的内容：只留文字，每个文字块成为一个段落（保留行内格式与
/// 对齐，丢掉类型专有的字段）；缩进的子块依次提到后面；表格按格子顺序
/// 展开；媒体、分隔线等没有文字的块丢掉。
List<af.Node> diaryTableCellParagraphs(Iterable<af.Node> nodes) {
  final result = <af.Node>[];
  void visit(af.Node node) {
    final delta = node.delta;
    if (delta != null &&
        node.type != kDiaryBlockTable &&
        node.type != kDiaryBlockTableCell) {
      result.add(
        af.paragraphNode(
          attributes: {
            kDiaryBlockDeltaKey: delta.toJson(),
            if (node.attributes[kDiaryBlockAlignKey] case final align?)
              kDiaryBlockAlignKey: align,
          },
        ),
      );
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final node in nodes) {
    visit(node);
  }
  return result;
}
