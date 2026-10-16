import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/utils/text_stats.dart';

/// 字数口径：汉字与全角标点各算 1，非中文按词，空白不计。
void main() {
  test('Chinese characters and full-width punctuation count one each', () {
    final stats = TextStats.of('今天天气很好，我们去公园玩。');
    expect(stats.cjk, 14);
    expect(stats.latinWords, 0);
    expect(stats.words, 14);
  });

  test('non-Chinese text counts whitespace-separated words', () {
    expect(TextStats.countWords('hello world'), 2);
    expect(TextStats.countWords("Don't stop, e-mail me at 3.14!"), 6);
    // 单独的符号与 emoji 不算词。
    expect(TextStats.countWords('— 😀 !!'), 0);
    // 全角字母数字并入单词。
    expect(TextStats.countWords('ＡＢＣ １２３'), 2);
  });

  test('mixed text splits words at Chinese characters', () {
    final stats = TextStats.of('我用iPhone拍的，走了12000步');
    expect(stats.latinWords, 2);
    expect(stats.cjk, 8);
    expect(stats.words, 10);
  });

  test('shared quotes and ellipses count only next to Chinese', () {
    expect(TextStats.countWords('他说：“你好……”'), 9);
    expect(TextStats.countWords('……开始'), 4);
    expect(TextStats.countWords('“Hello” she said'), 3);
    expect(TextStats.countWords('it’s'), 1);
  });

  test('whitespace, line breaks and embed placeholders are not counted', () {
    final stats = TextStats.of('第一段\n\n￼\n  second line　！');
    expect(stats.words, 6);
    expect(stats.paragraphs, 2);
    expect(stats.characters, 14);
    // 计空格：两个半角空格 + 一个全角空格 + 词间空格。
    expect(stats.charactersWithSpaces, 18);
  });

  test('characters count grapheme clusters', () {
    final stats = TextStats.of('👨‍👩‍👧 家');
    expect(stats.characters, 2);
    expect(stats.charactersWithSpaces, 3);
    expect(stats.words, 1);
  });

  test('empty and blank text have no words and no reading time', () {
    expect(TextStats.of(''), TextStats.empty);
    expect(TextStats.of(' \n\t').words, 0);
    expect(TextStats.of(' \n\t').readingMinutes, 0);
  });

  test('reading time rounds up and is at least one minute', () {
    expect(TextStats.of('短').readingMinutes, 1);
    expect(TextStats.of('字' * 401).readingMinutes, 2);
    expect(TextStats.of(List.filled(200, 'word').join(' ')).readingMinutes, 1);
    expect(TextStats.of(List.filled(201, 'word').join(' ')).readingMinutes, 2);
  });

  test('cached counts refresh when the diary changes', () {
    final at = DateTime(2026, 10, 16);
    expect(
      DiaryWordCounts.of(diaryId: 'cache-1', updatedAt: at, text: '一二三'),
      3,
    );
    // 同一版本命中缓存（文字不再参与计算）。
    expect(DiaryWordCounts.of(diaryId: 'cache-1', updatedAt: at, text: ''), 3);
    expect(
      DiaryWordCounts.of(
        diaryId: 'cache-1',
        updatedAt: at.add(const Duration(minutes: 1)),
        text: '一二',
      ),
      2,
    );
  });
}
