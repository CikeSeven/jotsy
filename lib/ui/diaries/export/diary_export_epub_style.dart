import '../models/diary_callout_tone.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import '../models/diary_text_colors.dart';
import 'diary_export_code.dart';
import 'diary_export_html_markup.dart';

/// EPUB 的样式表（`OEBPS/style.css`），与网页共用同一套类名（正文由
/// `DiaryHtmlBody` 写出），但按阅读器的习惯另写：
///
/// - 不写页面底色、正文字色、字号与页边距：阅读器自带白底 / 米黄 / 夜间
///   主题，读者可以调字号与页边距，书里写死只会与它们打架；
/// - 不用 CSS 变量与 `prefers-color-scheme`：不少阅读器的排版引擎不认它们。
///   线条、底纹与次要文字一律用半透明的中性灰或透明度，白底与夜间主题上都
///   看得清；
/// - 代码块折行（阅读器里不能横向滚动），给了代码配色时用纸面那套
///   （底色与字色一起写，任何阅读主题下都自成一块）；
/// - 提示块的底色是强调色（[DiaryCalloutTone.paperAccent]）的半透明叠色
///   （[_calloutTint]），浅色与夜间主题上都是一层淡淡的同色底；
/// - 小图一排用弹性布局，不认弹性布局的引擎退回行内图片，仍排成一行；
/// - 用户选了导入字体时把字族名写进 `body`（不嵌入字体文件，与网页、Word
///   一致），阅读器里没有这款字体时用阅读器的字体。
class DiaryEpubStyle {
  const DiaryEpubStyle._();

  /// 提示块底色：强调色的不透明度。
  static const double _calloutTint = 0.18;

  static String css({
    DiaryExportCodeTheme? code,
    List<String> fontFamilies = const <String>[],
    bool panguSpacing = false,
  }) {
    final out = StringBuffer(_base);
    if (fontFamilies.isNotEmpty) {
      out.write(
        'body{font-family:'
        '${fontFamilies.map(DiaryHtmlMarkup.cssString).join(',')}}\n',
      );
    }
    if (panguSpacing) {
      out.write(
        'body{text-autospace:normal}\npre,code{text-autospace:no-autospace}\n',
      );
    }
    for (final tone in DiaryCalloutTone.values) {
      out.write(
        '.callout-${tone.id}{background:'
        '${DiaryHtmlMarkup.cssColor(tone.paperAccent.withValues(alpha: _calloutTint))};'
        'border-left-color:${DiaryHtmlMarkup.cssColor(tone.paperAccent)}}\n',
      );
    }
    if (code != null) {
      _writeCodeCss(
        out,
        code.paper,
        italicComments: code.italicFor(DiaryCodeTokenRole.comment),
      );
    }
    return out.toString();
  }

  static void _writeCodeCss(
    StringBuffer out,
    DiaryCodePalette palette, {
    required bool italicComments,
  }) {
    out.write(
      'pre{background:${diaryColorRgbHex(palette.background)};'
      'color:${diaryColorRgbHex(palette.foreground)}}\n',
    );
    for (final role in DiaryCodeTokenRole.values) {
      out.write(
        '.hl-${role.name}{color:${diaryColorRgbHex(palette.tokens[role]!)}}',
      );
    }
    if (italicComments) {
      out.write('.hl-comment{font-style:italic}');
    }
    out.write('\n');
  }

  static const String _base = '''
body{line-height:1.6;overflow-wrap:break-word}
article>header{margin:0 0 1em}
article>header h1,article>header h2{margin:0 0 .25em;font-size:1.5em;line-height:1.35}
.meta{margin:0;font-size:.875em;opacity:.7}
.tags{list-style:none;margin:.5em 0 0;padding:0}
.tags li{display:inline-block;margin:0 .4em .3em 0;padding:0 .6em;border:1px solid rgba(128,128,128,.4);border-radius:.8em;font-size:.8em}
p{margin:0}
p.blank{height:1em}
h2,h3,h4,h5,h6{margin:1em 0 .25em;line-height:1.4}
h6.h-level-7{opacity:.75}
h6.h-level-8{opacity:.75;font-weight:500}
figure{margin:.75em 0}
img{display:block;max-width:100%;height:auto}
figure.align-center img{margin-left:auto;margin-right:auto}
figure.align-right img{margin-left:auto}
.cover img{width:100%}
figure.thumbs{display:flex}
figure.thumbs-center{justify-content:center;text-align:center}
figure.thumbs-right{justify-content:flex-end;text-align:right}
img.thumb{display:inline-block;flex:none;width:30%;width:calc((100% - 16px) / 3);max-width:120px;height:auto;aspect-ratio:1;object-fit:cover;border-radius:12px;margin:0 8px 0 0}
img.thumb:last-child{margin-right:0}
hr{margin:1em 0;border:0;border-top:1px solid rgba(128,128,128,.45)}
blockquote{margin:.5em 0;padding:.25em 0 .25em 1em;border-left:3px solid rgba(128,128,128,.45);opacity:.85}
pre{margin:.5em 0;padding:.75em 1em;background:rgba(128,128,128,.12);border-radius:.5em;white-space:pre-wrap;overflow-wrap:break-word;font-size:.875em;line-height:1.5}
code{font-family:monospace}
p code,li code,td code,th code,summary code,.callout-body code{background:rgba(128,128,128,.15);border-radius:.3em;padding:0 .3em}
ul,ol{margin:.25em 0;padding-left:1.6em}
li.task{list-style:none;margin-left:-1.4em}
li.task input{margin:0 .2em 0 0}
li.ls-decimal{list-style-type:decimal}
li.ls-paren{list-style-type:jotsy-paren}
li.ls-circled{list-style-type:jotsy-circled}
li.ls-cjk{list-style-type:simp-chinese-informal}
li.ls-lower-alpha{list-style-type:lower-alpha}
li.ls-upper-alpha{list-style-type:upper-alpha}
li.ls-lower-roman{list-style-type:lower-roman}
li.ls-upper-roman{list-style-type:upper-roman}
li.ls-disc{list-style-type:disc}
li.ls-circle{list-style-type:circle}
li.ls-square{list-style-type:square}
li.ls-diamond{list-style-type:"◆  "}
li.ls-star{list-style-type:"★  "}
li.ls-arrow{list-style-type:"→  "}
li.ls-dash{list-style-type:"–  "}
@counter-style jotsy-paren{system:extends decimal;prefix:"(";suffix:") "}
@counter-style jotsy-circled{system:fixed;symbols:"①" "②" "③" "④" "⑤" "⑥" "⑦" "⑧" "⑨" "⑩";suffix:" "}
.attachment{margin:.25em 0;font-size:.875em;opacity:.7}
.callout{display:flex;margin:.5em 0;padding:.6em .9em;border-left:3px solid rgba(128,128,128,.6);border-radius:.4em}
.callout-icon{flex:none;margin-right:.6em}
.callout-body{flex:1;min-width:0}
details{margin:.25em 0;padding-left:1.4em}
details>summary{margin-left:-1.4em}
table{width:100%;border-collapse:collapse;margin:.5em 0}
th,td{border:1px solid rgba(128,128,128,.45);padding:.3em .6em;text-align:left;text-align:start;vertical-align:top}
th{background:rgba(128,128,128,.12);font-weight:600}
.comments{margin-top:1.25em;padding-top:.75em;border-top:1px solid rgba(128,128,128,.4)}
.comments>h2,.comments>h3{margin:0 0 .5em;font-size:1em;line-height:1.4;opacity:.7}
.comment{margin:0 0 .75em}
.comment-text{white-space:pre-wrap}
.comment-images{margin-top:.4em}
.comment-images img{display:inline-block;width:112px;height:112px;object-fit:cover;border-radius:10px;margin:0 4px 4px 0}
.book-title{text-align:center;padding-top:2em}
.book-title h1{margin:0 0 .5em;font-size:2em;line-height:1.3}
.book-cover{margin:0 auto 1.5em;max-width:80%}
.book-cover img{margin:0 auto}
.book-description{margin:0 0 1em;opacity:.75}
.book-title .meta{margin:.25em 0}
nav.toc h1{margin:0 0 .75em;font-size:1.5em}
nav.toc ol{list-style:none;margin:0;padding:0}
nav.toc li{margin:.2em 0}
nav.toc a{text-decoration:none;color:inherit}
.toc-chapters>li{margin:0 0 .75em;font-weight:600}
.toc-chapters .toc-entries{margin:.25em 0 0 1.2em;font-weight:400}
.toc-date{font-size:.875em;opacity:.7;margin-right:.3em}
.chapter-title{margin:0 0 1.25em;font-size:1.8em;line-height:1.3}
''';
}
