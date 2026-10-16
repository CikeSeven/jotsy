import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// 日记纯文本的字数统计，全应用唯一的“字数”口径（卡片角标、日历、探索页、
/// 预览页都经这里计算，禁止各处自行 `.length`）。
///
/// 规则与 Word / WPS 的“字数”一致：
/// - 中文字符：每个汉字、假名、谚文与全角标点算 1 字；`“” ‘’ …… —— ·` 这类
///   中英共用的标点只在紧挨中文时按中文标点计（英文里的弯引号不算字）；
/// - 非中文单词：以空白与中文字符分隔的一段文字算 1 个词，其中至少要有一个
///   字母或数字（“don’t”“e-mail”“3.14”“hello,”各算 1 个，单独的符号与
///   emoji 不算）；
/// - 空格、换行与嵌入占位符（U+FFFC）不计。
///
/// 输入是纯文本（日记的 `contentText`）；无状态、无副作用。
@immutable
class TextStats {
  const TextStats({
    this.cjk = 0,
    this.latinWords = 0,
    this.characters = 0,
    this.charactersWithSpaces = 0,
    this.paragraphs = 0,
  });

  static const TextStats empty = TextStats();

  /// 阅读速度：中文每分钟约 400 字，英文每分钟约 200 词。
  static const int cjkPerMinute = 400;
  static const int wordsPerMinute = 200;

  factory TextStats.of(String text) {
    if (text.isEmpty) {
      return empty;
    }
    final (cjk, latinWords) = _countWords(text);
    var characters = 0;
    var withSpaces = 0;
    for (final grapheme in text.characters) {
      final rune = grapheme.runes.first;
      if (rune == _lineFeed || rune == _carriageReturn || rune == _embed) {
        continue;
      }
      withSpaces += 1;
      if (!_isSpace(rune)) {
        characters += 1;
      }
    }
    var paragraphs = 0;
    for (final line in text.split('\n')) {
      if (line.runes.any((int rune) => !_isSpace(rune) && rune != _embed)) {
        paragraphs += 1;
      }
    }
    return TextStats(
      cjk: cjk,
      latinWords: latinWords,
      characters: characters,
      charactersWithSpaces: withSpaces,
      paragraphs: paragraphs,
    );
  }

  /// 只算字数（不统计字符与段落），供列表与日历的高频路径使用。
  static int countWords(String text) {
    if (text.isEmpty) {
      return 0;
    }
    final (cjk, latinWords) = _countWords(text);
    return cjk + latinWords;
  }

  /// 中文字符数（含全角标点）。
  final int cjk;

  /// 非中文单词数。
  final int latinWords;

  /// 字符数（不计空白），按字素计：组合 emoji 算 1 个。
  final int characters;

  /// 字符数（计空格，不计换行）。
  final int charactersWithSpaces;

  /// 有文字的段落数（只含图片等嵌入的段落不算）。
  final int paragraphs;

  /// 字数 = 中文字符 + 非中文单词。
  int get words => cjk + latinWords;

  /// 预计阅读分钟数：向上取整，有字时至少 1 分钟。
  int get readingMinutes {
    if (words == 0) {
      return 0;
    }
    final minutes = cjk / cjkPerMinute + latinWords / wordsPerMinute;
    return math.max(1, minutes.ceil());
  }

  static const int _lineFeed = 0x0A;
  static const int _carriageReturn = 0x0D;
  static const int _embed = 0xFFFC;
  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static (int, int) _countWords(String text) {
    final runes = text.runes.toList(growable: false);
    var cjk = 0;
    var latin = 0;
    var inWord = false;
    var wordHasAlnum = false;
    var previousCjk = false;

    void endWord() {
      if (inWord && wordHasAlnum) {
        latin += 1;
      }
      inWord = false;
      wordHasAlnum = false;
    }

    for (var i = 0; i < runes.length; i++) {
      final rune = runes[i];
      if (_isSpace(rune) || rune == _embed) {
        endWord();
        previousCjk = false;
        continue;
      }
      final cjkHere =
          _isCjk(rune) ||
          (_isSharedPunctuation(rune) &&
              (previousCjk || _nextSolidIsCjk(runes, i + 1)));
      if (cjkHere) {
        endWord();
        cjk += 1;
        previousCjk = true;
        continue;
      }
      previousCjk = false;
      inWord = true;
      if (!wordHasAlnum && _isLetterOrDigit(rune)) {
        wordHasAlnum = true;
      }
    }
    endWord();
    return (cjk, latin);
  }

  /// 跳过连续的共用标点，看下一个字符是不是中文（处理“……中文”开头）。
  static bool _nextSolidIsCjk(List<int> runes, int start) {
    for (var i = start; i < runes.length; i++) {
      final rune = runes[i];
      if (_isSharedPunctuation(rune)) {
        continue;
      }
      return _isCjk(rune);
    }
    return false;
  }

  static bool _isLetterOrDigit(int rune) {
    if (rune < 0x80) {
      return (rune >= 0x30 && rune <= 0x39) ||
          (rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A);
    }
    return _letterOrDigit.hasMatch(String.fromCharCode(rune));
  }

  static bool _isSpace(int rune) {
    return rune == 0x20 ||
        (rune >= 0x09 && rune <= 0x0D) ||
        rune == 0xA0 ||
        rune == 0x1680 ||
        (rune >= 0x2000 && rune <= 0x200B) ||
        rune == 0x2028 ||
        rune == 0x2029 ||
        rune == 0x202F ||
        rune == 0x205F ||
        rune == 0x3000 ||
        rune == 0xFEFF;
  }

  /// 中日韩字符与全角标点；全角字母、数字不在内（并入单词）。
  static bool _isCjk(int rune) {
    if (rune < 0x1100) {
      return false;
    }
    return (rune >= 0x1100 && rune <= 0x11FF) || // 谚文字母
        (rune >= 0x2E80 && rune <= 0x2FDF) || // 部首
        (rune >= 0x3001 && rune <= 0x303F) || // 中日韩标点（不含全角空格）
        (rune >= 0x3040 && rune <= 0x30FF) || // 假名
        (rune >= 0x3100 && rune <= 0x31FF) || // 注音、谚文兼容字母等
        (rune >= 0x3200 && rune <= 0x4DBF) || // 带圈字符、扩展 A
        (rune >= 0x4E00 && rune <= 0x9FFF) || // 基本汉字
        (rune >= 0xA960 && rune <= 0xA97F) ||
        (rune >= 0xAC00 && rune <= 0xD7FF) || // 谚文音节
        (rune >= 0xF900 && rune <= 0xFAFF) || // 兼容汉字
        (rune >= 0xFE10 && rune <= 0xFE1F) || // 竖排标点
        (rune >= 0xFE30 && rune <= 0xFE6F) || // 兼容与小写标点
        (rune >= 0xFF01 && rune <= 0xFF0F) || // 全角标点
        (rune >= 0xFF1A && rune <= 0xFF20) ||
        (rune >= 0xFF3B && rune <= 0xFF40) ||
        (rune >= 0xFF5B && rune <= 0xFFEF) || // 全角标点、半角假名与谚文
        (rune >= 0x20000 && rune <= 0x3134F); // 扩展 B–H
  }

  /// 中英文共用的标点：紧挨中文时按中文标点计。
  static bool _isSharedPunctuation(int rune) {
    return rune == 0x00B7 ||
        rune == 0x2014 ||
        rune == 0x2015 ||
        rune == 0x2018 ||
        rune == 0x2019 ||
        rune == 0x201C ||
        rune == 0x201D ||
        rune == 0x2026;
  }

  @override
  bool operator ==(Object other) {
    return other is TextStats &&
        other.cjk == cjk &&
        other.latinWords == latinWords &&
        other.characters == characters &&
        other.charactersWithSpaces == charactersWithSpaces &&
        other.paragraphs == paragraphs;
  }

  @override
  int get hashCode => Object.hash(
    cjk,
    latinWords,
    characters,
    charactersWithSpaces,
    paragraphs,
  );
}

/// 按 `(diaryId, updatedAt)` 缓存的日记字数。
///
/// 日历与探索页每次数据库流推送都会重新汇总一整月（年视图一整年）的字数；
/// 日记内容只随 updatedAt 变化，命中缓存时不再逐字扫描。固定容量 LRU。
abstract final class DiaryWordCounts {
  static const int _maxEntries = 2000;
  static final LinkedHashMap<String, int> _cache = LinkedHashMap<String, int>();

  static int of({
    required String diaryId,
    required DateTime updatedAt,
    required String text,
  }) {
    final key = '${diaryId}_${updatedAt.microsecondsSinceEpoch}';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    final count = TextStats.countWords(text);
    _cache[key] = count;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return count;
  }
}
