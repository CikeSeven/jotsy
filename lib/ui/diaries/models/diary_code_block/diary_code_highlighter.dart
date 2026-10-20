import 'package:flutter/foundation.dart';
import 'package:highlight/highlight_core.dart';

import 'diary_code_language.dart';
import 'diary_code_theme.dart';

// 代码块语法高亮与语言识别（纯计算，不碰界面）。
//
// 输入：代码文本与语言 id（[kDiaryCodeLanguages] 之一）。
// 输出：[DiaryCodeTokens]——按起点排好、互不重叠、只含需要着色的区间，偏移
// 为 `text` 的 UTF-16 code unit 下标，渲染层可直接按区间切 TextSpan。
//
// 高亮器自带一个 `Highlight` 实例，只注册应用支持的 22 种语言（首次使用
// 时注册一次）：不用 `package:highlight` 的全局实例，避免自动识别在全部
// 约 190 种语言里逐个试（慢且容易误判成冷门语言）。
//
// highlight 0.7.0 产出的是嵌套节点树：带 className 的节点包住子节点，叶子
// 节点的 value 依次拼起来等于原文（不做 HTML 转义，转义只在 toHtml 里）。
// 展平时“最内层带角色的 className 胜出”：字符串里的转义、注释里的 doctag
// 等内层记号要用它自己的颜色；没有角色的内层节点（`subst`、子语言包装等）
// 继承外层角色，所以模板字符串插值里的普通文字仍是字符串色。
// 例外：hljs 9 的 `class` / `function` 是整段声明的包装节点（含关键字、
// 标题、参数与中间的标点空白），它们只提供上下文、不给自己的文字着色：
// `class` 包装里的 `title` 记为类型名，`function` 包装里的记为函数名。否则
// 声明里的括号、冒号与未识别的返回类型都会染成函数色。
//
// 非法记号：highlight 0.7.0 的公开 parse 固定 `ignoreIllegals: false`，遇到
// 语言定义里的非法记号（JS 的 `#x` 私有字段、正在输入、还没闭合的字符串等）
// 不抛异常，而是放弃整段、返回一个原文纯文本节点。若按此显示，用户每敲一个
// 引号整块都会闪成纯文本。所以识别出“放弃”后改为逐行各自高亮：一行写错或
// 没写完不连累其余行，仍放弃的行按纯文本显示；代价只是这时跨行结构（块注释、
// 多行字符串）按行断开。不去改语言的 Mode 对象（如清掉 illegal）：它们是
// 全局共享的，PDF 导出（flutter_quill_to_pdf）也在用。
//
// 上限与容错：超过 20000 个字符或 600 行的文本不高亮（返回空结果，按纯文本
// 显示）；高亮库抛出的任何异常都吞掉并返回空结果 / null，绝不抛进界面。
// 缓存：高亮结果按 (语言, 文本) 保留最近 48 份，识别结果按取样文本保留最近
// 128 份（编辑时每次重建只有当前这一块会变，其余块直接命中）。

/// 一段需要着色的区间 `[start, end)`。
@immutable
class DiaryCodeToken {
  const DiaryCodeToken(this.start, this.end, this.role);

  final int start;
  final int end;
  final DiaryCodeTokenRole role;

  @override
  bool operator ==(Object other) =>
      other is DiaryCodeToken &&
      other.start == start &&
      other.end == end &&
      other.role == role;

  @override
  int get hashCode => Object.hash(start, end, role);

  @override
  String toString() => 'DiaryCodeToken($start, $end, ${role.name})';
}

/// 一段文本的高亮结果。
@immutable
class DiaryCodeTokens {
  const DiaryCodeTokens(this.tokens);

  /// 不高亮（纯文本）。
  static const DiaryCodeTokens empty = DiaryCodeTokens(<DiaryCodeToken>[]);

  /// 按起点排好、互不重叠，只含着色区间；区间之间的空隙按正文色显示。
  final List<DiaryCodeToken> tokens;

  bool get isEmpty => tokens.isEmpty;

  /// 与 `[start, end)` 相交的区间（二分查找起点）。
  Iterable<DiaryCodeToken> overlapping(int start, int end) sync* {
    if (start >= end) {
      return;
    }
    var low = 0;
    var high = tokens.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (tokens[mid].end <= start) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    for (var i = low; i < tokens.length && tokens[i].start < end; i++) {
      yield tokens[i];
    }
  }
}

/// 语法高亮与语言识别；用 [instance]。
class DiaryCodeHighlighter {
  DiaryCodeHighlighter._();

  static final DiaryCodeHighlighter instance = DiaryCodeHighlighter._();

  /// 超过这个字符数不高亮。
  static const int maxLength = 20000;

  /// 超过这个行数不高亮。
  static const int maxLines = 600;

  /// 识别语言时只看开头这么多字符。
  static const int detectSampleLength = 2000;

  static const int _tokensCacheSize = 48;
  static const int _detectCacheSize = 128;

  // 识别结果的门槛：最高相关度至少 6，且领先第二名至少 2；否则宁可不识别
  // （按纯文本显示），也不要把一段普通文字染成某种语言。
  static const int _minRelevance = 6;
  static const int _minLead = 2;

  Highlight? _highlight;
  final Map<(String, String), DiaryCodeTokens> _tokensCache = {};
  final Map<String, String?> _detectCache = {};

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
        diaryCodeLanguageById(languageId) == null ||
        _exceedsLimits(text)) {
      return DiaryCodeTokens.empty;
    }
    final key = (languageId, text);
    final cached = _tokensCache.remove(key);
    if (cached != null) {
      _tokensCache[key] = cached;
      return cached;
    }
    final result = _computeTokens(text, languageId);
    _tokensCache[key] = result;
    if (_tokensCache.length > _tokensCacheSize) {
      _tokensCache.remove(_tokensCache.keys.first);
    }
    return result;
  }

  /// 识别 [text] 的语言；只看开头 [detectSampleLength] 个字符，把握不够时
  /// （相关度不足或与第二名太接近）返回 null。
  String? detect(String text) {
    final sample = text.length > detectSampleLength
        ? text.substring(0, detectSampleLength)
        : text;
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
    if (_detectCache.length > _detectCacheSize) {
      _detectCache.remove(_detectCache.keys.first);
    }
    return result;
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
      final result = _engine.parse(sample, autoDetection: true);
      final language = result.language;
      final relevance = result.relevance ?? 0;
      if (language == null || diaryCodeLanguageById(language) == null) {
        return null;
      }
      final second = result.secondBest?.relevance ?? 0;
      if (relevance < _minRelevance || relevance - second < _minLead) {
        return null;
      }
      return language;
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
          : DiaryCodeTokens(List.unmodifiable(tokens));
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
    final Result result;
    try {
      result = _engine.parse(segment, language: languageId);
    } catch (error) {
      if (wholeBlock) {
        rethrow;
      }
      return null;
    }
    final nodes = result.nodes;
    if (nodes == null || _isBailOut(result, segment)) {
      return null;
    }
    final flattener = _Flattener(base);
    flattener.walk(nodes, null, false);
    // 防御：叶子拼回去必须与原文一致，否则偏移会错位，宁可不高亮。
    if (flattener.offset != base + segment.length ||
        flattener.source.toString() != segment) {
      return null;
    }
    return flattener.tokens;
  }

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

/// 把 highlight 的节点树展平为着色区间。
class _Flattener {
  /// [offset] 从这段文本在原文中的起点开始（逐行回退时为行首）。
  _Flattener(this.offset);

  final List<DiaryCodeToken> tokens = [];
  final StringBuffer source = StringBuffer();
  int offset;

  /// [inherited]：外层节点的角色；[inClass]：是否在 `class` 声明包装内。
  void walk(List<Node> nodes, DiaryCodeTokenRole? inherited, bool inClass) {
    for (final node in nodes) {
      var role = inherited;
      var childInClass = inClass;
      final className = node.className;
      // noPrefix 节点是子语言的包装（className 为语言名，如 xml 里的
      // css），不代表记号，直接继承外层。
      if (className != null && className.isNotEmpty && !node.noPrefix) {
        if (className == 'class') {
          childInClass = true;
        } else if (className == 'function') {
          childInClass = false;
        } else {
          final own = diaryCodeTokenRoleFor(className);
          if (own == DiaryCodeTokenRole.function &&
              inClass &&
              className.startsWith('title')) {
            role = DiaryCodeTokenRole.type;
          } else if (own != null) {
            role = own;
          }
        }
      }
      final value = node.value;
      if (value != null) {
        _emit(value, role);
      }
      final children = node.children;
      if (children != null) {
        walk(children, role, childInClass);
      }
    }
  }

  void _emit(String value, DiaryCodeTokenRole? role) {
    if (value.isEmpty) {
      return;
    }
    final start = offset;
    offset += value.length;
    source.write(value);
    if (role == null) {
      return;
    }
    if (tokens.isNotEmpty) {
      final last = tokens.last;
      if (last.end == start && last.role == role) {
        tokens[tokens.length - 1] = DiaryCodeToken(last.start, offset, role);
        return;
      }
    }
    tokens.add(DiaryCodeToken(start, offset, role));
  }
}
