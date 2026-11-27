import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';

import 'diary_editor_styles.dart';

// 代码块行号列宽计算、可见行定位与绘制（供 `DiaryCodeBlockSurface` 使用）。
//
// 输入：代码正文字符串、行首偏移表、正文实际 [RenderParagraph] 与解析后的样式；
// 输出：动态行号槽几何 [DiaryCodeGutterMetrics]、可见行号列表与画笔
// [DiaryCodeLineNumbersPainter]；无文档副作用。
//
// 行号直接读取正文自身 [RenderParagraph] 的排版结果（`getOffsetForCaret`），
// 不再另起一套逐行 `TextPainter` 猜测折行与行高，从而与斜体高亮、回退字体、
// 跟随正文字体及系统字体缩放严格同步，长代码块下既不漂移也不溢出底部（#381）。

/// 默认两位数行号的右对齐基准与行号到代码正文之间的间距：1–99 行默认字号下
/// 行号槽宽为 22 + 10 = 32dp，与改版前逐像素一致。
const double kDiaryCodeMinLineNumberWidth = 22;
const double kDiaryCodeLineNumberGap = 10;

/// 代码块为代码正文保底预留的最小宽度（极窄容器里防止行号槽把正文挤没）。
const double kDiaryCodeMinContentWidth = 24;

/// 行号槽水平几何：[numberRight] 为行号右缘（相对内容区左缘），[width] 为整列宽。
typedef DiaryCodeGutterMetrics = ({double numberRight, double width});

/// 单条待绘制行号的位置与行高规则。
@visibleForTesting
typedef DiaryCodeLineNumberEntry = ({
  int lineNumber,
  double top,
  TextHeightBehavior behavior,
});

/// 段内中间行：上下均保留行距，均分方式与正文一致。
final TextHeightBehavior _kInnerLineBehavior = TextHeightBehavior(
  leadingDistribution: kDiaryTextHeightBehavior.leadingDistribution,
);

/// 每逻辑行首字符在 [text] 中的 UTF-16 偏移（至少含第 1 行的 0）。
List<int> diaryCodeLineStarts(String text) {
  final starts = <int>[0];
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      starts.add(i + 1);
    }
  }
  return starts;
}

/// 按最大行号位数、实际代码字形与缩放计算行号槽宽：两位数及以内保持 32dp，
/// 三位及以上或大字号时自动加宽，行号不会向左侵入内边距或溢出灰框。
DiaryCodeGutterMetrics diaryCodeGutterMetrics({
  required int lineCount,
  required TextStyle style,
  required TextScaler scaler,
}) {
  final digits = math.max(2, math.max(1, lineCount).toString().length);
  final sample = TextPainter(
    text: TextSpan(text: '8' * digits, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final measured = sample.width.ceilToDouble();
  sample.dispose();
  final numberRight = math.max(kDiaryCodeMinLineNumberWidth, measured);
  return (
    numberRight: numberRight,
    width: numberRight + kDiaryCodeLineNumberGap,
  );
}

/// 在可用宽度 [maxWidth] 下把行号槽宽夹到合理范围，确保正文至少保留
/// [kDiaryCodeMinContentWidth]。
DiaryCodeGutterMetrics clampDiaryCodeGutterMetrics(
  DiaryCodeGutterMetrics metrics,
  double maxWidth,
) {
  if (!maxWidth.isFinite) return metrics;
  final maxGutter = math.max(0.0, maxWidth - kDiaryCodeMinContentWidth);
  final width = math.min(metrics.width, maxGutter);
  final numberRight = math.max(0.0, width - kDiaryCodeLineNumberGap);
  return (numberRight: numberRight, width: width);
}

/// 读取 [paragraph] 已排版好的纵坐标，二分选出落在
/// `[[clipTop] - [lineMargin], [clipBottom] + [lineMargin]]` 内的逻辑行号。
@visibleForTesting
List<DiaryCodeLineNumberEntry> diaryCodeVisibleLineNumbers({
  required RenderParagraph paragraph,
  required List<int> lineStarts,
  required int textLength,
  required double clipTop,
  required double clipBottom,
  required double lineMargin,
}) {
  if (lineStarts.isEmpty) return const [];
  final minTop = clipTop - lineMargin;
  final maxTop = clipBottom + lineMargin;

  double lineTop(int index) => index == 0
      ? 0.0
      : paragraph
            .getOffsetForCaret(
              TextPosition(offset: lineStarts[index]),
              Rect.zero,
            )
            .dy;

  // 行首偏移单调递增，二分定位第一条进入可见窗口的逻辑行。
  var low = 0;
  var high = lineStarts.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (lineTop(mid) < minTop) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  final startLine = math.max(0, low - 1);
  final entries = <DiaryCodeLineNumberEntry>[];
  for (var i = startLine; i < lineStarts.length; i++) {
    final offset = lineStarts[i];
    final top = lineTop(i);
    if (top > maxTop) break;
    if (top < minTop) continue;
    // 首行无上方行距；末尾空行（text 以 \n 结尾，offset == textLength）的
    // getOffsetForCaret 已减去不含上方行距的模板基线，这两处使用
    // kDiaryTextHeightBehavior，其余中间行使用带上方行距的 _kInnerLineBehavior，
    // 行号与代码基线一致。
    entries.add((
      lineNumber: i + 1,
      top: top,
      behavior: (i == 0 || offset == textLength)
          ? kDiaryTextHeightBehavior
          : _kInnerLineBehavior,
    ));
  }
  return entries;
}

/// 代码块行号画笔：按当前画布裁切窗口只画可见行号，并严格裁切在内容区内。
class DiaryCodeLineNumbersPainter extends CustomPainter {
  const DiaryCodeLineNumbersPainter({
    required this.paragraphFinder,
    required this.text,
    required this.lineStarts,
    required this.style,
    required this.color,
    required this.numberRight,
    required this.contentWidth,
    required this.scaler,
    required this.highlightLanguage,
  });

  final RenderParagraph? Function() paragraphFinder;
  final String text;
  final List<int> lineStarts;
  final TextStyle style;
  final Color color;
  final double numberRight;
  final double contentWidth;
  final TextScaler scaler;
  final String? highlightLanguage;

  @override
  void paint(Canvas canvas, Size size) {
    final paragraph = paragraphFinder();
    if (paragraph == null ||
        !paragraph.attached ||
        !paragraph.hasSize ||
        paragraph.debugNeedsLayout ||
        lineStarts.isEmpty) {
      return;
    }
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    try {
      final clip = canvas.getLocalClipBounds();
      if (clip.isEmpty || clip.bottom < 0 || clip.top > size.height) {
        return;
      }
      final lineExtent =
          scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.5);
      final margin = math.max(lineExtent * 2, 32.0);
      final clipTop = clip.top.isFinite ? math.max(0.0, clip.top) : 0.0;
      final clipBottom = clip.bottom.isFinite
          ? math.min(size.height, clip.bottom)
          : size.height;
      final entries = diaryCodeVisibleLineNumbers(
        paragraph: paragraph,
        lineStarts: lineStarts,
        textLength: text.length,
        clipTop: clipTop,
        clipBottom: clipBottom,
        lineMargin: margin,
      );
      if (entries.isEmpty) return;
      final numberStyle = style.copyWith(color: color);
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      );
      try {
        for (final entry in entries) {
          painter
            ..textHeightBehavior = entry.behavior
            ..text = TextSpan(text: '${entry.lineNumber}', style: numberStyle)
            ..layout();
          painter.paint(canvas, Offset(numberRight - painter.width, entry.top));
        }
      } finally {
        painter.dispose();
      }
    } finally {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DiaryCodeLineNumbersPainter old) =>
      text != old.text ||
      style != old.style ||
      color != old.color ||
      numberRight != old.numberRight ||
      contentWidth != old.contentWidth ||
      scaler != old.scaler ||
      highlightLanguage != old.highlightLanguage;
}
