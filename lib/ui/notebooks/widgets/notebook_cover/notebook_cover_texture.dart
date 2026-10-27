import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

/// 封面底色上的纸张纹理（圆点 / 横线 / 方格 / 斜纹）。
///
/// 只画在露出底色的区域，不盖在封面图上：调用方把它放在底色那一块的后面
/// （`CustomPaint.painter`），或作为整张封面的底层。颜色由调用方给出——
/// 封面上是强调色的 onContainer，头部卡片上更淡；每种纹理再乘一个透明度
/// 系数，让点、线、格看起来一样“轻”（点小、需要更实一些）。
///
/// [scale] 缩放间距与线宽：小封面与版式预览按尺寸缩小，纹理的疏密看起来
/// 与完整封面一致。全部为实色描画，没有任何渐变。
class NotebookCoverTexturePainter extends CustomPainter {
  const NotebookCoverTexturePainter({
    required this.texture,
    required this.color,
    this.scale = 1,
  });

  final NotebookCoverTexture texture;

  /// 基础颜色（不透明度由调用方先乘好），各纹理在此基础上再调轻重。
  final Color color;
  final double scale;

  /// 各纹理相对 [color] 的透明度系数。
  static double weightOf(NotebookCoverTexture texture) => switch (texture) {
    NotebookCoverTexture.none => 0,
    NotebookCoverTexture.dots => 1,
    NotebookCoverTexture.lines => 0.75,
    NotebookCoverTexture.grid => 0.6,
    NotebookCoverTexture.diagonal => 0.7,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (texture == NotebookCoverTexture.none || size.isEmpty) return;
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * weightOf(texture))
      ..isAntiAlias = true;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (texture) {
      case NotebookCoverTexture.none:
        break;
      case NotebookCoverTexture.dots:
        _dots(canvas, size, paint);
      case NotebookCoverTexture.lines:
        _lines(canvas, size, paint);
      case NotebookCoverTexture.grid:
        _grid(canvas, size, paint);
      case NotebookCoverTexture.diagonal:
        _diagonal(canvas, size, paint);
    }
    canvas.restore();
  }

  /// 错位的圆点（相邻两行错开半格），比正方阵更像点阵纸。
  void _dots(Canvas canvas, Size size, Paint paint) {
    final step = 10 * scale;
    final radius = 1.1 * scale;
    var row = 0;
    for (var y = step / 2; y < size.height + step; y += step, row++) {
      final shift = row.isOdd ? step / 2 : 0;
      for (var x = step / 2 + shift; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  /// 横格本的横线。
  void _lines(Canvas canvas, Size size, Paint paint) {
    final step = 9 * scale;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.9 * scale);
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// 方格本的方格。
  void _grid(Canvas canvas, Size size, Paint paint) {
    final step = 12 * scale;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, 0.7 * scale);
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  /// 45° 斜纹：从左下到右上的平行线，覆盖整个矩形。
  void _diagonal(Canvas canvas, Size size, Paint paint) {
    final step = 9 * scale;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.9 * scale);
    final reach = size.width + size.height;
    for (var d = step; d < reach; d += step) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(NotebookCoverTexturePainter oldDelegate) =>
      oldDelegate.texture != texture ||
      oldDelegate.color != color ||
      oldDelegate.scale != scale;
}

/// 封面上的纹理颜色：强调色 onContainer 的低透明度。
Color notebookCoverTextureColor(Color onContainer) =>
    onContainer.withValues(alpha: 0.22);

/// 铺满父级的纹理层（放在封面 `Stack` 的最底层）；没有纹理时不占任何绘制。
class NotebookCoverTextureLayer extends StatelessWidget {
  const NotebookCoverTextureLayer({
    super.key,
    required this.texture,
    required this.color,
    this.scale = 1,
  });

  final NotebookCoverTexture texture;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (texture == NotebookCoverTexture.none) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: NotebookCoverTexturePainter(
        texture: texture,
        color: color,
        scale: scale,
      ),
    );
  }
}

/// 在 [child] 背后画纹理（尺寸取 [child]）；没有纹理时原样返回 [child]，
/// 默认样式的组件树与改版前完全一致。
Widget notebookCoverTextured({
  required NotebookCoverTexture texture,
  required Color color,
  required Widget child,
  double scale = 1,
}) {
  if (texture == NotebookCoverTexture.none) return child;
  return CustomPaint(
    painter: NotebookCoverTexturePainter(
      texture: texture,
      color: color,
      scale: scale,
    ),
    child: child,
  );
}
