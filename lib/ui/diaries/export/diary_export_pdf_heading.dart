import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 正文标题的局部适配：输入共用解析器读出的标题块（颜色已压平），
/// 把行内样式叠到标题字阶上；不读取设置、不改写原正文。
///
/// 直接在 PDF 标题字阶上叠加行内片段，沿用既有导出的字阶与缩进规格。
class DiaryPdfHeading {
  const DiaryPdfHeading._();

  static pw.Widget build(
    ExportBlock block, {
    required pw.ThemeData theme,
    required pw.TextDirection textDirection,
    required bool aligned,
    required DiaryPdfTextEffects effects,
  }) {
    final base = switch (block.level) {
      1 => theme.header1,
      2 => theme.header2,
      3 => theme.header3,
      4 => theme.header4,
      5 => theme.header5,
      // PDF 主题 只有五级标题；H6 使用其默认的 15pt。
      _ => theme.defaultTextStyle.copyWith(fontSize: 15),
    };
    final rtl = textDirection == pw.TextDirection.rtl;
    final align = switch (block.align) {
      ExportAlign.center => pw.TextAlign.center,
      ExportAlign.justify => pw.TextAlign.justify,
      ExportAlign.start => rtl ? pw.TextAlign.right : pw.TextAlign.left,
      ExportAlign.end => rtl ? pw.TextAlign.left : pw.TextAlign.right,
    };
    // 兼容既有导出：非零缩进先加一级，标题的显式对齐与普通对齐用不同内边距。
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
                for (final run in block.inlines)
                  buildDiaryPdfInline(
                    run,
                    base,
                    effects: effects,
                    bodyFontSize: theme.defaultTextStyle.fontSize ?? 12,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
