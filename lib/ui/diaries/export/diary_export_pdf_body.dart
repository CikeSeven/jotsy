import 'dart:typed_data';

import 'package:flutter/widgets.dart' show TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
import 'diary_export_code.dart';
import 'diary_export_pdf_heading.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_line_break.dart';
import 'diary_export_pdf_list_item.dart';
import 'diary_export_pdf_rich_blocks.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 正文直接使用共用块模型渲染，不再调用编辑器插件。图片已在准备阶段
/// 载入并替换为虚拟地址，媒体已换为说明文字；这里不做 IO、不改原文。
/// 按段/代码行返回可分页的组件，避免把整篇长文放进一个不可分页的容器。
/// 标注、折叠列表与表格的画法见 `diary_export_pdf_rich_blocks.dart`。
///
/// 文字块一律铺满可用宽度再排版：pdf 库的 [pw.RichText] 在宽松约束下只取
/// 最长一行的宽度，单行段落的居中 / 右对齐就在这条窄框里“对齐”，落到页面
/// 上仍贴着左边（标题另经 [DiaryPdfHeading] 的 `alignment` 撑满）。
///
/// 首行缩进与应用一致（见 `DiaryParagraphBlock`）：[firstLineIndent] 为全局
/// 首行缩进的字数，[markedFirstLineIndent] 为带工具栏缩进标记的段落的字数
/// （两字与全局取较大者，由调用方换算好），按正文字号折成宽度；只缩进正文
/// 段落（媒体名称行与链接卡片标题这类 `standIn` 不算），居中、右对齐的段落不缩进，
/// 两端对齐照常缩进。中文要能在缩进之后接着排、按字换行，文字块经
/// `diary_export_pdf_line_break.dart` 逐字断行。
List<pw.Widget> buildDiaryPdfBody(
  List<ExportBlock> blocks, {
  required pw.ThemeData theme,
  required pw.Font codeFont,
  required DiaryPdfTextEffects effects,
  required List<Uint8List> images,
  required TextDirection textDirection,
  DiaryExportCodeTheme? code,
  double firstLineIndent = 0,
  double markedFirstLineIndent = 0,
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
      final image = buildDiaryPdfImage(
        block,
        images[index],
        textDirection: direction,
      );
      if (image == null) continue;
      content = image;
    } else if (block.kind == ExportBlockKind.divider) {
      // 与应用一样是一条横贯整行的细线，跟着所在层级缩进。
      content = pw.Padding(
        padding: pw.EdgeInsetsDirectional.only(start: block.indent * 18.0),
        child: pw.Divider(color: PdfColors.grey500, thickness: 0.7),
      );
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
      final checked = block.kind == ExportBlockKind.checked;
      // 已完成的待办与应用一样：没设颜色的文字转灰，整项划线。
      final style = checked ? base.copyWith(color: PdfColors.grey600) : base;
      final indentChars = _firstLineIndentChars(
        block,
        regular: firstLineIndent,
        marked: markedFirstLineIndent,
      );
      final spans = <pw.InlineSpan>[
        // pdf 库没有首行缩进，段首放一个占位宽度的空白组件：只占第一行，
        // 折行后的各行照常顶格；高度为 0，不改变行高。
        if (indentChars > 0)
          pw.WidgetSpan(
            child: pw.SizedBox(width: indentChars * (base.fontSize ?? 12)),
          ),
        for (final run in block.inlines)
          buildDiaryPdfInline(
            checked ? run.copyWith(strike: true) : run,
            style,
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
      // 撑满宽度，对齐才落在整行上（见本函数注释）。
      content = pw.SizedBox(
        width: double.infinity,
        child: pw.RichText(
          text: pw.TextSpan(children: spans),
          textDirection: direction,
          textAlign: align,
          softWrap: true,
          overflow: pw.TextOverflow.span,
          lineSplitter: diaryPdfLineSplitter,
        ),
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
      } else if (block.isListItem) {
        content = buildDiaryPdfListItem(
          block,
          content,
          base: base,
          textDirection: direction,
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

/// 本块首行缩进的字数：只有正文段落、且从起始侧排起（左对齐或两端对齐）
/// 时缩进，带工具栏缩进标记的取 [marked]，否则取全局的 [regular]。
double _firstLineIndentChars(
  ExportBlock block, {
  required double regular,
  required double marked,
}) {
  if (block.kind != ExportBlockKind.paragraph || block.standIn) return 0;
  if (block.align == ExportAlign.center || block.align == ExportAlign.end) {
    return 0;
  }
  return block.firstLineIndent ? marked : regular;
}
