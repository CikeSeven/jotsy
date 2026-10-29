import 'diary_blocks_schema.dart';
import 'diary_blocks_walk.dart';

/// 表格块的结构校验、读取时的整理与纯文本。
///
/// 存储结构与上游 AppFlowy 一致（见 diary_blocks_schema.dart 的
/// [kDiaryBlockTable]）：表格 → 格子（`table/cell`，带行列位置）→ 段落。
/// 上游的表格组件按位置找格子，结构不对（缺格、重格、位置越界、混进别的
/// 块）时会画错甚至抛出，所以读取时先经 [normalizeDiaryTable] 修正：
/// - 结构有效（[DiaryTableGrid.of] 认得）：表格与格子原样保留；格子里不是
///   段落的文字块换成段落（保留行内文字与对齐），格内段落的子块、媒体与
///   其他块提到表格后面，空格子补一个空段落。
/// - 结构无效：表格整个换成格子里的内容，按行优先的顺序排开（认不出位置
///   的格子与混进来的块按原顺序排在最后）。
/// 两种情况都不丢内容。纯 Map 处理，无 IO。

/// 列数与行数的上限：超出视为结构无效（多半是损坏的数据），按无效表格
/// 展开，避免编辑器一次排出过大的表格。
const int kDiaryTableMaxCols = 12;
const int kDiaryTableMaxRows = 200;

/// 结构有效的表格：[cells] 按 `[行][列]` 索引到格子节点。
class DiaryTableGrid {
  const DiaryTableGrid._(this.rows, this.cols, this.cells, this.headerRow);

  /// [table] 结构有效时返回网格，否则为 null。有效即：类型为表格；
  /// `rowsLen` / `colsLen` 为正整数且不超过上限；子块全是格子，每个
  /// （行, 列）恰好一格。
  static DiaryTableGrid? of(Map<String, Object?> table) {
    if (table[kDiaryBlockTypeKey] != kDiaryBlockTable) return null;
    final data = diaryBlockData(table);
    final rows = _positiveInt(data[kDiaryTableRowsLenKey]);
    final cols = _positiveInt(data[kDiaryTableColsLenKey]);
    if (rows == null || cols == null) return null;
    if (rows > kDiaryTableMaxRows || cols > kDiaryTableMaxCols) return null;
    final children = table[kDiaryBlockChildrenKey];
    if (children is! List || children.length != rows * cols) return null;
    final cells = List<List<Map<String, Object?>?>>.generate(
      rows,
      (_) => List<Map<String, Object?>?>.filled(cols, null),
    );
    for (final child in children) {
      if (child is! Map || child[kDiaryBlockTypeKey] != kDiaryBlockTableCell) {
        return null;
      }
      final cell = child.cast<String, Object?>();
      final (row, col) = _position(cell);
      if (row == null || col == null || row >= rows || col >= cols) {
        return null;
      }
      if (cells[row][col] != null) return null;
      cells[row][col] = cell;
    }
    // 格数等于行 × 列且没有重复，每个位置都已填上。
    return DiaryTableGrid._(rows, cols, <List<Map<String, Object?>>>[
      for (final row in cells) <Map<String, Object?>>[...row.nonNulls],
    ], data[kDiaryTableHeaderRowKey] == true);
  }

  final int rows;
  final int cols;
  final List<List<Map<String, Object?>>> cells;

  /// 首行是否为表头（[kDiaryTableHeaderRowKey]，缺省 false）。
  final bool headerRow;

  /// 一格里带文字的块，按文档顺序（含整理前可能残留的嵌套子块）。
  Iterable<Map<String, Object?>> textBlocksAt(int row, int col) sync* {
    for (final child in diaryBlockChildren(cells[row][col])) {
      yield* _textBlocksIn(child);
    }
  }

  /// 纯文本：每行一行，格与格之间 ` | `；一格里的几段以空格相连（空段
  /// 略过）。整行都是空格子时为空行，不留一串分隔符。
  Iterable<String> rowTexts() sync* {
    for (var row = 0; row < rows; row++) {
      final texts = <String>[
        for (var col = 0; col < cols; col++)
          textBlocksAt(row, col)
              .map(diaryBlockText)
              .where((text) => text.trim().isNotEmpty)
              .join(' '),
      ];
      yield texts.every((text) => text.isEmpty) ? '' : texts.join(' | ');
    }
  }
}

Iterable<Map<String, Object?>> _textBlocksIn(Map<String, Object?> node) sync* {
  if (kDiaryTextBlockTypes.contains(node[kDiaryBlockTypeKey])) yield node;
  for (final child in diaryBlockChildren(node)) {
    yield* _textBlocksIn(child);
  }
}

/// 读取时整理一个表格节点（规则见文件顶部）。不需要改动时返回 null（调用
/// 方原样保留同一个对象）；否则 `table` 为整理后的表格（结构无效时为
/// null），`following` 为要接在它后面（或取代它）的同级块，由调用方继续
/// 做子块修正。
({Map<String, Object?>? table, List<Map<String, Object?>> following})?
normalizeDiaryTable(Map<String, Object?> table) {
  final grid = DiaryTableGrid.of(table);
  if (grid == null) {
    final content = _flattenedContent(table);
    return (
      table: null,
      following: content.isEmpty
          ? <Map<String, Object?>>[_emptyParagraph()]
          : content,
    );
  }
  var changed = false;
  final following = <Map<String, Object?>>[];
  final cells = <Map<String, Object?>>[];
  for (final raw in table[kDiaryBlockChildrenKey]! as List) {
    final cell = (raw as Map).cast<String, Object?>();
    final children = cell[kDiaryBlockChildrenKey];
    final paragraphs = <Map<String, Object?>>[];
    var cellChanged = children is! List;
    for (final child in children is List ? children : const <Object?>[]) {
      if (child is! Map) {
        cellChanged = true;
        continue;
      }
      final node = child.cast<String, Object?>();
      final type = node[kDiaryBlockTypeKey];
      if (!kDiaryTextBlockTypes.contains(type)) {
        // 媒体、分隔线、嵌套表格与认不出的块：整块提到表格后面。
        following.add(node);
        cellChanged = true;
        continue;
      }
      final nested = diaryBlockChildren(node);
      following.addAll(nested);
      if (type == kDiaryBlockParagraph && nested.isEmpty) {
        paragraphs.add(node);
        continue;
      }
      paragraphs.add(
        type == kDiaryBlockParagraph
            ? ({...node}..remove(kDiaryBlockChildrenKey))
            : _asParagraph(node),
      );
      cellChanged = true;
    }
    if (paragraphs.isEmpty) {
      paragraphs.add(_emptyParagraph());
      cellChanged = true;
    }
    cells.add(
      cellChanged ? {...cell, kDiaryBlockChildrenKey: paragraphs} : cell,
    );
    changed = changed || cellChanged;
  }
  if (!changed) return null;
  return (
    table: {...table, kDiaryBlockChildrenKey: cells},
    following: following,
  );
}

/// 结构无效的表格展开后的内容：有位置的格子按行优先，其余（认不出位置的
/// 格子、混进来的别的块）按原顺序排在后面；格子取它的子块，别的块取它
/// 本身。
List<Map<String, Object?>> _flattenedContent(Map<String, Object?> table) {
  const unplaced = 1 << 30;
  final keyed = <(int, int, int, List<Map<String, Object?>>)>[];
  for (final (index, child) in diaryBlockChildren(table).indexed) {
    if (child[kDiaryBlockTypeKey] != kDiaryBlockTableCell) {
      keyed.add((unplaced, unplaced, index, [child]));
      continue;
    }
    final (row, col) = _position(child);
    final placed = row != null && col != null;
    keyed.add((
      placed ? row : unplaced,
      placed ? col : unplaced,
      index,
      diaryBlockChildren(child),
    ));
  }
  keyed.sort((a, b) {
    final byRow = a.$1.compareTo(b.$1);
    if (byRow != 0) return byRow;
    final byCol = a.$2.compareTo(b.$2);
    return byCol != 0 ? byCol : a.$3.compareTo(b.$3);
  });
  return <Map<String, Object?>>[for (final entry in keyed) ...entry.$4];
}

/// 格子里的非段落文字块（标题、列表、代码……）换成段落：只保留行内文字
/// 与对齐，类型专有的字段（级别、勾选、语言、样式）不再有意义。
Map<String, Object?> _asParagraph(Map<String, Object?> node) {
  final data = diaryBlockData(node);
  final align = data[kDiaryBlockAlignKey];
  return <String, Object?>{
    kDiaryBlockTypeKey: kDiaryBlockParagraph,
    kDiaryBlockDataKey: <String, Object?>{
      kDiaryBlockDeltaKey: data[kDiaryBlockDeltaKey] is List
          ? data[kDiaryBlockDeltaKey]
          : <Object?>[],
      if (align is String && align.isNotEmpty) kDiaryBlockAlignKey: align,
    },
  };
}

Map<String, Object?> _emptyParagraph() => <String, Object?>{
  kDiaryBlockTypeKey: kDiaryBlockParagraph,
  kDiaryBlockDataKey: <String, Object?>{kDiaryBlockDeltaKey: <Object?>[]},
};

(int?, int?) _position(Map<String, Object?> cell) {
  final data = diaryBlockData(cell);
  return (
    _nonNegativeInt(data[kDiaryTableRowPositionKey]),
    _nonNegativeInt(data[kDiaryTableColPositionKey]),
  );
}

/// 整数值（JSON 里可能是 `2.0`）；其他类型、小数与负数为 null。
int? _nonNegativeInt(Object? value) {
  if (value is! num || !value.isFinite || value != value.truncate()) {
    return null;
  }
  return value < 0 ? null : value.toInt();
}

int? _positiveInt(Object? value) {
  final result = _nonNegativeInt(value);
  return result == null || result == 0 ? null : result;
}
