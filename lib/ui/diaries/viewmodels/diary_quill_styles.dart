import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'diary_text_appearance.dart';

/// 在正文所在位置生成 Quill 样式，再交给 [builder] 构建编辑器。
///
/// Quill 的基础样式取自 `DefaultTextStyle`：正文必须在 Material（Scaffold）
/// 之下取 context，那里才是主题正文样式。页面 State 的 context 位于 Scaffold
/// 之上，只能拿到 MaterialApp 的兜底样式（红色、等宽、粗体），直接用它生成
/// 样式会让正文变红，因此各页面一律经本组件生成，不要在页面 build 里直接
/// 调用 [buildDiaryQuillStyles]。主题或正文样式变化时本组件随依赖重建。
class DiaryQuillStylesBuilder extends StatelessWidget {
  const DiaryQuillStylesBuilder({
    super.key,
    required this.appearance,
    required this.builder,
  });

  final DiaryTextAppearance appearance;
  final Widget Function(BuildContext context, quill.DefaultStyles styles)
  builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, buildDiaryQuillStyles(context, appearance));
  }
}

/// 由正文外观生成 Quill 样式；编辑页、预览页、发布页与设置预览共用，保证
/// 同一篇日记在写、读、发布时排版一致。
///
/// Quill 的行样式以 `paragraph` 为底（居中、缩进的行也是），标题行只用
/// h1–h6，列表 / 引用 / 代码块再叠加各自样式，因此：
/// - 字体、字号、行距、字间距写入 paragraph 及叠加在它之上的块样式；
/// - 标题只换字体并叠加字间距，保留 Quill 的标题字号与字重；
/// - 代码块保留等宽字体，只跟随字号与行距；
/// - 段间距加在“段落型”行之后：普通行（paragraph 的外边距）以及居中 /
///   缩进块（块内行距与块外边距）；列表项与引用不是段落，保持原有间距。
///
/// 段间距与字间距都在 Quill 默认值上叠加，取 0 时与旧版排版完全一致。
quill.DefaultStyles buildDiaryQuillStyles(
  BuildContext context,
  DiaryTextAppearance appearance,
) {
  final defaults = quill.DefaultStyles.getInstance(context);
  final typography = appearance.typography;
  final family = appearance.fontFamily;

  TextStyle body(TextStyle style) => style.copyWith(
    fontFamily: family,
    fontSize: typography.fontSize,
    height: typography.lineHeight,
    letterSpacing: typography.letterSpacing,
  );

  TextStyle heading(TextStyle style) => style.copyWith(
    fontFamily: family,
    letterSpacing: (style.letterSpacing ?? 0) + typography.letterSpacing,
  );

  quill.VerticalSpacing afterParagraph(quill.VerticalSpacing spacing) =>
      quill.VerticalSpacing(
        spacing.top,
        spacing.bottom + typography.paragraphSpacing,
      );

  quill.DefaultTextBlockStyle? text(
    quill.DefaultTextBlockStyle? style,
    TextStyle Function(TextStyle) apply,
  ) => style?.copyWith(style: apply(style.style));

  quill.DefaultTextBlockStyle? paragraphBlock(
    quill.DefaultTextBlockStyle? style,
  ) => style?.copyWith(
    style: body(style.style),
    verticalSpacing: afterParagraph(style.verticalSpacing),
    lineSpacing: afterParagraph(style.lineSpacing),
  );

  final paragraph = defaults.paragraph;
  final lists = defaults.lists;
  final code = defaults.code;
  return quill.DefaultStyles(
    h1: text(defaults.h1, heading),
    h2: text(defaults.h2, heading),
    h3: text(defaults.h3, heading),
    h4: text(defaults.h4, heading),
    h5: text(defaults.h5, heading),
    h6: text(defaults.h6, heading),
    // 独立的普通行只取 paragraph 的外边距（verticalSpacing），lineSpacing 仅
    // 作未知块的兜底，保持默认。
    paragraph: paragraph?.copyWith(
      style: body(paragraph.style),
      verticalSpacing: afterParagraph(paragraph.verticalSpacing),
    ),
    placeHolder: text(defaults.placeHolder, body),
    lists: lists?.copyWith(style: body(lists.style)),
    quote: text(defaults.quote, body),
    code: code?.copyWith(
      style: code.style.copyWith(
        fontSize: typography.fontSize,
        height: typography.lineHeight,
      ),
    ),
    indent: paragraphBlock(defaults.indent),
    align: paragraphBlock(defaults.align),
    leading: text(defaults.leading, body),
  );
}
