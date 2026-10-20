import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/diary_code_block_editing.dart';
import '../controllers/diary_code_language_tracker.dart';
import '../models/diary_code_block/diary_code_block_style.dart';
import '../providers/diary_code_block_style_provider.dart';
import '../providers/diary_typography_provider.dart';
import 'diary_code_block_look.dart';
import 'diary_code_span_builder.dart';
import 'diary_text_appearance.dart';

/// 正文位置解析出的 Quill 外观：样式表、代码块外观与该控制器的语言识别
/// 状态。各页面用 [configure] 把它们装进自己的 `QuillEditorConfig`。
@immutable
class DiaryQuillLook {
  const DiaryQuillLook({
    required this.styles,
    required this.code,
    required this.tracker,
  });

  final quill.DefaultStyles styles;
  final DiaryCodeBlockLook code;
  final DiaryCodeLanguageTracker tracker;

  /// 在页面自己的 [config] 上装入样式表与代码块的渲染钩子（高亮、代码
  /// 字体、行号）。
  ///
  /// 经 `QuillEditorConfig.copyWith`：flutter_quill 11.6.0 的 copyWith 漏掉了
  /// `onSingleLongTap*` 与 `quillMagnifierBuilder`，页面若要用到这几个回调，
  /// 需要先在这里补上（断言兜底，防止被静默丢掉）。
  quill.QuillEditorConfig configure(quill.QuillEditorConfig config) {
    assert(
      config.onSingleLongTapStart == null &&
          config.onSingleLongTapMoveUpdate == null &&
          config.onSingleLongTapEnd == null &&
          config.quillMagnifierBuilder == null,
      'QuillEditorConfig.copyWith drops these callbacks; pass them here.',
    );
    return config.copyWith(
      customStyles: styles,
      showCodeBlockLineNumbers: code.lineNumbers,
      textSpanBuilder: buildDiaryCodeSpanBuilder(code, tracker),
      customStyleBuilder: buildDiaryCodeCustomStyleBuilder(code),
      customLeadingBlockBuilder: buildDiaryCodeLeadingBuilder(code),
    );
  }
}

/// 在正文所在位置生成 Quill 样式，再交给 [builder] 构建编辑器。
///
/// Quill 的基础样式取自 `DefaultTextStyle`：正文必须在 Material（Scaffold）
/// 之下取 context，那里才是主题正文样式。页面 State 的 context 位于 Scaffold
/// 之上，只能拿到 MaterialApp 的兜底样式（红色、等宽、粗体），直接用它生成
/// 样式会让正文变红，因此各页面一律经本组件生成，不要在页面 build 里直接
/// 调用 [buildDiaryQuillStyles]。主题或正文样式变化时本组件随依赖重建。
///
/// 代码块外观同样在这里解析：本组件自己监听代码块样式设置、导入字体与
/// [controller] 的语言识别结果，变化时自行重建。编辑页缓存了整棵编辑器
/// （按控制器、主题与正文外观判断是否复用），代码块设置不在它的缓存键里，
/// 也能即时生效。构建时顺带给 [controller] 挂上代码块的回车处理
/// （`attachDiaryCodeBlockEditing`，重复挂载无副作用、只读时不接管）。
class DiaryQuillStylesBuilder extends ConsumerStatefulWidget {
  const DiaryQuillStylesBuilder({
    super.key,
    required this.appearance,
    required this.controller,
    required this.builder,
    this.codeBlockStyle,
  });

  final DiaryTextAppearance appearance;
  final quill.QuillController controller;
  final Widget Function(BuildContext context, DiaryQuillLook look) builder;

  /// 覆盖代码块样式（设置页的实时预览用草稿）；null 时读已保存的设置
  /// `diaryCodeBlockStyleProvider`。
  final DiaryCodeBlockStyle? codeBlockStyle;

  @override
  ConsumerState<DiaryQuillStylesBuilder> createState() =>
      _DiaryQuillStylesBuilderState();
}

class _DiaryQuillStylesBuilderState
    extends ConsumerState<DiaryQuillStylesBuilder> {
  late DiaryCodeLanguageTracker _tracker;

  @override
  void initState() {
    super.initState();
    _bind(widget.controller);
  }

  @override
  void didUpdateWidget(DiaryQuillStylesBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _tracker.removeListener(_onLanguagesChanged);
      _bind(widget.controller);
    }
  }

  void _bind(quill.QuillController controller) {
    attachDiaryCodeBlockEditing(controller);
    _tracker = DiaryCodeLanguageTracker.of(controller)
      ..addListener(_onLanguagesChanged);
  }

  /// 自动识别的语言变了：高亮钩子要换新的闭包（同一帧缓存随之失效），
  /// 重建整棵编辑器。
  void _onLanguagesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tracker.removeListener(_onLanguagesChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.codeBlockStyle;
    final DiaryCodeBlockStyle style =
        override ?? ref.watch(diaryCodeBlockStyleProvider);
    final String? importedFamily;
    if (override == null) {
      importedFamily = ref.watch(diaryCodeBlockFontFamilyProvider);
    } else if (override.usesImportedFont) {
      importedFamily = ref
          .watch(diaryImportedFontFamilyProvider(override.fontId))
          .asData
          ?.value;
    } else {
      importedFamily = null;
    }
    final code = DiaryCodeBlockLook.resolve(
      context,
      style: style,
      appearance: widget.appearance,
      importedFontFamily: importedFamily,
    );
    return widget.builder(
      context,
      DiaryQuillLook(
        styles: buildDiaryQuillStyles(context, widget.appearance, code: code),
        code: code,
        tracker: _tracker,
      ),
    );
  }
}

/// 由正文外观生成 Quill 样式；编辑页、预览页、发布页与设置预览共用，保证
/// 同一篇日记在写、读、发布时排版一致。
///
/// Quill 的行样式以 `paragraph` 为底（居中、缩进的行也是），标题行只用
/// h1–h6，列表 / 引用 / 代码块再叠加各自样式，因此：
/// - 字体、字号、行距、字间距写入 paragraph 及叠加在它之上的块样式；
/// - 标题只换字体并叠加字间距，保留 Quill 的标题字号与字重；
/// - 代码块与行内代码取 [code]（代码块样式设置：配色、字体、字号倍数、
///   行距、圆角与边框），不沿用 Quill 默认的蓝字灰底与 Android 上并不存在的
///   `Roboto Mono`；
/// - 段间距加在“段落型”行之后：普通行（paragraph 的外边距）以及居中 /
///   缩进块（块内行距与块外边距）；列表项与引用不是段落，保持原有间距。
///
/// 段间距与字间距都在 Quill 默认值上叠加，取 0 时与旧版排版完全一致。
quill.DefaultStyles buildDiaryQuillStyles(
  BuildContext context,
  DiaryTextAppearance appearance, {
  required DiaryCodeBlockLook code,
}) {
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
    code: code.blockStyle,
    inlineCode: code.inlineStyle,
    indent: paragraphBlock(defaults.indent),
    align: paragraphBlock(defaults.align),
    leading: text(defaults.leading, body),
    // 行内字号三档（导入笔记带来的 small / large / huge）按正文字号缩放，跟随
    // 用户的排版设置；Quill 默认是与正文无关的固定 10 / 18 / 22。档位划分见
    // journalFontSizeForRatio。
    sizeSmall: TextStyle(fontSize: typography.fontSize * 0.85),
    sizeLarge: TextStyle(fontSize: typography.fontSize * 1.25),
    sizeHuge: TextStyle(fontSize: typography.fontSize * 1.5),
  );
}
