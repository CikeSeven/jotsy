import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart' show DiaryCommentRowImages;
import 'diary_export_entry.dart';

/// PDF 的留言区：输入一篇日记与文案，输出接在正文之后的组件；没有留言时
/// 为空，文档与没有留言功能时相同。普通导出与成书共用（都经
/// `DiaryPdfWriter._entryWidgets`）。
///
/// - 每条留言拆成说明行与文字两个组件交给 `MultiPage` 分页：放进同一个
///   Column 会成为不可分页的整体，很长的留言整页放不下时排版会失败；
/// - 心情 emoji 不写：内置字体没有 emoji 字形，会印成方框（与信息行的
///   `includeMood: false` 一致）；
/// - 留言图片：[images] 为已读出、已计入总量的图片（来源 → 字节），在文字
///   下面排成一行 [_imageExtent] 见方的圆角缩略图；不在其中的（不带媒体、
///   文件缺失）在文字里写成占位。
List<pw.Widget> buildDiaryPdfComments(
  DiaryExportEntry entry,
  DiaryExportLabels labels, {
  Map<String, Uint8List> images = const <String, Uint8List>{},
}) {
  if (entry.comments.isEmpty) {
    return const <pw.Widget>[];
  }
  const muted = pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600);
  const text = pw.TextStyle(fontSize: 11, lineSpacing: 2);
  final widgets = <pw.Widget>[
    pw.SizedBox(height: 18),
    pw.Divider(color: PdfColors.grey300, thickness: 0.5),
    pw.SizedBox(height: 6),
    pw.Text(
      labels.commentsHeading,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey800,
      ),
    ),
    pw.SizedBox(height: 6),
  ];
  for (final (index, comment) in entry.comments.indexed) {
    if (index > 0) {
      widgets.add(pw.SizedBox(height: 10));
    }
    final shown = <Uint8List>[
      for (final source in comment.imagePaths) ?images[source],
    ];
    final body = labels.commentText(
      comment,
      includeMood: false,
      unrenderedImages: comment.imagePaths.length - shown.length,
    );
    widgets
      ..add(pw.Text(labels.commentMetaLine(entry, comment), style: muted))
      ..add(pw.SizedBox(height: 2));
    if (body.isNotEmpty) widgets.add(pw.Text(body, style: text));
    if (shown.isNotEmpty) {
      widgets
        ..add(pw.SizedBox(height: 4))
        ..add(
          pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <pw.Widget>[
              for (final bytes in shown)
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(
                    pw.MemoryImage(bytes),
                    width: _imageExtent,
                    height: _imageExtent,
                    fit: pw.BoxFit.cover,
                  ),
                ),
            ],
          ),
        );
    }
  }
  return widgets;
}

/// 留言缩略图的边长（磅）：一行放得下六张，九张最多两行。
const double _imageExtent = 76;
