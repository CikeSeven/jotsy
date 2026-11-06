import 'package:pdf/widgets.dart' as pw;

import '../models/diary_text_style_options.dart';
import 'diary_export_blocks.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_line_break.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 正文标题的局部适配：输入共用解析器读出的标题块（颜色已压平），
/// 把行内样式叠到标题字阶上；不读取设置、不改写原正文。
///
/// 标题与应用一致：加粗，字号为正文字号乘 [kDiaryHeadingScales]（与编辑器
/// 同一组倍数，六级依次变小）；行内片段叠在这个字阶上。缩进沿用既有导出
/// 的规格。
class DiaryPdfHeading {
  const DiaryPdfHeading._();

  static pw.Widget build(
    ExportBlock block, {
    required pw.ThemeData theme,
    required pw.TextDirection textDirection,
    required bool aligned,
    required DiaryPdfTextEffects effects,
  }) {
    // 不用 pdf 库主题的 header1–5：它们不加粗、各级只差 0.1 倍，也没有
    // 第六级。
    final body = theme.defaultTextStyle;
    final base = body.copyWith(
      fontSize:
          (body.fontSize ?? 12) *
          kDiaryHeadingScales[block.level.clamp(1, 6) - 1],
      fontWeight: pw.FontWeight.bold,
    );
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
            // 长标题里的中文同样逐字换行（见 diaryPdfLineSplitter）。
            lineSplitter: diaryPdfLineSplitter,
            text: pw.TextSpan(
              children: <pw.InlineSpan>[
                for (final run in block.inlines)
                  buildDiaryPdfInline(
                    run,
                    base,
                    effects: effects,
                    bodyFontSize: body.fontSize ?? 12,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
