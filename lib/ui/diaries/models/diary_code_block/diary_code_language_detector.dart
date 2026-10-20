import 'dart:convert';

import 'diary_code_language_signals.dart';

// 有界、无状态的语言识别：先识别数据/标记格式，再对剥离字串与注释的代码
// 做特征计分。只读样本，不初始化或运行任何语言的语法高亮器。
//
// 不用 highlight.js 的 relevance 判断短代码：分数受样本长度影响，而且
// JavaScript/TypeScript 等相近语法经常打平。独有语法优先，共有语法按分数
// 判断；只有 print(...) 一类无法区分的片段时采用常见语言，用户仍可手选。
abstract final class DiaryCodeLanguageDetector {
  // 取样前略过开头的空白与 C 风格说明注释，否则长许可证会占满整个样本。
  // 最多向前扫描 maxLength，不随任意大粘贴增长。
  static String sample(
    String input, {
    required int maxLength,
    required int sampleLength,
  }) {
    final text = input.length > maxLength
        ? input.substring(0, maxLength)
        : input;
    final budget = text.length;
    var start = 0;
    while (start < budget) {
      if (text.codeUnitAt(start) <= 32) {
        start++;
        continue;
      }
      if (text.startsWith('//', start)) {
        final end = text.indexOf('\n', start + 2);
        if (end < 0 || end >= budget) break;
        start = end + 1;
      } else if (text.startsWith('/*', start)) {
        final end = text.indexOf('*/', start + 2);
        if (end < 0 || end + 2 > budget) break;
        start = end + 2;
      } else {
        break;
      }
    }
    final end = start + sampleLength;
    return text.substring(start, end < text.length ? end : text.length);
  }

  static String? detect(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;

    // 完整 JSON（包括数组、空对象）无需正则猜测；字符串内的代码不参与识别。
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final value = jsonDecode(trimmed);
        if (value is Map || value is List) return 'json';
      } on FormatException {
        // 正在输入或采样截断的 JSON 继续看属性名，不能拖到闭合后才着色。
      }
      if (_jsonProperty.hasMatch(trimmed)) return 'json';
    }

    final (code: code, markup: markup) = _withoutStringsAndComments(source);
    final scores = diaryCodeLanguageScores(source, code);
    // 数据与标记格式要有结构证据，避免把日记里的冒号、链接或单个单词当代码。
    if ((_xml.hasMatch(code) &&
            (code.contains('</') ||
                code.contains('/>') ||
                _htmlTag.hasMatch(code))) ||
        _xmlDeclaration.hasMatch(code)) {
      scores['xml'] = 16;
    }
    if (_css.hasMatch(code)) scores['css'] = 16;
    if (_diff.hasMatch(markup)) scores['diff'] = 24;
    final yamlKeys = _yamlKey.allMatches(code).take(3).length;
    if (yamlKeys >= 2 && !code.contains('{') && !code.contains(';')) {
      scores['yaml'] = 6 + yamlKeys;
    }
    final heading = _markdownHeading.hasMatch(markup);
    final list = _markdownList.hasMatch(markup);
    final link = _markdownLink.hasMatch(markup);
    if ((heading && (list || link)) || (list && link)) {
      scores['markdown'] = 12;
    }

    String? best;
    var first = 4;
    var second = 0;
    for (final entry in scores.entries) {
      if (entry.value > first) {
        second = first;
        first = entry.value;
        best = entry.key;
      } else if (entry.value > second) {
        second = entry.value;
      }
    }
    // 已出现类型注解时，JavaScript 的 console/箭头函数只是共有语法。
    if ((scores['typescript'] ?? 0) >= 18 &&
        (best == 'javascript' || best == 'typescript')) {
      return 'typescript';
    }
    return best != null && first - second >= 1 ? best : null;
  }

  static final _jsonProperty = RegExp(r'''[\[{,]\s*"[^"\r\n]+"\s*:''');
  static final _xml = RegExp(
    r'^\s*<[A-Za-z][\w:-]*(?:\s+[^<>\n]*)?/?>',
    multiLine: true,
  );
  static final _htmlTag = RegExp(
    r'<(?:html|head|body|div|span|p|a|ul|li|script|style|h[1-6])(?:\s|>)',
    caseSensitive: false,
  );
  static final _xmlDeclaration = RegExp(
    r'<\?(?:xml)\b|<!DOCTYPE\s+',
    caseSensitive: false,
  );
  static final _css = RegExp(
    r'(?:^|[}\n])\s*[.#@:\w\[\]> ,*+~-]+\{\s*(?:--[\w-]+|(?:color|background|font|margin|padding|border|display|position|width|height|content|align|justify|gap|opacity|transform|animation)[\w-]*)\s*:',
    multiLine: true,
  );
  static final _diff = RegExp(
    r'^diff --git |^@@[ -+\d,]+@@|^--- [^\n]+\n\+\+\+ ',
    multiLine: true,
  );
  static final _yamlKey = RegExp(
    r'^\s*[A-Za-z_][\w.-]*\s*:(?:\s|$)',
    multiLine: true,
  );
  static final _markdownHeading = RegExp(
    r'^ {0,3}#{1,6}\s+\S',
    multiLine: true,
  );
  static final _markdownList = RegExp(
    r'^ {0,3}(?:[-*+]\s+|\d+\.\s+)\S',
    multiLine: true,
  );
  static final _markdownLink = RegExp(r'\[[^\]\n]+\]\([^\s)]+\)');
}

/// 保留换行、引号与偏移，屏蔽字串/注释里的语言特征。单行字符串没闭合时
/// 在换行处恢复扫描，输入半个引号不妨碍下一行的语言证据；三引号与反引号
/// 允许跨行。实现为一次线性扫描，不用可能回溯的大正则清洗整个样本。
({String code, String markup}) _withoutStringsAndComments(String source) {
  final units = source.codeUnits.toList();
  final hashComments = <(int, int)>[];
  var i = 0;
  void blank(int index) {
    if (units[index] != 10 && units[index] != 13) units[index] = 32;
  }

  while (i < units.length) {
    final c = units[i];
    final next = i + 1 < units.length ? units[i + 1] : -1;
    if (c == 47 && (next == 47 || next == 42)) {
      final block = next == 42;
      blank(i++);
      blank(i++);
      while (i < units.length) {
        if (!block && units[i] == 10) break;
        if (block &&
            units[i] == 42 &&
            i + 1 < units.length &&
            units[i + 1] == 47) {
          blank(i++);
          blank(i++);
          break;
        }
        blank(i++);
      }
    } else if (c == 35 &&
        next != 33 &&
        next != 91 &&
        !source.startsWith(_directive, i + 1)) {
      final start = i;
      while (i < units.length && units[i] != 10) {
        i++;
      }
      hashComments.add((start, i));
    } else if (c == 39 || c == 34 || c == 96) {
      final triple =
          c != 96 &&
          i + 2 < units.length &&
          units[i + 1] == c &&
          units[i + 2] == c;
      final delimiter = triple ? 3 : 1;
      i += delimiter;
      while (i < units.length) {
        if (units[i] == c &&
            (!triple ||
                i + 2 < units.length &&
                    units[i + 1] == c &&
                    units[i + 2] == c)) {
          i += delimiter;
          break;
        }
        if (!triple && c != 96 && units[i] == 10) break;
        if (units[i] == 92) {
          blank(i++);
          if (i < units.length) blank(i++);
        } else {
          blank(i++);
        }
      }
    } else {
      i++;
    }
  }
  final markup = String.fromCharCodes(units);
  for (final (start, end) in hashComments) {
    for (var at = start; at < end; at++) {
      blank(at);
    }
  }
  return (code: String.fromCharCodes(units), markup: markup);
}

final _directive = RegExp(r'\s*(?:include|define|pragma)\b');
