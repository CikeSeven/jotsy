import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../models/diary_code_block/diary_code_block_style.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import 'diary_text_appearance.dart';

// 代码块（与行内代码）在某个正文位置的可渲染形态：配色、字体、Quill 的块
// 样式与行内代码样式。
//
// 输入：代码块样式设置、正文外观、导入字体的字族名，以及正文位置的主题
// （取明暗与配色）。
// 输出：不可变的 [DiaryCodeBlockLook]，每次构建现算（配色有缓存，其余是
// 少量 TextStyle / BoxDecoration）。
// 副作用：无。
//
// 明暗分两套：代码块跟随设置（可固定深色），行内代码嵌在正文里，始终按
// 正文所在页面的明暗取色，否则浅色页面上的行内代码会变成一块块深色底。

/// 代码块在正文位置解析出的外观。
@immutable
class DiaryCodeBlockLook {
  const DiaryCodeBlockLook._({
    required this.style,
    required this.palette,
    required this.inlinePalette,
    required this.codeTextStyle,
    required this.blockStyle,
    required this.inlineStyle,
  });

  /// 标题栏（语言名 + 复制）的高度；画在代码块上方的外边距里。
  static const double headerHeight = 32;

  /// 代码块与上下正文之间的间距。
  static const double blockGap = 8;

  /// 行内代码的圆角。
  static const Radius inlineRadius = Radius.circular(4);

  /// Quill 默认行内代码在 h1–h3 中的字号（`DefaultStyles.getInstance`），
  /// 再乘代码字号倍数。
  static const List<double> _inlineHeadingSizes = <double>[32, 22, 18];

  /// 按设置与正文位置的主题解析。[context] 必须在正文位置（预览页的纸张
  /// 主题之下），“跟随应用”的明暗才会跟着纸张走。
  static DiaryCodeBlockLook resolve(
    BuildContext context, {
    required DiaryCodeBlockStyle style,
    required DiaryTextAppearance appearance,
    String? importedFontFamily,
  }) {
    final theme = Theme.of(context);
    final appBrightness = theme.brightness;
    final brightness = switch (style.brightness) {
      DiaryCodeBrightness.system => appBrightness,
      DiaryCodeBrightness.light => Brightness.light,
      DiaryCodeBrightness.dark => Brightness.dark,
    };
    final palette = DiaryCodeThemes.palette(
      style.theme,
      brightness,
      theme.colorScheme,
    );
    final inlinePalette = DiaryCodeThemes.palette(
      style.theme,
      appBrightness,
      theme.colorScheme,
    );

    final mono = monospaceFamily(theme.platform);
    final family = switch (style.fontId) {
      kDiaryCodeFontMono => mono,
      // null = 沿用主题正文字体：TextStyle.merge 不覆盖行样式里的字族。
      kDiaryCodeFontBody => appearance.fontFamily,
      _ => importedFontFamily ?? mono,
    };
    // 等宽字体大多没有中文字形：缺字先回落正文字体（与周围正文同一套
    // 中文字形），再交给系统回退链。正文用主题字体时字族名为 null，取主题
    // 正文样式里的字族。
    final bodyFamily =
        appearance.fontFamily ?? theme.textTheme.bodyLarge?.fontFamily;
    final fallback = <String>[
      if (family != mono) mono,
      if (bodyFamily != null && bodyFamily != family) bodyFamily,
    ];

    final fontSize = appearance.typography.fontSize * style.fontScale;
    final codeTextStyle = TextStyle(
      color: palette.foreground,
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      height: style.lineHeight,
      letterSpacing: 0,
    );

    final radius = Radius.circular(style.radius);
    final headerExtent = style.header ? headerHeight : 0.0;
    final borderSide = BorderSide(color: palette.border, width: 0.8);
    final blockStyle = quill.DefaultTextBlockStyle(
      codeTextStyle,
      quill.HorizontalSpacing.zero,
      // 上外边距里留出标题栏的位置（标题栏由代码块装饰层另画），装饰只画
      // 内容区，因此有标题栏时只有下边两个角是圆的，与标题栏拼成一整块；
      // 边框也只画左右下三边，上边由标题栏的边框接上，两者之间不画分隔线。
      quill.VerticalSpacing(blockGap + headerExtent, blockGap),
      quill.VerticalSpacing.zero,
      BoxDecoration(
        color: palette.background,
        borderRadius: style.header
            ? BorderRadius.vertical(bottom: radius)
            : BorderRadius.all(radius),
        border: !style.border
            ? null
            : style.header
            ? Border(left: borderSide, right: borderSide, bottom: borderSide)
            : Border.fromBorderSide(borderSide),
      ),
    );

    final inlineText = TextStyle(
      color: inlinePalette.inlineForeground,
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
    );
    TextStyle heading(int level) => inlineText.copyWith(
      fontSize: _inlineHeadingSizes[level] * style.fontScale,
      fontWeight: FontWeight.w500,
    );
    final inlineStyle = quill.InlineCodeStyle(
      style: inlineText,
      header1: heading(0),
      header2: heading(1),
      header3: heading(2),
      backgroundColor: inlinePalette.inlineBackground,
      radius: inlineRadius,
    );

    return DiaryCodeBlockLook._(
      style: style,
      palette: palette,
      inlinePalette: inlinePalette,
      codeTextStyle: codeTextStyle,
      blockStyle: blockStyle,
      inlineStyle: inlineStyle,
    );
  }

  /// 平台的系统等宽字族。Android 上 `monospace` 由系统字体配置解析
  /// （Quill 默认的 `Roboto Mono` 在 Android 上并不存在）。
  static String monospaceFamily(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
    TargetPlatform.windows => 'Consolas',
    TargetPlatform.android ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => 'monospace',
  };

  final DiaryCodeBlockStyle style;

  /// 代码块配色（按设置的明暗）。
  final DiaryCodePalette palette;

  /// 行内代码配色（按正文所在页面的明暗）。
  final DiaryCodePalette inlinePalette;

  /// 代码块文字样式：字族、字号、行距与正文字色。
  final TextStyle codeTextStyle;

  /// Quill 的 `code` 块样式。
  final quill.DefaultTextBlockStyle blockStyle;

  /// Quill 的 `inlineCode` 样式。
  final quill.InlineCodeStyle inlineStyle;

  bool get lineNumbers => style.lineNumbers;

  bool get autoDetect => style.autoDetect;

  bool get header => style.header;

  /// 标题栏占用的上外边距；关闭标题栏时为 0。
  double get headerExtent => style.header ? headerHeight : 0;
}
