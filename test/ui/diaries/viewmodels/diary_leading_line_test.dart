import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_leading_line.dart';

void main() {
  test('skips blank lines and collapses whitespace in the first line', () {
    const text = '\n  \n  今天\t下雨了  \n一整天没出门\n第三行';
    final leading = DiaryLeadingLine.of(text)!;
    expect(leading.line, '今天 下雨了');
    expect(leading.restOf(text), '一整天没出门\n第三行');
  });

  test('a single line leaves nothing after it', () {
    const text = '只有一行';
    final leading = DiaryLeadingLine.of(text)!;
    expect(leading.line, '只有一行');
    expect(leading.restStart, text.length);
    expect(leading.restOf(text), isEmpty);
  });

  test('text without visible characters has no first line', () {
    expect(DiaryLeadingLine.of(''), isNull);
    expect(DiaryLeadingLine.of('\n \n\t\n'), isNull);
  });

  test('maxLength cuts a long first line but keeps the rest offset', () {
    final text = '${'字' * 500}\n下一行';
    final leading = DiaryLeadingLine.of(text, maxLength: 240)!;
    expect(leading.line.length, 240);
    expect(leading.restOf(text), '下一行');
  });
}
