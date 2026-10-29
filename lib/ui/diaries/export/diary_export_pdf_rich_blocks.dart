import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_callout_tone.dart';
import 'diary_export_blocks.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 正文里的标注、折叠列表与表格（[buildDiaryPdfBody] 调用）。
///
/// - 输入：共用块模型里的一块（颜色已在 prepareBody 压平到白纸上）与已经
///   排好的行内文字；
/// - 输出：可交给 `MultiPage` 的组件，不做 IO、不读设置；
/// - 只画矢量形状与文字，不依赖字体里的符号字形：内置的 HarmonyOS Sans SC
///   没有 emoji，也没有 ▸ 这类几何符号，写成文字会印成方框。

/// 标注：圆角浅色底，左侧一条强调色竖条，颜色只取 [DiaryCalloutTone] 的
/// 纸面配色（导出纸面恒为白底）。
///
/// 不画标注的图标：图标是 emoji，内置字体没有 emoji 字形（会印成方框并
/// 在排版时报缺字），底色与色条已经足以把它和正文区分开。
pw.Widget buildDiaryPdfCallout(ExportBlock block, pw.Widget text) {
  final tone = DiaryCalloutTone.fromId(block.calloutTone);
  // 竖条用 Positioned 贴住左缘、上下撑满，再整体按圆角裁切：pdf 库的
  // 圆角边框只支持四边相同，不能直接画“只有左边”的粗边。
  return pw.ClipRRect(
    horizontalRadius: 6,
    verticalRadius: 6,
    child: pw.Container(
      color: PdfColor.fromInt(tone.paperBackground.toARGB32()),
      child: pw.Stack(
        children: <pw.Widget>[
          // 与编辑器一致，标注铺满整行宽度，不随文字长短收缩。
          pw.SizedBox(
            width: double.infinity,
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(13, 6, 10, 6),
              child: text,
            ),
          ),
          pw.Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(
              width: 3,
              color: PdfColor.fromInt(tone.paperAccent.toARGB32()),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 折叠列表的标题行：行首一个朝下的小三角（导出一律展开，子块照常以
/// 更深的缩进跟在后面）。三角是矢量路径而不是 ▸ / ▾ 字符：内置字体没有
/// 这些字形。[fontSize] 为标题行的字号，三角按它缩放并对齐第一行文字。
pw.Widget buildDiaryPdfToggle(
  pw.Widget text, {
  required double fontSize,
  required pw.TextDirection textDirection,
}) {
  final side = fontSize * 0.5;
  return pw.Directionality(
    textDirection: textDirection,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Padding(
          // 三角的中心大致落在第一行文字的 x 字高中线上。
          padding: pw.EdgeInsetsDirectional.only(
            top: fontSize * 0.42,
            end: fontSize * 0.45,
          ),
          child: pw.CustomPaint(
            size: PdfPoint(side, side * 0.8),
            // pdf 画布原点在左下：上边两个角在 y = 高，尖朝下在 y = 0。
            painter: (PdfGraphics canvas, PdfPoint size) => canvas
              ..setFillColor(PdfColors.grey700)
              ..moveTo(0, size.y)
              ..lineTo(size.x, size.y)
              ..lineTo(size.x / 2, 0)
              ..closePath()
              ..fillPath(),
          ),
        ),
        pw.Expanded(child: text),
      ],
    ),
  );
}

/// 表格：每行一个单行的 [pw.Table]，列宽等分、0.5pt 中性灰细线、格子留
/// 内边距；首行为表头时加粗并垫浅灰底。
///
/// 为什么每行单独一张表：正文的每个组件都要套 [DiaryPdfTextEffects.wrap]
/// 才能画出补偿的粗斜体，套上之后 `MultiPage` 就不能在组件内部分页；拆成
/// 一行一个组件，长表格照样能在行与行之间换页。各行列宽相同、竖线对齐；
/// 只有第一行画上边线，其余行与上一行共用分隔线，不会叠成粗线。格里的
/// 文字经共用的行内渲染（颜色、链接、字号、上下标），段与段之间换行。
List<pw.Widget> buildDiaryPdfTableRows(
  ExportBlock block, {
  required pw.TextStyle base,
  required DiaryPdfTextEffects effects,
  required pw.TextDirection textDirection,
}) {
  final rows = block.tableRows;
  if (rows.isEmpty || rows.first.isEmpty) return const <pw.Widget>[];
  const line = pw.BorderSide(color: PdfColors.grey500, width: 0.5);
  final cols = rows.first.length;
  final bold = base.copyWith(fontWeight: pw.FontWeight.bold);
  final fontSize = base.fontSize ?? 12;
  return <pw.Widget>[
    for (final (index, cells) in rows.indexed)
      pw.Table(
        columnWidths: <int, pw.TableColumnWidth>{
          for (var col = 0; col < cols; col++) col: const pw.FlexColumnWidth(),
        },
        border: pw.TableBorder(
          top: index == 0 ? line : pw.BorderSide.none,
          left: line,
          right: line,
          bottom: line,
          verticalInside: line,
        ),
        children: <pw.TableRow>[
          pw.TableRow(
            decoration: block.tableHeaderRow && index == 0
                ? const pw.BoxDecoration(color: PdfColors.grey200)
                : null,
            children: <pw.Widget>[
              for (final cell in cells)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: pw.RichText(
                    textDirection: textDirection,
                    softWrap: true,
                    overflow: pw.TextOverflow.span,
                    text: pw.TextSpan(
                      children: <pw.InlineSpan>[
                        for (final run in cell)
                          buildDiaryPdfInline(
                            run,
                            block.tableHeaderRow && index == 0 ? bold : base,
                            effects: effects,
                            bodyFontSize: fontSize,
                          ),
                        // 空格子也要撑出一行高，整行不会塌下去。
                        if (cell.isEmpty) pw.TextSpan(text: ' ', style: base),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
  ];
}
