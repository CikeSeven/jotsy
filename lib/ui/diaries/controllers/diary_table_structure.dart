import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_table.dart';
import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';

/// 表格面板的行列操作：增删行列、表头行开关、删除整个表格。
///
/// 增删行列不在原树上逐格改位置，而是按新的行列数**整个重建**表格节点
/// （未动的格子里的段落取副本，位置按行优先重新编号），一次事务里先插入
/// 新表格、再删除旧表格——事务里删除操作持有的是未改动的原节点，撤销原样
/// 放回，一步撤销；重建后的表格由构造保证结构有效。光标落到合理的格子：
/// 插入时留在原来的格子，删除时到同列的下一行 / 同行的右边一列（没有则
/// 上一行 / 左边一列）。

/// 在光标所在行的上方（[above]）或下方插入一行。
void insertDiaryTableRow(
  DiaryEditorController controller, {
  required bool above,
}) {
  final caret = diaryTableCaret(controller);
  if (caret == null || caret.rows >= kDiaryTableMaxRows) return;
  if (controller.readOnly) return;
  _insertRow(controller.state, caret, at: above ? caret.row : caret.row + 1);
}

/// 在最后一行下面追加一行（桌面在最后一格按 Tab），光标进新行的第一格。
void appendDiaryTableRow(af.EditorState state, DiaryTableCaret caret) {
  if (caret.rows >= kDiaryTableMaxRows) return;
  _insertRow(state, caret, at: caret.rows, enterNewRow: true);
}

/// 在第 [at] 行之前插入一行；[enterNewRow] 时光标进新行的第一格，否则留在
/// 原来的格子里。
void _insertRow(
  af.EditorState state,
  DiaryTableCaret caret, {
  required int at,
  bool enterNewRow = false,
}) {
  final cells = _grid(caret).cellNodes;
  _rebuildTable(
    state,
    caret,
    rows: caret.rows + 1,
    cols: caret.cols,
    cellAt: (row, col) =>
        row == at ? null : cells[row < at ? row : row - 1][col],
    caretRow: enterNewRow
        ? at
        : at <= caret.row
        ? caret.row + 1
        : caret.row,
    caretCol: enterNewRow ? 0 : caret.col,
    keepOffset: !enterNewRow,
  );
}

/// 在光标所在列的左侧（[before]）或右侧插入一列；已达
/// [kDiaryTableEditorMaxCols] 时不插。
void insertDiaryTableColumn(
  DiaryEditorController controller, {
  required bool before,
}) {
  final caret = diaryTableCaret(controller);
  if (caret == null || !canInsertDiaryTableColumn(caret)) return;
  if (controller.readOnly) return;
  final at = before ? caret.col : caret.col + 1;
  final cells = _grid(caret).cellNodes;
  _rebuildTable(
    controller.state,
    caret,
    rows: caret.rows,
    cols: caret.cols + 1,
    cellAt: (row, col) =>
        col == at ? null : cells[row][col < at ? col : col - 1],
    caretRow: caret.row,
    caretCol: before ? caret.col + 1 : caret.col,
  );
}

bool canInsertDiaryTableColumn(DiaryTableCaret caret) =>
    caret.cols < kDiaryTableEditorMaxCols;
bool canDeleteDiaryTableRow(DiaryTableCaret caret) => caret.rows > 1;
bool canDeleteDiaryTableColumn(DiaryTableCaret caret) => caret.cols > 1;

/// 删除光标所在行（只剩一行时不删）；光标到同列的下一行（没有则上一行）。
void deleteDiaryTableRow(DiaryEditorController controller) {
  final caret = diaryTableCaret(controller);
  if (caret == null || !canDeleteDiaryTableRow(caret)) return;
  if (controller.readOnly) return;
  final cells = _grid(caret).cellNodes;
  _rebuildTable(
    controller.state,
    caret,
    rows: caret.rows - 1,
    cols: caret.cols,
    cellAt: (row, col) => cells[row < caret.row ? row : row + 1][col],
    caretRow: caret.row.clamp(0, caret.rows - 2),
    caretCol: caret.col,
    keepOffset: false,
  );
}

/// 删除光标所在列（只剩一列时不删）；光标到同行的右边一列（没有则左边）。
void deleteDiaryTableColumn(DiaryEditorController controller) {
  final caret = diaryTableCaret(controller);
  if (caret == null || !canDeleteDiaryTableColumn(caret)) return;
  if (controller.readOnly) return;
  final cells = _grid(caret).cellNodes;
  _rebuildTable(
    controller.state,
    caret,
    rows: caret.rows,
    cols: caret.cols - 1,
    cellAt: (row, col) => cells[row][col < caret.col ? col : col + 1],
    caretRow: caret.row,
    caretCol: caret.col.clamp(0, caret.cols - 2),
    keepOffset: false,
  );
}

/// 切换首行是否为表头（只改表格的 `headerRow`，格子不动）。
void toggleDiaryTableHeaderRow(DiaryEditorController controller) {
  final caret = diaryTableCaret(controller);
  if (caret == null || controller.readOnly) return;
  final transaction = controller.state.transaction
    ..updateNode(caret.table, {
      kDiaryTableHeaderRowKey: caret.headerRow ? null : true,
    })
    ..afterSelection = controller.selection;
  controller.apply(transaction);
}

/// 删除整个表格；光标落到后一块（没有则前一块）的开头，文档只剩它时换成
/// 一个空段落。
void deleteDiaryTable(DiaryEditorController controller) {
  final caret = diaryTableCaret(controller);
  if (caret == null || controller.readOnly) return;
  final table = caret.table;
  final path = table.path;
  final transaction = controller.state.transaction;
  final next = table.next;
  final previous = table.previous;
  if (next == null && previous == null) {
    transaction
      ..insertNode(path, af.paragraphNode())
      ..deleteNode(table)
      ..afterSelection = af.Selection.collapsed(af.Position(path: path));
  } else {
    transaction
      ..deleteNode(table)
      ..afterSelection = af.Selection.collapsed(
        next != null
            ? af.Position(path: path)
            : af.Position(
                path: previous!.path,
                offset: previous.delta?.length ?? 0,
              ),
      );
  }
  controller.apply(transaction);
}

/// 光标所在表格的网格（光标位置来自有效的网格，这里一定有）。
({int rows, int cols, bool headerRow, List<List<af.Node>> cellNodes}) _grid(
  DiaryTableCaret caret,
) => diaryTableGridOf(caret.table)!;

/// 按 [rows] × [cols] 重建 [caret] 所在的表格：第 (row, col) 格的内容由
/// [cellAt] 给出原格子（null 为新的空格子），段落取副本。光标落到新表格
/// 的 ([caretRow], [caretCol])：[keepOffset] 时沿用原来的段落序号与偏移
/// （那一格就是原来的格子），否则到第一段开头。
void _rebuildTable(
  af.EditorState state,
  DiaryTableCaret caret, {
  required int rows,
  required int cols,
  required af.Node? Function(int row, int col) cellAt,
  required int caretRow,
  required int caretCol,
  bool keepOffset = true,
}) {
  final table = caret.table;
  final rebuilt = af.Node(
    type: kDiaryBlockTable,
    attributes: {
      ...table.attributes,
      kDiaryTableRowsLenKey: rows,
      kDiaryTableColsLenKey: cols,
    },
    children: [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++)
          diaryTableCellNode(row, col, switch (cellAt(row, col)) {
            null => null,
            final cell => [for (final child in cell.children) child.copyWith()],
          }),
    ],
  );
  final selection = state.selection;
  final offset = keepOffset && selection != null && selection.isCollapsed
      ? selection.end.offset
      : 0;
  final transaction = state.transaction
    ..insertNode(table.path, rebuilt)
    ..deleteNode(table)
    ..afterSelection = af.Selection.collapsed(
      af.Position(
        path: [
          ...table.path,
          caretRow * cols + caretCol,
          keepOffset ? caret.paragraphIndex : 0,
        ],
        offset: offset,
      ),
    );
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
}
