import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
import 'diary_export_pdf_line_break.dart';

/// 列表项：行首的标记单独占一列，文字折行后与第一行的文字对齐（与应用
/// 一致，不会折到标记下面）。列宽、内边距按编辑器的标记列
/// （`DiaryMarkerMetrics`，以 16 为一个字的设计稿）换算成字号的倍数；
/// 序号与项目符号写成文字（中文序号经 [diaryPdfTextSpan]），待办画成矢量
/// 方框（内置字体没有 ☑ / ☐ 字形）。
///
/// [continued] 为软换行后的续行（见 `buildDiaryPdfBody`）：标记只占位不画
/// （[DiaryPdfPlaceholder]），文字仍与第一行对齐。
pw.Widget buildDiaryPdfListItem(
  ExportBlock block,
  pw.Widget text, {
  required pw.TextStyle base,
  required pw.TextDirection textDirection,
  bool continued = false,
}) {
  final em = base.fontSize ?? 12;
  final glyph = switch (block.kind) {
    ExportBlockKind.checked || ExportBlockKind.unchecked => pw.Padding(
      // 方框的中心大致落在第一行文字的中线上。
      padding: pw.EdgeInsets.only(top: em * 0.22),
      child: _checkbox(
        em * 0.85,
        checked: block.kind == ExportBlockKind.checked,
      ),
    ),
    _ => pw.RichText(
      maxLines: 1,
      textDirection: textDirection,
      text: diaryPdfTextSpan(block.listMarker, style: base),
    ),
  };
  final marker = continued ? DiaryPdfPlaceholder(glyph) : glyph;
  return pw.Directionality(
    textDirection: textDirection,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.ConstrainedBox(
          constraints: pw.BoxConstraints(minWidth: em * 28 / 16),
          child: pw.Padding(
            padding: pw.EdgeInsetsDirectional.only(
              start: em * 2 / 16,
              end: em * 6 / 16,
            ),
            // 标记按自身大小贴着列的起始侧，不被列宽拉伸（方框要保持方形）。
            child: pw.Align(
              alignment: textDirection == pw.TextDirection.rtl
                  ? pw.Alignment.topRight
                  : pw.Alignment.topLeft,
              widthFactor: 1,
              heightFactor: 1,
              child: marker,
            ),
          ),
        ),
        pw.Expanded(child: text),
      ],
    ),
  );
}

/// 只占位、不绘制的组件：按 [child] 排版、占同样大的地方，但什么都不画。
///
/// 软换行后的续行用它在行首留出与第一行标记、图标同样的宽度：序号宽窄
/// 不一（`10.` 比 `9.` 宽，标记列随之变宽），留一个固定宽度的空列会对不齐；
/// 也不能画成透明文字——复制或朗读 PDF 时会多读出一遍序号。
///
/// [pw.SingleChildWidget] 排版时照常排子组件、取它的尺寸，绘制只画子类经
/// `paintChild` 交出的子组件；这里不调用它，子组件就不会画出来。
class DiaryPdfPlaceholder extends pw.SingleChildWidget {
  DiaryPdfPlaceholder(pw.Widget child) : super(child: child);
}

/// 待办的方框：圆角描边；已完成时填成深灰并画白色的勾。pdf 画布原点在
/// 左下。
pw.Widget _checkbox(double side, {required bool checked}) => pw.CustomPaint(
  size: PdfPoint(side, side),
  painter: (PdfGraphics canvas, PdfPoint size) {
    final stroke = size.x * 0.09;
    final radius = size.x * 0.22;
    canvas.drawRRect(
      stroke / 2,
      stroke / 2,
      size.x - stroke,
      size.y - stroke,
      radius,
      radius,
    );
    if (!checked) {
      canvas
        ..setStrokeColor(PdfColors.grey600)
        ..setLineWidth(stroke)
        ..strokePath();
      return;
    }
    canvas
      ..setFillColor(PdfColors.grey700)
      ..fillPath()
      ..setStrokeColor(PdfColors.white)
      ..setLineWidth(size.x * 0.12)
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round)
      ..moveTo(size.x * 0.26, size.y * 0.52)
      ..lineTo(size.x * 0.43, size.y * 0.33)
      ..lineTo(size.x * 0.75, size.y * 0.70)
      ..strokePath();
  },
);
