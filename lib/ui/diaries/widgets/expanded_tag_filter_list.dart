import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'tag_filter_layout.dart';

/// Expanded tag viewport: consumes the panel's cached row layout and builds
/// only visible rows, never every Material/InkWell in the full collection.
class ExpandedTagFilterList extends StatelessWidget {
  const ExpandedTagFilterList({
    super.key,
    required this.layout,
    required this.controller,
    required this.itemBuilder,
    required this.rowHeight,
    required this.spacing,
    required this.rowSpacing,
  });

  final TagFilterLayout layout;
  final ScrollController controller;
  final Widget Function(int index) itemBuilder;
  final double rowHeight;
  final double spacing;
  final double rowSpacing;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView.builder(
        key: const PageStorageKey<String>('diary_tag_filter_vertical'),
        controller: controller,
        primary: false,
        padding: EdgeInsets.zero,
        // Even a short collection owns its vertical drags. Otherwise the
        // diary scrollable can take over when this viewport has no overflow.
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        // Do not reserve a gap after the last row: with a content-sized
        // viewport that would give even a single row artificial scroll space.
        itemExtentBuilder: (index, _) =>
            rowHeight + (index == layout.rows.length - 1 ? 0 : rowSpacing),
        scrollCacheExtent: ScrollCacheExtent.pixels(
          (rowHeight + rowSpacing) * 2,
        ),
        itemCount: layout.rows.length,
        itemBuilder: (context, index) {
          final cells = layout.rows[index];
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              height: rowHeight,
              child: Row(
                children: <Widget>[
                  for (var cell = 0; cell < cells.length; cell++) ...[
                    if (cell > 0) SizedBox(width: spacing),
                    SizedBox(
                      width: cells[cell].width,
                      height: rowHeight,
                      child: itemBuilder(cells[cell].index),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
