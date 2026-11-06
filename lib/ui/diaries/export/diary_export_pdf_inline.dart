import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_text_style_options.dart';
import 'diary_export_blocks.dart';
import 'diary_export_pdf_line_break.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 行内样式：把共用块模型的文字、颜色、装饰和链接叠到当前段落字阶。
/// 不改正文，不读取设置；字体回退与绘制补粗由 DiaryPdfTextEffects 负责。
pw.TextSpan buildDiaryPdfInline(
  ExportInline run,
  pw.TextStyle base, {
  required DiaryPdfTextEffects effects,
  required double bodyFontSize,
  bool isCodeBlock = false,
}) {
  // 文字色 / 背景色已经在 prepareBody 中叠到纸面上。链接与行内代码
  // 只在未设颜色时使用默认值，避免用户的格式被整份默认样式替换。
  final color = run.color != null
      ? PdfColor.fromInt(run.color!.toARGB32())
      : run.link != null
      ? const PdfColor.fromInt(0x002AAB)
      : run.code && !isCodeBlock
      ? PdfColors.black
      : base.color;
  final background = run.background != null
      ? PdfColor.fromInt(run.background!.toARGB32())
      : run.code && !isCodeBlock
      ? const PdfColor.fromInt(0xFFDBDBDB)
      : null;
  final bold = run.bold || base.fontWeight == pw.FontWeight.bold;
  final italic = run.italic || base.fontStyle == pw.FontStyle.italic;
  // 字号档位按正文字号的倍数（与应用同一口径，认不出的数字字号按所在块
  // 的字号）；上下标再按所在字号缩小、抬高 / 降低基线，倍数与编辑器共用
  // [DiaryScript]（pdf 库的 baseline 为正时向上）。
  final scale = run.sizeScale;
  final size = scale == null ? base.fontSize : bodyFontSize * scale;
  final script = switch (run.script) {
    ExportScript.superscript => DiaryScript.superscript,
    ExportScript.subscript => DiaryScript.subscript,
    null => null,
  };
  final fontSize = script == null || size == null
      ? size
      : size * DiaryScript.scale;
  final baseline = script == null || size == null
      ? 0.0
      : size * script.baselineShift;
  final style = effects.apply(
    base.copyWith(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      fontSize: fontSize,
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
    ),
    isBold: bold,
    isItalic: italic,
    isCodeBlock: isCodeBlock,
  );
  // 含中日韩文字时拆成可逐字断行的子片段（见 diaryPdfLineSplitter）。
  return diaryPdfTextSpan(
    run.text,
    style: style,
    baseline: baseline,
    annotation: run.link == null ? null : pw.AnnotationUrl(run.link!),
  );
}
