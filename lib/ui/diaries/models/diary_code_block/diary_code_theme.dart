import 'package:flutter/material.dart';

import '../../viewmodels/diary_card_colors.dart';
import 'diary_code_block_style.dart';
import 'diary_code_theme_palettes.dart';

// 代码块配色：语法记号的语义角色、highlight.js className 到角色的映射、
// 一套可直接用于渲染的调色板 [DiaryCodePalette] 及其构建 [DiaryCodeThemes]。
//
// 输入：主题 id、明暗与当前 ColorScheme（只有跟随应用的 `app` 主题用到）。
// 输出：不可变的 [DiaryCodePalette]，按 (主题, 明暗, app 用到的配色) 缓存。
//
// 可读性兜底在构建时统一做（[ensureContrast]），原始色值保持官方原样：
// - 正文字色与除注释外的每个语法色对代码块底色 ≥ 4.5:1；
// - 注释与行号 ≥ 3.0:1（它们本就是弱化信息，但不能看不清）；
// - 正文字色对标题栏底色 ≥ 4.5:1；行内代码文字对其底色 ≥ 4.5:1。
// 部分官方配色（Solarized 的正文、One Dark 的注释、Nord 浅色的 Frost 色等）
// 达不到这些阈值，只在 HSL 中调明度、保留色相与饱和度，尽量不改变观感。

/// 语法记号的语义角色；各主题按角色给颜色。
enum DiaryCodeTokenRole {
  keyword,
  type,
  function,
  string,
  number,
  literal,
  comment,
  variable,
  meta,
  tag,
  addition,
  deletion,
}

const Map<String, DiaryCodeTokenRole> _classNameRoles = {
  'keyword': DiaryCodeTokenRole.keyword,
  'selector-tag': DiaryCodeTokenRole.keyword,
  'doctag': DiaryCodeTokenRole.keyword,
  'built_in': DiaryCodeTokenRole.type,
  'type': DiaryCodeTokenRole.type,
  'class': DiaryCodeTokenRole.type,
  'title': DiaryCodeTokenRole.function,
  'section': DiaryCodeTokenRole.function,
  'function': DiaryCodeTokenRole.function,
  'string': DiaryCodeTokenRole.string,
  'regexp': DiaryCodeTokenRole.string,
  'char': DiaryCodeTokenRole.string,
  'number': DiaryCodeTokenRole.number,
  'literal': DiaryCodeTokenRole.literal,
  'symbol': DiaryCodeTokenRole.literal,
  'bullet': DiaryCodeTokenRole.literal,
  'link': DiaryCodeTokenRole.literal,
  'comment': DiaryCodeTokenRole.comment,
  'quote': DiaryCodeTokenRole.comment,
  'variable': DiaryCodeTokenRole.variable,
  'attr': DiaryCodeTokenRole.variable,
  'attribute': DiaryCodeTokenRole.variable,
  'params': DiaryCodeTokenRole.variable,
  'template-variable': DiaryCodeTokenRole.variable,
  'property': DiaryCodeTokenRole.variable,
  'meta': DiaryCodeTokenRole.meta,
  'meta-keyword': DiaryCodeTokenRole.meta,
  'meta-string': DiaryCodeTokenRole.meta,
  'tag': DiaryCodeTokenRole.tag,
  'name': DiaryCodeTokenRole.tag,
  'selector-id': DiaryCodeTokenRole.tag,
  'selector-class': DiaryCodeTokenRole.tag,
  'selector-attr': DiaryCodeTokenRole.tag,
  'selector-pseudo': DiaryCodeTokenRole.tag,
  'addition': DiaryCodeTokenRole.addition,
  'deletion': DiaryCodeTokenRole.deletion,
};

/// highlight.js 的 className → 语义角色；不着色的类（`subst`、`emphasis`、
/// `strong` 等）返回 null，由外层节点的角色决定颜色。
///
/// 兼容复合写法：`title class_` / `title.class_`（新版 highlight.js 的类名
/// 标题）→ type；其余复合名按第一段（空格或 `.` 之前）解析，如
/// `meta.prompt` → meta、`char.escape` → string。
DiaryCodeTokenRole? diaryCodeTokenRoleFor(String className) {
  final name = className.trim();
  if (name.isEmpty) {
    return null;
  }
  final exact = _classNameRoles[name];
  if (exact != null) {
    return exact;
  }
  final parts = name.split(RegExp(r'[ .]+'));
  if (parts.first == 'title' &&
      parts.skip(1).any((part) => part.startsWith('class'))) {
    return DiaryCodeTokenRole.type;
  }
  return _classNameRoles[parts.first];
}

/// 一套可直接用于渲染的代码块配色（已过对比度兜底）。
@immutable
class DiaryCodePalette {
  const DiaryCodePalette({
    required this.background,
    required this.header,
    required this.border,
    required this.foreground,
    required this.lineNumber,
    required this.inlineBackground,
    required this.inlineForeground,
    required this.tokens,
    required this.brightness,
    this.commentItalic = true,
  });

  final Color background;

  /// 标题栏底色，与 [background] 差一级色调。
  final Color header;
  final Color border;
  final Color foreground;
  final Color lineNumber;

  /// 行内代码的底色与文字色。
  final Color inlineBackground;
  final Color inlineForeground;

  /// 每个 [DiaryCodeTokenRole] 都有颜色。
  final Map<DiaryCodeTokenRole, Color> tokens;

  /// 注释是否斜体（各主题均为 true）。
  final bool commentItalic;
  final Brightness brightness;

  /// 某个角色的文字样式：颜色，注释另加斜体。
  TextStyle tokenStyle(DiaryCodeTokenRole role) => TextStyle(
    color: tokens[role] ?? foreground,
    fontStyle: role == DiaryCodeTokenRole.comment && commentItalic
        ? FontStyle.italic
        : null,
  );
}

/// 调整 [fg] 的 HSL 明度（保留色相与饱和度），直到与 [bg] 的 WCAG 对比度
/// 达到 [minRatio]；已满足时原样返回。
///
/// 朝“离背景更远”的方向调：背景偏亮时压暗、偏暗时提亮（以与纯白 / 纯黑
/// 对比度相等的亮度为界）。走到明度尽头仍不达标（如中灰背景要 4.5:1）时，
/// 返回两个方向中对比度最高的一端。按 0.005 的步长逐步试：前景比背景亮却
/// 要压暗时，对比度先降后升，不是单调函数，不能二分。
Color ensureContrast(Color fg, Color bg, double minRatio) {
  if (DiaryCardColors.contrastRatio(fg, bg) >= minRatio) {
    return fg;
  }
  final hsl = HSLColor.fromColor(fg);
  final white = HSLColor.fromColor(fg).withLightness(1).toColor();
  final black = HSLColor.fromColor(fg).withLightness(0).toColor();
  final darken =
      DiaryCardColors.contrastRatio(black, bg) >=
      DiaryCardColors.contrastRatio(white, bg);
  const step = 0.005;
  var lightness = hsl.lightness;
  while (true) {
    lightness = darken ? lightness - step : lightness + step;
    if (lightness <= 0 || lightness >= 1) {
      break;
    }
    final candidate = hsl.withLightness(lightness).toColor();
    if (DiaryCardColors.contrastRatio(candidate, bg) >= minRatio) {
      return candidate.withValues(alpha: fg.a);
    }
  }
  final extreme = darken ? black : white;
  final other = darken ? white : black;
  final best =
      DiaryCardColors.contrastRatio(extreme, bg) >=
          DiaryCardColors.contrastRatio(other, bg)
      ? extreme
      : other;
  return best.withValues(alpha: fg.a);
}

/// 前景对代码块底色与语法色的对比度阈值。
const double _kTextContrast = 4.5;

/// 注释与行号的对比度阈值。
const double _kMutedContrast = 3.0;

/// 配色构建与缓存。
abstract final class DiaryCodeThemes {
  // 键：(主题, 明暗, app 主题用到的配色)。非 app 主题第三项为 null，只有
  // 18 种组合；app 主题随种子色变化，加一个上限防止反复换色时无限增长。
  static final Map<Object, DiaryCodePalette> _cache = {};
  static const int _cacheLimit = 32;

  /// 主题 [id] 在 [brightness] 下的配色。[scheme] 只用于 `app` 主题；它的
  /// 明暗与 [brightness] 不一致时（代码块固定深色而应用为浅色等），以
  /// `scheme.primary` 为种子按 [brightness] 重新推一套配色方案。
  static DiaryCodePalette palette(
    DiaryCodeThemeId id,
    Brightness brightness,
    ColorScheme scheme,
  ) {
    final Object key = id == DiaryCodeThemeId.app
        ? (id, brightness, _appSchemeKey(scheme))
        : (id, brightness, null);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    final raw = diaryCodeRawPalette(id, brightness);
    final palette = raw == null
        ? _buildApp(brightness, scheme)
        : _finish(raw, brightness);
    _cache[key] = palette;
    while (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    return palette;
  }

  static (int, int, int, int, int, int, int, int, int, Brightness)
  _appSchemeKey(ColorScheme s) => (
    s.primary.toARGB32(),
    s.surfaceContainer.toARGB32(),
    s.surfaceContainerHigh.toARGB32(),
    s.surfaceContainerHighest.toARGB32(),
    s.outlineVariant.toARGB32(),
    s.onSurface.toARGB32(),
    s.onSurfaceVariant.toARGB32(),
    s.error.toARGB32(),
    s.surface.toARGB32(),
    s.brightness,
  );

  static DiaryCodePalette _finish(
    DiaryCodeRawPalette raw,
    Brightness brightness,
  ) {
    final tokens = raw.tokens;
    return _guard(
      background: raw.background,
      header: raw.header,
      border: raw.border,
      foreground: raw.foreground,
      lineNumber: raw.lineNumber,
      inlineBackground: raw.inlineBackground,
      inlineForeground: tokens[raw.inlineForegroundRole]!,
      tokens: tokens,
      brightness: brightness,
    );
  }

  /// 跟随应用配色：底色取表面容器色，语法色由主色在 HSL 中旋转色相得到，
  /// 与用户选的种子色同一色调家族。
  static DiaryCodePalette _buildApp(Brightness brightness, ColorScheme input) {
    final scheme = input.brightness == brightness
        ? input
        : ColorScheme.fromSeed(
            seedColor: input.primary,
            brightness: brightness,
          );
    final dark = brightness == Brightness.dark;
    final primary = HSLColor.fromColor(scheme.primary);
    final saturation = primary.saturation.clamp(0.35, 0.75).toDouble();
    final lightness = dark ? 0.75 : 0.40;
    Color rotate(double degrees) => HSLColor.fromAHSL(
      1,
      (primary.hue + degrees) % 360,
      saturation,
      lightness,
    ).toColor();

    final number = rotate(200);
    final meta = rotate(260);
    final tokens = <DiaryCodeTokenRole, Color>{
      DiaryCodeTokenRole.keyword: rotate(0),
      DiaryCodeTokenRole.function: rotate(40),
      DiaryCodeTokenRole.type: rotate(80),
      DiaryCodeTokenRole.string: rotate(140),
      DiaryCodeTokenRole.number: number,
      DiaryCodeTokenRole.literal: number,
      DiaryCodeTokenRole.variable: rotate(-40 + 360),
      DiaryCodeTokenRole.meta: meta,
      DiaryCodeTokenRole.tag: meta,
      DiaryCodeTokenRole.comment: scheme.onSurfaceVariant,
      DiaryCodeTokenRole.addition: HSLColor.fromAHSL(
        1,
        130,
        0.5,
        dark ? 0.72 : 0.35,
      ).toColor(),
      DiaryCodeTokenRole.deletion: scheme.error,
    };
    return _guard(
      background: dark ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
      header: dark
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerHigh,
      border: scheme.outlineVariant,
      foreground: scheme.onSurface,
      lineNumber: scheme.onSurfaceVariant,
      inlineBackground: scheme.surfaceContainerHighest,
      inlineForeground: tokens[DiaryCodeTokenRole.keyword]!,
      tokens: tokens,
      brightness: brightness,
    );
  }

  /// 统一施加对比度兜底并组装调色板。
  static DiaryCodePalette _guard({
    required Color background,
    required Color header,
    required Color border,
    required Color foreground,
    required Color lineNumber,
    required Color inlineBackground,
    required Color inlineForeground,
    required Map<DiaryCodeTokenRole, Color> tokens,
    required Brightness brightness,
  }) {
    // 先对标题栏、再回头对底色：两者在同一明暗侧，第二次调整只会朝同一
    // 方向继续，不会破坏第一次的结果；回头再查一次是兜住极端的例外。
    var fg = ensureContrast(foreground, background, _kTextContrast);
    fg = ensureContrast(fg, header, _kTextContrast);
    fg = ensureContrast(fg, background, _kTextContrast);
    return DiaryCodePalette(
      background: background,
      header: header,
      border: border,
      foreground: fg,
      lineNumber: ensureContrast(lineNumber, background, _kMutedContrast),
      inlineBackground: inlineBackground,
      inlineForeground: ensureContrast(
        inlineForeground,
        inlineBackground,
        _kTextContrast,
      ),
      tokens: Map.unmodifiable({
        for (final role in DiaryCodeTokenRole.values)
          role: ensureContrast(
            tokens[role]!,
            background,
            role == DiaryCodeTokenRole.comment
                ? _kMutedContrast
                : _kTextContrast,
          ),
      }),
      brightness: brightness,
    );
  }
}
