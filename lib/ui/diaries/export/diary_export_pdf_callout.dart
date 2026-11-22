import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart'
    show kDiaryCalloutDefaultIcon;
import '../models/diary_callout_tone.dart';
import '../widgets/diary_editor/diary_callout_block.dart'
    show kDiaryCalloutIconGap;
import 'diary_export_blocks.dart';
import 'diary_export_pdf_emoji.dart';
import 'diary_export_pdf_line_break.dart';
import 'diary_export_pdf_list_item.dart' show DiaryPdfPlaceholder;
import 'diary_export_pdf_rich_blocks.dart' show diaryPdfPt;

/// 标注：圆角浅色底，左侧一条强调色竖条，颜色只取 [DiaryCalloutTone] 的
/// 纸面配色（导出纸面恒为白底）。
///
/// 与应用一样，行首是标注的图标（缺省 [kDiaryCalloutDefaultIcon]），按正文
/// 字号 [base] 画，隔 [kDiaryCalloutIconGap] 接文字；对齐只作用于文字，图标
/// 始终在起始侧。图标是 emoji，经 [emoji] 画成图片；没给 [emoji] 时不画图标
/// （写成文字只会印成方框）。
///
/// 有软换行的标注逐行成段（见 `buildDiaryPdfBody`）：[first] / [last] 为
/// 这一段是不是第一 / 最后一行。只有一段时就是一整个标注；分段时各段
/// 上下相接拼成一个：图标只画在第一段（续行占位对齐），上下内边距与圆角
/// 只在两端（[_calloutSegment]）。
pw.Widget buildDiaryPdfCallout(
  ExportBlock block,
  pw.Widget text, {
  required pw.TextStyle base,
  required pw.TextDirection textDirection,
  DiaryPdfEmoji? emoji,
  bool first = true,
  bool last = true,
}) {
  final tone = DiaryCalloutTone.fromId(block.calloutTone);
  final icon = block.calloutIcon ?? kDiaryCalloutDefaultIcon;
  final glyph = pw.RichText(
    text: diaryPdfTextSpan(icon, style: base, emoji: emoji),
  );
  final content = emoji == null || icon.trim().isEmpty
      ? text
      : pw.Directionality(
          textDirection: textDirection,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              first ? glyph : DiaryPdfPlaceholder(glyph),
              pw.SizedBox(width: kDiaryCalloutIconGap * diaryPdfPt),
              pw.Expanded(child: text),
            ],
          ),
        );
  if (!first || !last) {
    return _calloutSegment(tone, content, first: first, last: last);
  }
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
              child: content,
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

/// 标注分段里的一段（见 [buildDiaryPdfCallout]）：底色与竖条画得比这一段
/// 高，在相接的一侧多出一个圆角半径，再由 [pw.Stack] 裁到这一段的范围——
/// 圆角只落在整个标注的两端，段与段之间的底色和竖条连成一片。
pw.Widget _calloutSegment(
  DiaryCalloutTone tone,
  pw.Widget content, {
  required bool first,
  required bool last,
}) {
  const radius = 6.0;
  return pw.Stack(
    children: <pw.Widget>[
      pw.Positioned(
        left: 0,
        right: 0,
        top: first ? 0 : -radius,
        bottom: last ? 0 : -radius,
        child: pw.ClipRRect(
          horizontalRadius: radius,
          verticalRadius: radius,
          child: pw.Container(
            color: PdfColor.fromInt(tone.paperBackground.toARGB32()),
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: 3,
              color: PdfColor.fromInt(tone.paperAccent.toARGB32()),
            ),
          ),
        ),
      ),
      pw.SizedBox(
        width: double.infinity,
        child: pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(13, first ? 6 : 0, 10, last ? 6 : 0),
          child: content,
        ),
      ),
    ],
  );
}
