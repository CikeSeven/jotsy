import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

/// 正文查找与替换的纯计算部分：查找条件、编译成正则、在块文档里逐块找出
/// 匹配，以及正则替换串里的分组引用展开。不读布局、不改文档（改写见
/// `controllers/diary_find_replace.dart`）。
///
/// 口径：
/// - 只在有文字的块（`node.delta`）里找，按阅读顺序（先序）逐块匹配，匹配
///   不跨块——段落、列表项、表格的格子、代码块各是一段文字；纯文本里的
///   `^` / `$` 按块的开头与结尾（块内的软换行同样算行界，`multiLine`）。
///   标题、图片说明与嵌入块（图片、日记卡片、导图）不参与；
/// - 偏移与 `Delta.toPlainText()` 一一对应（编辑器的选区偏移同一口径），
///   行内格式与链接不影响匹配。

/// 一次最多列出的匹配数：超过时只标出前这么多处（计数显示为“N+”），
/// 避免 `.` 之类的模式在长日记里一次造出几十万个匹配。全部替换不受限。
const int kDiaryFindMaxMatches = 9999;

/// 查找条件：查找文字与三个开关。
@immutable
class DiaryFindQuery {
  const DiaryFindQuery({
    this.text = '',
    this.regex = false,
    this.caseSensitive = false,
    this.wholeWord = false,
  });

  final String text;

  /// 按正则表达式解释 [text]；关时按原文逐字匹配。
  final bool regex;
  final bool caseSensitive;

  /// 只匹配完整的词：前后不能紧挨着字母、数字或下划线。汉字也算“字母”，
  /// 所以开着时“日记”不匹配“写日记”里的那两个字。
  final bool wholeWord;

  bool get isEmpty => text.isEmpty;

  DiaryFindQuery copyWith({
    String? text,
    bool? regex,
    bool? caseSensitive,
    bool? wholeWord,
  }) => DiaryFindQuery(
    text: text ?? this.text,
    regex: regex ?? this.regex,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    wholeWord: wholeWord ?? this.wholeWord,
  );

  @override
  bool operator ==(Object other) =>
      other is DiaryFindQuery &&
      other.text == text &&
      other.regex == regex &&
      other.caseSensitive == caseSensitive &&
      other.wholeWord == wholeWord;

  @override
  int get hashCode => Object.hash(text, regex, caseSensitive, wholeWord);
}

/// [query] 编译出的正则；查找文字为空时为 null，正则写错时抛
/// [FormatException]。
///
/// 先按 Unicode 模式编译：`\p{Script=Han}` 这类属性类可用，空匹配不会落在
/// emoji 的两个代码单元中间。Unicode 模式对转义更严（`\-`、`\#` 这类多余的
/// 转义算错），用户写的正则在 Unicode 模式下编译不过时退回普通模式再试，
/// 两种都不行才算写错。原文查找经 [RegExp.escape]，两种模式都能编译。
RegExp? compileDiaryFindPattern(DiaryFindQuery query) {
  if (query.isEmpty) return null;
  final body = query.regex ? query.text : RegExp.escape(query.text);
  RegExp build({required bool unicode}) {
    // 整词：前后不紧挨“词字符”。Unicode 模式按字母 / 数字类判断（含汉字、
    // 假名、西里尔字母），普通模式只有 `\w`（ASCII）。
    final word = unicode ? r'[\p{L}\p{N}_]' : r'\w';
    final source = query.wholeWord ? '(?<!$word)(?:$body)(?!$word)' : body;
    return RegExp(
      source,
      caseSensitive: query.caseSensitive,
      multiLine: true,
      unicode: unicode,
    );
  }

  try {
    return build(unicode: true);
  } on FormatException {
    if (!query.regex) rethrow;
    return build(unicode: false);
  }
}

/// 文档里的一处匹配：[node] 文字里 [start]～[end] 这一段（[end] 可以等于
/// [start]：`^`、`\b` 这类零宽匹配）。[match] 留着分组，替换时展开引用。
///
/// [path] 与 [block]（[node] 所在的顶层块，高亮按它分组）是查找那一刻的
/// 位置：遍历时顺手记下，不再逐个调用 `node.path`（它每层都要在兄弟里
/// 查找下标，几千处匹配时很慢）。文档一改就要重新查找，见
/// `DiaryFindReplace`。
@immutable
class DiaryFindMatch {
  const DiaryFindMatch({
    required this.node,
    required this.block,
    required this.path,
    required this.start,
    required this.end,
    required this.match,
  });

  final af.Node node;
  final af.Node block;
  final af.Path path;
  final int start;
  final int end;
  final RegExpMatch match;

  int get length => end - start;
  bool get isEmpty => start == end;

  af.Selection get selection => af.Selection(
    start: af.Position(path: path, offset: start),
    end: af.Position(path: path, offset: end),
  );
}

/// 按阅读顺序找出 [root] 之下全部文字块里 [pattern] 的匹配；[limit] 为 null
/// 时不设上限。返回匹配与是否因上限截断。
({List<DiaryFindMatch> matches, bool truncated}) findDiaryMatches(
  af.Node root,
  RegExp pattern, {
  int? limit = kDiaryFindMaxMatches,
}) {
  final matches = <DiaryFindMatch>[];
  bool visit(af.Node node, af.Node block, af.Path path) {
    final delta = node.delta;
    if (delta != null) {
      final text = delta.toPlainText();
      for (final match in pattern.allMatches(text)) {
        if (match.start == match.end &&
            _splitsSurrogatePair(text, match.start)) {
          continue;
        }
        if (limit != null && matches.length >= limit) return false;
        matches.add(
          DiaryFindMatch(
            node: node,
            block: block,
            path: path,
            start: match.start,
            end: match.end,
            match: match,
          ),
        );
      }
    }
    final children = node.children;
    for (var i = 0; i < children.length; i++) {
      if (!visit(children[i], block, [...path, i])) return false;
    }
    return true;
  }

  final blocks = root.children;
  for (var i = 0; i < blocks.length; i++) {
    if (!visit(blocks[i], blocks[i], [i])) {
      return (matches: matches, truncated: true);
    }
  }
  return (matches: matches, truncated: false);
}

/// 两个位置在阅读顺序里的先后（路径按字典序：父块在子块之前、子块在
/// 下一个兄弟之前；同一块再比偏移）。
int compareDiaryFindPositions(
  af.Path aPath,
  int aOffset,
  af.Path bPath,
  int bOffset,
) {
  final shared = aPath.length < bPath.length ? aPath.length : bPath.length;
  for (var i = 0; i < shared; i++) {
    if (aPath[i] != bPath[i]) return aPath[i].compareTo(bPath[i]);
  }
  if (aPath.length != bPath.length) {
    return aPath.length.compareTo(bPath.length);
  }
  return aOffset.compareTo(bOffset);
}

/// 普通模式的空匹配会逐个代码单元前进，可能停在 emoji 的高低两半之间；
/// 在那里插入替换文字会拆坏这个字，这样的位置不算匹配。
bool _splitsSurrogatePair(String text, int offset) =>
    offset > 0 &&
    offset < text.length &&
    _isHighSurrogate(text.codeUnitAt(offset - 1)) &&
    _isLowSurrogate(text.codeUnitAt(offset));

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// 正则替换串的展开（与 JavaScript `String.replace` 同一套写法）：
/// - `$1`～`$99`：第几个分组（两位数的分组不存在时按一位数加一个数字）；
/// - `$&` 或 `$0`：整个匹配；`${名字}`：命名分组；
/// - `$$`：一个 `$`；其余的 `$` 与不存在的分组原样保留。
///
/// 没参与匹配的分组展开为空串。
String expandDiaryReplacement(String template, RegExpMatch match) {
  if (!template.contains(r'$')) return template;
  final out = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final char = template[i];
    if (char != r'$' || i + 1 >= template.length) {
      out.write(char);
      i++;
      continue;
    }
    final next = template[i + 1];
    if (next == r'$') {
      out.write(r'$');
      i += 2;
      continue;
    }
    if (next == '&') {
      out.write(match[0]);
      i += 2;
      continue;
    }
    if (next == '{') {
      final close = template.indexOf('}', i + 2);
      final name = close < 0 ? null : template.substring(i + 2, close);
      if (name != null && match.groupNames.contains(name)) {
        out.write(match.namedGroup(name) ?? '');
        i = close + 1;
        continue;
      }
      out.write(char);
      i++;
      continue;
    }
    final first = _digit(next);
    if (first == null) {
      out.write(char);
      i++;
      continue;
    }
    final second = i + 2 < template.length ? _digit(template[i + 2]) : null;
    if (second != null && first * 10 + second <= match.groupCount) {
      out.write(match.group(first * 10 + second) ?? '');
      i += 3;
      continue;
    }
    if (first <= match.groupCount) {
      out.write(match.group(first) ?? '');
      i += 2;
      continue;
    }
    out.write(char);
    i++;
  }
  return out.toString();
}

int? _digit(String char) {
  final unit = char.codeUnitAt(0);
  return unit >= 0x30 && unit <= 0x39 ? unit - 0x30 : null;
}
