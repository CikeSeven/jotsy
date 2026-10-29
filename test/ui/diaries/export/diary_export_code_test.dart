import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_code.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_theme.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:xml/xml.dart';

import 'diary_export_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
  DiaryExportCodeTheme themeOf(DiaryCodeBlockStyle style) =>
      DiaryExportCodeTheme.resolve(style, scheme);
  final code = themeOf(
    DiaryCodeBlockStyle.defaults.copyWith(theme: DiaryCodeThemeId.github),
  );

  /// 每行的片段写成 `文字@角色`，无角色的只写文字。
  List<List<String>> describe(List<List<DiaryExportCodeRun>> lines) => [
    for (final runs in lines)
      [for (final run in runs) '${run.text}@${run.role?.name ?? '-'}'],
  ];

  String hexOf(DiaryCodeTokenRole role) =>
      diaryColorRgbHex(code.paper.tokens[role]!);

  Map<String, dynamic> codeLine(String text, Object value) => <String, dynamic>{
    'insert': '$text\n',
    'attributes': <String, dynamic>{'code-block': value},
  };

  DiaryExportEntry codeEntry(List<dynamic> ops) => DiaryExportEntry.parse(
    diaryId: 'code',
    title: '代码',
    createdAt: DateTime(2026, 4, 3),
    updatedAt: DateTime(2026, 4, 3),
    deltaOps: <dynamic>[
      <String, dynamic>{'insert': '前\n'},
      ...ops,
    ],
  );

  final options = DiaryExportOptions.defaults.copyWith(
    includeMeta: false,
    includeMedia: false,
  );

  group('DiaryExportCodeTheme', () {
    test('follows the code block style: light paper with a dark-mode '
        'palette, or one fixed palette for both', () {
      final system = themeOf(DiaryCodeBlockStyle.defaults);
      expect(system.paper.brightness, Brightness.light);
      expect(system.night.brightness, Brightness.dark);
      expect(system.autoDetect, isTrue);

      final dark = themeOf(
        DiaryCodeBlockStyle.defaults.copyWith(
          brightness: DiaryCodeBrightness.dark,
          autoDetect: false,
        ),
      );
      expect(dark.paper.brightness, Brightness.dark);
      expect(dark.night, same(dark.paper));
      expect(dark.autoDetect, isFalse);

      final light = themeOf(
        DiaryCodeBlockStyle.defaults.copyWith(
          brightness: DiaryCodeBrightness.light,
        ),
      );
      expect(light.paper.brightness, Brightness.light);
      expect(light.night, same(light.paper));
    });

    test('highlights a whole block and splits it back into lines', () {
      final lines = code.highlightLines(<String>[
        'def add(a, b):',
        '',
        '    # sum',
        '    return a + b',
      ], 'python');
      expect(describe(lines), <List<String>>[
        // 与应用里同一个高亮器：参数表归为变量色。
        <String>[
          'def@keyword',
          ' @-',
          'add@function',
          '(a, b)@variable',
          ':@-',
        ],
        <String>[],
        <String>['    @-', '# sum@comment'],
        <String>['    @-', 'return@keyword', ' a + b@-'],
      ]);
    });

    test('a block comment spanning lines is colored on every line', () {
      final lines = code.highlightLines(<String>[
        '/* one',
        'two */ let x = 1;',
      ], 'javascript');
      expect(lines[0].single.role, DiaryCodeTokenRole.comment);
      expect(lines[1].first.text, 'two */');
      expect(lines[1].first.role, DiaryCodeTokenRole.comment);
    });

    test('plain, auto with detection off and oversized blocks stay '
        'uncolored', () {
      expect(describe(code.highlightLines(<String>['def f():'], 'plain')), [
        <String>['def f():@-'],
      ]);
      final noDetect = themeOf(
        DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
      );
      expect(describe(noDetect.highlightLines(<String>['{"a": 1}'], null)), [
        <String>['{"a": 1}@-'],
      ]);
      final huge = List<String>.filled(601, 'x = 1');
      expect(
        code
            .highlightLines(huge, 'python')
            .every((runs) => runs.every((run) => run.role == null)),
        isTrue,
      );
    });

    test('auto blocks use the detected language', () {
      final lines = code.highlightLines(<String>['{"a": 1}'], null);
      expect(lines.single.map((run) => run.role), contains(isNotNull));
    });

    test('highlightBlocks groups adjacent lines of the same language and '
        'leaves other blocks alone', () {
      final blocks = codeEntry(<dynamic>[
        codeLine('/* a', 'javascript'),
        codeLine('b */', 'javascript'),
        codeLine('# c', 'python'),
      ]).blocks;
      final runs = code.highlightBlocks(blocks);
      expect(runs.first, isNull);
      expect(runs[1]!.single.role, DiaryCodeTokenRole.comment);
      // 与上一行合成一块：块注释延续到这一行。
      expect(runs[2]!.single.role, DiaryCodeTokenRole.comment);
      expect(runs[3]!.single.role, DiaryCodeTokenRole.comment);
    });

    test('highlightBlocks splits tokens where user colors change and keeps '
        'them', () {
      final blocks = codeEntry(<dynamic>[
        <String, dynamic>{
          'insert': 'ret',
          'attributes': <String, dynamic>{
            'color': '#FF112233',
            'background': '#4DFF6369',
          },
        },
        <String, dynamic>{'insert': 'urn 1'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'code-block': 'python'},
        },
        codeLine('return 2', 'python'),
      ]).blocks;
      final runs = code.highlightBlocks(blocks);
      // 一个记号被用户颜色切成两段，角色不变。
      expect(describe(<List<DiaryExportCodeRun>>[runs[1]!]).single, <String>[
        'ret@keyword',
        'urn@keyword',
        ' @-',
        '1@number',
      ]);
      expect(runs[1]!.first.color, const Color(0xFF112233));
      expect(runs[1]!.first.background, const Color(0x4DFF6369));
      expect(runs[1]![1].color, isNull);
      // 没设颜色的行保持原来的片段。
      expect(describe(<List<DiaryExportCodeRun>>[runs[2]!]).single, <String>[
        'return@keyword',
        ' @-',
        '2@number',
      ]);
    });

    test('colorCodeBlocks colors code text, keeps user colors and '
        'everything else, and never mutates the diary', () {
      final blocks = DiaryExportEntry.parse(
        diaryId: 'color',
        title: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deltaOps: <dynamic>[
          <String, dynamic>{'insert': '正文\n'},
          <String, dynamic>{
            'insert': 'return',
            'attributes': <String, dynamic>{'color': '#FF112233', 'bold': true},
          },
          <String, dynamic>{'insert': ' 1 # x'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'code-block': 'python'},
          },
          <String, dynamic>{'insert': '后\n'},
        ],
      ).blocks;
      final colored = code.colorCodeBlocks(blocks);
      expect(colored.first, same(blocks.first));
      expect(colored.last, same(blocks.last));
      int argb(DiaryCodeTokenRole role) => code.paper.tokens[role]!.toARGB32();
      expect(
        <(String, int?, bool, bool)>[
          for (final run in colored[1].inlines)
            (run.text, run.color?.toARGB32(), run.italic, run.bold),
        ],
        <(String, int?, bool, bool)>[
          // 用户手动上的颜色与其他格式保留。
          ('return', 0xFF112233, false, true),
          (' ', null, false, false),
          ('1', argb(DiaryCodeTokenRole.number), false, false),
          (' ', null, false, false),
          ('# x', argb(DiaryCodeTokenRole.comment), true, false),
        ],
      );
      expect(colored[1].codeLanguage, 'python');
      // 原来的块不变。
      expect(blocks[1].inlines.map((run) => run.text), <String>[
        'return',
        ' 1 # x',
      ]);
      expect(blocks[1].inlines.last.color, isNull);

      final prose = <ExportBlock>[blocks.first];
      expect(code.colorCodeBlocks(prose), same(prose));
    });
  });

  group('writers', () {
    // 与 Quill 的输出一致：块属性只挂在换行上。
    Map<String, dynamic> lineEnd(Object value) => <String, dynamic>{
      'insert': '\n',
      'attributes': <String, dynamic>{'code-block': value},
    };
    final entry = codeEntry(<dynamic>[
      <String, dynamic>{'insert': 'def f():'},
      lineEnd('python'),
      <String, dynamic>{'insert': '    return 1'},
      lineEnd('python'),
    ]);

    test('PDF colors code tokens by the block language', () async {
      final body = await DiaryPdfWriter.prepareBody(
        entry,
        includeImages: false,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: <Uint8List>[],
        code: code,
      );
      final def = body!
          .expand((ExportBlock block) => block.inlines)
          .firstWhere((ExportInline run) => run.text == 'def');
      expect(
        def.color?.toARGB32(),
        code.paper.tokens[DiaryCodeTokenRole.keyword]!.toARGB32(),
      );
      expect(
        body
            .where((ExportBlock b) => b.kind == ExportBlockKind.code)
            .map((ExportBlock b) => b.codeLanguage)
            .toSet(),
        <String?>{'python'},
      );

      final output = await DiaryPdfWriter.write(
        <DiaryExportEntry>[entry],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        fonts: await DiaryPdfFonts.load(),
        documentTitle: '代码',
        code: code,
      );
      expect(ascii.decode(output.bytes!.sublist(0, 5)), '%PDF-');
    });

    test('Word writes colored runs on the themed code style', () async {
      final docx = await DiaryDocxWriter.write(
        <DiaryExportEntry>[entry],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '代码',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 20),
        code: code,
      );
      final parts = {for (final f in docx.files!) f.path: f};
      final document = utf8.decode(parts['word/document.xml']!.bytes!);
      final styles = utf8.decode(parts['word/styles.xml']!.bytes!);
      // Word 对元素顺序很严格：两份 XML 都必须能解析。
      XmlDocument.parse(document);
      XmlDocument.parse(styles);
      final keyword = hexOf(DiaryCodeTokenRole.keyword).substring(1);
      expect(
        document,
        contains(
          '<w:r><w:rPr><w:color w:val="$keyword"/></w:rPr>'
          '<w:t xml:space="preserve">def</w:t></w:r>',
        ),
      );
      final fill = diaryColorRgbHex(code.paper.background).substring(1);
      final fg = diaryColorRgbHex(code.paper.foreground).substring(1);
      expect(styles, contains('w:fill="$fill"'));
      expect(styles, contains('<w:color w:val="$fg"/>'));
    });

    test('Word and HTML keep user colors on code over token colors', () async {
      final colored = codeEntry(<dynamic>[
        <String, dynamic>{
          'insert': 'def',
          'attributes': <String, dynamic>{
            'color': '#FF112233',
            'background': '#4DFF6369',
          },
        },
        <String, dynamic>{'insert': ' f():'},
        lineEnd('python'),
      ]);
      final docx = await DiaryDocxWriter.write(
        <DiaryExportEntry>[colored],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '代码',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 20),
        code: code,
      );
      final document = utf8.decode(
        docx.files!.firstWhere((f) => f.path == 'word/document.xml').bytes!,
      );
      XmlDocument.parse(document);
      // 背景叠在代码底色上（Word 的颜色没有透明度）。
      final fill = diaryColorRgbHex(
        Color.alphaBlend(const Color(0x4DFF6369), code.paper.background),
      ).substring(1);
      expect(
        document,
        contains(
          '<w:r><w:rPr><w:color w:val="112233"/>'
          '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/></w:rPr>'
          '<w:t xml:space="preserve">def</w:t></w:r>',
        ),
      );

      final output = await DiaryHtmlWriter.write(
        <DiaryExportEntry>[colored],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '代码',
        languageTag: 'zh',
        code: code,
      );
      expect(
        utf8.decode(output.bytes!),
        contains(
          '<span class="hl-keyword" style="color:#112233;'
          'background-color:rgba(255,99,105,0.302)">def</span> '
          '<span class="hl-function">f</span>',
        ),
      );
    });

    test('HTML wraps tokens in spans with light and dark variables', () async {
      Future<String> htmlOf(DiaryExportEntry entry) async {
        final output = await DiaryHtmlWriter.write(
          <DiaryExportEntry>[entry],
          options: options,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          documentTitle: '代码',
          languageTag: 'zh',
          code: code,
        );
        return utf8.decode(output.bytes!);
      }

      final html = await htmlOf(entry);
      expect(
        html,
        contains(
          '<pre><code class="language-python">'
          '<span class="hl-keyword">def</span> '
          '<span class="hl-function">f</span>'
          '<span class="hl-variable">()</span>:\n'
          '    <span class="hl-keyword">return</span> '
          '<span class="hl-number">1</span></code></pre>',
        ),
      );
      expect(
        html,
        contains('--hl-keyword:${hexOf(DiaryCodeTokenRole.keyword)}'),
      );
      expect(
        html,
        contains(
          '--hl-keyword:'
          '${diaryColorRgbHex(code.night.tokens[DiaryCodeTokenRole.keyword]!)}',
        ),
      );
      expect(
        html,
        contains('@media (prefers-color-scheme:dark){:root{--code-bg'),
      );

      // 没有代码块的页面不带高亮样式。
      final prose = await htmlOf(
        DiaryExportEntry.parse(
          diaryId: 'p',
          title: '散文',
          createdAt: DateTime(2026, 4, 3),
          updatedAt: DateTime(2026, 4, 3),
          deltaOps: <dynamic>[
            <String, dynamic>{'insert': '没有代码\n'},
          ],
        ),
      );
      expect(prose, isNot(contains('--code-bg')));
    });
  });
}
