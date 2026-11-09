import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../controllers/diary_block_selection.dart';
import '../../models/diary_thumbnail_rows.dart';

/// 选择圈的直径：与段落把手同宽，放进 16dp 的页面左边距。
const double kDiaryBlockSelectCircleSize = 16;

/// 段落选择模式的绘制：选中的块下面衬一块圆角底，左侧页边距里给每个看得
/// 见的块画选择圈。画在正文之下（不盖住文字），绘制阶段才读块的几何——
/// 滚动、移动后的那一帧布局已经更新，底与圈与文字同帧到位。
///
/// - 选中底：`secondaryContainer`、12 圆角，左右各多出 8dp（同拖动时拿起
///   的底板）；并排的几张小图整排一块底；
/// - 选择圈（直径 [kDiaryBlockSelectCircleSize]，中心在块首行的字形中线、
///   把手那一列）：选中为 `primary` 实心 + `onPrimary` 对勾；被选中的祖先
///   连带的为 `primary` 38% 实心 + 对勾；未选为 1.5dp `outline` 描边空心圈。
///   并排的小图只在第一张画一个圈。
class DiaryBlockSelectionPainter extends CustomPainter {
  DiaryBlockSelectionPainter({
    required this.selection,
    required this.root,
    required this.blockRect,
    required this.centerY,
    required this.circleX,
    required this.colors,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DiaryBlockSelection selection;
  final af.Node root;

  /// 块（含子块）在本层的矩形；不在布局里时为 null。
  final Rect? Function(af.Node node) blockRect;

  /// 块首行字形中线在本层的纵坐标。
  final double Function(af.Node node) centerY;
  final double circleX;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (!selection.isActive) return;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final fill = Paint()..color = colors.secondaryContainer;
    for (final node in selection.roots) {
      final rect = _rowRect(node);
      if (rect == null || rect.bottom < 0 || rect.top > size.height) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(rect.left - 8, rect.top, rect.right + 8, rect.bottom),
          const Radius.circular(12),
        ),
        fill,
      );
    }
    for (final unit in diaryBlockSelectionUnits(root)) {
      if (!_leadsRow(unit)) continue;
      final rect = blockRect(unit);
      if (rect == null || rect.bottom < 0 || rect.top > size.height) continue;
      final y = centerY(unit);
      _paintCircle(
        canvas,
        Offset(circleX, y),
        selected: selection.isSelected(unit),
        covered: selection.isCovered(unit),
      );
    }
    canvas.restore();
  }

  /// 并排小图里的第一张代表整排：底画在整排上，圈只画一个。
  bool _leadsRow(af.Node node) {
    final row = diaryThumbnailRowOf(node);
    return row == null || row.start == node.path.last;
  }

  Rect? _rowRect(af.Node node) {
    if (!_leadsRow(node)) return null;
    final row = diaryThumbnailRowOf(node);
    final parent = node.parent;
    if (row == null || parent == null || row.end - row.start < 2) {
      return blockRect(node);
    }
    Rect? union;
    for (var i = row.start; i < row.end; i++) {
      final rect = blockRect(parent.children[i]);
      if (rect != null) union = union?.expandToInclude(rect) ?? rect;
    }
    return union;
  }

  void _paintCircle(
    Canvas canvas,
    Offset center, {
    required bool selected,
    required bool covered,
  }) {
    const radius = kDiaryBlockSelectCircleSize / 2;
    if (!selected && !covered) {
      canvas.drawCircle(
        center,
        radius - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.outline,
      );
      return;
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = selected
            ? colors.primary
            : colors.primary.withValues(alpha: 0.38),
    );
    // 对勾：两段折线，按圈的尺寸取点。
    final check = Path()
      ..moveTo(center.dx - 3.6, center.dy + 0.2)
      ..lineTo(center.dx - 1.0, center.dy + 2.8)
      ..lineTo(center.dx + 3.8, center.dy - 2.4);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colors.onPrimary,
    );
  }

  @override
  bool shouldRepaint(DiaryBlockSelectionPainter old) =>
      old.selection != selection ||
      old.root != root ||
      old.circleX != circleX ||
      old.colors != colors;
}
