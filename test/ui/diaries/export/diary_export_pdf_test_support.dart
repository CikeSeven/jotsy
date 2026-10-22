import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_test_fixtures.dart';

Future<DiaryPdfFonts> pdfAsciiFonts() async => DiaryPdfFonts(
  pw.Font.helvetica(),
  pw.Font.helveticaBold(),
  bundled: (await DiaryPdfFonts.load()).regular,
);

Future<Uint8List> exportPdfOps(
  List<dynamic> ops, {
  DiaryPdfFonts? fonts,
}) async {
  final output = await DiaryPdfWriter.write(
    <DiaryExportEntry>[
      DiaryExportEntry.parse(
        diaryId: 'heading',
        title: 'Heading formats',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deltaOps: ops,
      ),
    ],
    options: DiaryExportOptions.defaults.copyWith(
      includeMedia: false,
      includeMeta: false,
    ),
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    fonts: fonts ?? await DiaryPdfFonts.load(),
    documentTitle: 'Heading formats',
  );
  return Uint8List.fromList(output.bytes!);
}

({String font, double size}) pdfTextRun(String commands, String text) {
  final run = RegExp(
    r'BT\s*/(\w+)\s+([\d.]+)\s+Tf\b(?:(?!\bET\b).)*?'
    '\\(${RegExp.escape(text)}\\)',
    dotAll: true,
  ).firstMatch(commands);
  expect(run, isNotNull, reason: 'Missing PDF text run: $text\n$commands');
  return (font: run!.group(1)!, size: double.parse(run.group(2)!));
}

String pdfFontName(String pdf, String resource) {
  final reference = RegExp('/$resource (\\d+) 0 R').firstMatch(pdf)!;
  final object = RegExp(
    '${reference.group(1)} 0 obj\\s*<<(.*?)>>',
    dotAll: true,
  ).firstMatch(pdf)!;
  return RegExp(
    r'/BaseFont\s*/([^\s/>]+)',
  ).firstMatch(object.group(1)!)!.group(1)!;
}

/// PDF 的字体与页面流都会压缩；按字节长度解压，只保留含文字绘制的页面
/// 流，避免把嵌入字体的二进制内容误当成颜色、字号或文字命令。
String pdfPageCommands(Uint8List bytes) {
  final source = latin1.decode(bytes);
  final streams = RegExp(
    r'<<(.*?)>>\s*stream\r?\n',
    dotAll: true,
  ).allMatches(source);
  return streams
      .map((match) {
        final dictionary = match.group(1)!;
        final length = RegExp(r'/Length\s+(\d+)').firstMatch(dictionary);
        if (length == null || !dictionary.contains('/FlateDecode')) {
          return '';
        }
        final end = match.end + int.parse(length.group(1)!);
        final stream = latin1.decode(
          zlib.decode(bytes.sublist(match.end, end)),
        );
        return stream.contains('BT') ? stream : '';
      })
      .join('\n');
}
