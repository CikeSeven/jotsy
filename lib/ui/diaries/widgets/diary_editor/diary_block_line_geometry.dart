import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import 'diary_block_marker_metrics.dart';

/// 块在页边距里那一列的几何：段落把手与段落选择圈都画在块首行的字形
/// 中线上、水平固定在页面左边距里。只读上一帧的布局，不改文档。
///
/// 按块样式与缩放缓存首行字形中心（到文字顶端的距离）：把手与选择圈可见
/// 期间每帧都要核对位置，样式只在换块或改排版时才变。
class DiaryBlockLineGeometry {
  final Map<(TextStyle, TextScaler), double> _glyphCenters = {};

  /// 把手 / 选择圈中线的全局纵坐标：文字块为首行字形中心，媒体等没有文字
  /// 的块为块顶下方 20dp（矮于 40dp 时取块的中线）。
  double centerY(af.Node node) {
    final rect = node.rect;
    return _firstLineCenter(node) ?? rect.top + math.min(rect.height / 2, 20);
  }

  /// 文字块首行字形中心的全局纵坐标：基线上方 0.37em，与列表圆点、待办框
  /// 同一口径（见 [DiaryMarkerMetrics]）。媒体等没有文字的块返回 null。
  ///
  /// 为什么不取首行光标矩形的中线：正文首行上方的半个行距被裁掉、下方的
  /// 保留（`kDiaryTextHeightBehavior`），多行段落的首行光标比文字多出下方
  /// 半个行距，中线偏低，行距越大偏得越多。这里改读块里的占位文字段落——
  /// 它带着与正文相同的块样式（标题字号、代码字体）与缩放，叠在正文同一
  /// 位置，首行顶端就是文字顶端——按它的样式量出字形中心。
  double? _firstLineCenter(af.Node node) {
    if (node.delta == null) return null;
    final paragraph = _placeholderParagraph(node);
    final style = paragraph?.text.style;
    if (paragraph == null || style == null || !paragraph.hasSize) return null;
    final scaler = paragraph.textScaler;
    final center = _glyphCenters.putIfAbsent((style, scaler), () {
      if (_glyphCenters.length >= 16) _glyphCenters.clear();
      return DiaryMarkerMetrics.measure(style, scaler).glyphCenter;
    });
    return paragraph.localToGlobal(Offset(0, center)).dy;
  }

  /// 块自身文字的占位段落：块里第一个 [af.AppFlowyRichText]（子块排在自身
  /// 文字之后）中的第一个 [RichText]——上游先画占位、再画正文。
  static RenderParagraph? _placeholderParagraph(af.Node node) {
    final root = node.key.currentContext;
    if (root is! Element) return null;
    Element? richText;
    void findRichText(Element element) {
      if (richText != null) return;
      if (element.widget is af.AppFlowyRichText) {
        richText = element;
      } else {
        element.visitChildElements(findRichText);
      }
    }

    RenderParagraph? paragraph;
    void findParagraph(Element element) {
      if (paragraph != null) return;
      final object = element.renderObject;
      if (element.widget is RichText && object is RenderParagraph) {
        paragraph = object;
      } else {
        element.visitChildElements(findParagraph);
      }
    }

    findRichText(root);
    richText?.visitChildElements(findParagraph);
    return paragraph;
  }

  /// 块（含子块）在 [box] 里的矩形；块不在布局里时为 null。左边界按结构
  /// 算：顶层块为页面左边距 [contentLeft]，子块为父块左边界加缩进
  /// [childIndent]。代码块等组件的节点几何只覆盖内部文字区（行号右侧），
  /// 直接取它的 left 会把底板压进块里面。
  static Rect? blockRect(
    af.Node node,
    RenderBox box, {
    required double contentLeft,
    required double childIndent,
  }) {
    final global = node.rect;
    if (global == Rect.zero || !box.hasSize) return null;
    final local = box.globalToLocal(global.topLeft) & global.size;
    final parent = node.parent;
    final double structural;
    if (parent == null || parent.type == af.PageBlockKeys.type) {
      structural = contentLeft;
    } else {
      final parentRect = parent.rect;
      structural = parentRect == Rect.zero
          ? local.left
          : box.globalToLocal(parentRect.topLeft).dx + childIndent;
    }
    return Rect.fromLTRB(
      math.min(local.left, structural),
      local.top,
      local.right,
      local.bottom,
    );
  }

  /// 把手与选择圈中心的横坐标（[box] 的局部坐标）：固定在页面左边距里，
  /// 不随缩进右移。
  static double columnCenterX(double contentLeft, double width) =>
      math.max(contentLeft - width / 2, 8.0);
}
