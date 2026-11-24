import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_epub.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_emoji.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_inline.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_text_effects.dart';
import 'package:node_diary/utils/pangu_spacing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// HTML / EPUB / Word / PDF 四种导出格式的盘古之白：默认关闭时与改版前逐字节
/// 一致；开启时按各自格式原生能力或微占位呈现间距，并跳过代码块。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleEntry = pdfEntryOf(<Map<String, Object?>>[
    pdfTextBlock('paragraph', '用Flutter写3行代码'),
    pdfTextBlock('code', 'const 版本 = 1;'),
  ]);

  group('HTML export pangu spacing', () {
    Future<String> renderHtml(DiaryTypography typography) async {
      final out = await DiaryHtmlWriter.write(
        <DiaryExportEntry>[sampleEntry],
        options: DiaryExportOptions.defaults.copyWith(includeMeta: false),
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '用Flutter写日记',
        languageTag: 'zh-CN',
        typography: typography,
      );
      return utf8.decode(out.bytes!);
    }

    test(
      'omits text-autospace when disabled and emits it when enabled',
      () async {
        final off = await renderHtml(
          const DiaryTypography(panguSpacing: false),
        );
        expect(off, isNot(contains('text-autospace')));

        final on = await renderHtml(const DiaryTypography(panguSpacing: true));
        expect(on, contains('body{text-autospace:normal}'));
        expect(on, contains('pre,code{text-autospace:no-autospace}'));
      },
    );
  });

  group('EPUB export pangu spacing', () {
    Future<String> epubCss(DiaryTypography typography) async {
      final out = await DiaryEpubWriter.write(
        <DiaryExportEntry>[sampleEntry],
        options: DiaryExportOptions.defaults.copyWith(includeMeta: false),
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '用Flutter写日记',
        languageTag: 'zh-CN',
        typography: typography,
        now: DateTime.utc(2026, 11, 24),
      );
      final cssFile = out.files!.firstWhere(
        (DiaryExportBundleFile f) => f.path == 'OEBPS/style.css',
      );
      return utf8.decode(cssFile.bytes!);
    }

    test('writes text-autospace into style.css only when enabled', () async {
      final off = await epubCss(const DiaryTypography(panguSpacing: false));
      expect(off, isNot(contains('text-autospace')));

      final on = await epubCss(const DiaryTypography(panguSpacing: true));
      expect(on, contains('body{text-autospace:normal}'));
      expect(on, contains('pre,code{text-autospace:no-autospace}'));
    });
  });

  group('Word (.docx) export pangu spacing', () {
    Future<String> docxStyles(DiaryTypography typography) async {
      final out = await DiaryDocxWriter.write(
        <DiaryExportEntry>[sampleEntry],
        options: DiaryExportOptions.defaults.copyWith(includeMeta: false),
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '用Flutter写日记',
        languageTag: 'zh-CN',
        typography: typography,
        now: DateTime.utc(2026, 11, 24),
      );
      final styles = out.files!.firstWhere(
        (DiaryExportBundleFile f) => f.path == 'word/styles.xml',
      );
      return utf8.decode(styles.bytes!);
    }

    test('emits OOXML autoSpaceDE/autoSpaceDN in valid schema order', () async {
      final off = await docxStyles(const DiaryTypography(panguSpacing: false));
      expect(off, isNot(contains('autoSpaceDE')));
      expect(off, isNot(contains('autoSpaceDN')));

      final on = await docxStyles(const DiaryTypography(panguSpacing: true));
      final doc = XmlDocument.parse(on);

      XmlElement styleById(String id) => doc
          .findAllElements('w:style')
          .firstWhere((e) => e.getAttribute('w:styleId') == id);

      for (final id in const <String>[
        'Normal',
        'Title',
        'Heading1',
        'Heading6',
      ]) {
        final pPr = styleById(id).getElement('w:pPr')!;
        final names = pPr.childElements.map((e) => e.name.local).toList();
        final de = names.indexOf('autoSpaceDE');
        final dn = names.indexOf('autoSpaceDN');
        final spacing = names.indexOf('spacing');
        expect(de, greaterThanOrEqualTo(0), reason: id);
        expect(dn, de + 1, reason: id);
        expect(dn, lessThan(spacing), reason: id);
      }

      // 代码块显式关闭自动间距，并排在 shd 之后、spacing 之前。
      final codePPr = styleById('CodeBlock').getElement('w:pPr')!;
      final codeChildren = codePPr.childElements.toList();
      final codeNames = codeChildren.map((e) => e.name.local).toList();
      final shd = codeNames.indexOf('shd');
      final de = codeNames.indexOf('autoSpaceDE');
      final dn = codeNames.indexOf('autoSpaceDN');
      final spacing = codeNames.indexOf('spacing');
      expect(de, greaterThan(shd));
      expect(dn, de + 1);
      expect(dn, lessThan(spacing));
      expect(codeChildren[de].getAttribute('w:val'), '0');
      expect(codeChildren[dn].getAttribute('w:val'), '0');
    });
  });

  group('PDF export pangu spacing', () {
    List<double> collectGapWidths(pw.InlineSpan root) {
      final widths = <double>[];
      void visit(pw.InlineSpan span) {
        if (span is pw.WidgetSpan) {
          final child = span.child;
          if (child is pw.SizedBox && child.width != null) {
            widths.add(child.width!);
          }
        } else if (span is pw.TextSpan && span.children != null) {
          for (final child in span.children!) {
            visit(child);
          }
        }
      }

      visit(root);
      return widths;
    }

    test('inserts proportional WidgetSpan gaps inside and across runs, '
        'skipping code blocks and superscripts', () async {
      final fonts = await DiaryPdfFonts.load();
      final emoji = DiaryPdfEmoji(fontCovers: (_) => true);
      final effects = DiaryPdfTextEffects(
        regular: fonts.regular,
        bold: fonts.bold,
        bundled: fonts.bundled,
        emoji: emoji,
      );
      final base = pw.TextStyle(font: fonts.regular, fontSize: 12);

      final runs = const <ExportInline>[
        ExportInline('今天用'),
        ExportInline('Flutter', bold: true),
        ExportInline('写3行'),
      ];
      final offSpans = buildDiaryPdfInlines(
        runs,
        base,
        effects: effects,
        bodyFontSize: 12,
        panguSpacing: false,
      );
      expect(collectGapWidths(pw.TextSpan(children: offSpans)), isEmpty);

      final onSpans = buildDiaryPdfInlines(
        runs,
        base,
        effects: effects,
        bodyFontSize: 12,
        panguSpacing: true,
      );
      final expectedGap = panguSpacingExtent(12);
      // 4 处边界：用|Flutter、Flutter|写、写|3、3|行。
      final gaps = collectGapWidths(pw.TextSpan(children: onSpans));
      expect(gaps, hasLength(4));
      for (final width in gaps) {
        expect(width, closeTo(expectedGap, 0.0001));
      }

      // 代码块与上下标不插盘古之白。
      final codeSpans = buildDiaryPdfInlines(
        const <ExportInline>[ExportInline('中文123abc')],
        base,
        effects: effects,
        bodyFontSize: 12,
        isCodeBlock: true,
        panguSpacing: true,
      );
      expect(collectGapWidths(pw.TextSpan(children: codeSpans)), isEmpty);

      final scriptSpans = buildDiaryPdfInlines(
        const <ExportInline>[
          ExportInline('注解'),
          ExportInline('1', script: ExportScript.superscript),
          ExportInline('说明'),
        ],
        base,
        effects: effects,
        bodyFontSize: 12,
        panguSpacing: true,
      );
      expect(collectGapWidths(pw.TextSpan(children: scriptSpans)), isEmpty);

      // 标题纯文本构建器同样在开启时插入微占位。
      final titleWidget = buildDiaryPdfText(
        '用Flutter写日记',
        emoji: emoji,
        style: const pw.TextStyle(fontSize: 20),
        panguSpacing: true,
      );
      expect(titleWidget, isA<pw.RichText>());
      final titleGaps = collectGapWidths((titleWidget as pw.RichText).text);
      expect(titleGaps, hasLength(2));
      expect(titleGaps.first, closeTo(panguSpacingExtent(20), 0.0001));
    });

    test(
      'renders a complete PDF document with pangu spacing enabled',
      () async {
        final fonts = await DiaryPdfFonts.load();
        final out = await DiaryPdfWriter.write(
          <DiaryExportEntry>[sampleEntry],
          options: DiaryExportOptions.defaults.copyWith(includeMeta: false),
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          fonts: fonts,
          documentTitle: '用Flutter写日记',
          textDirection: TextDirection.ltr,
          typography: const DiaryTypography(panguSpacing: true),
        );
        final bytes = out.bytes;
        expect(bytes, isA<Uint8List>());
        expect(bytes!.length, greaterThan(100));
      },
    );
  });
}
