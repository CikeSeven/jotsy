import 'dart:convert';
import 'dart:ui' show Color;

import '../models/diary_text_colors.dart';
import 'diary_export_blocks.dart';
import 'diary_export_code.dart';

/// 网页与 EPUB 共用的 HTML 片段写法：转义、行内样式、代码记号与颜色。
///
/// 两种语法（[xhtml]）：
/// - 网页（false）写 HTML5：空元素不闭合（`<br>`）、布尔属性只写名字
///   （`disabled`）；
/// - EPUB（true）写 XHTML：阅读器按 XML 解析，任何一处不合规整本书都打不开，
///   所以空元素自闭合（`<br/>`）、布尔属性写全（`disabled="disabled"`），
///   文字与属性里去掉 XML 1.0 不允许的字符（制表符、换行、回车以外的控制
///   字符与 U+FFFE / U+FFFF；网页照原样写出，浏览器容忍它们），链接地址
///   规整成合法的 URL（[_href]）。
///
/// 转义只产生 `&amp;` `&lt;` `&gt;` `&quot;` 四种实体，XML 同样认得。
class DiaryHtmlMarkup {
  const DiaryHtmlMarkup._(this.xhtml);

  /// 网页（HTML5 语法）。
  static const DiaryHtmlMarkup html = DiaryHtmlMarkup._(false);

  /// EPUB（XHTML 语法）。
  static const DiaryHtmlMarkup epub = DiaryHtmlMarkup._(true);

  final bool xhtml;

  /// XML 1.0 不允许出现的字符（`Char` 产生式之外）。不成对的代理项由
  /// UTF-8 编码换成 U+FFFD，不必在这里处理。
  static final RegExp _xmlInvalid = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]');

  /// 元素内容的转义。
  String text(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(_clean(value));

  /// 属性值（双引号内）的转义。
  String attr(String value) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert(_clean(value));

  String _clean(String value) =>
      xhtml ? value.replaceAll(_xmlInvalid, '') : value;

  /// 空元素的结尾：网页为 `>`，XHTML 为 `/>`。
  String get voidEnd => xhtml ? '/>' : '>';

  /// 布尔属性：网页只写名字，XHTML 写成 `name="name"`。
  String flag(String name) => xhtml ? '$name="$name"' : name;

  /// 块内换行（软换行、表格格子里两段之间）。
  String get lineBreak => xhtml ? '<br/>' : '<br>';

  /// 一段行内片段写成 HTML；块内换行（[ExportInline.lineBreak]）写成
  /// [lineBreak]，仍在同一个元素里（列表项不会多出一项）。
  String inlines(List<ExportInline> runs) {
    final out = StringBuffer();
    for (final run in runs) {
      if (run.isLineBreak) {
        out.write(lineBreak);
        continue;
      }
      var html = text(run.text);
      final colors = colorStyle(run.color, run.background);
      // 颜色写在下划线 / 删除线外层，线与文字同色（与应用一致）；写在链接
      // 里层，盖过链接色。行内代码直接写在 <code> 上，否则代码自带的底色
      // 会盖住用户的背景色。
      if (run.code) {
        html = colors == null
            ? '<code>$html</code>'
            : '<code style="$colors">$html</code>';
      }
      if (run.bold) html = '<strong>$html</strong>';
      if (run.italic) html = '<em>$html</em>';
      if (run.underline) html = '<u>$html</u>';
      if (run.strike) html = '<s>$html</s>';
      // 字号以 em 计，跟着所在块（标题、表格）的字号缩放，与应用里相对
      // 正文的倍数一致；与颜色写在同一个 span 上。
      final scale = run.sizeScale;
      final style = <String>[
        if (colors != null && !run.code) colors,
        if (scale != null) 'font-size:${em(scale)}',
      ].join(';');
      if (style.isNotEmpty) {
        html = '<span style="$style">$html</span>';
      }
      html = switch (run.script) {
        ExportScript.superscript => '<sup>$html</sup>',
        ExportScript.subscript => '<sub>$html</sub>',
        null => html,
      };
      final link = run.link;
      if (link != null && isSafeLink(link)) {
        html = '<a href="${attr(_href(link))}">$html</a>';
      }
      out.write(html);
    }
    return out.toString();
  }

  /// 记号的 class 与用户颜色写在同一个 span 上：内联样式优先于 class，
  /// 设过文字色的片段保留原色，注释的斜体照旧。
  String codeRun(DiaryExportCodeRun run) {
    final role = run.role;
    final colors = colorStyle(run.color, run.background);
    final value = text(run.text);
    final attributes =
        '${role == null ? '' : ' class="hl-${role.name}"'}'
        '${colors == null ? '' : ' style="$colors"'}';
    return attributes.isEmpty ? value : '<span$attributes>$value</span>';
  }

  /// 链接地址：EPUB 要求是合法的 URL（epubcheck 的 RSC-020），用户粘贴的
  /// 地址里常有空格、引号或中文，经 [Uri] 规整成百分号编码（[isSafeLink]
  /// 已确认解析得了）；网页照原样写出，浏览器自己会规整。
  String _href(String link) => xhtml ? Uri.parse(link).toString() : link;

  /// 只保留 http(s)、mailto、tel 链接：导出文件可能在任意浏览器或阅读器里
  /// 打开，`javascript:` 之类的地址不能变成可点的链接。
  static bool isSafeLink(String link) {
    final scheme = Uri.tryParse(link)?.scheme.toLowerCase();
    return scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'mailto' ||
        scheme == 'tel';
  }

  /// 文字色与背景色的内联样式；都没设时为 null。
  static String? colorStyle(Color? color, Color? background) {
    if (color == null && background == null) {
      return null;
    }
    return <String>[
      if (color != null) 'color:${cssColor(color)}',
      if (background != null) 'background-color:${cssColor(background)}',
    ].join(';');
  }

  /// 不透明写 `#RRGGBB`，半透明写 `rgba()`（比 `#RRGGBBAA` 兼容更旧的
  /// 浏览器与阅读器；Jotsy 导入网页时两种都认）。
  static String cssColor(Color color) {
    final argb = color.toARGB32();
    final alpha = argb >>> 24;
    if (alpha == 0xFF) {
      return diaryColorRgbHex(color);
    }
    return 'rgba(${(argb >> 16) & 0xFF},${(argb >> 8) & 0xFF},${argb & 0xFF},'
        '${(alpha / 255).toStringAsFixed(3)})';
  }

  /// 写成 CSS 字符串。字族名来自用户导入的字体文件，引号、反斜杠、尖括号、
  /// `&` 与控制字符一律转成十六进制转义，不能借名称闭合 `<style>`。
  static String cssString(String value) {
    final out = StringBuffer('"');
    for (final rune in value.runes) {
      if (rune < 0x20 || rune == 0x7F || '"\\<>&'.runes.contains(rune)) {
        out.write('\\${rune.toRadixString(16)} ');
      } else {
        out.writeCharCode(rune);
      }
    }
    return (out..write('"')).toString();
  }

  /// 倍数写成 em，去掉多余的零（如 1.25em、1.5em、0.85em）。
  static String em(double scale) =>
      '${scale.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}em';

  static String px(double value) =>
      '${value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}px';
}
