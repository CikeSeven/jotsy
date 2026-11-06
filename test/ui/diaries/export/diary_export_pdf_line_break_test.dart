import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_line_break.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF 正文中日韩断行：切词与分段的口径。
void main() {
  group('diaryPdfLineSplitter', () {
    test('splits text without CJK on whitespace exactly like the pdf '
        'library', () {
      for (final line in <String>['Hello  world', ' lead', 'a-b,c.', '']) {
        expect(
          diaryPdfLineSplitter(line),
          line.split(RegExp(r'\s')),
          reason: line,
        );
      }
    });

    test('lets CJK text break between any two characters', () {
      expect(diaryPdfLineSplitter('今天很好'), <String>['今', '天', '很', '好']);
      // 小假名不放在行首，与前一个字连在一起。
      expect(diaryPdfLineSplitter('きょうは'), <String>['きょ', 'う', 'は']);
    });

    test('keeps closing punctuation off the line start and opening '
        'punctuation off the line end', () {
      expect(diaryPdfLineSplitter('他说：“你好”。'), <String>[
        '他',
        '说：',
        '“你',
        '好”。',
      ]);
      expect(diaryPdfLineSplitter('（注）好……'), <String>['（注）', '好……']);
    });

    test('keeps words that start with Latin letters whole and splits the '
        'rest on whitespace', () {
      expect(diaryPdfLineSplitter('iPhone，好 ok'), <String>['iPhone，好', 'ok']);
      expect(diaryPdfLineSplitter('好 ok'), <String>['好', 'ok']);
    });
  });

  group('diaryPdfTextSpan', () {
    const style = pw.TextStyle(fontSize: 12, wordSpacing: 1);

    test('returns a single plain span for text without CJK', () {
      final span = diaryPdfTextSpan('Plain words', style: style, baseline: 2);
      expect(span.text, 'Plain words');
      expect(span.children, isNull);
      expect(span.style, style);
      expect(span.baseline, 2);
    });

    test('splits mixed text into CJK segments without word spacing and '
        'other segments in the original style', () {
      final link = pw.AnnotationUrl('https://example.invalid');
      final span = diaryPdfTextSpan(
        '我用 “iPhone” 拍照。',
        style: style,
        baseline: 2,
        annotation: link,
      );
      expect(span.text, isNull);
      expect(span.annotation, link);
      final children = span.children!.cast<pw.TextSpan>();
      expect(
        <(String?, double?, double)>[
          for (final child in children)
            (child.text, child.style!.wordSpacing, child.baseline),
        ],
        <(String?, double?, double)>[
          ('我用', 0, 2),
          (' “iPhone” ', 1, 2),
          ('拍照。', 0, 2),
        ],
      );
    });
  });
}
