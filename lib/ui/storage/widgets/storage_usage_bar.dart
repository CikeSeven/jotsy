import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 一段占用：颜色与字节数。
class StorageBarSegment {
  const StorageBarSegment({required this.color, required this.bytes});

  final Color color;
  final int bytes;
}

/// 分段占用条：各类别按字节比例首尾相接，两端全圆、段间 2dp 缝（DESIGN.md
/// §5.25 的条形规格：6–12dp、全圆角、轨道取 `surfaceContainerHighest`）。
///
/// [reveal]（0–1）为首次出现的生长进度，由外层 `ExploreReveal` 驱动：从左往
/// 右依次铺满，与探索页图表同一种入场。占比极小的段至少画 [minSegment]
/// 宽，否则在条上看不见、只能在图例里找到。
class StorageUsageBar extends StatelessWidget {
  const StorageUsageBar({
    super.key,
    required this.segments,
    required this.track,
    this.reveal = 1,
    this.height = 12,
    this.minSegment = 3,
    this.totalBytes,
  });

  final List<StorageBarSegment> segments;

  /// 整条代表的总量；比各段之和大时，多出的部分留作轨道（如手机存储条里
  /// 的可用空间）。为 null 时各段铺满整条。
  final int? totalBytes;
  final Color track;
  final double reveal;
  final double height;
  final double minSegment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _StorageUsageBarPainter(
          segments: segments,
          track: track,
          reveal: reveal.clamp(0, 1),
          minSegment: minSegment,
          totalBytes: totalBytes,
        ),
      ),
    );
  }
}

class _StorageUsageBarPainter extends CustomPainter {
  _StorageUsageBarPainter({
    required this.segments,
    required this.track,
    required this.reveal,
    required this.minSegment,
    required this.totalBytes,
  });

  static const double _gap = 2;

  final List<StorageBarSegment> segments;
  final Color track;
  final double reveal;
  final double minSegment;
  final int? totalBytes;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final bounds = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(bounds, Paint()..color = track);
    final visible = [
      for (final segment in segments)
        if (segment.bytes > 0) segment,
    ];
    final sum = visible.fold<int>(0, (total, s) => total + s.bytes);
    if (sum <= 0 || reveal <= 0) return;
    // 留给轨道的剩余部分不画，但同样参与分宽（前面也留一道缝）。
    final rest = (totalBytes ?? 0) > sum ? totalBytes! - sum : 0;
    final total = sum + rest;

    // 先按比例分宽，再把太窄的段补到 minSegment、从宽段里按比例扣回。
    final available = size.width - _gap * (visible.length - (rest > 0 ? 0 : 1));
    if (available <= 0) return;
    final widths = [
      for (final segment in visible) available * segment.bytes / total,
    ];
    var deficit = 0.0;
    // 剩余部分也能让出宽度给太窄的段。
    var spare = available * rest / total;
    for (var i = 0; i < widths.length; i++) {
      if (widths[i] < minSegment) {
        deficit += minSegment - widths[i];
        widths[i] = minSegment;
      } else {
        spare += widths[i] - minSegment;
      }
    }
    if (deficit > 0 && spare > 0) {
      final ratio = math.min(1.0, deficit / spare);
      for (var i = 0; i < widths.length; i++) {
        if (widths[i] > minSegment) {
          widths[i] -= (widths[i] - minSegment) * ratio;
        }
      }
    }

    canvas.save();
    canvas.clipRRect(bounds);
    final limit = size.width * reveal;
    var x = 0.0;
    for (var i = 0; i < visible.length && x < limit; i++) {
      final right = math.min(x + widths[i], limit);
      canvas.drawRect(
        Rect.fromLTRB(x, 0, right, size.height),
        Paint()..color = visible[i].color,
      );
      x += widths[i] + _gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StorageUsageBarPainter old) =>
      old.reveal != reveal ||
      old.track != track ||
      old.minSegment != minSegment ||
      old.totalBytes != totalBytes ||
      !_sameSegments(old.segments, segments);

  static bool _sameSegments(
    List<StorageBarSegment> a,
    List<StorageBarSegment> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].bytes != b[i].bytes || a[i].color != b[i].color) return false;
    }
    return true;
  }
}
