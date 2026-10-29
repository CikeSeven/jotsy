import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_table.dart';
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';

/// 工具栏「表格」工具、表格面板与 `/` 菜单读写正文里的表格。
///
/// 结构（见 diary_blocks_schema.dart）：表格 → 格子（带行列位置）→ 段落。
/// 读取时 `decodeStoredDiaryBlocks` 只认结构有效的表格（每个位置恰好一格、
/// `rowsLen` / `colsLen` 与格数相符），无效的整个摊平，所以每次改动都必须
/// 让表格仍然有效：这里只管定位（光标在哪一格）、建新表格与插入；增删行列
/// 在 diary_table_structure.dart，跨格的键盘与选区规则在
/// diary_table_shortcuts.dart 与 diary_table_selection.dart。
///
/// 位置按行优先排列（第 r 行第 c 列的格子是第 `r * cols + c` 个子块），
/// 读取时不依赖这个顺序，只是让路径好算。

/// 编辑器里能插到的列数上限：再宽的列在手机上排不下字。导入的更宽表格
/// （最多 [kDiaryTableMaxCols]）照常显示与编辑，只是不能再加列。
const int kDiaryTableEditorMaxCols = 6;

/// 新插入的表格：3 × 3，首行为表头。
const int kDiaryTableDefaultRows = 3;
const int kDiaryTableDefaultCols = 3;

/// 光标所在的表格位置：表格、格子、格内的段落与它们的行列数。
class DiaryTableCaret {
  const DiaryTableCaret._({
    required this.table,
    required this.cell,
    required this.paragraph,
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
    required this.headerRow,
  });

  final af.Node table;
  final af.Node cell;

  /// 光标所在的格内段落（光标落在格子或表格本身上时为 null）。
  final af.Node? paragraph;
  final int row;
  final int col;
  final int rows;
  final int cols;
  final bool headerRow;

  /// 段落在格子里的序号（没有段落时为 0）。
  int get paragraphIndex =>
      paragraph == null ? 0 : paragraph!.path.last.clamp(0, 1 << 30);

  bool get isFirstParagraph => paragraph == null || paragraph!.path.last == 0;
  bool get isLastParagraph =>
      paragraph == null || paragraph!.path.last == cell.children.length - 1;
  bool get isFirstCell => row == 0 && col == 0;
  bool get isLastCell => row == rows - 1 && col == cols - 1;
}

/// [node] 所在（或就是）的表格；不在表格里为 null。
af.Node? diaryTableOf(af.Node? node) {
  for (var current = node; current != null; current = current.parent) {
    if (current.type == kDiaryBlockTable) return current;
  }
  return null;
}

/// [node] 所在（或就是）的格子。
af.Node? diaryTableCellOf(af.Node? node) {
  for (var current = node; current != null; current = current.parent) {
    if (current.type == kDiaryBlockTableCell) return current;
  }
  return null;
}

/// [node] 是否在某个格子里（格子本身不算：它不是能打字的块）。
bool diaryNodeInTableCell(af.Node node) =>
    node.type != kDiaryBlockTableCell && diaryTableCellOf(node.parent) != null;

/// [node] 处的表格位置；[node] 不在表格里、或表格结构无效时为 null。
DiaryTableCaret? diaryTableCaretOf(af.Node? node) {
  final table = diaryTableOf(node);
  if (table == null) return null;
  final cell = diaryTableCellOf(node);
  final grid = diaryTableGridOf(table);
  if (grid == null) return null;
  if (cell == null) {
    // 光标在表格块本身：按第一格算。
    return DiaryTableCaret._(
      table: table,
      cell: grid.cellNodes[0][0],
      paragraph: null,
      row: 0,
      col: 0,
      rows: grid.rows,
      cols: grid.cols,
      headerRow: grid.headerRow,
    );
  }
  final (row, col) = diaryTableCellPosition(cell);
  if (row == null || col == null || row >= grid.rows || col >= grid.cols) {
    return null;
  }
  af.Node? paragraph;
  for (var current = node; current != null; current = current.parent) {
    if (current.parent == cell) {
      paragraph = current;
      break;
    }
  }
  return DiaryTableCaret._(
    table: table,
    cell: cell,
    paragraph: paragraph,
    row: row,
    col: col,
    rows: grid.rows,
    cols: grid.cols,
    headerRow: grid.headerRow,
  );
}

/// 选区两端都在同一个表格里时的位置（按选区末端）；折叠光标即光标所在。
DiaryTableCaret? diaryTableCaret(DiaryEditorController controller) {
  final selection = controller.selection;
  if (selection == null) return null;
  final document = controller.document;
  final end = diaryTableCaretOf(document.nodeAtPath(selection.end.path));
  if (end == null) return null;
  if (selection.isCollapsed) return end;
  final start = diaryTableOf(document.nodeAtPath(selection.start.path));
  return start == end.table ? end : null;
}

/// 工具栏「表格」工具的选中态与面板是否该开着：光标（或整个选区）在一个
/// 表格里。
bool diarySelectionInTable(DiaryEditorController controller) =>
    diaryTableCaret(controller) != null;

/// 格子的行列位置（认不出时为 null）。
(int?, int?) diaryTableCellPosition(af.Node cell) => (
  _index(cell.attributes[kDiaryTableRowPositionKey]),
  _index(cell.attributes[kDiaryTableColPositionKey]),
);

int? _index(Object? value) =>
    value is num && value.isFinite && value >= 0 && value == value.truncate()
    ? value.toInt()
    : null;

/// 编辑器节点上的网格：`cellNodes[行][列]`。结构无效时为 null（与存储层的
/// [DiaryTableGrid.of] 同一口径，由它校验）。
({int rows, int cols, bool headerRow, List<List<af.Node>> cellNodes})?
diaryTableGridOf(af.Node table) {
  final grid = DiaryTableGrid.of(table.toJson());
  if (grid == null) return null;
  final cells = List<List<af.Node?>>.generate(
    grid.rows,
    (_) => List<af.Node?>.filled(grid.cols, null),
  );
  for (final child in table.children) {
    final (row, col) = diaryTableCellPosition(child);
    if (row == null || col == null) return null;
    cells[row][col] = child;
  }
  return (
    rows: grid.rows,
    cols: grid.cols,
    headerRow: grid.headerRow,
    cellNodes: [
      for (final row in cells) [for (final cell in row) cell!],
    ],
  );
}

/// 空格子：一个空段落。
af.Node diaryTableCellNode(int row, int col, [List<af.Node>? children]) =>
    af.Node(
      type: kDiaryBlockTableCell,
      attributes: {
        kDiaryTableRowPositionKey: row,
        kDiaryTableColPositionKey: col,
      },
      children: children ?? [af.paragraphNode()],
    );

/// 新表格节点：[rows] × [cols] 个空格子。
af.Node diaryTableNode({
  int rows = kDiaryTableDefaultRows,
  int cols = kDiaryTableDefaultCols,
  bool headerRow = true,
}) => af.Node(
  type: kDiaryBlockTable,
  attributes: {
    kDiaryTableRowsLenKey: rows,
    kDiaryTableColsLenKey: cols,
    if (headerRow) kDiaryTableHeaderRowKey: true,
  },
  children: [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++) diaryTableCellNode(row, col),
  ],
);

/// 在光标所在块后面插入一个新表格（光标在空段落上时取代它；光标已在表格
/// 里时插到那个表格后面），光标进第一格。一步撤销。
void insertDiaryTable(
  DiaryEditorController controller, {
  int rows = kDiaryTableDefaultRows,
  int cols = kDiaryTableDefaultCols,
  bool headerRow = true,
}) {
  if (controller.readOnly) return;
  final selection = diaryEditorInsertionSelection(controller).normalized;
  final current = controller.document.nodeAtPath(selection.end.path);
  if (current == null) return;
  final table = diaryTableNode(rows: rows, cols: cols, headerRow: headerRow);
  final transaction = controller.state.transaction;
  final enclosing = diaryTableOf(current);
  final af.Path insertPath;
  if (enclosing != null) {
    insertPath = enclosing.path.next;
    transaction.insertNode(insertPath, table);
  } else if (current.type == kDiaryBlockParagraph &&
      current.children.isEmpty &&
      (current.delta?.isEmpty ?? true)) {
    // 先插后删：同一路径先删再插会被事务换算成 -1（见 insertDiaryEditorNodes）。
    insertPath = current.path;
    transaction
      ..insertNode(insertPath, table)
      ..deleteNode(current);
  } else {
    insertPath = current.path.next;
    transaction.insertNode(insertPath, table);
  }
  transaction.afterSelection = af.Selection.collapsed(
    af.Position(path: [...insertPath, 0, 0]),
  );
  controller.apply(transaction);
}
