import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'storage_usage_bar.dart';

/// 环形占比图：各段按字节比例从 12 点方向顺时针首尾相接，段间留一点缝，
/// 中间放 [center]（总数等）。底下先画一整圈轨道。
///
/// [reveal]（0–1，由外层 `ExploreReveal` 驱动）为首次出现的生长进度：整圈
/// 从 12 点顺时针画出来，与条形图同一节奏。占比极小的段至少画
/// [minSweep]（弧度），在环上看得见。只用语义色，不用渐变。
class StorageRingChart extends StatelessWidget {
  const StorageRingChart({
    super.key,
    required this.segments,
    required this.track,
    required this.center,
    this.size = 132,
    this.thickness = 14,
    this.reveal = 1,
    this.minSweep = 0.04,
  });

  final List<StorageBarSegment> segments;
  final Color track;
  final Widget center;
  final double size;
  final double thickness;
  final double reveal;
  final double minSweep;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          segments: segments,
          track: track,
          thickness: thickness,
          reveal: reveal.clamp(0, 1),
          minSweep: minSweep,
        ),
        child: Padding(
          padding: EdgeInsets.all(thickness + 6),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.segments,
    required this.track,
    required this.thickness,
    required this.reveal,
    required this.minSweep,
  });

  final List<StorageBarSegment> segments;
  final Color track;
  final double thickness;
  final double reveal;
  final double minSweep;

  /// 段间缝（弧度）。
  static const double _gap = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - thickness) / 2,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = track,
    );
    final visible = [
      for (final segment in segments)
        if (segment.bytes > 0) segment,
    ];
    final total = visible.fold<int>(0, (sum, s) => sum + s.bytes);
    if (total <= 0 || reveal <= 0) return;

    // 平头分段、段间留 [_gap]：类别多时小类别是一道细弧，不会挤成一串
    // 圆点。每段至少 [minSweep]，否则在环上看不见。
    final single = visible.length == 1;
    final gap = single ? 0.0 : _gap;
    final floor = single ? 0.0 : minSweep;
    final available = math.pi * 2 - gap * visible.length;
    if (available <= 0) return;
    final sweeps = [
      for (final segment in visible) available * segment.bytes / total,
    ];
    var deficit = 0.0;
    var spare = 0.0;
    for (var i = 0; i < sweeps.length; i++) {
      if (sweeps[i] < floor) {
        deficit += floor - sweeps[i];
        sweeps[i] = floor;
      } else {
        spare += sweeps[i] - floor;
      }
    }
    if (deficit > 0 && spare > 0) {
      final ratio = math.min(1.0, deficit / spare);
      for (var i = 0; i < sweeps.length; i++) {
        if (sweeps[i] > floor) sweeps[i] -= (sweeps[i] - floor) * ratio;
      }
    }

    final limit = math.pi * 2 * reveal;
    var start = 0.0;
    for (var i = 0; i < visible.length && start < limit; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + start,
        math.min(sweeps[i], limit - start),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..color = visible[i].color,
      );
      start += sweeps[i] + gap;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.reveal != reveal ||
      old.track != track ||
      old.thickness != thickness ||
      old.segments.length != segments.length ||
      !_same(old.segments, segments);

  static bool _same(List<StorageBarSegment> a, List<StorageBarSegment> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].bytes != b[i].bytes || a[i].color != b[i].color) return false;
    }
    return true;
  }
}
