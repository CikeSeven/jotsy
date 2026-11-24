import 'package:flutter/widgets.dart' show StringCharacters;

/// 盘古之白（中西文 / 中数字自动渲染间距）纯函数工具。
///
/// - 输入：纯文本与可选的跳过范围（如输入法组字区间、上下标、行内代码）；
/// - 输出：所有需要追加视觉间距的前侧字素 UTF-16 区间 `(start, end)`，按起点
///   升序、互不重叠；
/// - 副作用：无；不修改原字符串，也不增减码元。
///
/// 字符分类口径与 CSS Text Level 4 `text-autospace: normal`（`ideograph-alpha`
/// + `ideograph-numeric`）及 Word `autoSpaceDE` / `autoSpaceDN` 保持一致：
/// 仅在 CJK 表意 / 假名 / 谚文与拉丁 / 希腊 / 西里尔字母或阿拉伯数字相邻时
/// 产生间距；全角标点、半角标点、空白与 emoji 一律归为中性字符，避免误伤
/// `#标签`、`@提及`、全角引号与括号。

/// 盘古之白间距占所在字号的比例（约 1/5 em，与 CLREQ / CSS text-autospace
/// 的视觉密度接近）。
const double kPanguSpacingRatio = 0.2;

/// 按字号 [fontSize] 换算盘古之白间距（逻辑像素 / 磅）。
double panguSpacingExtent(double fontSize) =>
    fontSize > 0 ? fontSize * kPanguSpacingRatio : 0;

/// 找出 [text] 中所有需要追加盘古之白的前侧字素区间（UTF-16 偏移）。
///
/// 每个区间 `(start, end)` 对应一个完整的 Unicode 字素（不拆开代理对与组合
/// 字符），其紧邻右侧字素与它构成 CJK ↔ 西文/数字 边界。
///
/// - [excludeStart] / [excludeEnd]：半开区间 `[start, end)`，落在其中或紧邻其
///   边界的字符不产生盘古之白（用于跳过输入法组字区间，避免打拼音时来回抖动）；
/// - [ignoreAt]：返回 `true` 的字素视作中性字符，不触发左右任意一侧的间距
///   （如上下标：注脚上标应紧贴被标注文字）；
/// - [skipTrailingAt]：返回 `true` 的字素仍可作为右侧邻居触发前一个字的间距，
///   但自身不追加尾部间距（如行内代码：避免底色向右拖尾）。
List<(int, int)> findPanguGapRanges(
  String text, {
  int? excludeStart,
  int? excludeEnd,
  bool Function(int offset)? ignoreAt,
  bool Function(int offset)? skipTrailingAt,
}) {
  if (text.length < 2 || !_hasBothScripts(text)) {
    return const <(int, int)>[];
  }
  final hasExclude =
      excludeStart != null && excludeEnd != null && excludeStart < excludeEnd;
  final ranges = <(int, int)>[];
  var offset = 0;
  var prevStart = 0;
  var prevEnd = 0;
  var prevKind = _PanguCharKind.other;
  var prevSkipped = false;

  for (final grapheme in text.characters) {
    final start = offset;
    final end = offset + grapheme.length;
    offset = end;

    final excluded = hasExclude && start < excludeEnd && end > excludeStart;
    final ignored = excluded || (ignoreAt?.call(start) ?? false);
    final kind = ignored ? _PanguCharKind.other : _classifyGrapheme(grapheme);

    if (!prevSkipped && _isBoundary(prevKind, kind)) {
      ranges.add((prevStart, prevEnd));
    }

    prevStart = start;
    prevEnd = end;
    prevKind = kind;
    prevSkipped = ignored || (skipTrailingAt?.call(start) ?? false);
  }
  return ranges;
}

/// 判断相邻两段非空文字 [before] 与 [after] 交界处是否需要盘古之白
/// （用于 PDF 导出时跨样式片段的边界判定）。
bool hasPanguBoundaryBetween(String before, String after) {
  if (before.isEmpty || after.isEmpty) {
    return false;
  }
  final left = _classifyGrapheme(before.characters.last);
  if (left == _PanguCharKind.other) {
    return false;
  }
  final right = _classifyGrapheme(after.characters.first);
  return _isBoundary(left, right);
}

enum _PanguCharKind { cjk, western, other }

bool _isBoundary(_PanguCharKind left, _PanguCharKind right) =>
    (left == _PanguCharKind.cjk && right == _PanguCharKind.western) ||
    (left == _PanguCharKind.western && right == _PanguCharKind.cjk);

/// 快速预检：纯中文、纯西文或纯数字段落不构建 [Characters] 迭代器。
bool _hasBothScripts(String text) {
  var hasCjk = false;
  var hasWestern = false;
  for (final rune in text.runes) {
    if (!hasCjk && _isCjkRune(rune)) {
      hasCjk = true;
      if (hasWestern) return true;
    } else if (!hasWestern && _isWesternRune(rune)) {
      hasWestern = true;
      if (hasCjk) return true;
    }
  }
  return false;
}

_PanguCharKind _classifyGrapheme(String grapheme) {
  if (grapheme.isEmpty) {
    return _PanguCharKind.other;
  }
  // 键帽 emoji（如 `1️⃣`）或显式彩色变体（U+FE0F）的字素虽以数字开头，
  // 但属于图形符号，不按西文处理。
  if (grapheme.length > 1) {
    for (final unit in grapheme.codeUnits) {
      if (unit == 0x20E3 || unit == 0xFE0F) {
        return _PanguCharKind.other;
      }
    }
  }
  final first = grapheme.runes.first;
  if (_isCjkRune(first)) {
    return _PanguCharKind.cjk;
  }
  if (_isWesternRune(first)) {
    return _PanguCharKind.western;
  }
  return _PanguCharKind.other;
}

/// CJK 表意文字、日文假名、注音与韩文谚文（不含全角标点与空白）。
bool _isCjkRune(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK 统一表意文字
    (rune >= 0x3400 && rune <= 0x4DBF) || // CJK 扩展 A
    (rune >= 0x3041 && rune <= 0x3096) || // 平假名
    (rune >= 0x309D && rune <= 0x309F) || // 平假名迭代符号
    (rune >= 0x30A1 && rune <= 0x30FA) || // 片假名（不含中点 U+30FB）
    (rune >= 0x30FC && rune <= 0x30FF) || // 片假名长音与迭代符号
    (rune >= 0x31F0 && rune <= 0x31FF) || // 片假名语音扩展
    (rune >= 0xAC00 && rune <= 0xD7AF) || // 谚文音节
    (rune >= 0x1100 && rune <= 0x11FF) || // 谚文字母
    (rune >= 0x3130 && rune <= 0x318F) || // 谚文兼容字母
    (rune >= 0xA960 && rune <= 0xA97F) || // 谚文字母扩展 A
    (rune >= 0xD7B0 && rune <= 0xD7FF) || // 谚文字母扩展 B
    (rune >= 0x3105 && rune <= 0x312F) || // 注音符号
    (rune >= 0x31A0 && rune <= 0x31BF) || // 注音符号扩展
    (rune >= 0x2E80 && rune <= 0x2FDF) || // CJK 部首补充与康熙部首
    (rune >= 0x3005 && rune <= 0x3007) || // 々 〆 〇
    (rune >= 0xF900 && rune <= 0xFAFF) || // CJK 兼容表意文字
    (rune >= 0x20000 && rune <= 0x323AF) || // CJK 扩展 B–I
    (rune >= 0x2F800 && rune <= 0x2FA1F); // CJK 兼容表意文字补充

/// 拉丁字母（含扩展变音字母）、希腊字母、西里尔字母与阿拉伯数字（不含标点）。
bool _isWesternRune(int rune) =>
    (rune >= 0x0030 && rune <= 0x0039) || // 0–9
    (rune >= 0x0041 && rune <= 0x005A) || // A–Z
    (rune >= 0x0061 && rune <= 0x007A) || // a–z
    (rune >= 0x00C0 && rune <= 0x00D6) || // Latin-1 字母
    (rune >= 0x00D8 && rune <= 0x00F6) ||
    (rune >= 0x00F8 && rune <= 0x024F) || // Latin Extended-A/B
    (rune >= 0x1E00 && rune <= 0x1EFF) || // Latin Extended Additional
    rune == 0x0386 ||
    (rune >= 0x0388 && rune <= 0x038A) ||
    rune == 0x038C ||
    (rune >= 0x038E && rune <= 0x03A1) ||
    (rune >= 0x03A3 && rune <= 0x03FF) || // 希腊字母
    (rune >= 0x0400 && rune <= 0x052F); // 西里尔字母（含扩展）
