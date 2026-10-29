import 'package:flutter/foundation.dart';

import '../../../app/theme/app_spacing.dart';

/// 首页日记本头部子本网格（`NotebookChildrenGrid`）的排布：按卡片里实际
/// 可用的宽度定列数，子本放不进 [collapsedRows] 行时折叠。
///
/// - 列数：每格至少 [minCellWidth]，至少 2 列（窄手机上名称宁可省略，也不
///   退回一列长条）、至多 [maxColumns] 列；
/// - 折叠：子本多于 `列数 × collapsedRows` 时，收起状态只列前
///   `列数 × collapsedRows − 1` 本，最后一格留给“还有 N 本”，网格高度恰好
///   两行；展开时列出全部，末尾一格为“收起”；放得下时全部列出、没有这一格。
@immutable
class NotebookChildrenLayout {
  const NotebookChildrenLayout._({
    required this.columns,
    required this.cellWidth,
    required this.total,
    required this.shown,
    required this.collapsible,
  });

  /// [width] 为网格可用宽度，[count] 为直接子本数，[expanded] 为用户是否
  /// 展开了这本的全部子本。
  factory NotebookChildrenLayout.of({
    required double width,
    required int count,
    required bool expanded,
  }) {
    final columns = columnsFor(width);
    final capacity = columns * collapsedRows;
    final collapsible = count > capacity;
    return NotebookChildrenLayout._(
      columns: columns,
      cellWidth: (width - gap * (columns - 1)) / columns,
      total: count,
      shown: collapsible && !expanded ? capacity - 1 : count,
      collapsible: collapsible,
    );
  }

  static const double minCellWidth = 160;
  static const double gap = AppSpacing.s;
  static const int collapsedRows = 2;
  static const int maxColumns = 6;

  static int columnsFor(double width) {
    if (!width.isFinite) return 2;
    return ((width + gap) / (minCellWidth + gap)).floor().clamp(2, maxColumns);
  }

  final int columns;

  /// 每格的宽度（“还有 N 本”格按它决定叠放几张小封面）。
  final double cellWidth;
  final int total;

  /// 列出的子本格数（不含“还有 N 本 / 收起”格）。
  final int shown;

  /// 是否有“还有 N 本 / 收起”这一格。
  final bool collapsible;

  /// 收起时没列出的子本数。
  int get hidden => total - shown;
}
