import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_list_style.dart';

/// 列表样式的序号文字、“一段列表共用样式”的解析规则与按文档顺序给出的
/// 实际样式（导出解析用）。
Map<String, Object?> _item(
  String type, {
  String? style,
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': 'x'},
    ],
    'listStyle': ?style,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _doc(List<Map<String, Object?>> children) => {
  'document': {'type': 'page', 'children': children},
};

const _numbered = 'numbered_list';
const _bulleted = 'bulleted_list';

void main() {
  group('ordered labels', () {
    test('each format renders its own numbering and punctuation', () {
      String labels(DiaryOrderedListStyle style) =>
          [1, 2, 3].map(style.label).join(' ');

      expect(labels(DiaryOrderedListStyle.decimal), '1. 2. 3.');
      expect(labels(DiaryOrderedListStyle.parenthesized), '(1) (2) (3)');
      expect(labels(DiaryOrderedListStyle.circled), '① ② ③');
      expect(labels(DiaryOrderedListStyle.chinese), '一、 二、 三、');
      expect(labels(DiaryOrderedListStyle.lowerAlpha), 'a. b. c.');
      expect(labels(DiaryOrderedListStyle.upperAlpha), 'A. B. C.');
      expect(labels(DiaryOrderedListStyle.lowerRoman), 'i. ii. iii.');
      expect(labels(DiaryOrderedListStyle.upperRoman), 'I. II. III.');
    });

    test('letters continue past z like spreadsheet columns', () {
      const style = DiaryOrderedListStyle.lowerAlpha;
      expect(style.label(26), 'z.');
      expect(style.label(27), 'aa.');
      expect(style.label(52), 'az.');
      expect(DiaryOrderedListStyle.upperAlpha.label(28), 'AB.');
    });

    test('Chinese numerals read naturally, with 零 for gaps', () {
      const style = DiaryOrderedListStyle.chinese;
      expect(style.label(10), '十、');
      expect(style.label(11), '十一、');
      expect(style.label(20), '二十、');
      expect(style.label(105), '一百零五、');
      expect(style.label(110), '一百一十、');
      expect(style.label(1010), '一千零一十、');
      expect(style.label(9999), '九千九百九十九、');
    });

    test('out-of-range numbers fall back to Arabic numerals', () {
      // 内置字体只有 ①–⑩。
      expect(DiaryOrderedListStyle.circled.label(10), '⑩');
      expect(DiaryOrderedListStyle.circled.label(11), '11.');
      expect(DiaryOrderedListStyle.upperRoman.label(4000), '4000.');
      expect(DiaryOrderedListStyle.chinese.label(10000), '10000、');
      // 起始号可以手改成 0 或负数。
      expect(DiaryOrderedListStyle.lowerAlpha.label(0), '0.');
      expect(DiaryOrderedListStyle.lowerRoman.label(-2), '-2.');
    });

    test('auto rotates 1. → a. → i. by nesting level', () {
      expect(DiaryOrderedListStyle.auto(0), DiaryOrderedListStyle.decimal);
      expect(DiaryOrderedListStyle.auto(1), DiaryOrderedListStyle.lowerAlpha);
      expect(DiaryOrderedListStyle.auto(2), DiaryOrderedListStyle.lowerRoman);
      expect(DiaryOrderedListStyle.auto(3), DiaryOrderedListStyle.decimal);
      expect(DiaryBulletListStyle.auto(1), DiaryBulletListStyle.circle);
      expect(DiaryBulletListStyle.auto(5), DiaryBulletListStyle.square);
    });
  });

  group('resolveDiaryListStyleId', () {
    String? resolve(List<Map<String, Object?>> siblings, int index) =>
        resolveDiaryListStyleId(
          siblings,
          index,
          typeOf: (node) => node['type'],
          styleOf: (node) => (node['data'] as Map)['listStyle'],
        );

    test('an item without a style follows the nearest styled item', () {
      final run = [
        _item(_numbered, style: 'lower-alpha'),
        _item(_numbered),
        _item(_numbered),
      ];
      expect(resolve(run, 0), 'lower-alpha');
      expect(resolve(run, 2), 'lower-alpha');
    });

    test('a leading item without a style looks ahead in its run', () {
      final run = [_item(_numbered), _item(_numbered, style: 'circled')];
      expect(resolve(run, 0), 'circled');
    });

    test('runs end where the block type changes', () {
      final siblings = [
        _item(_numbered, style: 'cjk'),
        _item('paragraph'),
        _item(_numbered),
        _item(_bulleted, style: 'star'),
      ];
      expect(resolve(siblings, 2), isNull);
      expect(resolve(siblings, 3), 'star');
    });

    test('values that are not strings count as unset', () {
      final run = [
        _item(_bulleted, style: 'diamond'),
        {
          'type': _bulleted,
          'data': {'listStyle': 3},
        },
      ];
      expect(resolve(run, 1), 'diamond');
    });
  });

  test('styles in document order follow the run and the nesting level', () {
    final document = _doc([
      _item(
        _numbered,
        style: 'upper-roman',
        children: [
          _item(_numbered),
          _item(_bulleted, children: [_item(_bulleted)]),
        ],
      ),
      _item(_numbered),
      _item('paragraph'),
      _item(_bulleted, style: 'unknown-shape'),
    ]);

    final styles = diaryListStylesInOrder(document);

    expect(styles.map((s) => s.ordered ?? s.bullet), [
      DiaryOrderedListStyle.upperRoman,
      // 嵌套的有序列表是另一段：没选过，按第 1 层轮换。
      DiaryOrderedListStyle.lowerAlpha,
      // 无序列表只数无序祖先：仍是第 0 层。
      DiaryBulletListStyle.disc,
      DiaryBulletListStyle.circle,
      // 同段沿用首项的样式。
      DiaryOrderedListStyle.upperRoman,
      null,
      // 认不出的值按没选过显示。
      DiaryBulletListStyle.disc,
    ]);
  });

  test('templates keep only styles that belong to the list type', () {
    expect(sanitizeDiaryListStyleId(_numbered, 'lower-alpha'), 'lower-alpha');
    expect(sanitizeDiaryListStyleId(_bulleted, 'star'), 'star');
    expect(sanitizeDiaryListStyleId(_bulleted, 'lower-alpha'), isNull);
    expect(sanitizeDiaryListStyleId('paragraph', 'star'), isNull);
    expect(sanitizeDiaryListStyleId(_numbered, 42), isNull);
  });
}
