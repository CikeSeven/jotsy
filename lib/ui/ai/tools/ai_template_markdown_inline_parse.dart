// 模板 Markdown 的行内部分（读取）：一行文字 → 行内 Delta；写出见
// `ai_template_markdown_inline.dart`。纯函数，无 IO。
//
// 为什么不用 markdown 包的 CommonMark 解析：它按左右侧规则判断 `**` 能否
// 开闭，中文全角标点紧挨着时（`**心情：**今天`）粗体认不出来，原样留下
// 星号；模型写中文模板时几乎必然碰上。这里的 `*` 与 `~~` 是成对的“开关”：
// 一行里按出现顺序两两配对，落单的最后一个原样留作文字。写出时同一种
// 格式总是成对出现，所以读写对称。`_` 一律是普通文字：模板里常用 `____`
// 当填空线，不能被当成斜体。

import 'dart:ui' show Color;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../diaries/models/diary_text_colors.dart';
import 'ai_template_markdown_inline.dart';

sealed class _Token {
  const _Token(this.source);

  /// 原文：配不上对时按文字留下。
  final String source;
}

class _Text extends _Token {
  const _Text(super.source);
}

/// 一串 `*`：按个数拆成 n ~/ 2 个粗体开关与 n % 2 个斜体开关。
class _Stars extends _Token {
  _Stars(super.source) : bold = source.length ~/ 2, italic = source.length % 2;

  int bold;
  int italic;
}

/// 一串 `~`：n ~/ 2 个删除线开关，落单的一个原样留下。
class _Tildes extends _Token {
  _Tildes(super.source) : strike = source.length ~/ 2;

  int strike;
}

class _Code extends _Token {
  const _Code(super.source, this.text);

  final String text;
}

class _LinkOpen extends _Token {
  _LinkOpen(super.source, {required this.image});

  final bool image;
  _LinkClose? partner;
}

class _LinkClose extends _Token {
  _LinkClose(super.source, this.href);

  final String href;
  bool paired = false;

  /// 配上的是图片的开头：只用来结束跳过。
  bool image = false;
}

class _Tag extends _Token {
  const _Tag(super.source, this.name, {required this.closing});

  final String name;
  final bool closing;
}

/// 认得的行内标签；其余尖括号原样是文字。
const Set<String> _knownTags = <String>{
  'b', 'strong', 'i', 'em', 'u', 'ins', 's', 'del', 'strike', 'code', //
  'span', 'font', 'mark', 'sup', 'sub', 'br',
};

final RegExp _tagPattern = RegExp(
  r'''<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[a-zA-Z-]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'<>]+))?)*)\s*/?>''',
);

List<_Token> _tokenize(String line) {
  final tokens = <_Token>[];
  final text = StringBuffer();
  void flush() {
    if (text.isEmpty) return;
    tokens.add(_Text(text.toString()));
    text.clear();
  }

  var i = 0;
  while (i < line.length) {
    final char = line[i];
    if (char == r'\') {
      if (i + 1 < line.length) {
        // 转义一个完整的字符（含代理对）。
        final unit = line.codeUnitAt(i + 1);
        final width = unit >= 0xD800 && unit <= 0xDBFF && i + 2 < line.length
            ? 2
            : 1;
        text.write(line.substring(i + 1, i + 1 + width));
        i += 1 + width;
      } else {
        text.write(char);
        i++;
      }
      continue;
    }
    if (char == '`') {
      final run = _runLength(line, i, '`');
      final close = _findRun(line, i + run, '`', run);
      if (close < 0) {
        text.write(line.substring(i, i + run));
        i += run;
        continue;
      }
      flush();
      tokens.add(
        _Code(line.substring(i, close + run), line.substring(i + run, close)),
      );
      i = close + run;
      continue;
    }
    if (char == '<') {
      final match = _tagPattern.matchAsPrefix(line, i);
      final name = match?.group(2)?.toLowerCase();
      if (match != null && name != null && _knownTags.contains(name)) {
        flush();
        tokens.add(_Tag(match.group(0)!, name, closing: match.group(1) == '/'));
        i = match.end;
        continue;
      }
      text.write(char);
      i++;
      continue;
    }
    if (char == '*' || char == '~') {
      final run = _runLength(line, i, char);
      flush();
      final source = line.substring(i, i + run);
      tokens.add(char == '*' ? _Stars(source) : _Tildes(source));
      i += run;
      continue;
    }
    if (char == '!' && i + 1 < line.length && line[i + 1] == '[') {
      flush();
      tokens.add(_LinkOpen('![', image: true));
      i += 2;
      continue;
    }
    if (char == '[') {
      flush();
      tokens.add(_LinkOpen('[', image: false));
      i++;
      continue;
    }
    if (char == ']' && i + 1 < line.length && line[i + 1] == '(') {
      final end = _linkEnd(line, i + 2);
      if (end >= 0) {
        flush();
        tokens.add(
          _LinkClose(
            line.substring(i, end + 1),
            _linkHref(line.substring(i + 2, end)),
          ),
        );
        i = end + 1;
        continue;
      }
    }
    text.write(char);
    i++;
  }
  flush();
  return tokens;
}

int _runLength(String line, int start, String char) {
  var end = start;
  while (end < line.length && line[end] == char) {
    end++;
  }
  return end - start;
}

/// 从 [from] 起找一串恰好 [length] 个 [char]；没有时为 -1。
int _findRun(String line, int from, String char, int length) {
  var i = from;
  while (i < line.length) {
    if (line[i] != char) {
      i++;
      continue;
    }
    final run = _runLength(line, i, char);
    if (run == length) return i;
    i += run;
  }
  return -1;
}

/// 链接地址的右括号位置（地址里的 `\)` 与成对的括号跳过）；没有时为 -1。
int _linkEnd(String line, int from) {
  var depth = 0;
  for (var i = from; i < line.length; i++) {
    final char = line[i];
    if (char == r'\') {
      i++;
    } else if (char == '(') {
      depth++;
    } else if (char == ')') {
      if (depth == 0) return i;
      depth--;
    }
  }
  return -1;
}

String _linkHref(String raw) {
  var href = raw.trim().replaceAll(r'\)', ')').replaceAll(r'\(', '(');
  if (href.startsWith('<') && href.endsWith('>')) {
    href = href.substring(1, href.length - 1);
  }
  // 去掉可选的标题：[文字](https://… "标题")
  final space = href.indexOf(RegExp(r'\s'));
  if (space > 0) href = href.substring(0, space);
  return href;
}

/// 一行模板 Markdown 读成行内 Delta（相邻同格式的片段已合并）。不认的
/// 格式与配不上对的标记按文字留下；图片 `![…](…)` 整个去掉（模板不放
/// 媒体）；`<br>` 去掉（模板正文一行就是一个块）。
List<Map<String, Object?>> aiTemplateInlineDelta(String line) {
  final tokens = _tokenize(line);
  _pairToggles(tokens);
  _pairLinks(tokens);

  final ops = <Map<String, Object?>>[];
  var bold = false;
  var italic = false;
  var strike = false;
  final depth = <String, int>{};
  final styles = <({String tag, Map<String, Object?> style})>[];
  final links = <String>[];
  var skipping = 0;

  Map<String, Object?> attributes() {
    final result = <String, Object?>{};
    for (final entry in styles) {
      result.addAll(entry.style);
    }
    if (bold || (depth['b'] ?? 0) > 0) result[kDiaryInlineBold] = true;
    if (italic || (depth['i'] ?? 0) > 0) result[kDiaryInlineItalic] = true;
    if (strike || (depth['s'] ?? 0) > 0) {
      result[kDiaryInlineStrikethrough] = true;
    }
    if ((depth['u'] ?? 0) > 0) result[kDiaryInlineUnderline] = true;
    if ((depth['code'] ?? 0) > 0) result[kDiaryInlineCode] = true;
    if (links.isNotEmpty) result[kDiaryInlineHref] = links.last;
    return result;
  }

  void add(String text, [Map<String, Object?> extra = const {}]) {
    if (text.isEmpty || skipping > 0) return;
    final attrs = {...attributes(), ...extra};
    if (ops.isNotEmpty && aiTemplateSameAttributes(_attrs(ops.last), attrs)) {
      ops.last['insert'] = '${ops.last['insert']}$text';
      return;
    }
    ops.add(<String, Object?>{
      'insert': text,
      if (attrs.isNotEmpty) 'attributes': attrs,
    });
  }

  for (final token in tokens) {
    switch (token) {
      case _Text(:final source):
        add(source);
      case _Code(:final text):
        add(text, const {kDiaryInlineCode: true});
      case final _Stars stars:
        if (stars.bold.isOdd) bold = !bold;
        if (stars.italic.isOdd) italic = !italic;
        final used = stars.bold * 2 + stars.italic;
        add(stars.source.substring(0, stars.source.length - used));
      case final _Tildes tildes:
        if (tildes.strike.isOdd) strike = !strike;
        final used = tildes.strike * 2;
        add(tildes.source.substring(0, tildes.source.length - used));
      case final _LinkOpen open:
        final partner = open.partner;
        if (partner == null) {
          add(open.source);
        } else if (open.image) {
          skipping++;
        } else {
          links.add(partner.href);
        }
      case final _LinkClose close:
        if (!close.paired) {
          add(close.source);
        } else if (close.image) {
          skipping--;
        } else if (links.isNotEmpty) {
          links.removeLast();
        }
      case final _Tag tag:
        _applyTag(tag, depth, styles);
    }
  }
  return ops;
}

Map<String, Object?> _attrs(Map<String, Object?> op) {
  final attributes = op['attributes'];
  return attributes is Map<String, Object?>
      ? attributes
      : const <String, Object?>{};
}

/// 每种开关在一行里两两配对，落单的最后一个改回文字（从它所在的那串里
/// 扣掉，剩下的字符原样留下）。
void _pairToggles(List<_Token> tokens) {
  final stars = tokens.whereType<_Stars>().toList();
  final tildes = tokens.whereType<_Tildes>().toList();
  if (stars.fold(0, (sum, t) => sum + t.bold).isOdd) {
    stars.lastWhere((t) => t.bold > 0).bold--;
  }
  if (stars.fold(0, (sum, t) => sum + t.italic).isOdd) {
    stars.lastWhere((t) => t.italic > 0).italic--;
  }
  if (tildes.fold(0, (sum, t) => sum + t.strike).isOdd) {
    tildes.lastWhere((t) => t.strike > 0).strike--;
  }
}

/// `[` 与其后最近的、尚未配对的 `](地址)` 配对（嵌套时内层先配）。
void _pairLinks(List<_Token> tokens) {
  final stack = <_LinkOpen>[];
  for (final token in tokens) {
    if (token is _LinkOpen) {
      stack.add(token);
    } else if (token is _LinkClose && stack.isNotEmpty) {
      final open = stack.removeLast();
      open.partner = token;
      token
        ..paired = true
        ..image = open.image;
    }
  }
}

void _applyTag(
  _Tag tag,
  Map<String, int> depth,
  List<({String tag, Map<String, Object?> style})> styles,
) {
  final flag = switch (tag.name) {
    'b' || 'strong' => 'b',
    'i' || 'em' => 'i',
    's' || 'del' || 'strike' => 's',
    'u' || 'ins' => 'u',
    'code' => 'code',
    _ => null,
  };
  if (flag != null) {
    final next = (depth[flag] ?? 0) + (tag.closing ? -1 : 1);
    depth[flag] = next < 0 ? 0 : next;
    return;
  }
  if (tag.name == 'br') return;
  if (tag.closing) {
    final index = styles.lastIndexWhere((entry) => entry.tag == tag.name);
    if (index >= 0) styles.removeAt(index);
    return;
  }
  styles.add((tag: tag.name, style: _tagStyle(tag.name, tag.source)));
}

final RegExp _attributePattern = RegExp(
  r'''([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>/]+))''',
);

/// 标签带来的行内格式：`<span style>`、`<font color>`、`<mark>`、`<sup>` / `<sub>`。
Map<String, Object?> _tagStyle(String name, String source) {
  final attributes = <String, String>{
    for (final match in _attributePattern.allMatches(source))
      match.group(1)!.toLowerCase():
          match.group(2) ?? match.group(3) ?? match.group(4) ?? '',
  };
  final result = <String, Object?>{};
  switch (name) {
    case 'sup':
      result[kDiaryInlineScript] = kDiaryScriptSuper;
    case 'sub':
      result[kDiaryInlineScript] = kDiaryScriptSub;
    case 'mark':
      result[kDiaryInlineBackgroundColor] = encodeDiaryColor(
        DiaryColorPreset.yellow.colorFor(DiaryColorTarget.background),
      );
    case 'font':
      if (_parseColor(attributes['color'], DiaryColorTarget.text)
          case final color?) {
        result[kDiaryInlineTextColor] = encodeDiaryColor(color);
      }
  }
  final style = attributes['style'];
  if (style == null) return result;
  for (final declaration in style.split(';')) {
    final colon = declaration.indexOf(':');
    if (colon < 0) continue;
    final property = declaration.substring(0, colon).trim().toLowerCase();
    final value = declaration.substring(colon + 1).trim();
    switch (property) {
      case 'color':
        if (_parseColor(value, DiaryColorTarget.text) case final color?) {
          result[kDiaryInlineTextColor] = encodeDiaryColor(color);
        }
      case 'background-color' || 'background':
        if (_parseColor(value, DiaryColorTarget.background) case final color?) {
          result[kDiaryInlineBackgroundColor] = encodeDiaryColor(color);
        }
      case 'font-size':
        if (_parseSize(value) case final size?) result[kDiaryInlineSize] = size;
      case 'vertical-align':
        switch (value.toLowerCase()) {
          case 'super':
            result[kDiaryInlineScript] = kDiaryScriptSuper;
          case 'sub':
            result[kDiaryInlineScript] = kDiaryScriptSub;
        }
      case 'font-weight':
        if (value == 'bold' || RegExp(r'^[6-9]00$').hasMatch(value)) {
          result[kDiaryInlineBold] = true;
        }
      case 'font-style':
        if (value == 'italic') result[kDiaryInlineItalic] = true;
      case 'text-decoration' || 'text-decoration-line':
        if (value.contains('underline')) {
          result[kDiaryInlineUnderline] = true;
        }
        if (value.contains('line-through')) {
          result[kDiaryInlineStrikethrough] = true;
        }
    }
  }
  return result;
}

Object? _parseSize(String raw) {
  final value = raw.trim().toLowerCase();
  if (aiTemplateSizeTiers.contains(value)) return value;
  if (value == 'x-large' || value == 'xx-large') return 'huge';
  if (value == 'x-small' || value == 'smaller') return 'small';
  if (value == 'larger') return 'large';
  final number = num.tryParse(value);
  if (number == null || !number.isFinite || number <= 0) return null;
  return number == number.truncate() ? number.toInt() : number;
}

final RegExp _hexColor = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$');
final RegExp _rgbColor = RegExp(
  r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+%?)\s*)?\)$',
);

/// CSS 颜色：预设名（与颜色面板同名，按 [target] 取文字色或背景色）、
/// `#RGB`、`#RRGGBB`、`#RRGGBBAA`、`rgb()` / `rgba()`；其他写法为 null。
Color? _parseColor(String? raw, DiaryColorTarget target) {
  if (raw == null) return null;
  final value = raw.trim().toLowerCase();
  for (final preset in DiaryColorPreset.values) {
    if (preset.name == value) return preset.colorFor(target);
  }
  if (value == 'grey') return DiaryColorPreset.gray.colorFor(target);
  final hex = _hexColor.firstMatch(value);
  if (hex != null) {
    var digits = hex.group(1)!;
    if (digits.length == 3) {
      digits = digits.split('').map((d) => '$d$d').join();
    }
    final rgb = int.parse(digits.substring(0, 6), radix: 16);
    final alpha = digits.length == 8
        ? int.parse(digits.substring(6), radix: 16)
        : 0xFF;
    return Color((alpha << 24) | rgb);
  }
  final rgb = _rgbColor.firstMatch(value);
  if (rgb != null) {
    int channel(int group) => int.parse(rgb.group(group)!).clamp(0, 255);
    var alpha = 0xFF;
    final rawAlpha = rgb.group(4);
    if (rawAlpha != null) {
      final number = rawAlpha.endsWith('%')
          ? (double.tryParse(rawAlpha.substring(0, rawAlpha.length - 1)) ??
                    100) /
                100
          : double.tryParse(rawAlpha) ?? 1;
      alpha = (number.clamp(0, 1) * 255).round();
    }
    return Color.fromARGB(alpha, channel(1), channel(2), channel(3));
  }
  return null;
}
