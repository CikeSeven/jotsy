import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_thumbnail_rows.dart';
import 'diary_export_blocks.dart';
import 'diary_export_image_box.dart';
import 'diary_export_media.dart';
import 'diary_export_pdf_emoji.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_line_break.dart';
import 'diary_export_pdf_list_item.dart' show DiaryPdfPlaceholder;
import 'diary_export_pdf_text_effects.dart';

/// PDF 正文里的图片（含并排的一排小图）、折叠列表与表格（[buildDiaryPdfBody]
/// 调用；标注见 `diary_export_pdf_callout.dart`）。
///
/// - 输入：共用块模型里的一块（颜色已在 prepareBody 压平到白纸上）与已经
///   排好的行内文字；
/// - 输出：可交给 `MultiPage` 的组件，不做 IO、不读设置；
/// - 只画矢量形状与文字，不依赖字体里的符号字形：内置的 HarmonyOS Sans SC
///   没有 ▸ 这类几何符号，写成文字会印成方框；表格里的 emoji 经
///   [DiaryPdfEmoji] 画成图片。

/// 正文图片：尺寸、小图与对齐与应用一致（口径见 [ExportImageBox]，逻辑
/// 像素按 96 DPI 折成磅）。原图比版心宽时按比例缩到版心宽，比一页的图片
/// 上限（560pt）高时缩到这个高度，从不放大；跟着所在层级缩进，按块的对齐
/// 靠起始侧、居中或靠右。读不出尺寸的图片返回 null（准备正文时已经去掉）。
pw.Widget? buildDiaryPdfImage(
  ExportBlock block,
  Uint8List bytes, {
  required pw.TextDirection textDirection,
}) {
  final picture = _pdfPicture(block, bytes);
  if (picture == null) return null;
  return _placePdfImage(block, picture, textDirection: textDirection);
}

/// 并排的一排小图（[exportThumbnailRowEnd] 取出的同一排，每项是块与它的
/// 图片字节）：与应用的 `DiaryThumbnailRowView` 一样从起始侧排起、格间
/// [kDiaryThumbnailRowGap]，整排按第一张的对齐与上下留白摆放；每张仍是
/// [buildDiaryPdfImage] 的方形 cover 裁切。读不出尺寸的跳过，一张都画不出
/// 时返回 null。
///
/// 一排是一个不可拆分的组件：三张小图同高（90pt），换页时整排一起挪到下
/// 一页，不会上下页各一半。
pw.Widget? buildDiaryPdfThumbnailRow(
  List<(ExportBlock, Uint8List)> images, {
  required pw.TextDirection textDirection,
}) {
  final pictures = <pw.Widget>[
    for (final (block, bytes) in images) ?_pdfPicture(block, bytes),
  ];
  if (pictures.isEmpty) return null;
  return _placePdfImage(
    images.first.$1,
    pictures.length == 1
        ? pictures.single
        : pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              for (final (index, picture) in pictures.indexed) ...<pw.Widget>[
                if (index > 0)
                  pw.SizedBox(width: kDiaryThumbnailRowGap * diaryPdfPt),
                picture,
              ],
            ],
          ),
    textDirection: textDirection,
  );
}

/// 应用的逻辑像素折成磅（96 DPI）：图片尺寸、小图间距与标注的图标间距共用。
const double diaryPdfPt = 0.75;

/// 一张图片本身（不含缩进与对齐）；读不出尺寸时为 null。
pw.Widget? _pdfPicture(ExportBlock block, Uint8List bytes) {
  final info = ExportImageInfo.read(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) return null;
  final box = ExportImageBox.of(
    block,
    info.width,
    info.height,
    maxHeight: 560 / diaryPdfPt,
  );
  final memory = pw.MemoryImage(bytes);
  if (box.thumbnail) {
    final radius = box.radius * diaryPdfPt;
    return pw.ClipRRect(
      horizontalRadius: radius,
      verticalRadius: radius,
      child: pw.Image(
        memory,
        width: box.width * diaryPdfPt,
        height: box.height * diaryPdfPt,
        fit: pw.BoxFit.cover,
        alignment: box.keepsTop ? pw.Alignment.topCenter : pw.Alignment.center,
      ),
    );
  }
  // 版心宽度在排版时才知道（还要减去缩进）：先给原尺寸，放不下时由
  // FittedBox 按比例缩小。
  return pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    child: pw.Image(
      memory,
      width: box.width * diaryPdfPt,
      height: box.height * diaryPdfPt,
    ),
  );
}

/// 按 [block] 的层级缩进、对齐与上下留白摆放 [picture]。
pw.Widget _placePdfImage(
  ExportBlock block,
  pw.Widget picture, {
  required pw.TextDirection textDirection,
}) {
  final rtl = textDirection == pw.TextDirection.rtl;
  return pw.Padding(
    padding: pw.EdgeInsetsDirectional.only(
      start: block.indent * 18.0,
      top: 6,
      bottom: 6,
    ),
    child: pw.Align(
      alignment: switch (block.align) {
        ExportAlign.center => pw.Alignment.center,
        ExportAlign.end =>
          rtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        _ => rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      },
      heightFactor: 1,
      child: picture,
    ),
  );
}

/// 折叠列表的标题行：行首一个朝下的小三角（导出一律展开，子块照常以
/// 更深的缩进跟在后面）。三角是矢量路径而不是 ▸ / ▾ 字符：内置字体没有
/// 这些字形。[fontSize] 为标题行的字号，三角按它缩放并对齐第一行文字。
/// [continued] 为软换行后的续行（见 `buildDiaryPdfBody`）：三角只占位不画。
pw.Widget buildDiaryPdfToggle(
  pw.Widget text, {
  required double fontSize,
  required pw.TextDirection textDirection,
  bool continued = false,
}) {
  final side = fontSize * 0.5;
  final triangle = pw.Padding(
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
  );
  return pw.Directionality(
    textDirection: textDirection,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        continued ? DiaryPdfPlaceholder(triangle) : triangle,
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
                    // 窄格子里的中文逐字换行，不会整段挤到下一行。
                    lineSplitter: diaryPdfLineSplitter,
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
