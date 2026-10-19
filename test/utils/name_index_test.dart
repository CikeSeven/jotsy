import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/utils/pinyin/name_index.dart';
import 'package:node_diary/utils/pinyin/pinyin_table.dart';

List<String> _sorted(List<String> names) {
  final keys = {for (final name in names) name: NameIndexKey.of(name)};
  return [...names]..sort((a, b) {
    final order = keys[a]!.compareTo(keys[b]!);
    return order != 0 ? order : a.compareTo(b);
  });
}

bool _matches(String name, String query) =>
    NameIndexKey.of(name).matches(normalizeNameQuery(query));

/// 名称的 A–Z 索引：汉字按拼音归组排序，支持拼音检索。
void main() {
  test('the table covers the CJK block with toneless syllables', () {
    expect(pinyinTableData.length, 2 * (0x9FFF - 0x4E00 + 1));
    expect(pinyinOf('生'.runes.single), 'sheng');
    expect(pinyinOf('活'.runes.single), 'huo');
    // ü 记作 v，多音字取最通行的读音。
    expect(pinyinOf('绿'.runes.single), 'lv');
    expect(pinyinOf('行'.runes.single), 'xing');
    expect(pinyinOf('a'.runes.single), isNull);
    expect(pinyinOf('😀'.runes.single), isNull);
  });

  test('the letter comes from the first character', () {
    expect(NameIndexKey.of('生活').letter, 'S');
    expect(NameIndexKey.of('travel').letter, 'T');
    // 全角字母与带附加符号的字母先折叠。
    expect(NameIndexKey.of('Ｌｉｆｅ').letter, 'L');
    expect(NameIndexKey.of('École').letter, 'E');
    // 数字、符号、表情与假名开头的归入 #。
    for (final name in ['2024', '🎵音乐', '#旅行', 'さくら']) {
      expect(NameIndexKey.of(name).letter, NameIndexKey.otherLetter);
    }
  });

  test('names sort by pinyin with Latin names interleaved and # last', () {
    expect(_sorted(['旅行', '2024', 'Apple', '爱好', '读书', 'banana', '摄影', '生活']), [
      '爱好',
      'Apple',
      'banana',
      '读书',
      '旅行',
      '摄影',
      '生活',
      '2024',
    ]);
  });

  test('syllables compare one by one', () {
    // “西安 xi an”在“先 xian”之前，“摄影 she”在“生活 sheng”之前。
    expect(_sorted(['先', '西安']), ['西安', '先']);
    expect(_sorted(['生活', '摄影']), ['摄影', '生活']);
  });

  test('a query matches the name, full pinyin from any character, or '
      'initials', () {
    expect(_matches('生活', '活'), isTrue);
    expect(_matches('生活', 'shenghuo'), isTrue);
    expect(_matches('生活', 'sheng huo'), isTrue);
    expect(_matches('生活', 'huo'), isTrue);
    expect(_matches('生活', 'shengh'), isTrue);
    expect(_matches('生活', 'sh'), isTrue);
    expect(_matches('生活', 'SH'), isTrue);
    // 拼音只从字的开头匹配：“eng”不是任何字的开头。
    expect(_matches('生活', 'eng'), isFalse);
    expect(_matches('生活', 'travel'), isFalse);
  });

  test('Latin names match case-insensitively and by word initials', () {
    expect(_matches('Travel Notes', 'notes'), isTrue);
    expect(_matches('Travel Notes', 'tn'), isTrue);
    expect(_matches('Ｌｉｆｅ', 'life'), isTrue);
    expect(_matches('AI绘画', 'aihh'), isFalse);
    expect(_matches('AI绘画', 'ahh'), isTrue);
    expect(_matches('AI绘画', 'huihua'), isTrue);
  });

  test('an empty or blank query matches everything', () {
    expect(_matches('生活', ''), isTrue);
    expect(_matches('生活', '   '), isTrue);
    expect(normalizeNameQuery('  ').isEmpty, isTrue);
  });
}
