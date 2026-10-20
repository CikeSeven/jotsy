import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_theme.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_code_block_look.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';

import '../../../support/expressive_test_theme.dart';

Future<(quill.DefaultStyles, quill.DefaultStyles)> _buildStyles(
  WidgetTester tester,
  DiaryTextAppearance appearance, {
  DiaryCodeBlockStyle codeStyle = DiaryCodeBlockStyle.defaults,
  Brightness brightness = Brightness.light,
  ValueChanged<DiaryCodeBlockLook>? onLook,
}) async {
  late quill.DefaultStyles defaults;
  late quill.DefaultStyles styles;
  // 与真实页面一样置于 Scaffold 下：Quill 的基础样式取自 DefaultTextStyle，
  // 由 Material 按主题正文样式提供。
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            defaults = quill.DefaultStyles.getInstance(context);
            final code = DiaryCodeBlockLook.resolve(
              context,
              style: codeStyle,
              appearance: appearance,
            );
            onLook?.call(code);
            styles = buildDiaryQuillStyles(context, appearance, code: code);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return (defaults, styles);
}

void main() {
  testWidgets('applies the typography to body text, headings and spacing', (
    tester,
  ) async {
    final typography = const DiaryTypography().copyWith(
      fontSize: 20,
      lineHeight: 2,
      letterSpacing: 1,
      paragraphSpacing: 12,
    );
    final (defaults, styles) = await _buildStyles(
      tester,
      DiaryTextAppearance(typography: typography, fontFamily: 'Imported'),
    );

    final paragraph = styles.paragraph!;
    expect(paragraph.style.fontFamily, 'Imported');
    expect(paragraph.style.fontSize, 20);
    expect(paragraph.style.height, 2);
    expect(paragraph.style.letterSpacing, 1);
    expect(paragraph.verticalSpacing.bottom, 12);

    // 标题只换字体并叠加字间距，字号字重保持 Quill 的标题层级。
    final h1 = styles.h1!.style;
    expect(h1.fontFamily, 'Imported');
    expect(h1.fontSize, defaults.h1!.style.fontSize);
    expect(h1.letterSpacing, defaults.h1!.style.letterSpacing! + 1);

    // 居中 / 缩进块按段落处理：块内每行后都有段间距。
    expect(styles.align!.lineSpacing.bottom, 12);
    expect(
      styles.indent!.lineSpacing.bottom,
      defaults.indent!.lineSpacing.bottom + 12,
    );

    // 列表不是段落，保持原有间距；代码块用系统等宽字体，字号按倍数缩放。
    expect(styles.lists!.style.fontSize, 20);
    expect(styles.lists!.lineSpacing, defaults.lists!.lineSpacing);
    expect(styles.code!.style.fontFamily, 'monospace');
    expect(
      styles.code!.style.fontSize,
      20 * DiaryCodeBlockStyle.defaultFontScale,
    );

    // 导入带来的行内字号三档按正文字号缩放。
    expect(styles.sizeSmall!.fontSize, 17);
    expect(styles.sizeLarge!.fontSize, 25);
    expect(styles.sizeHuge!.fontSize, 30);
  });

  testWidgets('the bundled font keeps the theme font family', (tester) async {
    final (defaults, styles) = await _buildStyles(
      tester,
      const DiaryTextAppearance(typography: DiaryTypography()),
    );

    expect(styles.paragraph!.style.fontFamily, 'HarmonyOSSansSC');
    expect(styles.paragraph!.style.fontSize, 16);
    expect(styles.paragraph!.style.height, 1.55);
    // 段间距为 0 时与 Quill 默认间距一致，旧日记排版不变。
    expect(
      styles.paragraph!.verticalSpacing,
      defaults.paragraph!.verticalSpacing,
    );
  });

  testWidgets('code blocks take the code style settings', (tester) async {
    late DiaryCodeBlockLook look;
    const appearance = DiaryTextAppearance(
      typography: DiaryTypography(),
      fontFamily: 'Imported',
    );
    final (_, styles) = await _buildStyles(
      tester,
      appearance,
      codeStyle: DiaryCodeBlockStyle.defaults.copyWith(
        fontScale: 1.2,
        lineHeight: 1.8,
        radius: 10,
        border: true,
      ),
      onLook: (value) => look = value,
    );

    final code = styles.code!;
    expect(code.style.fontFamily, 'monospace');
    // 等宽字体缺中文字形时回落正文字体。
    expect(code.style.fontFamilyFallback, contains('Imported'));
    expect(code.style.fontSize, closeTo(16 * 1.2, 1e-9));
    expect(code.style.height, 1.8);
    expect(code.style.color, look.palette.foreground);
    final decoration = code.decoration!;
    expect(decoration.color, look.palette.background);
    expect(decoration.border, isNotNull);
    // 标题栏占上外边距，装饰只有下边两个圆角。
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(10)),
    );
    expect(
      code.verticalSpacing.top,
      DiaryCodeBlockLook.blockGap + DiaryCodeBlockLook.headerHeight,
    );
    expect(code.verticalSpacing.bottom, DiaryCodeBlockLook.blockGap);
  });

  testWidgets('without a header every corner is rounded and no border', (
    tester,
  ) async {
    final (_, styles) = await _buildStyles(
      tester,
      const DiaryTextAppearance(typography: DiaryTypography()),
      codeStyle: DiaryCodeBlockStyle.defaults.copyWith(header: false),
    );

    final decoration = styles.code!.decoration!;
    expect(
      decoration.borderRadius,
      const BorderRadius.all(
        Radius.circular(DiaryCodeBlockStyle.defaultRadius),
      ),
    );
    expect(decoration.border, isNull);
    expect(styles.code!.verticalSpacing.top, DiaryCodeBlockLook.blockGap);
  });

  testWidgets('inline code follows the page brightness, not forced dark', (
    tester,
  ) async {
    late DiaryCodeBlockLook look;
    final (_, styles) = await _buildStyles(
      tester,
      const DiaryTextAppearance(typography: DiaryTypography()),
      codeStyle: DiaryCodeBlockStyle.defaults.copyWith(
        theme: DiaryCodeThemeId.github,
        brightness: DiaryCodeBrightness.dark,
      ),
      onLook: (value) => look = value,
    );

    final light = DiaryCodeThemes.palette(
      DiaryCodeThemeId.github,
      Brightness.light,
      expressiveTestTheme(Brightness.light).colorScheme,
    );
    expect(look.palette.brightness, Brightness.dark);
    expect(styles.code!.decoration!.color, look.palette.background);
    final inline = styles.inlineCode!;
    expect(inline.backgroundColor, light.inlineBackground);
    expect(inline.style.color, light.inlineForeground);
    expect(inline.style.fontFamily, 'monospace');
    expect(
      inline.style.fontSize,
      closeTo(16 * DiaryCodeBlockStyle.defaultFontScale, 1e-9),
    );
  });

  test('monospace family per platform', () {
    expect(
      DiaryCodeBlockLook.monospaceFamily(TargetPlatform.android),
      'monospace',
    );
    expect(DiaryCodeBlockLook.monospaceFamily(TargetPlatform.iOS), 'Menlo');
    expect(
      DiaryCodeBlockLook.monospaceFamily(TargetPlatform.windows),
      'Consolas',
    );
  });

  test('system font resolves per platform', () {
    final typography = const DiaryTypography().copyWith(
      fontId: DiaryTypography.systemFontId,
    );

    expect(
      DiaryTextAppearance.resolve(
        typography,
        platform: TargetPlatform.android,
      ).fontFamily,
      'sans-serif',
    );
    expect(
      DiaryTextAppearance.resolve(
        typography,
        platform: TargetPlatform.iOS,
      ).fontFamily,
      'CupertinoSystemText',
    );
    // 导入字体未就绪时为 null（沿用主题字体）。
    expect(
      DiaryTextAppearance.resolve(
        typography.copyWith(fontId: 'fwen'),
        platform: TargetPlatform.android,
      ).fontFamily,
      isNull,
    );
  });
}
