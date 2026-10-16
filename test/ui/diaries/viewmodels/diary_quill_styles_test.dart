import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';

import '../../../support/expressive_test_theme.dart';

Future<(quill.DefaultStyles, quill.DefaultStyles)> _buildStyles(
  WidgetTester tester,
  DiaryTextAppearance appearance,
) async {
  late quill.DefaultStyles defaults;
  late quill.DefaultStyles styles;
  // 与真实页面一样置于 Scaffold 下：Quill 的基础样式取自 DefaultTextStyle，
  // 由 Material 按主题正文样式提供。
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            defaults = quill.DefaultStyles.getInstance(context);
            styles = buildDiaryQuillStyles(context, appearance);
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

    // 列表不是段落，保持原有间距；代码块保留等宽字体。
    expect(styles.lists!.style.fontSize, 20);
    expect(styles.lists!.lineSpacing, defaults.lists!.lineSpacing);
    expect(styles.code!.style.fontFamily, defaults.code!.style.fontFamily);
    expect(styles.code!.style.fontSize, 20);
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
