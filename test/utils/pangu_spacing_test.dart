import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/utils/pangu_spacing.dart';

void main() {
  group('findPanguGapRanges', () {
    test('marks the preceding grapheme at every CJK-Western boundary', () {
      const text = '用Flutter写3行代码';
      final gaps = findPanguGapRanges(text);

      expect(gaps, const <(int, int)>[(0, 1), (7, 8), (8, 9), (9, 10)]);
      expect(
        [for (final (s, e) in gaps) text.substring(s, e)],
        const <String>['用', 'r', '写', '3'],
      );
    });

    test('does not double-space when manual whitespace already exists', () {
      expect(findPanguGapRanges('用 Flutter 写 3 行代码'), isEmpty);
      expect(findPanguGapRanges('中文\nEnglish\t123'), isEmpty);
    });

    test('ignores full-width and half-width punctuation and symbols', () {
      expect(findPanguGapRanges('你好，Flutter！（2026）'), isEmpty);
      expect(findPanguGapRanges('#标签 @提及 a/b (注释)'), isEmpty);
      expect(findPanguGapRanges(''), isEmpty);
      expect(findPanguGapRanges('中'), isEmpty);
      expect(findPanguGapRanges('纯中文没有任何西文'), isEmpty);
      expect(findPanguGapRanges('Pure English 123'), isEmpty);
    });

    test('supports kana, hangul, cyrillic, and accented Latin letters', () {
      const ja = '日本語とEnglish';
      expect(
        [for (final (s, e) in findPanguGapRanges(ja)) ja.substring(s, e)],
        const <String>['と'],
      );
      // 片假名中点 U+30FB 属于标点，不加间距。
      expect(findPanguGapRanges('東京・Tokyo'), isEmpty);

      const ko = '한국어123テスト';
      expect(
        [for (final (s, e) in findPanguGapRanges(ko)) ko.substring(s, e)],
        const <String>['어', '3'],
      );

      const ru = '学习Привет世界';
      expect(
        [for (final (s, e) in findPanguGapRanges(ru)) ru.substring(s, e)],
        const <String>['习', 'т'],
      );

      // 预组与组合变音符均作为完整字素，不拆开组合标记。
      const precomposed = '咖啡café馆';
      expect(
        [
          for (final (s, e) in findPanguGapRanges(precomposed))
            precomposed.substring(s, e),
        ],
        const <String>['啡', 'é'],
      );
      const combining = '咖啡cafe\u0301馆';
      expect(
        [
          for (final (s, e) in findPanguGapRanges(combining))
            combining.substring(s, e),
        ],
        const <String>['啡', 'e\u0301'],
      );
    });

    test('keeps surrogate-pair CJK glyphs intact and skips keycap emoji', () {
      // 𠮷 为补充平面汉字（UTF-16 占 2 码元）。
      const ext = '扩展𠮷123';
      final gaps = findPanguGapRanges(ext);
      expect(gaps, const <(int, int)>[(2, 4)]);
      expect(ext.substring(gaps.single.$1, gaps.single.$2), '𠮷');

      expect(findPanguGapRanges('1️⃣中文'), isEmpty);
      expect(findPanguGapRanges('中文1️⃣'), isEmpty);
    });

    test('skips IME composing range and its adjacent boundaries', () {
      // 用户输入“今天”后正在拼写未上屏的 “tianqi”，再后面是原有英文或汉字。
      const text = '今天tianqi很好';
      expect(findPanguGapRanges(text, excludeStart: 2, excludeEnd: 8), isEmpty);
      // 组字区间之外的其他边界仍保留。
      const mixed = '写1篇今天tianqi记2笔';
      final gaps = findPanguGapRanges(mixed, excludeStart: 5, excludeEnd: 11);
      expect(
        [for (final (s, e) in gaps) mixed.substring(s, e)],
        const <String>['写', '1', '记', '2'],
      );
    });

    test(
      'respects ignoreAt (superscripts) and skipTrailingAt (inline code)',
      () {
        // 上下标：左右两侧均不触发。
        const scriptText = '注解1说明';
        expect(
          findPanguGapRanges(scriptText, ignoreAt: (int offset) => offset == 2),
          isEmpty,
        );

        // 行内代码：左侧普通中文触发，行内代码自身尾部跳过。
        const codeText = '用Flutter写';
        final gaps = findPanguGapRanges(
          codeText,
          skipTrailingAt: (int offset) => offset >= 1 && offset < 8,
        );
        expect(gaps, const <(int, int)>[(0, 1)]);
      },
    );
  });

  group('hasPanguBoundaryBetween', () {
    test('detects cross-run CJK-Western boundaries without punctuation', () {
      expect(hasPanguBoundaryBetween('今天用', 'Flutter'), isTrue);
      expect(hasPanguBoundaryBetween('Flutter', '写日记'), isTrue);
      expect(hasPanguBoundaryBetween('今天用 ', 'Flutter'), isFalse);
      expect(hasPanguBoundaryBetween('今天，', 'Flutter'), isFalse);
      expect(hasPanguBoundaryBetween('', 'Flutter'), isFalse);
    });
  });

  test('panguSpacingExtent scales linearly with positive font sizes', () {
    expect(panguSpacingExtent(16), closeTo(3.2, 0.0001));
    expect(panguSpacingExtent(0), 0);
    expect(panguSpacingExtent(-4), 0);
  });
}
