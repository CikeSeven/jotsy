import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:pdf/widgets.dart' as pw;

/// PDF 正文里中日韩文字的断行：配合 pdf 库 [pw.RichText] 的 `lineSplitter`。
///
/// 为什么需要：pdf 库按空白切词，只在词与词之间换行。整段没有空格的中文是
/// 一个“词”，行里已有内容时放不下就整个挪到下一行，只有独占一行时才按行宽
/// 硬切。于是首行缩进之后的整段中文被挤到第二行（缩进看不出来），中英混排
/// 时空格前的几个字单独占一行，两端对齐也无从对齐。
///
/// 做法（与库文档里 CJK 示例同一思路）：
/// - [diaryPdfTextSpan] 把一段文字按断行单位分成中日韩段与其他段，各成一个
///   子片段。库在每个词后补一个空格宽，逐字成词时必须清掉，所以中日韩段的
///   `wordSpacing` 为 0；其他段保持原样式；
/// - [diaryPdfLineSplitter] 把中日韩段切成一个个断行单位，其余文字仍按空白
///   切（与库的默认行为相同）。片段之间库不补空格，各段首尾相接。
///
/// 断行单位是一个字（字素）连同避头尾的标点：收尾标点（，。」等）粘在前一个
/// 字后面，开头标点（（「等）粘在后一个字前面，标点不会落在行首 / 行尾。
///
/// 约束：用了 [diaryPdfLineSplitter] 的 [pw.RichText]，其中每段文字都须经
/// [diaryPdfTextSpan] 生成——不然以中日韩字开头的词会被逐字切开，又按原来的
/// 字间空格排开。没有中日韩文字的片段原样生成，西文排版与改动前一致。

/// 一段文字的 PDF 片段：含中日韩文字时拆成子片段（见文件注释），否则就是
/// 一个普通片段。[baseline] 不会被子片段继承，逐个写上。
pw.TextSpan diaryPdfTextSpan(
  String text, {
  required pw.TextStyle style,
  double baseline = 0,
  pw.AnnotationBuilder? annotation,
}) {
  final segments = _segments(text);
  if (segments == null) {
    return pw.TextSpan(
      text: text,
      style: style,
      baseline: baseline,
      annotation: annotation,
    );
  }
  final cjk = style.copyWith(wordSpacing: 0);
  return pw.TextSpan(
    style: style,
    baseline: baseline,
    annotation: annotation,
    children: <pw.InlineSpan>[
      for (final (text, isCjk) in segments)
        pw.TextSpan(text: text, style: isCjk ? cjk : style, baseline: baseline),
    ],
  );
}

/// [pw.RichText.lineSplitter]：按空白切词（与库的默认相同，连续空白切出的
/// 空串保留空格宽），以中日韩断行单位开头的词再切成一个个断行单位。
List<String> diaryPdfLineSplitter(String line) {
  final words = line.split(RegExp(r'\s'));
  if (!line.runes.any(_isCjkRune)) {
    return words;
  }
  return <String>[
    for (final word in words)
      if (word.isEmpty)
        word
      else
        ...switch (_units(word)) {
          final units when _isCjkUnit(units.first) => units,
          _ => <String>[word],
        },
  ];
}

/// 按断行单位分成 (文字, 是否中日韩) 段，相邻同类的单位并成一段；一个中日韩
/// 单位都没有时为 null。
List<(String, bool)>? _segments(String text) {
  if (!text.runes.any(_isCjkRune)) {
    return null;
  }
  final segments = <(String, bool)>[];
  var hasCjk = false;
  for (final unit in _units(text)) {
    final cjk = _isCjkUnit(unit);
    hasCjk = hasCjk || cjk;
    if (segments.isNotEmpty && segments.last.$2 == cjk) {
      segments.last = (segments.last.$1 + unit, cjk);
    } else {
      segments.add((unit, cjk));
    }
  }
  return hasCjk ? segments : null;
}

/// 切成断行单位：每个字素一个单位，收尾标点并进前一个单位，开头标点并进
/// 后一个单位（文末落单的开头标点自成一个单位）。
List<String> _units(String text) {
  final units = <String>[];
  var opening = '';
  for (final grapheme in text.characters) {
    if (opening.isEmpty &&
        units.isNotEmpty &&
        _noBreakBefore.contains(grapheme)) {
      units.last += grapheme;
    } else if (_noBreakAfter.contains(grapheme)) {
      opening += grapheme;
    } else {
      units.add(opening + grapheme);
      opening = '';
    }
  }
  if (opening.isNotEmpty) {
    units.add(opening);
  }
  return units;
}

/// 单位按它的主体（跳过开头标点后的第一个字）归类；只有开头标点时按标点
/// 本身归类。
bool _isCjkUnit(String unit) {
  final runes = unit.runes;
  final core = runes.firstWhere(
    (int rune) => !_noBreakAfter.contains(String.fromCharCode(rune)),
    orElse: () => runes.first,
  );
  return _isCjkRune(core);
}

/// 可以在字与字之间断行的中日韩字符：部首、标点与符号、假名、注音、谚文、
/// 汉字（含扩展区与兼容区）、竖排与全角形式。表意空格 U+3000 是空白，不算。
bool _isCjkRune(int rune) =>
    (rune >= 0x2E80 && rune <= 0x2FDF) ||
    (rune >= 0x3001 && rune <= 0x303F) ||
    (rune >= 0x3040 && rune <= 0x31FF) ||
    (rune >= 0x3200 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xA960 && rune <= 0xA97F) ||
    (rune >= 0xAC00 && rune <= 0xD7AF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFE30 && rune <= 0xFE4F) ||
    (rune >= 0xFF01 && rune <= 0xFF60) ||
    (rune >= 0xFFE0 && rune <= 0xFFE6) ||
    (rune >= 0x20000 && rune <= 0x3FFFF);

/// 不放在行首的字符（收尾标点、省略号与破折号、日文小假名与长音）。
final Set<String> _noBreakBefore = <String>{
  ...'，。、；：？！）」』】》〉〕〗〙〛｝］｠’”…‥—〜～・ー々ゝゞヽヾ'.characters,
  ...'ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ'.characters,
  ...',.;:?!)]}%'.characters,
};

/// 不放在行尾的字符（开头标点）。
final Set<String> _noBreakAfter = <String>{
  ...'（「『【《〈〔〖〘〚｛［｟‘“'.characters,
  ...'([{'.characters,
};
