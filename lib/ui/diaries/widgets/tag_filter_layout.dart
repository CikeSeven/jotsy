import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import 'tag_filter_chip.dart';

/// Resolves chip rows from the available width and text geometry.
/// The panel height and lazy list share this result so wrapping, clipping, and
/// gesture bounds cannot disagree. Expansion frames reuse it without measuring
/// text again; only changes to the layout inputs invalidate the cache.
///
/// 宽度与选中无关：`TagFilterChip` 按粗体字与较粗的选中描边占位（两种字重
/// 叠放交叉淡入、描边粗细差补进内边距），这里同样一律按粗体 + 2dp 描边
/// 测量。选中不会让展开的多行重新换行。
class TagFilterLayoutCache {
  List<Tag>? _source;
  TextStyle? _style;
  TextScaler? _scaler;
  TextDirection? _direction;
  double _width = -1;
  double _spacing = -1;
  double _leadingWidth = 0;
  TagFilterLayout? _layout;

  TagFilterLayout resolve(
    BuildContext context, {
    required List<Tag> tags,
    required double width,
    required double spacing,
    double leadingWidth = 0,
  }) {
    if (width <= 0) {
      return const TagFilterLayout(<List<TagFilterCell>>[]);
    }
    final style = Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    if (identical(_source, tags) &&
        _style == style &&
        _scaler == scaler &&
        _direction == direction &&
        _width == width &&
        _spacing == spacing &&
        _leadingWidth == leadingWidth) {
      return _layout!;
    }

    final rows = <List<TagFilterCell>>[];
    var row = <TagFilterCell>[];
    var usedWidth = 0.0;
    final painter = TextPainter(
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    );
    try {
      // 有前置项（日记本切换胶囊）时它占第一格，下标为 -1。
      final firstIndex = leadingWidth > 0 ? -1 : 0;
      for (var index = firstIndex; index <= tags.length; index++) {
        var itemWidth = index < 0 ? leadingWidth : 26.0;
        if (index > 0) {
          final tag = tags[index - 1];
          painter.text = TextSpan(text: tag.name, style: style);
          painter.layout();
          // Match the horizontal chips: 14dp `#` dot, 6dp gap, 10dp padding
          // per side, and the (selected-width) border on both sides.
          itemWidth =
              painter.width +
              14 +
              6 +
              20 +
              TagFilterChip.selectedBorderWidth * 2;
        }
        itemWidth = math.min(itemWidth, width);
        final gap = row.isEmpty ? 0.0 : spacing;
        if (row.isNotEmpty && usedWidth + gap + itemWidth > width + 0.01) {
          rows.add(row);
          row = <TagFilterCell>[];
          usedWidth = 0;
        }
        if (row.isNotEmpty) {
          usedWidth += spacing;
        }
        row.add(TagFilterCell(index, itemWidth));
        usedWidth += itemWidth;
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    } finally {
      painter.dispose();
    }
    _source = tags;
    _style = style;
    _scaler = scaler;
    _direction = direction;
    _width = width;
    _spacing = spacing;
    _leadingWidth = leadingWidth;
    return _layout = TagFilterLayout(rows);
  }
}

class TagFilterLayout {
  const TagFilterLayout(this.rows);

  final List<List<TagFilterCell>> rows;

  double visibleRowsExtent({
    required double rowHeight,
    required double rowSpacing,
    required int maxRows,
  }) {
    final count = rows.length.clamp(1, maxRows);
    return rowHeight * count + rowSpacing * (count - 1);
  }
}

class TagFilterCell {
  const TagFilterCell(this.index, this.width);

  final int index;
  final double width;
}
