// Markdown 里的表格（AI 回答、更新说明共用）：12 圆角描边的表，表头一行
// 加一层淡底，各列按内容取宽（每格最宽 240，超出折行），整张表比可用宽度
// 宽时横向滚动——手机上不把列挤成一个字一行。
//
// 颜色只取主题语义色：描边与格线为 `outlineVariant`，表头底为很淡的
// `onSurface`（经典与玻璃背景上都看得出来，明暗自动适配）。

import 'package:flutter/material.dart';

import '../desktop_horizontal_scroll.dart';

class MarkdownTable extends StatelessWidget {
  const MarkdownTable({
    super.key,
    required this.rows,
    this.alignments = const <TextAlign>[],
  });

  /// 各行各格已经带好样式的文字；第一行是表头。各行格数可以不同，短的行
  /// 用空格子补齐。
  final List<List<InlineSpan>> rows;

  /// 各列的对齐；比列数短时其余列靠起始边。
  final List<TextAlign> alignments;

  /// 一格文字的最大宽度。
  static const double maxCellWidth = 240;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    var columns = 0;
    for (final row in rows) {
      if (row.length > columns) columns = row.length;
    }
    if (columns == 0) return const SizedBox.shrink();
    final line = BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.7),
      width: 0.8,
    );
    final table = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(horizontalInside: line, verticalInside: line),
      children: <TableRow>[
        for (final (index, row) in rows.indexed)
          TableRow(
            decoration: index == 0
                ? BoxDecoration(color: colors.onSurface.withValues(alpha: 0.06))
                : null,
            children: <Widget>[
              for (var column = 0; column < columns; column++)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxCellWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text.rich(
                      column < row.length ? row[column] : const TextSpan(),
                      textAlign: column < alignments.length
                          ? alignments[column]
                          : TextAlign.start,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
    // 表比可用宽度窄时按内容取宽、靠起始边，不拉成整行。
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: DesktopHorizontalScroll(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ),
        ),
      ),
    );
  }
}
