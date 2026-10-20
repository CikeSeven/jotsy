import 'package:flutter/foundation.dart';
import 'package:highlight/highlight_core.dart';

import 'diary_code_language.dart';
import 'diary_code_language_detector.dart';
import 'diary_code_incremental_highlight.dart';
import 'diary_code_tokens.dart';

export 'diary_code_tokens.dart' show DiaryCodeToken, DiaryCodeTokens;

// 代码块语言识别与高亮的统一入口（纯计算，不碰界面）。
//
// 输入：代码文本与支持的语言 id；输出：按 UTF-16 偏移排列的着色区间。
// 识别用有界的语法特征扫描，不初始化语法引擎，也不轮流解析全部语言。
// 高亮器自带 Highlight 实例，只注册支持的 22 种语言；不使用全语言全局实例。
//
// 长块的小范围编辑先尝试复用上次完整快照；无法确认上下文独立时整块解析。
// highlight 0.7.0 公开 parse 固定 ignoreIllegals:false，遇到未完成的语法可能
// 直接返回原文：此时逐行容错，不让一行错误清掉整块颜色。JS/TS 私有字段
// 在等长的解析副本中兼容，不改日记原文，也不改 PDF 导出共用的 Mode。
//
// 超过 20000 字符或 600 行时显示纯文本；库异常不抛进界面。
// 高亮缓存同时限制份数（48）和估算权重（1MiB）；取样缓存限制 128 份和
// 32768 个 UTF-16 code unit。容量淘汰避免连续编辑长块留下大量历史快照。

/// 语法高亮与语言识别；用 [instance]。
class DiaryCodeHighlighter {
  DiaryCodeHighlighter._();

  @visibleForTesting
  factory DiaryCodeHighlighter.forTesting() => DiaryCodeHighlighter._();

  static final DiaryCodeHighlighter instance = DiaryCodeHighlighter._();

  /// 超过这个字符数不高亮。
  static const int maxLength = 20000;

  /// 超过这个行数不高亮。
  static const int maxLines = 600;

  /// 跳过开头说明注释后，语言识别最多取这么多字符。
  static const int detectSampleLength = 2000;

  static const int _tokensCacheSize = 48;
  static const int _detectCacheSize = 128;
  static const int _tokensCacheWeightLimit = 1024 * 1024;
  static const int _detectCacheUnitsLimit = 32768;

  Highlight? _highlight;
  final Map<(String, String), DiaryCodeTokens> _tokensCache = {};
  final Map<String, String?> _detectCache = {};
  int _tokensCacheWeight = 0;
  int _detectCacheUnits = 0;

  Highlight get _engine {
    final existing = _highlight;
    if (existing != null) {
      return existing;
    }
    final engine = Highlight();
    for (final language in kDiaryCodeLanguages) {
      engine.registerLanguage(language.id, language.mode);
    }
    return _highlight = engine;
  }

  /// [text] 按语言 [languageId] 的高亮区间；未知语言、超出上限或高亮失败时
  /// 返回 [DiaryCodeTokens.empty]。
  DiaryCodeTokens tokens(String text, String languageId) {
    if (text.isEmpty ||
        text.length > maxLength ||
        diaryCodeLanguageById(languageId) == null) {
      return DiaryCodeTokens.empty;
    }
    final key = (languageId, text);
    final cached = _tokensCache.remove(key);
    if (cached != null) {
      _tokensCache[key] = cached;
      return cached;
    }
    if (_exceedsLimits(text)) return DiaryCodeTokens.empty;
    final result =
        _incrementalTokens(text, languageId) ??
        _computeTokens(text, languageId);
    _tokensCache[key] = result;
    _tokensCacheWeight += _tokenWeight(text, result);
    while (_tokensCache.length > _tokensCacheSize ||
        _tokensCacheWeight > _tokensCacheWeightLimit) {
      final oldest = _tokensCache.keys.first;
      final removed = _tokensCache.remove(oldest)!;
      _tokensCacheWeight -= _tokenWeight(oldest.$2, removed);
    }
    return result;
  }

  /// 识别 [text] 的语言；只扫描有界的 [detectSampleLength] 字符样本。
  /// 语法特征扫描不运行各语言的 parser，普通文本与缺乏证据的片段返回 null。
  String? detect(String text) {
    final sample = DiaryCodeLanguageDetector.sample(
      text,
      maxLength: maxLength,
      sampleLength: detectSampleLength,
    );
    if (sample.trim().isEmpty) {
      return null;
    }
    if (_detectCache.containsKey(sample)) {
      final cached = _detectCache.remove(sample);
      _detectCache[sample] = cached;
      return cached;
    }
    final result = _computeDetect(sample);
    _detectCache[sample] = result;
    _detectCacheUnits += sample.length;
    while (_detectCache.length > _detectCacheSize ||
        _detectCacheUnits > _detectCacheUnitsLimit) {
      final oldest = _detectCache.keys.first;
      _detectCache.remove(oldest);
      _detectCacheUnits -= oldest.length;
    }
    return result;
  }

  // UTF-16 原文加上区间对象/列表引用的保守权重。只限份数会让 48 份长代码
  // 编辑快照占用数 MB；同时按容量淘汰后，小块仍可多缓存，长块及时回收。
  static int _tokenWeight(String text, DiaryCodeTokens tokens) =>
      text.length * 2 + tokens.tokens.length * 48;

  DiaryCodeTokens? _incrementalTokens(String text, String languageId) {
    try {
      MapEntry<(String, String), DiaryCodeTokens>? previous;
      for (final entry in _tokensCache.entries) {
        if (entry.key.$1 == languageId) previous = entry;
      }
      final incremental = previous == null
          ? null
          : incrementalDiaryCodeTokens(
              language: languageId,
              text: text,
              previousText: previous.key.$2,
              previous: previous.value,
              parse: (segment, base) =>
                  _parseSegment(segment, base, languageId),
            );
      return incremental;
    } catch (_) {
      // 增量只是一条加速路径：任何库边界异常都退回现有的整块容错解析。
      return null;
    }
  }

  bool _exceedsLimits(String text) {
    if (text.length > maxLength) {
      return true;
    }
    var lines = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A && ++lines > maxLines) {
        return true;
      }
    }
    return false;
  }

  String? _computeDetect(String sample) {
    try {
      return DiaryCodeLanguageDetector.detect(sample);
    } catch (error) {
      debugPrint('DiaryCodeHighlighter.detect failed: $error');
      return null;
    }
  }

  DiaryCodeTokens _computeTokens(String text, String languageId) {
    try {
      final whole = _parseSegment(text, 0, languageId, wholeBlock: true);
      if (whole != null) {
        return DiaryCodeTokens(List.unmodifiable(whole));
      }
      // 整块遇到非法记号被放弃：逐行各自高亮，一行写错或没写完不连累
      // 其余行。跨行结构（块注释、多行字符串）在这个模式下按行断开。
      final tokens = <DiaryCodeToken>[];
      var lineStart = 0;
      while (lineStart <= text.length) {
        var lineEnd = text.indexOf('\n', lineStart);
        if (lineEnd < 0) {
          lineEnd = text.length;
        }
        if (lineEnd > lineStart) {
          final line = text.substring(lineStart, lineEnd);
          final lineTokens = _parseSegment(line, lineStart, languageId);
          if (lineTokens != null) {
            tokens.addAll(lineTokens);
          }
        }
        lineStart = lineEnd + 1;
      }
      return tokens.isEmpty
          ? DiaryCodeTokens.empty
          : DiaryCodeTokens(List.unmodifiable(tokens), hasFullContext: false);
    } catch (error) {
      debugPrint('DiaryCodeHighlighter.tokens failed: $error');
      return DiaryCodeTokens.empty;
    }
  }

  /// 高亮 [segment]（位于原文 [base] 处），区间偏移已加上 [base]。
  ///
  /// 返回 null 表示这段需要按纯文本处理：highlight 遇到非法记号放弃了
  /// （见 [_isBailOut]），或叶子拼不回原文（偏移会错位）。不会放弃、只是
  /// 没有可着色内容时返回空列表。整块解析（[wholeBlock]）的异常交给调用方
  /// 返回空结果；逐行解析时某一行的异常只让这一行按纯文本显示。
  List<DiaryCodeToken>? _parseSegment(
    String segment,
    int base,
    String languageId, {
    bool wholeBlock = false,
  }) {
    // 老语法库把合法的 JS 私有名 #field 当作非法字符。只在解析副本中用
    // 同宽的 $field 占位，避免整块退出高亮；原文、复制内容及 UTF-16 偏移
    // 完全保留，也不修改 PDF 导出共用的全局 Mode 定义。
    final parserText =
        (languageId == 'javascript' || languageId == 'typescript') &&
            segment.contains('#')
        ? segment.replaceAll(_privateName, r'$')
        : segment;
    final Result result;
    try {
      result = _engine.parse(parserText, language: languageId);
    } catch (error) {
      if (wholeBlock) {
        rethrow;
      }
      return null;
    }
    final nodes = result.nodes;
    if (nodes == null || _isBailOut(result, parserText)) {
      return null;
    }
    final flattener = DiaryCodeTokenFlattener(base);
    flattener.walk(nodes, null, false);
    // 叶子必须无损拼回解析输入；兼容副本与原文等长，区间仍精确对应原文。
    if (flattener.offset != base + segment.length ||
        flattener.source.toString() != parserText) {
      return null;
    }
    return flattener.tokens;
  }

  static final _privateName = RegExp(r'#(?=[A-Za-z_$])');

  /// highlight 0.7.0 在 `ignoreIllegals: false`（公开的 parse 只有这一种）
  /// 下遇到非法记号不抛异常，而是返回相关度 0、只有一个无 className、
  /// 内容为整段原文的节点。非空白文本出现这个形状即视为放弃。纯文字
  /// （没有任何记号）也是这个形状，按放弃处理只是多走一遍逐行，结果同样
  /// 不着色。
  static bool _isBailOut(Result result, String source) {
    final nodes = result.nodes!;
    if (nodes.length != 1 || (result.relevance ?? 0) != 0) {
      return false;
    }
    final node = nodes.single;
    final className = node.className;
    return (className == null || className.isEmpty) &&
        node.children == null &&
        node.value == source &&
        source.trim().isNotEmpty;
  }
}
