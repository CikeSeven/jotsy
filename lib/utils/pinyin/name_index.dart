import 'package:flutter/foundation.dart';

import 'pinyin_table.dart';

/// 名称的 A–Z 索引：分组字母、按拼音的排序键与拼音检索。
///
/// 输入一个名称（标签名等），输出：
/// - [letter]：首字的字母（汉字取拼音首字母，拉丁字母折成大写），其他开头
///   （数字、符号、表情、假名等）归入 [otherLetter]；
/// - 排序：先按字母（[otherLetter] 排在 Z 之后），再按逐字拼音比较——汉字
///   与英文按读音交错（“爱好 ai hao”排在“Apple”之前），与系统通讯录一致；
/// - [matches]：名称包含检索词，或检索词是拼音（全拼从任一字开始，如
///   “huo”“shenghuo”；或首字母，如“sh”）。
///
/// 汉字读音只取 [pinyinOf] 的单一读音（见 `tool/generate_pinyin_table.dart`），
/// 多音字按最通行的读音归类；纯函数，无副作用。
@immutable
class NameIndexKey {
  const NameIndexKey._(
    this.letter,
    this._sortKey,
    this._folded,
    this._spelling,
    this._boundaries,
    this._initials,
  );

  /// 计算 [name] 的索引键。
  factory NameIndexKey.of(String name) {
    final folded = foldNameForIndex(name);
    // 排序键：每个汉字是一段拼音，连续的其他字符是一段，段间以空格分隔。
    // 空格小于任何字母，逐段比较时“西安 xi an”排在“先 xian”之前。
    final segments = <String>[];
    final spelling = StringBuffer();
    final boundaries = <int>[];
    final initials = StringBuffer();
    final run = StringBuffer();
    var inWord = false;

    void flushRun() {
      inWord = false;
      if (run.isEmpty) return;
      segments.add(run.toString());
      run.clear();
    }

    for (final rune in folded.runes) {
      final syllable = pinyinOf(rune);
      if (syllable != null) {
        flushRun();
        segments.add(syllable);
        boundaries.add(spelling.length);
        spelling.write(syllable);
        initials.write(syllable[0]);
        continue;
      }
      if (_isSeparator(rune)) {
        flushRun();
        continue;
      }
      final alphanumeric = _isAsciiAlphanumeric(rune);
      if (alphanumeric) {
        // 一个英文单词或数字串只在开头记一次首字母与检索起点。
        if (!inWord) {
          boundaries.add(spelling.length);
          initials.writeCharCode(rune);
        }
        spelling.writeCharCode(rune);
      }
      inWord = alphanumeric;
      run.writeCharCode(rune);
    }
    flushRun();

    final first = segments.isEmpty ? null : segments.first.codeUnitAt(0);
    final letter = first != null && first >= 0x61 && first <= 0x7A
        ? String.fromCharCode(first - 0x20)
        : otherLetter;
    return NameIndexKey._(
      letter,
      segments.join(' '),
      folded,
      spelling.toString(),
      boundaries,
      initials.toString(),
    );
  }

  /// 首字不是字母也不是可识别的汉字时的分组。
  static const String otherLetter = '#';

  /// `A`–`Z` 或 [otherLetter]。
  final String letter;

  final String _sortKey;
  final String _folded;
  final String _spelling;
  final List<int> _boundaries;
  final String _initials;

  /// 先按字母分组（[otherLetter] 最后），组内按拼音排序键。相等时返回 0，
  /// 调用方自行以名称或 id 兜底，保证顺序稳定。
  int compareTo(NameIndexKey other) {
    if (letter != other.letter) {
      if (letter == otherLetter) return 1;
      if (other.letter == otherLetter) return -1;
      return letter.compareTo(other.letter);
    }
    return _sortKey.compareTo(other._sortKey);
  }

  /// [query] 由 [normalizeNameQuery] 得到；空检索词匹配一切。
  bool matches(NameQuery query) {
    if (query.isEmpty) return true;
    if (_folded.contains(query.text)) return true;
    final spelled = query.spelling;
    if (spelled == null) return false;
    if (_initials.contains(spelled)) return true;
    for (final start in _boundaries) {
      if (_spelling.startsWith(spelled, start)) return true;
    }
    return false;
  }
}

/// 归一化后的检索词：[text] 用于名称包含匹配，[spelling] 在检索词只含
/// 字母与数字（忽略空格）时给出，用于拼音匹配。
@immutable
class NameQuery {
  const NameQuery._(this.text, this.spelling);

  final String text;
  final String? spelling;

  bool get isEmpty => text.isEmpty;
}

/// 去掉首尾空白并折叠（见 [foldNameForIndex]）。
NameQuery normalizeNameQuery(String raw) {
  final text = foldNameForIndex(raw.trim());
  final compact = text.replaceAll(' ', '');
  final spelled =
      compact.isNotEmpty && compact.runes.every(_isAsciiAlphanumeric)
      ? compact
      : null;
  return NameQuery._(text, spelled);
}

/// 检索与分组前的折叠：全角 ASCII 转半角、常见带附加符号的拉丁字母去掉
/// 附加符号（é → e），再转小写。中文输入法常打出全角字母，“Ｌｉｆｅ”与
/// “life”应当归在同一组、互相检索得到。
String foldNameForIndex(String value) {
  final buffer = StringBuffer();
  for (var rune in value.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      rune -= 0xFEE0;
    } else if (rune == 0x3000) {
      rune = 0x20;
    } else if (rune >= 0xC0 && rune <= 0xFF) {
      final base = _latin1Base.codeUnitAt(rune - 0xC0);
      if (base != 0x2A) rune = base;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString().toLowerCase();
}

/// 汉字 [codePoint] 去声调的拼音（ü 记作 v）；不在表内或没有读音时为 null。
String? pinyinOf(int codePoint) {
  if (codePoint < pinyinTableFirstCodePoint ||
      codePoint > pinyinTableLastCodePoint) {
    return null;
  }
  final offset = (codePoint - pinyinTableFirstCodePoint) * 2;
  final value =
      _digit(pinyinTableData.codeUnitAt(offset)) * 64 +
      _digit(pinyinTableData.codeUnitAt(offset + 1));
  return value == 0 ? null : _syllables[value - 1];
}

/// 音节列表只在第一次查拼音时切分一次。
final List<String> _syllables = pinyinTableSyllables.split(' ');

/// [pinyinTableAlphabet] 的反查：字符 → 0–63。
int _digit(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) return codeUnit - 0x41 + 10;
  if (codeUnit >= 0x61 && codeUnit <= 0x7A) return codeUnit - 0x61 + 36;
  return codeUnit == 0x2D ? 62 : 63;
}

/// U+00C0–U+00FF 对应的基本字母；`*` 表示不是字母（× ÷）或无对应（ß），
/// 原样保留。Æ / æ 取首字母 A。
const String _latin1Base =
    'AAAAAAACEEEEIIII'
    'DNOOOOO*OUUUUY**'
    'aaaaaaaceeeeiiii'
    'dnooooo*ouuuuy*y';

bool _isAsciiAlphanumeric(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || (rune >= 0x61 && rune <= 0x7A);

bool _isSeparator(int rune) =>
    rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0x0D;
