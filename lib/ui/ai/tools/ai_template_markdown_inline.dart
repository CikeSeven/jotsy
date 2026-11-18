// 模板 Markdown 的行内部分（写出）：一段行内 Delta → 一行文字；读取见
// `ai_template_markdown_inline_parse.dart`，写法见 `ai_template_markdown.dart`。
// 纯函数，无 IO。

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../diaries/models/diary_text_colors.dart';

/// 一段文字的格式分组：前四个是标签（从外到内，正确嵌套），后三个是开关。
enum _Group { link, span, underline, script, bold, italic, strike }

const List<_Group> _tags = [
  _Group.link,
  _Group.span,
  _Group.underline,
  _Group.script,
];
const List<_Group> _toggles = [_Group.bold, _Group.italic, _Group.strike];

String? _groupValue(
  _Group group,
  Map<String, Object?> attributes,
) => switch (group) {
  _Group.link => attributes[kDiaryInlineHref] as String?,
  _Group.span => _spanStyle(attributes),
  _Group.underline => attributes[kDiaryInlineUnderline] == true ? 'u' : null,
  _Group.script => switch (attributes[kDiaryInlineScript]) {
    kDiaryScriptSuper => 'sup',
    kDiaryScriptSub => 'sub',
    _ => null,
  },
  _Group.bold => attributes[kDiaryInlineBold] == true ? '**' : null,
  _Group.italic => attributes[kDiaryInlineItalic] == true ? '*' : null,
  _Group.strike => attributes[kDiaryInlineStrikethrough] == true ? '~~' : null,
};

String _open(_Group group, String value) => switch (group) {
  _Group.link => '[',
  _Group.span => '<span style="$value">',
  _Group.underline => '<u>',
  _Group.script => '<$value>',
  _ => value,
};

String _close(_Group group, String value) => switch (group) {
  _Group.link => '](${_escapeHref(value)})',
  _Group.span => '</span>',
  _Group.underline => '</u>',
  _Group.script => '</$value>',
  _ => value,
};

String _escapeHref(String href) =>
    href.replaceAll('(', r'\(').replaceAll(')', r'\)').replaceAll(' ', '%20');

/// `color` / `background-color` / `font-size` 合成的 style 值；都没有时为 null。
String? _spanStyle(Map<String, Object?> attributes) {
  final parts = <String>[
    if (_cssColor(attributes[kDiaryInlineTextColor], DiaryColorTarget.text)
        case final color?)
      'color: $color',
    if (_cssColor(
          attributes[kDiaryInlineBackgroundColor],
          DiaryColorTarget.background,
        )
        case final color?)
      'background-color: $color',
    if (_cssSize(attributes[kDiaryInlineSize]) case final size?)
      'font-size: $size',
  ];
  return parts.isEmpty ? null : parts.join('; ');
}

/// 存储的颜色（`#AARRGGBB`）写成预设名，不是预设时写 CSS 十六进制
/// （不透明 `#RRGGBB`，否则 `#RRGGBBAA`）。读不懂的值略去。
String? _cssColor(Object? raw, DiaryColorTarget target) {
  final color = parseDiaryColorValue(raw is String ? raw : null);
  if (color == null) return null;
  final preset = DiaryColorPreset.match(color, target);
  if (preset != null) return preset.name;
  final argb = color.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final alpha = argb >>> 24;
  final hex =
      '#$rgb${alpha == 0xFF ? '' : alpha.toRadixString(16).padLeft(2, '0')}';
  return hex.toUpperCase();
}

String? _cssSize(Object? raw) => switch (raw) {
  final String tier when aiTemplateSizeTiers.contains(tier) => tier,
  final num value when value.isFinite => '$value',
  _ => null,
};

/// 字号档位（与 `kDiaryInlineSize` 的取值一致）。
const Set<String> aiTemplateSizeTiers = <String>{'small', 'large', 'huge'};

/// 普通文字里要加 `\` 的字符（在格子里另加 `|`）。
const String _escapedChars = r'\*`[]<~';

String _escape(String text, {required bool cell}) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_escapedChars.contains(char) || (cell && char == '|')) {
      buffer.write(r'\');
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// 把行内 Delta 写成一行模板 Markdown。[cell] 为表格格子：另外转义 `|`。
/// 行首与行尾的空白写成 `\ `：行首空格本是缩进，行尾空格常被模型或编辑器
/// 顺手去掉。
String aiTemplateInlineMarkdown(
  List<Map<String, Object?>> delta, {
  bool cell = false,
}) {
  final out = StringBuffer();
  final open = <_Group, String>{};

  // 换格式的顺序：先关掉要关的开关（`**` 等），再从第一个变了的标签起由内
  // 向外关、由外向内开，最后打开新的开关。开关只在状态真的变化时写出：
  // 关了再开同一个开关会写出 `****` 这样分不清的一串（开关不要求嵌套，
  // 读取按开关算，见文件顶部）。这样相邻的星号最多三个（关粗体开斜体或
  // 反过来），拆法唯一。
  void switchTo(Map<String, Object?> attributes) {
    for (final group in _toggles.reversed) {
      final value = open[group];
      if (value != null && _groupValue(group, attributes) == null) {
        out.write(value);
        open.remove(group);
      }
    }
    final changed = _tags.where(
      (group) => _groupValue(group, attributes) != open[group],
    );
    if (changed.isNotEmpty) {
      final from = changed.first.index;
      for (final group in _tags.reversed) {
        if (group.index < from) break;
        final value = open.remove(group);
        if (value != null) out.write(_close(group, value));
      }
      for (final group in _tags.skip(from)) {
        final value = _groupValue(group, attributes);
        if (value == null) continue;
        open[group] = value;
        if (group == _Group.link) _escapeTrailingBang(out);
        out.write(_open(group, value));
      }
    }
    for (final group in _toggles) {
      final value = _groupValue(group, attributes);
      if (value != null && open[group] == null) {
        open[group] = value;
        out.write(value);
      }
    }
  }

  for (final run in aiTemplateMergeRuns(delta)) {
    final attributes = run.attributes;
    switchTo(attributes);
    if (attributes[kDiaryInlineCode] == true) {
      // 反引号里的字不转义：带反引号的代码与格子里的代码（可能有 `|`、
      // `<br>`，会被当成拆格）改用 <code> 标签加转义。
      out.write(
        cell || run.text.contains('`')
            ? '<code>${_escape(run.text, cell: cell)}</code>'
            : '`${run.text}`',
      );
      continue;
    }
    var text = _escape(run.text, cell: cell);
    if (out.isEmpty && text.isNotEmpty && _isSpace(text[0])) text = '\\$text';
    out.write(text);
  }
  switchTo(const <String, Object?>{});
  // 行尾是文字里的空白（之后没有任何标记）时补转义；已经转义过的不再加。
  final result = out.toString();
  final cut = result.length - 1;
  if (cut >= 0 && _isSpace(result[cut]) && !_escapedAt(result, cut)) {
    return '${result.substring(0, cut)}\\${result.substring(cut)}';
  }
  return result;
}

bool _isSpace(String char) => char == ' ' || char == '\t';

/// 链接前紧挨着文字里的 `!` 时转义它：否则 `![文字](地址)` 读回来是图片
/// （模板与日记正文都不收，整个去掉），文字与链接一起丢了。
void _escapeTrailingBang(StringBuffer out) {
  final text = out.toString();
  final last = text.length - 1;
  if (last < 0 || text[last] != '!' || _escapedAt(text, last)) return;
  out
    ..clear()
    ..write(text.substring(0, last))
    ..write(r'\!');
}

/// [text] 第 [index] 个字符前是否紧跟奇数个 `\`（即它已被转义）。
bool _escapedAt(String text, int index) {
  var count = 0;
  for (var i = index - 1; i >= 0 && text[i] == r'\'; i--) {
    count++;
  }
  return count.isOdd;
}

/// 相邻、格式完全相同的片段合并；空片段去掉。
List<({String text, Map<String, Object?> attributes})> aiTemplateMergeRuns(
  List<Map<String, Object?>> delta,
) {
  final runs = <({String text, Map<String, Object?> attributes})>[];
  for (final op in delta) {
    final text = op['insert'];
    if (text is! String || text.isEmpty) continue;
    final raw = op['attributes'];
    final attributes = <String, Object?>{
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String && entry.value != null)
            entry.key as String: entry.value,
    };
    if (runs.isNotEmpty &&
        aiTemplateSameAttributes(runs.last.attributes, attributes)) {
      final last = runs.removeLast();
      runs.add((text: last.text + text, attributes: last.attributes));
    } else {
      runs.add((text: text, attributes: attributes));
    }
  }
  return runs;
}

/// 两段文字的行内格式是否完全相同。
bool aiTemplateSameAttributes(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
