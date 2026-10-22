import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 行内格式适配：保留送入插件前的片段边界，以免插件把任意两个
/// 非空属性表当成相同样式合并。插件仍负责块布局、列表、引用和代码块。
/// 仅读取已清洗的 Delta；不读取设置、不改原文，也不处理媒体 IO。
class DiaryPdfInlineSource {
  DiaryPdfInlineSource(List<dynamic> ops) {
    final text = StringBuffer();
    for (final raw in ops) {
      if (raw is! Map || raw['insert'] is! String) {
        continue;
      }
      final value = raw['insert'] as String;
      if (value.isEmpty) {
        continue;
      }
      final attributes = raw['attributes'];
      _runs.add((
        start: text.length,
        text: value,
        attributes: attributes is Map
            ? Map<String, dynamic>.from(attributes)
            : const <String, dynamic>{},
      ));
      text.write(value);
    }
    _text = text.toString();
  }

  final _runs = <({int start, String text, Map<String, dynamic> attributes})>[];
  late final String _text;
  int _offset = 0;
  int _run = 0;

  /// 按插件实际请求的文字消费原始片段。空行、图片行的换行可能不产生
  /// 回调，所以从当前游标向前匹配，而不能假设每行恰有一次回调；重复的
  /// 文字也依次消费，不按内容去重。标题回调同样调用这里保持游标同步。
  List<ExportInline> take(String text) {
    if (text.isEmpty) {
      return const <ExportInline>[];
    }
    final start = _text.indexOf(text, _offset);
    if (start < 0) {
      throw StateError('PDF text does not match the prepared diary Delta');
    }
    final end = start + text.length;
    final result = <ExportInline>[];
    while (_run < _runs.length) {
      final run = _runs[_run];
      final runEnd = run.start + run.text.length;
      if (runEnd <= start) {
        _run++;
        continue;
      }
      if (run.start >= end) {
        break;
      }
      result.add(
        ExportInline.fromAttributes(
          run.text.substring(
            (start - run.start).clamp(0, run.text.length),
            (end - run.start).clamp(0, run.text.length),
          ),
          run.attributes,
        ),
      );
      if (runEnd >= end) {
        break;
      }
      _run++;
    }
    _offset = end;
    return result;
  }
}

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
  final style = effects.apply(
    base.copyWith(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      fontSize: _fontSize(run.size, bodyFontSize),
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
