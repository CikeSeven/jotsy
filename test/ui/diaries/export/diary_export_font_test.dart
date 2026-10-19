import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_font.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:xml/xml.dart';

import '../../../support/font_file_fixtures.dart';
import 'diary_export_test_fixtures.dart';

/// 导出跟随正文排版里选的导入字体：PDF 嵌入，Word 与网页按字族名引用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fontDirectory = 'assets/fonts/harmonyos_sans_sc';
  // 内置粗体充当“导入字体”：它与内置常规体的 PostScript 名不同，PDF 里
  // 用的是哪一款一眼可辨。
  late Uint8List imported;
  late String importedName;
  late String bundledName;

  setUpAll(() async {
    imported = await File(
      '$fontDirectory/HarmonyOS_Sans_SC_Bold.ttf',
    ).readAsBytes();
    importedName = TtfParser(ByteData.sublistView(imported)).fontName;
    bundledName = TtfParser(
      ByteData.sublistView(
        await File(
          '$fontDirectory/HarmonyOS_Sans_SC_Regular.ttf',
        ).readAsBytes(),
      ),
    ).fontName;
  });

  final entry = DiaryExportEntry.parse(
    diaryId: 'd',
    title: '出发',
    createdAt: DateTime(2026, 4, 1, 8),
    updatedAt: DateTime(2026, 4, 1, 8),
    deltaOps: <dynamic>[
      <String, dynamic>{'insert': '今天天气很好 hello\n'},
      <String, dynamic>{
        'insert': '加粗',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{'insert': '\n'},
    ],
  );

  const families = <String>['LXGW WenKai', '霞鹜文楷'];

  group('DiaryExportFont', () {
    test('lists the English family name first, then Chinese, without '
        'duplicates', () {
      final font = DiaryExportFont.fromBytes(
        buildTestFont(
          names: <TestFontName>[
            (
              platform: 3,
              encoding: 1,
              language: 0x0804,
              nameId: 1,
              value: '霞鹜文楷',
            ),
            (
              platform: 3,
              encoding: 1,
              language: 0x0409,
              nameId: 1,
              value: 'LXGW WenKai',
            ),
            (platform: 0, encoding: 3, language: 0, nameId: 1, value: '霞鹜文楷'),
          ],
        ),
      );

      expect(font!.families, families);
    });

    test('is null for files that are not fonts', () {
      expect(DiaryExportFont.fromBytes(utf8.encode('not a font file')), isNull);
    });

    group('load', () {
      late Directory root;
      late DiaryFontStorageService storage;

      setUp(() async {
        root = await Directory.systemTemp.createTemp('jotsy_export_font_');
        storage = DiaryFontStorageService(baseDirectory: () async => root);
      });
      tearDown(() => root.delete(recursive: true));

      Future<DiaryImportedFont> importFont() async {
        final source = File(p.join(root.path, 'LXGWWenKai.ttf'));
        await source.writeAsBytes(
          buildTestFont(
            names: <TestFontName>[
              (
                platform: 3,
                encoding: 1,
                language: 0x0409,
                nameId: 1,
                value: 'LXGW WenKai',
              ),
            ],
          ),
        );
        return storage.importFont(source.path, languageCode: 'zh');
      }

      test('reads the imported font the typography points at', () async {
        final font = await importFont();

        final loaded = await DiaryExportFont.load(
          DiaryTypography(fontId: font.id),
          storage,
        );

        expect(loaded!.families, <String>['LXGW WenKai']);
      });

      test('is null for the bundled and system fonts and for a font that '
          'was deleted or lost its file', () async {
        expect(
          await DiaryExportFont.load(const DiaryTypography(), storage),
          isNull,
        );
        expect(
          await DiaryExportFont.load(
            const DiaryTypography(fontId: DiaryTypography.systemFontId),
            storage,
          ),
          isNull,
        );
        expect(
          await DiaryExportFont.load(
            const DiaryTypography(fontId: 'gone'),
            storage,
          ),
          isNull,
        );
        final font = await importFont();
        await File(
          p.join(
            root.path,
            DiaryFontStorageService.directoryName,
            font.fileName,
          ),
        ).delete();
        expect(
          await DiaryExportFont.load(DiaryTypography(fontId: font.id), storage),
          isNull,
        );
      });
    });
  });

  group('PDF', () {
    Future<String> pdf(DiaryPdfFonts fonts) async {
      final output = await DiaryPdfWriter.write(
        <DiaryExportEntry>[entry],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        fonts: fonts,
        documentTitle: 'Jotsy',
      );
      // 字典部分是 ASCII；正文流已压缩，按 latin1 读不会出错。
      return latin1.decode(output.bytes!);
    }

    Matcher embeds(String fontName) => matches(
      RegExp('/BaseFont\\s*/${RegExp.escape(fontName)}(?![A-Za-z0-9_-])'),
    );

    test(
      'embeds the imported font for the whole document, bold included',
      () async {
        final fonts = await DiaryPdfFonts.load(
          DiaryExportFont.fromBytes(imported),
        );

        expect(identical(fonts.regular, fonts.bold), isTrue);
        expect(identical(fonts.bundled, fonts.regular), isFalse);
        final text = await pdf(fonts);
        expect(text, embeds(importedName));
        // 导入字体字形齐全，内置字体只是缺字时的回落，没有写进文档。
        expect(text, isNot(embeds(bundledName)));
      },
    );

    test('embeds the first face of a font collection', () async {
      final fonts = await DiaryPdfFonts.load(
        DiaryExportFont.fromBytes(wrapInCollection(imported)),
      );

      expect(await pdf(fonts), embeds(importedName));
    });

    test('keeps the bundled fonts without an imported font or when it '
        'cannot be embedded', () async {
      final bundled = await DiaryPdfFonts.load();
      expect(identical(bundled.regular, bundled.bold), isFalse);
      expect(identical(bundled.bundled, bundled.regular), isTrue);
      expect(await pdf(bundled), embeds(bundledName));

      // CFF 轮廓的 OpenType：pdf 库只认 TrueType 轮廓。
      final cff = DiaryExportFont.fromBytes(buildTestFont(version: 0x4F54544F));
      expect(cff, isNotNull);
      expect(DiaryPdfFonts.embeddable(cff!.bytes), isNull);
      final fallback = await DiaryPdfFonts.load(cff);
      expect(identical(fallback.regular, fallback.bold), isFalse);
      expect(identical(fallback.bundled, fallback.regular), isTrue);
      expect(await pdf(fallback), embeds(bundledName));
    });

    test('rejects fonts the PDF library would choke on mid-export', () {
      // 表目录齐全但 cmap 内容是垃圾：解析出错按无法嵌入处理。
      final broken = Uint8List.fromList(imported);
      final view = ByteData.sublistView(broken);
      final tableCount = view.getUint16(4);
      for (var index = 0; index < tableCount; index += 1) {
        final record = 12 + index * 16;
        if (ascii.decode(broken.sublist(record, record + 4)) == 'cmap') {
          final offset = view.getUint32(record + 8);
          broken.fillRange(offset, offset + 64, 0xFF);
        }
      }

      expect(DiaryPdfFonts.embeddable(broken), isNull);
      expect(DiaryPdfFonts.embeddable(imported), isNotNull);
    });
  });

  group('Word', () {
    Future<XmlElement> defaultRunProperties({
      List<String>? fontFamilies,
    }) async {
      final output = await DiaryDocxWriter.write(
        <DiaryExportEntry>[entry],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: 'Jotsy',
        languageTag: 'zh-CN',
        fontFamilies: fontFamilies ?? const <String>[],
        now: DateTime.utc(2026, 10, 19),
      );
      final styles = XmlDocument.parse(
        utf8.decode(
          output.files!.firstWhere((f) => f.path == 'word/styles.xml').bytes!,
        ),
      );
      return styles.findAllElements('w:rPrDefault').single.getElement('w:rPr')!;
    }

    test('sets the imported font as the default Latin and East Asian font, '
        'leaving complex scripts to Word', () async {
      final rPr = await defaultRunProperties(
        fontFamilies: <String>['A & B', '中文'],
      );

      // w:rFonts 必须排在 w:rPr 的最前面，否则 Word 报告内容无法读取。
      final fonts = rPr.childElements.first;
      expect(fonts.name.qualified, 'w:rFonts');
      for (final slot in <String>['w:ascii', 'w:eastAsia', 'w:hAnsi']) {
        expect(fonts.getAttribute(slot), 'A & B', reason: slot);
      }
      expect(fonts.getAttribute('w:cs'), isNull);
    });

    test('leaves the font to Word without an imported font', () async {
      final rPr = await defaultRunProperties();

      expect(rPr.getElement('w:rFonts'), isNull);
    });
  });

  group('HTML', () {
    Future<String> html({List<String>? fontFamilies}) async {
      final output = await DiaryHtmlWriter.write(
        <DiaryExportEntry>[entry],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: 'Jotsy',
        languageTag: 'zh',
        fontFamilies: fontFamilies ?? const <String>[],
      );
      return utf8.decode(output.bytes!);
    }

    test('puts the imported font at the front of the font stack', () async {
      expect(
        await html(fontFamilies: families),
        contains('body{font-family:"LXGW WenKai","霞鹜文楷",-apple-system,'),
      );
      expect(await html(), isNot(contains('font-family:"')));
    });

    test(
      'escapes font names so they cannot break out of the style sheet',
      () async {
        final page = await html(
          fontFamilies: <String>['</style><script>alert(1)</script>"\\'],
        );

        expect(page, isNot(contains('<script>')));
        expect(page, contains(r'"\3c /style\3e \3c script\3e alert(1)'));
        expect(page, contains(r'\22 \5c "'));
        expect(RegExp('</style>').allMatches(page), hasLength(1));
      },
    );
  });
}
