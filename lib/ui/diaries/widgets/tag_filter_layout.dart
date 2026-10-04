import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// Resolves chip rows from the available width and text/selection geometry.
/// The panel height and lazy list share this result so wrapping, clipping, and
/// gesture bounds cannot disagree. Expansion frames reuse it without measuring
/// text again; only changes to the layout inputs invalidate the cache.
class TagFilterLayoutCache {
  List<Tag>? _source;
  Set<int> _selected = <int>{};
  TextStyle? _style;
  TextScaler? _scaler;
  TextDirection? _direction;
  double _width = -1;
  double _spacing = -1;
  TagFilterLayout? _layout;

  TagFilterLayout resolve(
    BuildContext context, {
    required List<Tag> tags,
    required Set<int> selectedTagIds,
    required double width,
    required double spacing,
  }) {
    if (width <= 0) {
      return const TagFilterLayout(<List<TagFilterCell>>[]);
    }
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.w700
          : FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    if (identical(_source, tags) &&
        setEquals(_selected, selectedTagIds) &&
        _style == style &&
        _scaler == scaler &&
        _direction == direction &&
        _width == width &&
        _spacing == spacing) {
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
      for (var index = 0; index <= tags.length; index++) {
        var itemWidth = 26.0;
        if (index > 0) {
          final tag = tags[index - 1];
          painter.text = TextSpan(text: tag.name, style: style);
          painter.layout();
          final border = selectedTagIds.contains(tag.id) ? 2.0 : 1.2;
          // Match the horizontal chips: 12dp dot, 8dp gap, 10dp padding
          // per side, and the selected/unselected border on both sides.
          itemWidth = painter.width + 12 + 8 + 20 + border * 2;
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
    _selected = Set<int>.of(selectedTagIds);
    _style = style;
    _scaler = scaler;
    _direction = direction;
    _width = width;
    _spacing = spacing;
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
