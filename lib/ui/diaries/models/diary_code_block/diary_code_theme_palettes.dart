import 'package:flutter/material.dart';

import 'diary_code_block_style.dart';
import 'diary_code_theme.dart';

// 代码块配色主题的原始色值（不含跟随应用配色的 `app` 主题，它在
// `diary_code_theme.dart` 里由 ColorScheme 推出）。
//
// 每个主题各有浅色与深色一套，色值取自主题的官方色板：
// GitHub（Primer Light / Dark）、One（Atom One Light / One Dark）、
// Solarized（Light / Dark）、Gruvbox（Light / Dark）、Catppuccin（Latte /
// Mocha）、Tokyo Night（Day / Night）、Nord（Snow Storm 底配 Frost / Aurora，
// Polar Night 深色）、Dracula（Alucard / Dracula）、Rosé Pine（Dawn / Main）。
//
// 这里只存官方原值；部分官方配色的注释、行号与浅底上的冷色对比度不足，
// 由 [DiaryCodeThemes.palette] 在构建时统一经 `ensureContrast` 调整明度，
// 保证可读的同时不改动这里的数据。

/// 一套主题的原始色值。
@immutable
class DiaryCodeRawPalette {
  const DiaryCodeRawPalette({
    required this.background,
    required this.header,
    required this.border,
    required this.foreground,
    required this.lineNumber,
    required this.inlineBackground,
    required this.inlineForegroundRole,
    required this.keyword,
    required this.type,
    required this.function,
    required this.string,
    required this.number,
    required this.literal,
    required this.comment,
    required this.variable,
    required this.meta,
    required this.tag,
    required this.addition,
    required this.deletion,
  });

  final Color background;

  /// 标题栏底色：主题自己的次级背景，与 [background] 差一级色调。
  final Color header;
  final Color border;
  final Color foreground;
  final Color lineNumber;

  /// 行内代码底色（不透明，叠在正文页面上）。
  final Color inlineBackground;

  /// 行内代码文字取哪个语法色。
  final DiaryCodeTokenRole inlineForegroundRole;

  final Color keyword;
  final Color type;
  final Color function;
  final Color string;
  final Color number;
  final Color literal;
  final Color comment;
  final Color variable;
  final Color meta;
  final Color tag;
  final Color addition;
  final Color deletion;

  Map<DiaryCodeTokenRole, Color> get tokens => <DiaryCodeTokenRole, Color>{
    DiaryCodeTokenRole.keyword: keyword,
    DiaryCodeTokenRole.type: type,
    DiaryCodeTokenRole.function: function,
    DiaryCodeTokenRole.string: string,
    DiaryCodeTokenRole.number: number,
    DiaryCodeTokenRole.literal: literal,
    DiaryCodeTokenRole.comment: comment,
    DiaryCodeTokenRole.variable: variable,
    DiaryCodeTokenRole.meta: meta,
    DiaryCodeTokenRole.tag: tag,
    DiaryCodeTokenRole.addition: addition,
    DiaryCodeTokenRole.deletion: deletion,
  };
}

/// 取主题的原始色值；[DiaryCodeThemeId.app] 返回 null（由配色方案推出）。
DiaryCodeRawPalette? diaryCodeRawPalette(
  DiaryCodeThemeId id,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  return switch (id) {
    DiaryCodeThemeId.app => null,
    DiaryCodeThemeId.github => dark ? _githubDark : _githubLight,
    DiaryCodeThemeId.one => dark ? _oneDark : _oneLight,
    DiaryCodeThemeId.solarized => dark ? _solarizedDark : _solarizedLight,
    DiaryCodeThemeId.gruvbox => dark ? _gruvboxDark : _gruvboxLight,
    DiaryCodeThemeId.catppuccin => dark ? _catppuccinMocha : _catppuccinLatte,
    DiaryCodeThemeId.tokyoNight => dark ? _tokyoNight : _tokyoDay,
    DiaryCodeThemeId.nord => dark ? _nordDark : _nordLight,
    DiaryCodeThemeId.dracula => dark ? _dracula : _alucard,
    DiaryCodeThemeId.rosePine => dark ? _rosePineMain : _rosePineDawn,
  };
}

// GitHub：Primer 语法色（prettylights）。
const _githubLight = DiaryCodeRawPalette(
  background: Color(0xFFFFFFFF),
  header: Color(0xFFF6F8FA),
  border: Color(0xFFD0D7DE),
  foreground: Color(0xFF1F2328),
  lineNumber: Color(0xFF6E7781),
  inlineBackground: Color(0xFFEFF1F3),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFCF222E),
  type: Color(0xFF953800),
  function: Color(0xFF8250DF),
  string: Color(0xFF0A3069),
  number: Color(0xFF0550AE),
  literal: Color(0xFF0550AE),
  comment: Color(0xFF6E7781),
  variable: Color(0xFF953800),
  meta: Color(0xFF0550AE),
  tag: Color(0xFF116329),
  addition: Color(0xFF116329),
  deletion: Color(0xFF82071E),
);

const _githubDark = DiaryCodeRawPalette(
  background: Color(0xFF0D1117),
  header: Color(0xFF161B22),
  border: Color(0xFF30363D),
  foreground: Color(0xFFE6EDF3),
  lineNumber: Color(0xFF6E7681),
  inlineBackground: Color(0xFF343941),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFFF7B72),
  type: Color(0xFFFFA657),
  function: Color(0xFFD2A8FF),
  string: Color(0xFFA5D6FF),
  number: Color(0xFF79C0FF),
  literal: Color(0xFF79C0FF),
  comment: Color(0xFF8B949E),
  variable: Color(0xFFFFA657),
  meta: Color(0xFF79C0FF),
  tag: Color(0xFF7EE787),
  addition: Color(0xFFAFF5B4),
  deletion: Color(0xFFFFDCD7),
);

// One：Atom One Light / One Dark。
const _oneLight = DiaryCodeRawPalette(
  background: Color(0xFFFAFAFA),
  header: Color(0xFFEAEAEB),
  border: Color(0xFFDBDBDC),
  foreground: Color(0xFF383A42),
  lineNumber: Color(0xFF9D9D9F),
  inlineBackground: Color(0xFFEAEAEB),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFA626A4),
  type: Color(0xFFC18401),
  function: Color(0xFF4078F2),
  string: Color(0xFF50A14F),
  number: Color(0xFF986801),
  literal: Color(0xFF0184BC),
  comment: Color(0xFFA0A1A7),
  variable: Color(0xFFE45649),
  meta: Color(0xFF4078F2),
  tag: Color(0xFFE45649),
  addition: Color(0xFF50A14F),
  deletion: Color(0xFFE45649),
);

const _oneDark = DiaryCodeRawPalette(
  background: Color(0xFF282C34),
  header: Color(0xFF21252B),
  border: Color(0xFF3E4451),
  foreground: Color(0xFFABB2BF),
  lineNumber: Color(0xFF636D83),
  inlineBackground: Color(0xFF3E4451),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFC678DD),
  type: Color(0xFFE5C07B),
  function: Color(0xFF61AFEF),
  string: Color(0xFF98C379),
  number: Color(0xFFD19A66),
  literal: Color(0xFF56B6C2),
  comment: Color(0xFF5C6370),
  variable: Color(0xFFE06C75),
  meta: Color(0xFF61AFEF),
  tag: Color(0xFFE06C75),
  addition: Color(0xFF98C379),
  deletion: Color(0xFFE06C75),
);

// Solarized：base03…base3 与八个强调色。
const _solarizedLight = DiaryCodeRawPalette(
  background: Color(0xFFFDF6E3), // base3
  header: Color(0xFFEEE8D5), // base2
  border: Color(0xFFDDD6C1),
  foreground: Color(0xFF657B83), // base00
  lineNumber: Color(0xFF93A1A1), // base1
  inlineBackground: Color(0xFFEEE8D5),
  inlineForegroundRole: DiaryCodeTokenRole.meta,
  keyword: Color(0xFF859900), // green
  type: Color(0xFFB58900), // yellow
  function: Color(0xFF268BD2), // blue
  string: Color(0xFF2AA198), // cyan
  number: Color(0xFFD33682), // magenta
  literal: Color(0xFFD33682),
  comment: Color(0xFF93A1A1), // base1
  variable: Color(0xFF6C71C4), // violet
  meta: Color(0xFFCB4B16), // orange
  tag: Color(0xFF268BD2),
  addition: Color(0xFF859900),
  deletion: Color(0xFFDC322F), // red
);

const _solarizedDark = DiaryCodeRawPalette(
  background: Color(0xFF002B36), // base03
  header: Color(0xFF073642), // base02
  border: Color(0xFF194550),
  foreground: Color(0xFF839496), // base0
  lineNumber: Color(0xFF586E75), // base01
  inlineBackground: Color(0xFF073642),
  inlineForegroundRole: DiaryCodeTokenRole.meta,
  keyword: Color(0xFF859900),
  type: Color(0xFFB58900),
  function: Color(0xFF268BD2),
  string: Color(0xFF2AA198),
  number: Color(0xFFD33682),
  literal: Color(0xFFD33682),
  comment: Color(0xFF586E75), // base01
  variable: Color(0xFF6C71C4),
  meta: Color(0xFFCB4B16),
  tag: Color(0xFF268BD2),
  addition: Color(0xFF859900),
  deletion: Color(0xFFDC322F),
);

// Gruvbox：浅色用 faded 强调色，深色用 bright 强调色。
const _gruvboxLight = DiaryCodeRawPalette(
  background: Color(0xFFFBF1C7), // bg0
  header: Color(0xFFEBDBB2), // bg1
  border: Color(0xFFD5C4A1), // bg2
  foreground: Color(0xFF3C3836), // fg
  lineNumber: Color(0xFF7C6F64), // fg4
  inlineBackground: Color(0xFFEBDBB2),
  inlineForegroundRole: DiaryCodeTokenRole.meta,
  keyword: Color(0xFF9D0006), // red
  type: Color(0xFFB57614), // yellow
  function: Color(0xFF79740E), // green
  string: Color(0xFF79740E),
  number: Color(0xFF8F3F71), // purple
  literal: Color(0xFF8F3F71),
  comment: Color(0xFF928374), // gray
  variable: Color(0xFF076678), // blue
  meta: Color(0xFFAF3A03), // orange
  tag: Color(0xFF427B58), // aqua
  addition: Color(0xFF79740E),
  deletion: Color(0xFF9D0006),
);

const _gruvboxDark = DiaryCodeRawPalette(
  background: Color(0xFF282828), // bg0
  header: Color(0xFF3C3836), // bg1
  border: Color(0xFF504945), // bg2
  foreground: Color(0xFFEBDBB2), // fg
  lineNumber: Color(0xFF7C6F64), // bg4
  inlineBackground: Color(0xFF3C3836),
  inlineForegroundRole: DiaryCodeTokenRole.meta,
  keyword: Color(0xFFFB4934),
  type: Color(0xFFFABD2F),
  function: Color(0xFFB8BB26),
  string: Color(0xFFB8BB26),
  number: Color(0xFFD3869B),
  literal: Color(0xFFD3869B),
  comment: Color(0xFF928374),
  variable: Color(0xFF83A598),
  meta: Color(0xFFFE8019),
  tag: Color(0xFF8EC07C),
  addition: Color(0xFFB8BB26),
  deletion: Color(0xFFFB4934),
);

// Catppuccin：Latte / Mocha。
const _catppuccinLatte = DiaryCodeRawPalette(
  background: Color(0xFFEFF1F5), // base
  header: Color(0xFFE6E9EF), // mantle
  border: Color(0xFFCCD0DA), // surface0
  foreground: Color(0xFF4C4F69), // text
  lineNumber: Color(0xFF8C8FA1), // overlay1
  inlineBackground: Color(0xFFDCE0E8), // crust
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFF8839EF), // mauve
  type: Color(0xFFDF8E1D), // yellow
  function: Color(0xFF1E66F5), // blue
  string: Color(0xFF40A02B), // green
  number: Color(0xFFFE640B), // peach
  literal: Color(0xFFFE640B),
  comment: Color(0xFF7C7F93), // overlay2
  variable: Color(0xFFE64553), // maroon
  meta: Color(0xFFEA76CB), // pink
  tag: Color(0xFF179299), // teal
  addition: Color(0xFF40A02B),
  deletion: Color(0xFFD20F39), // red
);

const _catppuccinMocha = DiaryCodeRawPalette(
  background: Color(0xFF1E1E2E), // base
  header: Color(0xFF181825), // mantle
  border: Color(0xFF313244), // surface0
  foreground: Color(0xFFCDD6F4), // text
  lineNumber: Color(0xFF7F849C), // overlay1
  inlineBackground: Color(0xFF313244), // surface0
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFCBA6F7),
  type: Color(0xFFF9E2AF),
  function: Color(0xFF89B4FA),
  string: Color(0xFFA6E3A1),
  number: Color(0xFFFAB387),
  literal: Color(0xFFFAB387),
  comment: Color(0xFF9399B2),
  variable: Color(0xFFEBA0AC),
  meta: Color(0xFFF5C2E7),
  tag: Color(0xFF94E2D5),
  addition: Color(0xFFA6E3A1),
  deletion: Color(0xFFF38BA8),
);

// Tokyo Night：Day / Night。
const _tokyoDay = DiaryCodeRawPalette(
  background: Color(0xFFE1E2E7), // bg
  header: Color(0xFFD0D5E3), // bg_dark
  border: Color(0xFFC4C8DA), // bg_highlight
  foreground: Color(0xFF3760BF), // fg
  lineNumber: Color(0xFFA8AECB), // fg_gutter
  inlineBackground: Color(0xFFD0D5E3),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFF9854F1), // magenta
  type: Color(0xFF188092), // blue1
  function: Color(0xFF2E7DE9), // blue
  string: Color(0xFF587539), // green
  number: Color(0xFFB15C00), // orange
  literal: Color(0xFFB15C00),
  comment: Color(0xFF848CB5), // comment
  variable: Color(0xFF8C6C3E), // yellow
  meta: Color(0xFF007197), // cyan
  tag: Color(0xFFF52A65), // red
  addition: Color(0xFF587539),
  deletion: Color(0xFFF52A65),
);

const _tokyoNight = DiaryCodeRawPalette(
  background: Color(0xFF1A1B26), // bg
  header: Color(0xFF16161E), // bg_dark
  border: Color(0xFF292E42), // bg_highlight
  foreground: Color(0xFFC0CAF5), // fg
  lineNumber: Color(0xFF3B4261), // fg_gutter
  inlineBackground: Color(0xFF292E42),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFBB9AF7), // magenta
  type: Color(0xFF2AC3DE), // blue1
  function: Color(0xFF7AA2F7), // blue
  string: Color(0xFF9ECE6A), // green
  number: Color(0xFFFF9E64), // orange
  literal: Color(0xFFFF9E64),
  comment: Color(0xFF565F89), // comment
  variable: Color(0xFFE0AF68), // yellow
  meta: Color(0xFF7DCFFF), // cyan
  tag: Color(0xFFF7768E), // red
  addition: Color(0xFF9ECE6A),
  deletion: Color(0xFFF7768E),
);

// Nord：浅色以 Snow Storm 为底、Polar Night 为字，语法色仍取 Frost /
// Aurora（浅底上对比度不足的由构建时压暗）。
const _nordLight = DiaryCodeRawPalette(
  background: Color(0xFFECEFF4), // nord6
  header: Color(0xFFE5E9F0), // nord5
  border: Color(0xFFD8DEE9), // nord4
  foreground: Color(0xFF2E3440), // nord0
  lineNumber: Color(0xFF4C566A), // nord3
  inlineBackground: Color(0xFFE5E9F0),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFF5E81AC), // nord10
  type: Color(0xFF8FBCBB), // nord7
  function: Color(0xFF88C0D0), // nord8
  string: Color(0xFFA3BE8C), // nord14
  number: Color(0xFFB48EAD), // nord15
  literal: Color(0xFFB48EAD),
  comment: Color(0xFF616E88), // 官方注释色（nord3 提亮）
  variable: Color(0xFF4C566A), // nord3
  meta: Color(0xFFD08770), // nord12
  tag: Color(0xFF81A1C1), // nord9
  addition: Color(0xFFA3BE8C),
  deletion: Color(0xFFBF616A), // nord11
);

const _nordDark = DiaryCodeRawPalette(
  background: Color(0xFF2E3440), // nord0
  header: Color(0xFF3B4252), // nord1
  border: Color(0xFF434C5E), // nord2
  foreground: Color(0xFFD8DEE9), // nord4
  lineNumber: Color(0xFF4C566A), // nord3
  inlineBackground: Color(0xFF3B4252),
  inlineForegroundRole: DiaryCodeTokenRole.function,
  keyword: Color(0xFF81A1C1), // nord9
  type: Color(0xFF8FBCBB), // nord7
  function: Color(0xFF88C0D0), // nord8
  string: Color(0xFFA3BE8C), // nord14
  number: Color(0xFFB48EAD), // nord15
  literal: Color(0xFFB48EAD),
  comment: Color(0xFF616E88),
  variable: Color(0xFFD8DEE9), // nord4
  meta: Color(0xFFD08770), // nord12
  tag: Color(0xFF81A1C1), // nord9
  addition: Color(0xFFA3BE8C),
  deletion: Color(0xFFBF616A),
);

// Dracula：Alucard（官方浅色）/ Dracula。
const _alucard = DiaryCodeRawPalette(
  background: Color(0xFFFFFBEB),
  header: Color(0xFFEFEDDC),
  border: Color(0xFFCFCFDE),
  foreground: Color(0xFF1F1F1F),
  lineNumber: Color(0xFF6C664B),
  inlineBackground: Color(0xFFEFEDDC),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFA3144D), // pink
  type: Color(0xFF036A96), // cyan
  function: Color(0xFF14710A), // green
  string: Color(0xFF846E15), // yellow
  number: Color(0xFF644AC9), // purple
  literal: Color(0xFF644AC9),
  comment: Color(0xFF6C664B),
  variable: Color(0xFFA34D14), // orange
  meta: Color(0xFF036A96),
  tag: Color(0xFFA3144D),
  addition: Color(0xFF14710A),
  deletion: Color(0xFFCB3A2A), // red
);

const _dracula = DiaryCodeRawPalette(
  background: Color(0xFF282A36),
  header: Color(0xFF21222C),
  border: Color(0xFF44475A), // current line
  foreground: Color(0xFFF8F8F2),
  lineNumber: Color(0xFF6272A4),
  inlineBackground: Color(0xFF44475A),
  inlineForegroundRole: DiaryCodeTokenRole.keyword,
  keyword: Color(0xFFFF79C6), // pink
  type: Color(0xFF8BE9FD), // cyan
  function: Color(0xFF50FA7B), // green
  string: Color(0xFFF1FA8C), // yellow
  number: Color(0xFFBD93F9), // purple
  literal: Color(0xFFBD93F9),
  comment: Color(0xFF6272A4),
  variable: Color(0xFFFFB86C), // orange
  meta: Color(0xFF8BE9FD),
  tag: Color(0xFFFF79C6),
  addition: Color(0xFF50FA7B),
  deletion: Color(0xFFFF5555), // red
);

// Rosé Pine：Dawn / Main。
const _rosePineDawn = DiaryCodeRawPalette(
  background: Color(0xFFFAF4ED), // base
  header: Color(0xFFF2E9E1), // overlay
  border: Color(0xFFDFDAD9), // highlight med
  foreground: Color(0xFF575279), // text
  lineNumber: Color(0xFF9893A5), // muted
  inlineBackground: Color(0xFFF2E9E1),
  inlineForegroundRole: DiaryCodeTokenRole.variable,
  keyword: Color(0xFF286983), // pine
  type: Color(0xFF56949F), // foam
  function: Color(0xFFD7827E), // rose
  string: Color(0xFFEA9D34), // gold
  number: Color(0xFFEA9D34),
  literal: Color(0xFFB4637A), // love
  comment: Color(0xFF9893A5), // muted
  variable: Color(0xFF907AA9), // iris
  meta: Color(0xFF907AA9),
  tag: Color(0xFF56949F),
  addition: Color(0xFF56949F),
  deletion: Color(0xFFB4637A),
);

const _rosePineMain = DiaryCodeRawPalette(
  background: Color(0xFF191724), // base
  header: Color(0xFF1F1D2E), // surface
  border: Color(0xFF403D52), // highlight med
  foreground: Color(0xFFE0DEF4), // text
  lineNumber: Color(0xFF6E6A86), // muted
  inlineBackground: Color(0xFF26233A), // overlay
  inlineForegroundRole: DiaryCodeTokenRole.variable,
  keyword: Color(0xFF31748F), // pine
  type: Color(0xFF9CCFD8), // foam
  function: Color(0xFFEBBCBA), // rose
  string: Color(0xFFF6C177), // gold
  number: Color(0xFFF6C177),
  literal: Color(0xFFEB6F92), // love
  comment: Color(0xFF6E6A86), // muted
  variable: Color(0xFFC4A7E7), // iris
  meta: Color(0xFFC4A7E7),
  tag: Color(0xFF9CCFD8),
  addition: Color(0xFF9CCFD8),
  deletion: Color(0xFFEB6F92),
);
