import 'diary_blocks_schema.dart';
import 'diary_blocks_walk.dart';

/// 列表样式：有序列表的编号格式与无序列表的标记形状。
///
/// - 存储：每个列表块的 `data.listStyle`（[kDiaryListStyleKey]），值为下面
///   两个枚举的 `id`。只有用户在工具栏列表面板里选过的列表才有这个键；
/// - 作用范围是“一段列表”，即连续的同类型兄弟块（与序号接着数的范围一致）。
///   面板一次写进整段的每一项；回车新起的项（上游复制属性时不带这个键）、
///   从别处挪进来的项不必改写，经 [resolveDiaryListStyleId] 沿用同段里最近
///   一项的样式；
/// - 整段都没有选过时按嵌套层级轮换（有序 1. → a. → i.，无序 ● → ○ → ■），
///   与引入样式之前的显示一致，旧日记不变；
/// - 认不出的值（更新的版本写入的新样式）原样保留，显示按没有选过处理；
///   换块类型（`updateNodeType` 替换全部属性）时随之丢弃。
///
/// 编辑器标记、导出写出器与模板白名单都只经这里解析与生成序号文字。
const String kDiaryListStyleKey = 'listStyle';

/// 有序列表的编号格式。[label] 生成含标点的序号文字，编辑器与各导出格式
/// 共用；字形都在内置字体（HarmonyOS Sans SC）里，PDF 不会缺字。
enum DiaryOrderedListStyle {
  decimal('decimal'),
  parenthesized('paren'),
  circled('circled'),
  chinese('cjk'),
  lowerAlpha('lower-alpha'),
  upperAlpha('upper-alpha'),
  lowerRoman('lower-roman'),
  upperRoman('upper-roman');

  const DiaryOrderedListStyle(this.id);

  /// 写进 `data.listStyle` 的值。
  final String id;

  static DiaryOrderedListStyle? fromId(Object? value) {
    for (final style in values) {
      if (style.id == value) return style;
    }
    return null;
  }

  /// 没有选过样式时第 [level] 层（同类型祖先的个数）的格式。
  static DiaryOrderedListStyle auto(int level) =>
      const [decimal, lowerAlpha, lowerRoman][level % 3];

  /// 第 [number] 项的序号文字。超出该格式能表示的范围（带圈数字只到 ⑩：
  /// 内置字体没有 ⑪ 以后的字形；罗马数字只到 3999；汉字只到 9999）以及 0、
  /// 负数（起始号可以手改）时退回阿拉伯数字，标点不变的照常带上。
  String label(int number) => switch (this) {
    decimal => '$number.',
    parenthesized => '($number)',
    circled =>
      number >= 1 && number <= 10
          ? String.fromCharCode(0x2460 + number - 1)
          : '$number.',
    chinese => '${_chinese(number) ?? number}、',
    lowerAlpha => '${_alpha(number) ?? number}.',
    upperAlpha => '${_alpha(number)?.toUpperCase() ?? number}.',
    lowerRoman => '${_roman(number) ?? number}.',
    upperRoman => '${_roman(number)?.toUpperCase() ?? number}.',
  };

  static String? _alpha(int number) {
    if (number <= 0) return null;
    final buffer = <String>[];
    for (var value = number; value > 0; value = (value - 1) ~/ 26) {
      buffer.add(String.fromCharCode(97 + (value - 1) % 26));
    }
    return buffer.reversed.join();
  }

  static String? _roman(int number) {
    if (number <= 0 || number >= 4000) return null;
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = [
      'm',
      'cm',
      'd',
      'cd',
      'c',
      'xc',
      'l',
      'xl',
      'x',
      'ix',
      'v',
      'iv',
      'i',
    ];
    var value = number;
    final buffer = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      while (value >= values[i]) {
        buffer.write(symbols[i]);
        value -= values[i];
      }
    }
    return buffer.toString();
  }

  /// 小写汉字数字（一 … 九千九百九十九）：十几写作“十一”而不是“一十一”，
  /// 中间缺位补一个“零”（一百零五、一千零一十）。
  static String? _chinese(int number) {
    if (number <= 0 || number >= 10000) return null;
    const digits = '零一二三四五六七八九';
    const units = ['', '十', '百', '千'];
    final buffer = StringBuffer();
    var pendingZero = false;
    for (var position = 3; position >= 0; position--) {
      var unit = 1;
      for (var i = 0; i < position; i++) {
        unit *= 10;
      }
      final digit = number ~/ unit % 10;
      if (digit == 0) {
        pendingZero = buffer.isNotEmpty;
        continue;
      }
      if (pendingZero) buffer.write('零');
      pendingZero = false;
      if (!(digit == 1 && position == 1 && buffer.isEmpty)) {
        buffer.write(digits[digit]);
      }
      buffer.write(units[position]);
    }
    return buffer.toString();
  }
}

/// 无序列表的标记形状。编辑器自己绘制（见 `DiaryBulletMarker`），导出写
/// [glyph]：都是内置字体里有的字符。
enum DiaryBulletListStyle {
  disc('•'),
  circle('○'),
  square('■'),
  diamond('◆'),
  star('★'),
  arrow('→'),
  dash('–');

  const DiaryBulletListStyle(this.glyph);

  /// 纯文本、PDF、Word 里写在行首的字符。
  final String glyph;

  /// 写进 `data.listStyle` 的值。
  String get id => name;

  static DiaryBulletListStyle? fromId(Object? value) {
    for (final style in values) {
      if (style.id == value) return style;
    }
    return null;
  }

  /// 没有选过样式时第 [level] 层（同类型祖先的个数）的形状。
  static DiaryBulletListStyle auto(int level) =>
      const [disc, circle, square][level % 3];
}

/// [siblings] 中第 [index] 项所在那一段列表（与它相邻、类型相同的兄弟块）
/// 写着的样式值：自己有就用自己的，否则取同段里前面最近的一项，再找后面
/// 最近的一项；整段都没有为 null。只认字符串，类型不对的值当作没有。
///
/// 泛型是为了让编辑器节点（`af.Node`）与存储的 JSON 节点共用同一条规则。
String? resolveDiaryListStyleId<N>(
  List<N> siblings,
  int index, {
  required Object? Function(N node) typeOf,
  required Object? Function(N node) styleOf,
}) {
  String? read(int i) {
    final value = styleOf(siblings[i]);
    return value is String ? value : null;
  }

  final own = read(index);
  if (own != null) return own;
  final type = typeOf(siblings[index]);
  for (var i = index - 1; i >= 0 && typeOf(siblings[i]) == type; i--) {
    final value = read(i);
    if (value != null) return value;
  }
  for (
    var i = index + 1;
    i < siblings.length && typeOf(siblings[i]) == type;
    i++
  ) {
    final value = read(i);
    if (value != null) return value;
  }
  return null;
}

/// 一个块实际显示的列表样式（已按层级补全）；不是有序 / 无序列表时两项都
/// 为 null。
typedef DiaryListStyles = ({
  DiaryOrderedListStyle? ordered,
  DiaryBulletListStyle? bullet,
});

const DiaryListStyles _kNoListStyle = (ordered: null, bullet: null);

/// 按 [walkDiaryBlocks] 的顺序（先序、深度优先）给出每个块实际显示的列表
/// 样式，下标与遍历一一对应。导出解析据此写序号与标记，与编辑器的显示同一
/// 规则：段内沿用、未选过按同类型祖先的个数轮换。
List<DiaryListStyles> diaryListStylesInOrder(Map<String, Object?> document) {
  final result = <DiaryListStyles>[];
  final root = diaryBlocksRoot(document);
  if (root == null) return result;
  void visit(
    List<Map<String, Object?>> nodes, {
    required int orderedLevel,
    required int bulletLevel,
  }) {
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final type = node[kDiaryBlockTypeKey];
      final ordered = type == kDiaryBlockNumberedList;
      final bullet = type == kDiaryBlockBulletedList;
      final id = ordered || bullet
          ? resolveDiaryListStyleId(
              nodes,
              index,
              typeOf: (node) => node[kDiaryBlockTypeKey],
              styleOf: (node) => diaryBlockData(node)[kDiaryListStyleKey],
            )
          : null;
      result.add(
        ordered
            ? (
                ordered:
                    DiaryOrderedListStyle.fromId(id) ??
                    DiaryOrderedListStyle.auto(orderedLevel),
                bullet: null,
              )
            : bullet
            ? (
                ordered: null,
                bullet:
                    DiaryBulletListStyle.fromId(id) ??
                    DiaryBulletListStyle.auto(bulletLevel),
              )
            : _kNoListStyle,
      );
      visit(
        diaryBlockChildren(node),
        orderedLevel: orderedLevel + (ordered ? 1 : 0),
        bulletLevel: bulletLevel + (bullet ? 1 : 0),
      );
    }
  }

  visit(diaryBlockChildren(root), orderedLevel: 0, bulletLevel: 0);
  return result;
}

/// 模板白名单：[type] 的列表块只保留认得的样式值，其余（含别的列表类型的
/// 值）丢弃。
String? sanitizeDiaryListStyleId(Object? type, Object? value) => switch (type) {
  kDiaryBlockNumberedList => DiaryOrderedListStyle.fromId(value)?.id,
  kDiaryBlockBulletedList => DiaryBulletListStyle.fromId(value)?.id,
  _ => null,
};
