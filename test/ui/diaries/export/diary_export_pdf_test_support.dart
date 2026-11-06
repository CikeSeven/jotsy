import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
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

/// 块文档里带一段文字的块；[data] 合并进块的 `data`。
Map<String, Object?> pdfTextBlock(
  String type,
  String text, {
  Map<String, Object?> data = const <String, Object?>{},
  List<Map<String, Object?>> children = const <Map<String, Object?>>[],
}) => <String, Object?>{
  'type': type,
  'data': <String, Object?>{
    'delta': <Object?>[
      <String, Object?>{'insert': text},
    ],
    ...data,
  },
  if (children.isNotEmpty) 'children': children,
};

/// 以 [children] 为顶层块的一篇日记。
DiaryExportEntry pdfEntryOf(List<Map<String, Object?>> children) =>
    DiaryExportEntry.parse(
      diaryId: 'blocks',
      title: 'Blocks',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      blockDocument: <String, Object?>{
        'document': <String, Object?>{'type': 'page', 'children': children},
      },
    );

/// 导出 [children] 组成的一篇日记，返回页面流（[pdfPageCommands]）。默认用
/// 标准字体（[pdfAsciiFonts]），ASCII 文字原样写入，便于按文字找位置。
Future<String> exportPdfBlocks(
  List<Map<String, Object?>> children, {
  DiaryTypography typography = const DiaryTypography(),
  DiaryPdfFonts? fonts,
}) async {
  final output = await DiaryPdfWriter.write(
    <DiaryExportEntry>[pdfEntryOf(children)],
    options: DiaryExportOptions.defaults.copyWith(
      includeMedia: false,
      includeMeta: false,
    ),
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    fonts: fonts ?? await pdfAsciiFonts(),
    documentTitle: 'Blocks',
    typography: typography,
  );
  return pdfPageCommands(Uint8List.fromList(output.bytes!));
}

/// 页面流里文字恰为 [word] 的各个片段的横坐标，按绘制先后。正文块都在
/// 版心左缘平移后绘制，横坐标即相对版心左缘的位置。
List<double> pdfXsOf(String commands, String word) => <double>[
  for (final match in RegExp(
    '([-\\d.]+) [-\\d.]+ Td \\[\\(${RegExp.escape(word)}\\)\\]TJ',
  ).allMatches(commands))
    double.parse(match.group(1)!),
];

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
