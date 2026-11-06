import 'dart:typed_data';

import 'package:flutter/widgets.dart' show TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_body.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_text_effects.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// PDF 正文的段落对齐与首行缩进：按页面流里每个词的实际横坐标验证，而不是
/// 只看块模型里有没有带上对齐值。
///
/// 正文段落都在版心左缘平移后绘制，`Td` 的横坐标即相对版心左缘的位置；
/// 标准字体（Helvetica）让 ASCII 文字原样写入，便于按文字找到位置。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A4 宽 21cm、左右各 2cm 页边距后的版心宽度（pt）。
  const contentWidth = 17 / 2.54 * 72;

  /// PDF 正文字号（pdf 库主题默认），首行缩进按它折算每个字的宽度。
  const bodyFontSize = 12.0;

  Map<String, Object?> block(
    String type,
    String text, {
    Map<String, Object?> data = const <String, Object?>{},
  }) => <String, Object?>{
    'type': type,
    'data': <String, Object?>{
      'delta': <Object?>[
        <String, Object?>{'insert': text},
      ],
      ...data,
    },
  };

  DiaryExportEntry entryOf(List<Map<String, Object?>> children) =>
      DiaryExportEntry.parse(
        diaryId: 'align',
        title: 'Align',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        blockDocument: <String, Object?>{
          'document': <String, Object?>{'type': 'page', 'children': children},
        },
      );

  Future<String> export(
    List<Map<String, Object?>> children, {
    DiaryTypography typography = const DiaryTypography(),
  }) async {
    final output = await DiaryPdfWriter.write(
      <DiaryExportEntry>[entryOf(children)],
      options: DiaryExportOptions.defaults.copyWith(
        includeMedia: false,
        includeMeta: false,
      ),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      fonts: await pdfAsciiFonts(),
      documentTitle: 'Align',
      typography: typography,
    );
    return pdfPageCommands(Uint8List.fromList(output.bytes!));
  }

  /// 文字恰为 [word] 的各个片段的横坐标，按绘制先后。
  List<double> xsOf(String commands, String word) => <double>[
    for (final match in RegExp(
      '([-\\d.]+) [-\\d.]+ Td \\[\\(${RegExp.escape(word)}\\)\\]TJ',
    ).allMatches(commands))
      double.parse(match.group(1)!),
  ];

  test('centered and right-aligned single-line paragraphs sit in the middle '
      'and at the end of the line, not at its start', () async {
    final commands = await export(<Map<String, Object?>>[
      block('paragraph', 'Start'),
      block('paragraph', 'Twin', data: {'align': 'center'}),
      block('paragraph', 'Twin', data: {'align': 'right'}),
      block('quote', 'Quoted', data: {'align': 'center'}),
    ]);
    expect(xsOf(commands, 'Start'), <double>[0]);
    final [center, right] = xsOf(commands, 'Twin');
    // 同一个词：居中的空白是右对齐的一半，右对齐的右缘贴着版心右缘。
    expect(center, greaterThan(contentWidth / 3));
    expect(right, closeTo(center * 2, 0.01));
    expect(right, lessThan(contentWidth));
    // 引用块里的文字同样居中（左侧竖条与内边距之后的宽度里居中）。
    expect(xsOf(commands, 'Quoted').single, greaterThan(contentWidth / 3));
  });

  test('a paragraph marked with the toolbar indent starts two characters in '
      'and only its first line is indented', () async {
    final filler = List<String>.filled(80, 'xx').join(' ');
    final commands = await export(<Map<String, Object?>>[
      block('paragraph', 'Plain'),
      block('paragraph', 'Marked $filler', data: {'firstLineIndent': true}),
    ]);
    expect(xsOf(commands, 'Plain'), <double>[0]);
    expect(xsOf(commands, 'Marked'), <double>[2 * bodyFontSize]);
    // 折行后的各行顶格。
    expect(xsOf(commands, 'xx'), contains(0));
  });

  test('an indented Chinese paragraph without spaces continues on the first '
      'line after the indent instead of moving to the next line', () async {
    // pdf 库只在空白处换行：整段中文是一个“词”，前面有缩进时会被整个挤到
    // 下一行，第一行只剩缩进。用内置中文字体直接排正文（标准字体缺中文，
    // 库按缺字回落会把中文另拆成片段，掩盖这个问题），页面上只有这一段。
    final fonts = await DiaryPdfFonts.load();
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      fontFallback: <pw.Font>[fonts.bundled],
    );
    final blocks = entryOf(<Map<String, Object?>>[
      block(
        'paragraph',
        '今天天气很好，我们一起去公园散步。' * 6,
        data: {'firstLineIndent': true},
      ),
    ]).blocks;
    final document = pw.Document()
      ..addPage(
        pw.MultiPage(
          pageFormat: const PdfPageFormat(
            21 * PdfPageFormat.cm,
            29.7 * PdfPageFormat.cm,
            marginAll: 2 * PdfPageFormat.cm,
          ),
          theme: theme,
          build: (_) => buildDiaryPdfBody(
            blocks,
            theme: theme,
            codeFont: fonts.bundled,
            effects: DiaryPdfTextEffects(
              regular: fonts.regular,
              bold: fonts.bold,
              bundled: fonts.bundled,
            ),
            images: const <Uint8List>[],
            textDirection: TextDirection.ltr,
            markedFirstLineIndent: 2,
          ),
        ),
      );
    final commands = pdfPageCommands(await document.save());
    // 各行（按基线分组）的起点与终点；PDF 的纵坐标向上，第一行最高。
    final lines = <double, List<double>>{};
    for (final run in RegExp(
      r'([-\d.]+) ([-\d.]+) Td \[',
    ).allMatches(commands)) {
      lines
          .putIfAbsent(double.parse(run.group(2)!), () => <double>[])
          .add(double.parse(run.group(1)!));
    }
    final baselines = lines.keys.toList()..sort();
    expect(baselines.length, greaterThan(1));
    final first = lines[baselines.last]!;
    final second = lines[baselines[baselines.length - 2]]!;
    expect(first.first, 2 * bodyFontSize);
    // 第一行接着缩进一直排到接近版心右缘，折行后的第二行顶格。
    expect(first.last, greaterThan(contentWidth - 2 * bodyFontSize));
    expect(second.first, 0);
  });

  test('the global first-line indent applies to body paragraphs; marked ones '
      'take the larger of two characters and the global value', () async {
    final children = <Map<String, Object?>>[
      block('paragraph', 'Body'),
      block('paragraph', 'Marked', data: {'firstLineIndent': true}),
      block('paragraph', 'Justified', data: {'align': 'justify'}),
      block('bulleted_list', 'Item'),
      block('heading', 'Title', data: {'level': 2}),
    ];
    final one = await export(
      children,
      typography: const DiaryTypography(firstLineIndent: 1),
    );
    expect(xsOf(one, 'Body'), <double>[bodyFontSize]);
    expect(xsOf(one, 'Marked'), <double>[2 * bodyFontSize]);
    expect(xsOf(one, 'Justified'), <double>[bodyFontSize]);
    // 列表与标题不是正文段落，不缩进首行。
    final itemWithoutIndent = xsOf(await export(children), 'Item').single;
    expect(xsOf(one, 'Item').single, itemWithoutIndent);
    expect(xsOf(one, 'Title'), <double>[0]);

    final three = await export(
      children,
      typography: const DiaryTypography(firstLineIndent: 3),
    );
    expect(xsOf(three, 'Body'), <double>[3 * bodyFontSize]);
    expect(xsOf(three, 'Marked'), <double>[3 * bodyFontSize]);
  });

  test('centered and right-aligned paragraphs never indent their first '
      'line', () async {
    final commands = await export(<Map<String, Object?>>[
      block(
        'paragraph',
        'Twin',
        data: {'align': 'center', 'firstLineIndent': true},
      ),
      block('paragraph', 'Twin', data: {'align': 'right'}),
    ], typography: const DiaryTypography(firstLineIndent: 2));
    final [center, right] = xsOf(commands, 'Twin');
    // 缩进会让两者都多出一段，比例就不再是 2 倍。
    expect(center, greaterThan(contentWidth / 3));
    expect(right, closeTo(center * 2, 0.01));
  });

  test('media name lines stand in for blocks and are not indented as body '
      'paragraphs', () async {
    final children = <Map<String, Object?>>[
      <String, Object?>{
        'type': 'video',
        'data': <String, Object?>{'url': '/private/diary_videos/trip.mp4'},
      },
    ];
    final plain = await export(children);
    final indented = await export(
      children,
      typography: const DiaryTypography(firstLineIndent: 2),
    );
    expect(xsOf(plain, 'trip.mp4]'), hasLength(1));
    expect(xsOf(indented, 'trip.mp4]'), xsOf(plain, 'trip.mp4]'));
  });

  test('preparing the PDF body keeps the toolbar indent mark and alignment '
      'and marks media lines as stand-ins', () async {
    final body = await DiaryPdfWriter.prepareBody(
      entryOf(<Map<String, Object?>>[
        block('paragraph', 'Marked', data: {'firstLineIndent': true}),
        block('paragraph', 'Centered', data: {'align': 'center'}),
        <String, Object?>{
          'type': 'video',
          'data': <String, Object?>{'url': '/private/trip.mp4'},
        },
      ]),
      includeImages: false,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      images: <Uint8List>[],
    );
    expect(
      <(bool, ExportAlign, bool)>[
        for (final block in body!)
          (block.firstLineIndent, block.align, block.standIn),
      ],
      <(bool, ExportAlign, bool)>[
        (true, ExportAlign.start, false),
        (false, ExportAlign.center, false),
        (false, ExportAlign.start, true),
      ],
    );
  });
}
