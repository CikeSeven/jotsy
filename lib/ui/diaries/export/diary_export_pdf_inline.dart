import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
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
  // 上下标：按所在字号缩到 0.7 倍，基线抬高 / 降低（pdf 库的 baseline
  // 为正时向上）。
  final size = _fontSize(run.size, bodyFontSize) ?? base.fontSize;
  final script = run.script;
  final fontSize = script == null || size == null ? size : size * 0.7;
  final baseline = size == null
      ? 0.0
      : switch (script) {
          ExportScript.superscript => size * 0.33,
          ExportScript.subscript => -size * 0.12,
          null => 0.0,
        };
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
  return pw.TextSpan(
    text: run.text,
    style: style,
    baseline: baseline,
    annotation: run.link == null ? null : pw.AnnotationUrl(run.link!),
  );
}

double? _fontSize(String? size, double bodyFontSize) {
  final value = switch (size) {
    'small' => bodyFontSize * 0.85,
    'large' => bodyFontSize * 1.25,
    'huge' => bodyFontSize * 1.5,
    _ => double.tryParse(size ?? ''),
  };
  return value != null && value.isFinite && value > 0 ? value : null;
}
