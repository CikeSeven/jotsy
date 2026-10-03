import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/database/app_database.dart';

/// Expanded tag viewport: packs natural chip widths once, then builds only
/// visible rows. Scroll/expansion frames reuse the cached layout and never
/// create every Material/InkWell in the full tag collection.
class ExpandedTagFilterList extends StatefulWidget {
  const ExpandedTagFilterList({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.controller,
    required this.itemBuilder,
    required this.rowHeight,
    required this.spacing,
    required this.rowSpacing,
  });

  final List<Tag> tags;
  final Set<int> selectedTagIds;
  final ScrollController controller;
  final Widget Function(int index) itemBuilder;
  final double rowHeight;
  final double spacing;
  final double rowSpacing;

  @override
  State<ExpandedTagFilterList> createState() => _ExpandedTagFilterListState();
}

class _ExpandedTagFilterListState extends State<ExpandedTagFilterList> {
  List<Tag>? _source;
  Set<int> _selected = <int>{};
  TextStyle? _style;
  TextScaler? _scaler;
  TextDirection? _direction;
  double _width = -1;
  List<List<_TagCell>> _rows = const [];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.w700
          : FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        _resolveRows(constraints.maxWidth, style, scaler, direction);
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: ListView.builder(
            key: const PageStorageKey<String>('diary_tag_filter_vertical'),
            controller: widget.controller,
            primary: false,
            padding: EdgeInsets.zero,
            // Even a short collection owns its vertical drags. Otherwise the
            // diary scrollable can take over when this viewport has no overflow.
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            itemExtent: widget.rowHeight + widget.rowSpacing,
            scrollCacheExtent: ScrollCacheExtent.pixels(
              (widget.rowHeight + widget.rowSpacing) * 2,
            ),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final cells = _rows[index];
              return Align(
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  height: widget.rowHeight,
                  child: Row(
                    children: <Widget>[
                      for (var cell = 0; cell < cells.length; cell++) ...[
                        if (cell > 0) SizedBox(width: widget.spacing),
                        SizedBox(
                          width: cells[cell].width,
                          height: widget.rowHeight,
                          child: widget.itemBuilder(cells[cell].index),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _resolveRows(
    double width,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    if (identical(_source, widget.tags) &&
        setEquals(_selected, widget.selectedTagIds) &&
        _style == style &&
        _scaler == scaler &&
        _direction == direction &&
        _width == width) {
      return;
    }
    final rows = <List<_TagCell>>[];
    var row = <_TagCell>[];
    var usedWidth = 0.0;
    final painter = TextPainter(
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    );
    try {
      for (var index = 0; index <= widget.tags.length; index++) {
        var itemWidth = 26.0;
        if (index > 0) {
          final tag = widget.tags[index - 1];
          painter.text = TextSpan(text: tag.name, style: style);
          painter.layout();
          final border = widget.selectedTagIds.contains(tag.id) ? 2.0 : 1.2;
          // Same geometry as DiaryTagFilterBar's horizontal chips: 12dp dot,
          // 8dp gap, 10dp padding per side, and the selected/unselected border.
          itemWidth = painter.width + 12 + 8 + 20 + border * 2;
        }
        itemWidth = math.min(itemWidth, width);
        final gap = row.isEmpty ? 0.0 : widget.spacing;
        if (row.isNotEmpty && usedWidth + gap + itemWidth > width + 0.01) {
          rows.add(row);
          row = <_TagCell>[];
          usedWidth = 0;
        }
        if (row.isNotEmpty) {
          usedWidth += widget.spacing;
        }
        row.add(_TagCell(index, itemWidth));
        usedWidth += itemWidth;
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    } finally {
      painter.dispose();
    }
    _source = widget.tags;
    _selected = Set<int>.of(widget.selectedTagIds);
    _style = style;
    _scaler = scaler;
    _direction = direction;
    _width = width;
    _rows = rows;
  }
}

class _TagCell {
  const _TagCell(this.index, this.width);

  final int index;
  final double width;
}
