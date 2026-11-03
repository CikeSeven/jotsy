import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 文字选区菜单（长按选字 / 桌面右键的复制、粘贴菜单）只经
/// `lib/ui/widgets/text_selection_menu/`：
///
/// - 输入框（`TextField` / `TextFormField` / `SelectableText` /
///   `SearchBar`）一律传 `contextMenuBuilder: appTextContextMenuBuilder`，
///   漏传就会冒出系统默认的实色工具栏，与其余输入框不一致。
/// - SDK 的文字工具栏组件只在该目录里用（例如取按钮文字）。
///
/// 检查在“去掉注释与字符串内容”的源码上进行，注释或文案里提到这些类名
/// 不算违规；构造调用按括号配对取出完整参数，再找 `contextMenuBuilder:`。
void main() {
  const componentDir = 'lib/ui/widgets/text_selection_menu/';
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .where((File file) => !_normalized(file).startsWith('lib/l10n/'))
      .toList();

  test('text inputs pass the shared contextMenuBuilder', () {
    expect(files, isNotEmpty);
    // 前面不能是标识符字符或 `.`：排除 `TextFieldTapRegion`、
    // `MyTextField(`、`foo.TextField(` 这类其他用法。
    final constructor = RegExp(
      r'(?<![A-Za-z0-9_$.])'
      r'(TextField|TextFormField|SelectableText\.rich|SelectableText|SearchBar)'
      r'\s*\(',
    );
    final offenders = <String>[];
    var calls = 0;
    for (final file in files) {
      final source = file.readAsStringSync();
      final code = _maskCommentsAndStrings(source);
      for (final match in constructor.allMatches(code)) {
        calls++;
        final open = match.end - 1;
        final close = _matchingClose(code, open);
        final args = code.substring(open + 1, close);
        if (!RegExp(r'\bcontextMenuBuilder\s*:').hasMatch(args)) {
          final line = _lineOf(source, match.start);
          offenders.add(
            '${_normalized(file)}:$line ${match.group(1)} '
            'without contextMenuBuilder',
          );
        }
      }
    }
    expect(calls, greaterThan(0));
    expect(offenders, isEmpty);
  });

  test('SDK text selection toolbars only appear in text_selection_menu', () {
    // 整词匹配：`TextSelectionToolbarAnchors` 等后面接着字母的名字不算。
    final forbidden = RegExp(
      r'(?<![A-Za-z0-9_$])'
      r'(AdaptiveTextSelectionToolbar|DesktopTextSelectionToolbar|'
      r'CupertinoAdaptiveTextSelectionToolbar|CupertinoTextSelectionToolbar|'
      r'TextSelectionToolbar)'
      r'(?![A-Za-z0-9_$])',
    );
    final offenders = <String>[];
    for (final file in files) {
      if (_normalized(file).startsWith(componentDir)) continue;
      final source = file.readAsStringSync();
      final code = _maskCommentsAndStrings(source);
      for (final match in forbidden.allMatches(code)) {
        offenders.add(
          '${_normalized(file)}:${_lineOf(source, match.start)} '
          'uses ${match.group(1)}',
        );
      }
    }
    expect(offenders, isEmpty);
  });
}

String _normalized(File file) => file.path.replaceAll(r'\', '/');

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

/// 从 [open]（一个 `(`）开始找配对的右括号；三种括号一起计数。
int _matchingClose(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final char = code[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return code.length;
}

/// 把注释与字符串内容换成空格（保留换行与长度，偏移和行号不变）。
///
/// 字符串里的插值 `${...}` 一并抹掉：插值里的括号本就成对，不影响配对；
/// 只是插值里若再写字符串引号会提前结束，项目里的输入框参数没有这种写法。
String _maskCommentsAndStrings(String source) {
  final out = source.split('');
  void blank(int from, int to) {
    for (var k = from; k < to && k < out.length; k++) {
      if (out[k] != '\n') out[k] = ' ';
    }
  }

  var i = 0;
  final n = source.length;
  while (i < n) {
    if (source.startsWith('//', i)) {
      var end = source.indexOf('\n', i);
      if (end < 0) end = n;
      blank(i, end);
      i = end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      var end = source.indexOf('*/', i + 2);
      end = end < 0 ? n : end + 2;
      blank(i, end);
      i = end;
      continue;
    }
    final char = source[i];
    if (char == "'" || char == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = source.startsWith(char * 3, i);
      final quote = triple ? char * 3 : char;
      var j = i + quote.length;
      while (j < n && !source.startsWith(quote, j)) {
        if (!raw && source[j] == r'\') {
          j += 2;
          continue;
        }
        j++;
      }
      blank(i + quote.length, j);
      i = j + quote.length;
      continue;
    }
    i++;
  }
  return out.join();
}
