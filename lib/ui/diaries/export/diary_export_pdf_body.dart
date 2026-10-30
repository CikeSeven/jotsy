import 'dart:typed_data';

import 'package:flutter/widgets.dart' show TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
import 'diary_export_code.dart';
import 'diary_export_pdf_heading.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_rich_blocks.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 正文直接使用共用块模型渲染，不再调用编辑器插件。图片已在准备阶段
/// 载入并替换为虚拟地址，媒体已换为说明文字；这里不做 IO、不改原文。
/// 按段/代码行返回可分页的组件，避免把整篇长文放进一个不可分页的容器。
/// 标注、折叠列表与表格的画法见 `diary_export_pdf_rich_blocks.dart`。
List<pw.Widget> buildDiaryPdfBody(
  List<ExportBlock> blocks, {
  required pw.ThemeData theme,
  required pw.Font codeFont,
  required DiaryPdfTextEffects effects,
  required List<Uint8List> images,
  required TextDirection textDirection,
  DiaryExportCodeTheme? code,
}) {
  final result = <pw.Widget>[];
  final rtl = textDirection == TextDirection.rtl;
  final direction = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  var codeLine = 0;
  for (final block in blocks) {
    final isCode = block.kind == ExportBlockKind.code;
    if (isCode) {
      codeLine++;
    } else {
      codeLine = 0;
    }
    pw.Widget content;
    if (block.kind == ExportBlockKind.image) {
      final source = block.source ?? '';
      final index = int.tryParse(
        Uri.tryParse(source)?.pathSegments.last.split('.').first ?? '',
      );
      if (index == null || index < 0 || index >= images.length) continue;
      content = pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.ConstrainedBox(
          constraints: const pw.BoxConstraints(maxHeight: 560),
          child: pw.Image(
            pw.MemoryImage(images[index]),
            fit: pw.BoxFit.contain,
          ),
        ),
      );
    } else if (block.kind == ExportBlockKind.divider) {
      content = pw.Divider(color: PdfColors.grey500, thickness: 0.7);
    } else if (block.kind == ExportBlockKind.table) {
      // 一行一个组件（见 buildDiaryPdfTableRows），长表格能在行间换页；
      // 上下留白只加在首行之上、末行之下。
      final rows = buildDiaryPdfTableRows(
        block,
        base: theme.defaultTextStyle,
        effects: effects,
        textDirection: direction,
      );
      for (final (index, row) in rows.indexed) {
        result.add(
          effects.wrap(
            pw.Padding(
              padding: pw.EdgeInsetsDirectional.only(
                start: block.indent * 18.0,
                top: index == 0 ? 6 : 0,
                bottom: index == rows.length - 1 ? 6 : 0,
              ),
              child: row,
            ),
          ),
        );
      }
      continue;
    } else if (block.kind == ExportBlockKind.heading) {
      content = DiaryPdfHeading.build(
        block,
        theme: theme,
        textDirection: direction,
        aligned: block.align != ExportAlign.start,
        effects: effects,
      );
    } else {
      final palette = code?.paper;
      final base = isCode
          ? pw.TextStyle(
              font: codeFont,
              fontSize: 10,
              lineSpacing: 1,
              color: palette == null
                  ? PdfColors.black
                  : PdfColor.fromInt(palette.foreground.toARGB32()),
            )
          : theme.defaultTextStyle;
      final prefix = switch (block.kind) {
        ExportBlockKind.bullet ||
        ExportBlockKind.ordered => '${block.listMarker}  ',
        ExportBlockKind.checked => '[x]  ',
        ExportBlockKind.unchecked => '[ ]  ',
        _ => '',
      };
      final spans = <pw.InlineSpan>[
        if (prefix.isNotEmpty) pw.TextSpan(text: prefix, style: base),
        for (final run in block.inlines)
          buildDiaryPdfInline(
            run,
            base,
            effects: effects,
            bodyFontSize: base.fontSize ?? 12,
            isCodeBlock: isCode,
          ),
        if (block.inlines.isEmpty) pw.TextSpan(text: ' ', style: base),
      ];
      final align = switch (block.align) {
        ExportAlign.center => pw.TextAlign.center,
        ExportAlign.end => rtl ? pw.TextAlign.left : pw.TextAlign.right,
        ExportAlign.justify => pw.TextAlign.justify,
        ExportAlign.start => rtl ? pw.TextAlign.right : pw.TextAlign.left,
      };
      content = pw.RichText(
        text: pw.TextSpan(children: spans),
        textDirection: direction,
        textAlign: align,
        softWrap: true,
        overflow: pw.TextOverflow.span,
      );
      if (isCode) {
        content = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: palette == null
              ? PdfColors.grey100
              : PdfColor.fromInt(palette.background.toARGB32()),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 24,
                child: pw.Text(
                  '$codeLine',
                  style: base.copyWith(
                    color: palette == null
                        ? PdfColors.grey600
                        : PdfColor.fromInt(palette.lineNumber.toARGB32()),
                  ),
                ),
              ),
              pw.Expanded(child: content),
            ],
          ),
        );
      } else if (block.kind == ExportBlockKind.toggle) {
        content = buildDiaryPdfToggle(
          content,
          fontSize: base.fontSize ?? 12,
          textDirection: direction,
        );
      } else if (block.kind == ExportBlockKind.callout) {
        content = buildDiaryPdfCallout(block, content);
      } else if (block.kind == ExportBlockKind.quote) {
        content = pw.Container(
          padding: const pw.EdgeInsetsDirectional.only(start: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey400, width: 2),
            ),
          ),
          child: content,
        );
      }
      content = pw.Padding(
        padding: pw.EdgeInsetsDirectional.only(
          start: block.indent * 18.0,
          top: isCode ? 0 : 3.5,
          bottom: isCode ? 0 : 2.5,
        ),
        child: content,
      );
    }
    result.add(effects.wrap(content));
  }
  return result;
}
