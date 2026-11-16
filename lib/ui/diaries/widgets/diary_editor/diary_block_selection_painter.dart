import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../models/diary_thumbnail_rows.dart';

/// 选中色块比正文左右各多出的宽度：伸进页边距，文字不贴着色块的边。
const double kDiaryBlockSelectionOutset = 10;

/// 一组选中块最外面的圆角，与组内相邻两块之间的小圆角、缝宽（Material 3
/// Expressive 的连接式分段：外圆内方，中间留一道缝，看得出是几块）。
const double _kOuterRadius = 14;
const double _kInnerRadius = 4;
const double _kSeam = 2;

/// 文字块的色块上沿到首行文字顶端的留白：块自己的上边距只有两三 dp，直接
/// 取块的上沿文字会贴着色块；标题上方的大留白（最多 18dp）则会让色块头重
/// 脚轻。一组的第一块改按文字顶端留这么多。
const double _kTextInset = 7;

/// 自己不画底、选中色可以衬在文字下面的块；其余的块（代码块、提示块、
/// 表格、图片、视频、录音、附件、日记链接卡片…）自带不透明的底或画面，
/// 衬在下面看不见，选中色改盖在上面。
const Set<String> _kPlainTextBlocks = {
  kDiaryBlockParagraph,
  kDiaryBlockHeading,
  kDiaryBlockBulletedList,
  kDiaryBlockNumberedList,
  kDiaryBlockTodoList,
  kDiaryBlockQuote,
  kDiaryBlockToggleList,
};

/// [node] 连同子块里有没有自带底色 / 画面的块。
bool diaryBlockPaintsOwnSurface(af.Node node) =>
    !_kPlainTextBlocks.contains(node.type) ||
    node.children.any(diaryBlockPaintsOwnSurface);

/// 段落选择模式的绘制：选中的块铺一层半透明的选中色，整行宽（从页边距里
/// 起，不随缩进收窄），上下相邻的选中块连成一组——组的外角大圆角、组内
/// 相邻两块之间留一道细缝与小圆角。没选中的块不画任何东西，正文保持原样。
///
/// 同一份数据由两个实例分两层画（[overlay]）：只含文字的块衬在正文之下，
/// 字迹保持清晰；自带底色或画面的块盖在正文之上，图片、代码块也看得出被
/// 选中。两层用同一种半透明色，落在页面底色上是同一个颜色。
///
/// 进出与增减经 [opacities] 逐块淡入淡出（由段落选择层推进），几何在绘制
/// 阶段才读——滚动、移动后的那一帧布局已经更新，色块与文字同帧到位。
class DiaryBlockSelectionPainter extends CustomPainter {
  DiaryBlockSelectionPainter({
    required this.opacities,
    required this.curve,
    required this.blockRect,
    required this.textTop,
    required this.contentLeft,
    required this.color,
    required this.overlay,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// 要画的块与它的淡入进度（0–1，线性）：选中的块，以及正在淡出的块。
  final Map<af.Node, double> opacities;

  /// 淡入进度到不透明度的曲线。
  final Curve curve;

  /// 块（含子块）在本层的矩形；不在布局里时为 null。
  final Rect? Function(af.Node node) blockRect;

  /// 文字块首行文字顶端在本层的纵坐标；没有文字的块为 null。
  final double? Function(af.Node node) textTop;

  /// 正文的左内边距（右侧对称）。
  final double contentLeft;

  /// 选中色（已带透明度）。
  final Color color;

  /// true 画自带底色的块（作为前景），false 画只含文字的块（作为背景）。
  final bool overlay;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacities.isEmpty) return;
    final rows = <(af.Node, Rect, double)>[];
    opacities.forEach((node, opacity) {
      if (opacity <= 0 || node.parent == null) return;
      final rect = _rowRect(node);
      if (rect != null) rows.add((node, rect, opacity));
    });
    if (rows.isEmpty) return;
    rows.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    final left = math.max(contentLeft - kDiaryBlockSelectionOutset, 4.0);
    final right = size.width - left;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (var i = 0; i < rows.length; i++) {
      final (node, rect, opacity) = rows[i];
      if (rect.bottom < 0 || rect.top > size.height) continue;
      if (diaryBlockPaintsOwnSurface(node) != overlay) continue;
      // 上下紧挨着另一块选中的（块与块之间没有空隙）即连成一组。
      final joinsAbove = i > 0 && (rect.top - rows[i - 1].$2.bottom).abs() < 1;
      final joinsBelow =
          i + 1 < rows.length && (rows[i + 1].$2.top - rect.bottom).abs() < 1;
      final double top;
      if (joinsAbove) {
        top = rect.top + _kSeam / 2;
      } else {
        final text = textTop(node);
        top = text == null ? rect.top : text - _kTextInset;
      }
      final bottom = joinsBelow ? rect.bottom - _kSeam / 2 : rect.bottom;
      if (bottom <= top) continue;
      final above = Radius.circular(joinsAbove ? _kInnerRadius : _kOuterRadius);
      final below = Radius.circular(joinsBelow ? _kInnerRadius : _kOuterRadius);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          left,
          top,
          right,
          bottom,
          topLeft: above,
          topRight: above,
          bottomLeft: below,
          bottomRight: below,
        ),
        Paint()
          ..color = color.withValues(alpha: color.a * curve.transform(opacity)),
      );
    }
    canvas.restore();
  }

  /// 并排的几张小图是一块：色块画在整排上，由第一张代表，其余的不画。
  Rect? _rowRect(af.Node node) {
    final row = diaryThumbnailRowOf(node);
    final parent = node.parent;
    if (row == null || parent == null || row.end - row.start < 2) {
      return blockRect(node);
    }
    if (row.start != node.path.last) return null;
    Rect? union;
    for (var i = row.start; i < row.end; i++) {
      final rect = blockRect(parent.children[i]);
      if (rect != null) union = union?.expandToInclude(rect) ?? rect;
    }
    return union;
  }

  @override
  bool shouldRepaint(DiaryBlockSelectionPainter old) =>
      old.opacities != opacities ||
      old.contentLeft != contentLeft ||
      old.color != color ||
      old.overlay != overlay;
}
