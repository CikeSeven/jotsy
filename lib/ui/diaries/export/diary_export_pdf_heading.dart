import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';

/// PDF 正文标题的局部适配：输入共用解析器读出的标题块（颜色已压平），
/// 把行内样式叠到标题字阶上；不读取设置、不改写原正文。
///
/// flutter_quill_to_pdf 2.3.9 在算完行内样式后，会用 getHeaderStyle 整份
/// 替换它，导致 H1–H5 的颜色、背景、粗体与装饰丢失。只接管标题回调，
/// 其余正文、列表、代码块仍走插件；标题间距与字阶沿用插件的既有值。
class DiaryPdfHeading {
  const DiaryPdfHeading._();

  static pw.Widget build(
    ExportBlock block, {
    required pw.ThemeData theme,
    required pw.TextDirection textDirection,
    required bool aligned,
  }) {
    final base = switch (block.level) {
      1 => theme.header1,
      2 => theme.header2,
      3 => theme.header3,
      4 => theme.header4,
      5 => theme.header5,
      // 插件的 ThemeData 只有五级标题；H6 使用其默认的 15pt。
      _ => theme.defaultTextStyle.copyWith(fontSize: 15),
    };
    final rtl = textDirection == pw.TextDirection.rtl;
    final align = switch (block.align) {
      ExportAlign.center => pw.TextAlign.center,
      ExportAlign.justify => pw.TextAlign.justify,
      ExportAlign.start => rtl ? pw.TextAlign.right : pw.TextAlign.left,
      ExportAlign.end => rtl ? pw.TextAlign.left : pw.TextAlign.right,
    };
    // 插件对非零缩进先加一级，标题的显式对齐与普通对齐用不同内边距。
    final indent = block.indent > 0 ? block.indent + 1 : 0;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Directionality(
        textDirection: textDirection,
        child: pw.Container(
          alignment: switch (align) {
            pw.TextAlign.center => pw.Alignment.center,
            pw.TextAlign.right => pw.Alignment.centerRight,
            _ => pw.Alignment.centerLeft,
          },
          padding: aligned
              ? pw.EdgeInsetsDirectional.only(start: indent * 12.5)
              : pw.EdgeInsets.only(left: indent * 7, top: 3.5, bottom: 2.5),
          child: pw.RichText(
            textAlign: align,
            textDirection: textDirection,
            softWrap: true,
            overflow: pw.TextOverflow.span,
            text: pw.TextSpan(
              children: <pw.InlineSpan>[
                for (final run in block.inlines) _span(run, base),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static pw.TextSpan _span(ExportInline run, pw.TextStyle base) {
    // 颜色已在 DiaryPdfWriter.prepareBody 中叠到白纸上；保留用户颜色，
    // 未设颜色的链接与行内代码才使用插件原有的蓝色 / 灰底默认值。
    final color = run.color != null
        ? PdfColor.fromInt(run.color!.toARGB32())
        : run.link != null
        ? const PdfColor.fromInt(0x002AAB)
        : run.code
        ? PdfColors.black
        : base.color;
    final background = run.background != null
        ? PdfColor.fromInt(run.background!.toARGB32())
        : run.code
        ? const PdfColor.fromInt(0xFFDBDBDB)
        : null;
    final style = base.copyWith(
      fontWeight: run.bold ? pw.FontWeight.bold : null,
      fontStyle: run.italic ? pw.FontStyle.italic : null,
      color: color,
      background: background == null
          ? null
          : pw.BoxDecoration(
              color: background,
              borderRadius: run.code ? pw.BorderRadius.circular(3) : null,
            ),
      decoration: pw.TextDecoration.combine(<pw.TextDecoration>[
        if (run.underline || run.link != null) pw.TextDecoration.underline,
        if (run.strike) pw.TextDecoration.lineThrough,
      ]),
      decorationStyle: pw.TextDecorationStyle.solid,
      decorationColor: color,
    );
    return pw.TextSpan(
      text: run.text,
      style: style,
      annotation: run.link == null ? null : pw.AnnotationUrl(run.link!),
    );
  }
}
