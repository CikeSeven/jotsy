import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../controllers/diary_table_editing.dart';

/// 表格块（`table`）与格子块（`table/cell`）的渲染，编辑与只读共用。
///
/// - 整行铺满可用宽度、各列等宽（`Expanded`），文字在格内换行，**任何宽度
///   下都不横向滚动**——预览页左右滑动翻页，横向滚动容器会抢走翻页；导入
///   的最多 12 列也只是列变窄；
/// - 一行的高度为最高的格子（`IntrinsicHeight` + 拉伸），格子因此铺满整
///   行的高度，点在矮格子的空白处也能把光标放进那一格（上游的命中测试按
///   节点矩形找格子）；
/// - 1dp `outlineVariant` 网格线：外框带圆角 8 并裁切，格子只画右侧与下方
///   的内线；格内留白上下 5dp（加上段落自身的 3dp 即 8dp）、左右 10dp；
/// - 表头行（`headerRow`）垫 `surfaceContainerHigh`，文字加粗只在渲染时
///   （段落样式按 `diaryTableHeaderParagraph` 判断），不写进正文；
/// - 格内段落经编辑器同一份渲染器构建，行内格式、颜色、链接、对齐、上下标
///   与输入法都与正文相同；
/// - 结构无效（读取时已修正，这里只是兜底）的表格按子块顺序排开。
///
/// 选区：表格作为一个块参与上游的选区服务（[af.SelectableMixin]，与上游
/// 表格相同的 cover 口径）；格子也是可选对象，点在格内段落之外的留白时把
/// 光标交给最近的那一段。

/// 表格上下的块间距。
const EdgeInsets kDiaryTablePadding = EdgeInsets.symmetric(vertical: 8);

/// 格内留白：上下 5dp（段落自带 3dp，合计 8dp）、左右 10dp。
const EdgeInsets kDiaryTableCellPadding = EdgeInsets.symmetric(
  vertical: 5,
  horizontal: 10,
);
const double kDiaryTableRadius = 8;
const double kDiaryTableLineWidth = 1;

/// 段落是否在表头行里（表格 `headerRow` 为 true 且格子在第 0 行）：编辑器
/// 的段落样式据此加粗。
bool diaryTableHeaderParagraph(af.Node node) {
  final cell = node.parent;
  if (cell == null || cell.type != kDiaryBlockTableCell) return false;
  final table = cell.parent;
  if (table == null || table.type != kDiaryBlockTable) return false;
  return table.attributes[kDiaryTableHeaderRowKey] == true &&
      cell.attributes[kDiaryTableRowPositionKey] == 0;
}

class DiaryTableBlockBuilder extends af.BlockComponentBuilder {
  DiaryTableBlockBuilder({
    required af.BlockComponentConfiguration configuration,
    required this.editorState,
  }) : super(
         configuration: configuration.copyWith(
           padding: (_) => kDiaryTablePadding,
         ),
       );

  final af.EditorState editorState;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      DiaryTableBlock(
        key: context.node.key,
        node: context.node,
        configuration: configuration,
        editorState: editorState,
      );

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.type == kDiaryBlockTable;
}

class DiaryTableCellBlockBuilder extends af.BlockComponentBuilder {
  DiaryTableCellBlockBuilder({required this.editorState})
    : super(configuration: const af.BlockComponentConfiguration());

  final af.EditorState editorState;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      DiaryTableCellBlock(
        key: context.node.key,
        node: context.node,
        editorState: editorState,
      );

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.type == kDiaryBlockTableCell;
}

class DiaryTableBlock extends af.BlockComponentStatefulWidget {
  const DiaryTableBlock({
    super.key,
    required super.node,
    required super.configuration,
    required this.editorState,
  });

  final af.EditorState editorState;

  @override
  State<DiaryTableBlock> createState() => _DiaryTableBlockState();
}

class _DiaryTableBlockState extends State<DiaryTableBlock>
    with af.SelectableMixin, af.BlockComponentConfigurable {
  final GlobalKey _tableKey = GlobalKey(debugLabel: kDiaryBlockTable);

  @override
  af.BlockComponentConfiguration get configuration => widget.configuration;

  @override
  af.Node get node => widget.node;

  af.EditorState get editorState => widget.editorState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final line = BorderSide(
      color: colors.outlineVariant,
      width: kDiaryTableLineWidth,
    );
    final grid = diaryTableGridOf(node);
    final Widget body;
    if (grid == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: editorState.renderer.buildList(context, node.children),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < grid.rows; row++)
            _buildRow(
              context,
              grid.cellNodes[row],
              line: line,
              last: row == grid.rows - 1,
              header: grid.headerRow && row == 0
                  ? colors.surfaceContainerHigh
                  : null,
            ),
        ],
      );
    }
    Widget child = Container(
      key: _tableKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(line),
        borderRadius: BorderRadius.circular(kDiaryTableRadius),
      ),
      child: body,
    );
    child = af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [af.BlockSelectionType.block],
      child: child,
    );
    return Padding(padding: padding, child: child);
  }

  /// 一行：各格等宽并拉伸到行高；内线只画在格子右侧与行下方，最后一列与
  /// 最后一行不画（外框由表格画）。
  Widget _buildRow(
    BuildContext context,
    List<af.Node> cells, {
    required BorderSide line,
    required bool last,
    Color? header,
  }) {
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var col = 0; col < cells.length; col++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: col == cells.length - 1 ? BorderSide.none : line,
                    bottom: last ? BorderSide.none : line,
                  ),
                ),
                child: editorState.renderer.build(context, cells[col]),
              ),
            ),
        ],
      ),
    );
    return header == null ? row : ColoredBox(color: header, child: row);
  }

  // ---- 选区（与上游表格块同一口径：整块 cover） ----

  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  @override
  af.Position start() => af.Position(path: node.path);

  @override
  af.Position end() => af.Position(path: node.path, offset: 1);

  /// 点在格子之外（外框、格子上方的留白）：上半落到第一格开头、下半落到
  /// 最后一格末尾；没有格子时按整块。
  @override
  af.Position getPositionInOffset(Offset start) {
    final box = _box;
    final cells = node.children;
    if (box == null || cells.isEmpty) return end();
    final upper = box.globalToLocal(start).dy < box.size.height / 2;
    final paragraph = upper
        ? cells.first.children.firstOrNull
        : cells.last.children.lastOrNull;
    if (paragraph == null) return upper ? this.start() : end();
    return af.Position(
      path: paragraph.path,
      offset: upper ? 0 : paragraph.delta?.length ?? 0,
    );
  }

  /// 从表格外一路选进来、选区末端还在表格里：只让格内的段落各画各的；
  /// 否则（整个表格被覆盖、或就是表格块本身的选区）整块覆盖。
  @override
  List<Rect> getRectsInSelection(
    af.Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final end = selection.normalized.end.path;
    final path = node.path;
    if (end.length > path.length && end.sublist(0, path.length).equals(path)) {
      return const [];
    }
    return [getBlockRect(shiftWithBaseOffset: shiftWithBaseOffset)];
  }

  @override
  af.Selection getSelectionInRange(Offset start, Offset end) =>
      af.Selection.single(path: node.path, startOffset: 0, endOffset: 1);

  @override
  bool get shouldCursorBlink => false;

  @override
  af.CursorStyle get cursorStyle => af.CursorStyle.cover;

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _box?.localToGlobal(offset) ?? offset;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final box = _box;
    final table = _tableKey.currentContext?.findRenderObject();
    if (box != null && table is RenderBox && table.hasSize) {
      return (shiftWithBaseOffset
              ? table.localToGlobal(Offset.zero, ancestor: box)
              : Offset.zero) &
          table.size;
    }
    return Offset.zero & (box?.size ?? Size.zero);
  }

  @override
  Rect? getCursorRectInPosition(
    af.Position position, {
    bool shiftWithBaseOffset = false,
  }) => getBlockRect(shiftWithBaseOffset: shiftWithBaseOffset);
}

class DiaryTableCellBlock extends af.BlockComponentStatefulWidget {
  const DiaryTableCellBlock({
    super.key,
    required super.node,
    required this.editorState,
  }) : super(configuration: const af.BlockComponentConfiguration());

  final af.EditorState editorState;

  @override
  State<DiaryTableCellBlock> createState() => _DiaryTableCellBlockState();
}

class _DiaryTableCellBlockState extends State<DiaryTableCellBlock>
    with af.SelectableMixin {
  af.Node get node => widget.node;

  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kDiaryTableCellPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.editorState.renderer.buildList(context, node.children),
      ),
    );
  }

  af.Position _edge({required bool start}) {
    final paragraph = start
        ? node.children.firstOrNull
        : node.children.lastOrNull;
    if (paragraph == null) return af.Position(path: node.path);
    return af.Position(
      path: paragraph.path,
      offset: start ? 0 : paragraph.delta?.length ?? 0,
    );
  }

  @override
  af.Position start() => _edge(start: true);

  @override
  af.Position end() => _edge(start: false);

  /// 点在格内留白上：交给纵向最近的那一段，让它按横向位置取词间位置。
  @override
  af.Position getPositionInOffset(Offset start) {
    af.Node? target;
    for (final child in node.children) {
      final rect = child.rect;
      if (rect == Rect.zero) continue;
      target ??= child;
      if (start.dy < rect.top) break;
      target = child;
    }
    final selectable = target?.selectable;
    if (selectable == null) return end();
    return selectable.getPositionInOffset(start);
  }

  /// 格子自己不画选区，格内的段落各画各的。
  @override
  List<Rect> getRectsInSelection(
    af.Selection selection, {
    bool shiftWithBaseOffset = false,
  }) => const [];

  @override
  af.Selection getSelectionInRange(Offset start, Offset end) =>
      af.Selection.collapsed(this.start());

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _box?.localToGlobal(offset) ?? offset;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      Offset.zero & (_box?.size ?? Size.zero);
}
