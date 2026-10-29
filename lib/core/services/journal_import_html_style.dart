import 'package:html/dom.dart' as dom;

import '../database/diary_blocks/diary_blocks_schema.dart';
import 'journal_import_style.dart';

/// 读取元素自身的行内格式（内联 style、`<font>` 属性、`<mark>`、`<big>` /
/// `<small>`、上下标 `<sup>` / `<sub>` 与 `vertical-align`），叠加在继承的 [inline] 上；Markdown 的行内 HTML 标签也经这里
/// 读取。
///
/// 颜色与字号显式改回默认值（默认墨色、正文字号）时去掉继承的格式；看不
/// 懂的值（`inherit`、CSS 变量等）保持继承。`font-size` 先除以来源的正文
/// 字号 [baseRatio]（见 [journalDominantFontSizeRatio]）再换算档位。
Map<String, Object?> journalHtmlInlineStyle(
  dom.Element element,
  Map<String, Object?> inline, {
  double baseRatio = 1,
}) {
  final style = element.attributes['style'];
  final result = {...inline};
  switch (element.localName) {
    case 'mark':
      result['background'] = journalHighlightColor;
    case 'big':
      result['size'] = 'large';
    case 'small':
      result['size'] = 'small';
    case 'sup':
      result['script'] = kDiaryScriptSuper;
    case 'sub':
      result['script'] = kDiaryScriptSub;
    case 'font':
      _setColor(result, 'color', element.attributes['color'], text: true);
      final level = element.attributes['size'];
      if (level != null && int.tryParse(level.replaceFirst('+', '')) != null) {
        _setValue(result, 'size', journalFontSizeForLegacyLevel(level));
      }
  }
  if (style == null || style.trim().isEmpty) return result;
  final lower = style.toLowerCase();
  if (RegExp(r'font-weight\s*:\s*(bold|[6-9]00)').hasMatch(lower)) {
    result['bold'] = true;
  }
  if (RegExp(r'font-style\s*:\s*italic').hasMatch(lower)) {
    result['italic'] = true;
  }
  if (RegExp(r'text-decoration[^;]*underline').hasMatch(lower)) {
    result['underline'] = true;
  }
  if (RegExp(r'text-decoration[^;]*line-through').hasMatch(lower)) {
    result['strike'] = true;
  }
  _setColor(result, 'color', journalStyleValue(style, 'color'), text: true);
  _setColor(
    result,
    'background',
    journalStyleValue(style, 'background-color') ??
        journalStyleValue(style, 'background'),
    text: false,
  );
  // 上下标：super / sub 写入，baseline 取消继承的；长度、百分比等其他
  // 写法（多为排版微调）保持继承。
  switch (journalStyleValue(style, 'vertical-align')?.trim().toLowerCase()) {
    case 'super':
      result['script'] = kDiaryScriptSuper;
    case 'sub':
      result['script'] = kDiaryScriptSub;
    case 'baseline':
      result.remove('script');
  }
  final ratio = journalFontSizeRatio(journalStyleValue(style, 'font-size'));
  if (ratio != null) {
    _setValue(result, 'size', journalFontSizeForRatio(ratio / baseRatio));
  }
  return result;
}

/// 正文里占字数最多的 `font-size`（与 16px 之比），作为来源的正文字号。
///
/// 网页剪藏与部分应用把整篇包在一个字号里（如 `font-size: 12px`），按绝对
/// 值换算会让全文都变成小字；以占比最大的字号为正文，只有偏离它的文字才
/// 记作小 / 大 / 特大。占比最大的字号本就落在正文档位内时返回 1。标题、
/// 代码与不显示的内容不参与统计。
double journalDominantFontSizeRatio(Iterable<dom.Node> nodes) {
  final weights = <double, int>{};
  void walk(dom.Node node, double ratio) {
    if (node is dom.Text) {
      final length = node.text.trim().length;
      if (length > 0) weights[ratio] = (weights[ratio] ?? 0) + length;
      return;
    }
    if (node is! dom.Element) return;
    if (const {
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'pre',
      'code',
      'script',
      'style',
      'head',
      'title',
      'template',
    }.contains(node.localName)) {
      return;
    }
    final own = journalFontSizeRatio(
      journalStyleValue(node.attributes['style'], 'font-size'),
    );
    final next = own == null ? ratio : (own * 100).round() / 100;
    for (final child in node.nodes) {
      walk(child, next);
    }
  }

  for (final node in nodes) {
    walk(node, 1);
  }
  if (weights.isEmpty) return 1;
  final dominant = weights.entries.reduce(
    (a, b) => b.value > a.value || (b.value == a.value && b.key == 1) ? b : a,
  );
  return journalFontSizeForRatio(dominant.key) == null ? 1 : dominant.key;
}

/// 颜色声明：能识别时写入（默认墨色、白色背景去掉继承的值），看不懂的
/// 保持继承；透明背景不遮挡外层的高亮，同样保持继承。
void _setColor(
  Map<String, Object?> result,
  String key,
  String? css, {
  required bool text,
}) {
  if (css == null || !journalIsColor(css)) return;
  final value = text ? journalTextColor(css) : journalBackgroundColor(css);
  if (value == null && !text && _isTransparent(css)) return;
  _setValue(result, key, value);
}

void _setValue(Map<String, Object?> result, String key, String? v) {
  if (v == null) {
    result.remove(key);
  } else {
    result[key] = v;
  }
}

bool _isTransparent(String css) {
  final value = css.trim().toLowerCase();
  return value == 'transparent' ||
      RegExp(r'^rgba\(.*[,/]\s*0(\.0*)?\s*\)$').hasMatch(value) ||
      RegExp(r'^#([0-9a-f]{3}0|[0-9a-f]{6}00)$').hasMatch(value);
}
