import 'diary_code_tokens.dart';

// 长代码块的小范围编辑：只重算改动行与前后各一行，再平移未改区域的区间。
//
// 输入为最近的完整快照、新文本及同一个 parser；输出为新快照，无法确认上下文
// 独立时返回 null，由调用方整块解析。只用于词法规则适合逐行切分的语言。
//
// 必须同时满足三项，才能复用旧区间：
// 1. 新旧窗口都没有跨行字符串、块注释、声明包装或行尾续行；
// 2. 旧区间没有跨出窗口，且单独解析旧窗口得到完全相同的区间；
// 3. 新窗口仍可正常解析。
// 因此跨行注释、模板字符串与输入中的半截引号会自动回退；不能为了速度丢掉
// 整块上下文。前后邻行也包含在窗口中，覆盖键名/冒号等跨换行的词法匹配。
DiaryCodeTokens? incrementalDiaryCodeTokens({
  required String language,
  required String text,
  required String previousText,
  required DiaryCodeTokens previous,
  required List<DiaryCodeToken>? Function(String segment, int base) parse,
}) {
  if (!_languages.contains(language) ||
      text.length < 2048 ||
      previous.isEmpty ||
      !previous.hasFullContext) {
    return null;
  }
  var prefix = 0;
  final common = text.length < previousText.length
      ? text.length
      : previousText.length;
  while (prefix < common &&
      text.codeUnitAt(prefix) == previousText.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < common - prefix &&
      text.codeUnitAt(text.length - suffix - 1) ==
          previousText.codeUnitAt(previousText.length - suffix - 1)) {
    suffix++;
  }
  if (prefix == common && text.length == previousText.length) return previous;

  // 向外扩到完整行，再加一行邻居；公共前后缀保证新旧窗口外的文本完全相同。
  var start = prefix == 0 ? 0 : text.lastIndexOf('\n', prefix - 1) + 1;
  if (start > 0) {
    start = start <= 1 ? 0 : text.lastIndexOf('\n', start - 2) + 1;
  }
  var oldEnd = previousText.indexOf('\n', previousText.length - suffix);
  oldEnd = oldEnd < 0 ? previousText.length : oldEnd + 1;
  if (oldEnd < previousText.length) {
    final next = previousText.indexOf('\n', oldEnd);
    oldEnd = next < 0 ? previousText.length : next + 1;
  }
  final shift = text.length - previousText.length;
  final newEnd = oldEnd + shift;
  if (oldEnd - start > 2048 || newEnd - start > 2048) return null;
  final oldSegment = previousText.substring(start, oldEnd);
  final newSegment = text.substring(start, newEnd);
  if (!_independent(oldSegment, language) ||
      !_independent(newSegment, language)) {
    return null;
  }
  final oldTokens = previous.overlapping(start, oldEnd).toList();
  if (oldTokens.any((token) => token.start < start || token.end > oldEnd)) {
    return null;
  }
  final isolated = parse(oldSegment, start);
  if (isolated == null || isolated.length != oldTokens.length) return null;
  for (var i = 0; i < isolated.length; i++) {
    if (isolated[i] != oldTokens[i]) return null;
  }
  final changed = parse(newSegment, start);
  if (changed == null) return null;

  final result = <DiaryCodeToken>[];
  void append(DiaryCodeToken token) {
    if (result.isNotEmpty &&
        result.last.end == token.start &&
        result.last.role == token.role) {
      final last = result.removeLast();
      result.add(DiaryCodeToken(last.start, token.end, token.role));
    } else {
      result.add(token);
    }
  }

  for (final token in previous.tokens) {
    if (token.end <= start) append(token);
    if (token.start >= start) break;
  }
  for (final token in changed) {
    append(token);
  }
  for (final token in previous.tokens) {
    if (token.start >= oldEnd) {
      append(
        shift == 0
            ? token
            : DiaryCodeToken(
                token.start + shift,
                token.end + shift,
                token.role,
              ),
      );
    }
  }
  return DiaryCodeTokens(List.unmodifiable(result));
}

const _languages = <String>{
  'dart',
  'python',
  'javascript',
  'typescript',
  'json',
};
final _declaration = RegExp(
  r'\b(?:class|interface|enum|extends|implements|function|def|constructor|get|set)\b',
);

bool _independent(String text, String language) {
  if (_declaration.hasMatch(text) ||
      text.contains('/*') ||
      text.contains('*/') ||
      text.contains('`') ||
      text.contains("'''") ||
      text.contains('"""')) {
    return false;
  }
  var quote = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 10 || c == 13) {
      if (quote != 0) return false;
      continue;
    }
    if (c == 92) {
      // 任何行尾续行都可能影响窗口外的内容；转义字符只在闭合字串内跳过。
      if (i + 1 >= text.length ||
          text.codeUnitAt(i + 1) == 10 ||
          text.codeUnitAt(i + 1) == 13) {
        return false;
      }
      if (quote != 0) i++;
    } else if (quote != 0) {
      if (c == quote) quote = 0;
    } else if (c == 39 || c == 34) {
      quote = c;
    } else if ((c == 47 &&
            i + 1 < text.length &&
            text.codeUnitAt(i + 1) == 47) ||
        (c == 35 && language == 'python')) {
      final newline = text.indexOf('\n', i);
      if (newline < 0) return true;
      i = newline;
    }
  }
  return quote == 0;
}
