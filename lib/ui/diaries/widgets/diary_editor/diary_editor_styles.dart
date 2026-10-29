import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_table_editing.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_text_appearance.dart';
import 'diary_block_marker_metrics.dart';
import 'diary_table_block.dart';

/// 正文的行高分配（与上游默认相同，这里显式写出以便共用）：首行上方与末行
/// 下方不加行距，块与块的距离只由块的 padding 决定；多出的行距在行内上下
/// 均分。行首标记与代码行号按同一规则测量，才能与文字首行的基线对齐。
const TextHeightBehavior kDiaryTextHeightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
  leadingDistribution: TextLeadingDistribution.even,
);

/// 正文实际使用的字体缩放：上游把系统缩放折算成线性倍数
/// （[af.EditorStyle.textScaleFactor]），与正文并排绘制的标记与行号必须用
/// 同一个倍数，否则在非线性缩放（Android 14 起的大字体）下逐行错开。
TextScaler diaryEditorTextScaler(BuildContext context) =>
    TextScaler.linear(MediaQuery.textScalerOf(context).scale(1));

/// 在正文所在的 Material 下解析颜色、排版与块间距；所有编辑和只读入口共用。
af.EditorStyle buildDiaryEditorStyle(
  BuildContext context,
  DiaryTextAppearance appearance,
  DiaryCodeBlockLook code, {
  required EdgeInsets padding,
  af.TextSpanDecoratorForAttribute? decorator,
}) {
  final colors = Theme.of(context).colorScheme;
  return af.EditorStyle.mobile(
    padding: padding,
    cursorColor: colors.primary,
    dragHandleColor: colors.primary,
    selectionColor: colors.primary.withValues(alpha: 0.24),
    enableHapticFeedbackOnAndroid: false,
    textScaleFactor: diaryEditorTextScaler(context).scale(1),
    textStyleConfiguration: af.TextStyleConfiguration(
      text: diaryEditorBodyStyle(context, appearance),
      lineHeight: appearance.typography.lineHeight,
      applyHeightToFirstAscent:
          kDiaryTextHeightBehavior.applyHeightToFirstAscent,
      applyHeightToLastDescent:
          kDiaryTextHeightBehavior.applyHeightToLastDescent,
      leadingDistribution: kDiaryTextHeightBehavior.leadingDistribution,
      href: TextStyle(
        color: colors.primary,
        decoration: TextDecoration.underline,
        decorationColor: colors.primary.withValues(alpha: 0.6),
      ),
      code: code.codeTextStyle.copyWith(
        color: code.inlinePalette.inlineForeground,
        backgroundColor: code.inlinePalette.inlineBackground,
      ),
    ),
    textSpanDecorator: decorator,
  );
}

/// 正文基础样式：用户的字体、字号、行距与字间距，颜色取所在页面的墨色。
TextStyle diaryEditorBodyStyle(
  BuildContext context,
  DiaryTextAppearance appearance,
) {
  final typography = appearance.typography;
  final inherited = DefaultTextStyle.of(context).style;
  return inherited.copyWith(
    color: inherited.color ?? Theme.of(context).colorScheme.onSurface,
    fontFamily: appearance.fontFamily,
    fontSize: typography.fontSize,
    height: typography.lineHeight,
    letterSpacing: typography.letterSpacing,
    fontWeight: FontWeight.normal,
  );
}

/// 标题字号相对正文字号的倍数（h1–h6）。随正文字号缩放，不写绝对像素。
const List<double> kDiaryHeadingScales = [1.75, 1.45, 1.2, 1.1, 1.0, 0.9];

/// 标题的字号与字重（[level] 为 1–6）。上游标题块在块样式之后还会叠一层
/// 自己的默认字号（32 / 28 / 24 / 18…，不随正文字号变化），所以除了块样式，
/// 标题块的 `textStyleBuilder` 也必须交给这里，否则倍数被上游覆盖。
TextStyle diaryHeadingTextStyle(DiaryTextAppearance appearance, int level) =>
    TextStyle(
      fontSize:
          appearance.typography.fontSize *
          kDiaryHeadingScales[level.clamp(1, 6) - 1],
      fontWeight: FontWeight.w700,
    );

/// 标题上方的留白（h1–h6），与前文拉开层次；文档第一块不加。
const List<double> _headingTopSpacing = [18, 14, 10, 8, 8, 8];

int _headingLevel(af.Node node) {
  final raw = node.attributes['level'];
  return raw is num ? raw.toInt().clamp(1, 6) : 1;
}

bool _isFirstBlock(af.Node node) =>
    node.parent?.type == 'page' && node.path.length == 1 && node.path[0] == 0;

/// 文字块的间距与字形：
/// - 段落：上下 3dp，段后再加用户的段间距；
/// - 标题：上方按级别留白（文档第一块除外）、下方 4dp，字重 700、行高 1.3；
/// - 列表与待办：上下各 2dp 再补回半个行距（[DiaryMarkerMetrics.halfLeading]），
///   相邻两项的间距 = 一个整行 + 4dp，随行距设置变化，又不比项内换行更挤；
/// - 引用：上下 4dp，文字为 `onSurfaceVariant`，与正文区分而不刺眼；
/// - 提示块：框外上下 4dp（同引用），框内留白与底色见 `DiaryCalloutBlock`；
/// - 折叠块：标题行同列表与待办，展开时子块同列表子块的缩进；
/// - 子块缩进等于行首标记列宽：嵌套列表的标记正好落在上一级的正文起点下。
af.BlockComponentConfiguration diaryTextBlockConfiguration(
  BuildContext context,
  DiaryTextAppearance appearance, {
  required DiaryMarkerMetrics markers,
  String? placeholder,
  bool editable = true,
}) {
  final colors = Theme.of(context).colorScheme;
  final typography = appearance.typography;
  return af.BlockComponentConfiguration(
    indentPadding: (_, direction) =>
        EdgeInsetsDirectional.only(start: markers.width).resolve(direction),
    padding: (node) => switch (node.type) {
      'heading' => EdgeInsets.only(
        top: _isFirstBlock(node)
            ? 4
            : _headingTopSpacing[_headingLevel(node) - 1],
        bottom: 4,
      ),
      'bulleted_list' ||
      'numbered_list' ||
      'todo_list' ||
      // 折叠块的标题行与列表项同一节奏（标记格同一套几何）。
      'toggle_list' => EdgeInsets.symmetric(vertical: 2 + markers.halfLeading),
      // 提示块的底色框在块内（见 DiaryCalloutBlock），这里只是框外的
      // 上下间距，与引用相同。
      'quote' || 'callout' => const EdgeInsets.symmetric(vertical: 4),
      'paragraph' => EdgeInsets.only(
        top: 3,
        bottom: 3 + typography.paragraphSpacing,
      ),
      _ => const EdgeInsets.symmetric(vertical: 3),
    },
    textStyle: (node, {textSpan}) => switch (node.type) {
      'heading' => diaryHeadingTextStyle(
        appearance,
        _headingLevel(node),
      ).copyWith(fontFamily: appearance.fontFamily, height: 1.3),
      'quote' => TextStyle(color: colors.onSurfaceVariant),
      // 表头行的格子加粗只在渲染时，不写进正文。
      'paragraph' when diaryTableHeaderParagraph(node) => const TextStyle(
        fontWeight: FontWeight.w700,
      ),
      _ => const TextStyle(),
    },
    // 段落的占位只在光标停在这个空段落时显示（上游按选区控制）：整篇只有
    // 这一个空段落时是页面的占位（“开始记录…”），正文中间的空行提示 `/`
    // 命令；只读时不提示。标题与引用、列表、提示块的占位上游始终显示：
    // 空标题写出自己的级别，空提示块写“提示”，否则只是一块看不出用途的
    // 空白；其余不提示。
    placeholderText: (node) => switch (node.type) {
      'heading' => switch (_headingLevel(node)) {
        1 => context.l10n.diaryEditorHeading1,
        2 => context.l10n.diaryEditorHeading2,
        3 => context.l10n.diaryEditorHeading3,
        4 => context.l10n.diaryEditorHeading4,
        5 => context.l10n.diaryEditorHeading5,
        _ => context.l10n.diaryEditorHeading6,
      },
      'callout' => context.l10n.diaryCalloutPlaceholder,
      // 空折叠块写“折叠块”，同提示块始终显示。
      'toggle_list' => context.l10n.diaryToggleListPlaceholder,
      'paragraph'
          when node.parent?.type == 'page' &&
              node.parent!.children.length == 1 =>
        placeholder ?? ' ',
      // 格子里不能插入区块，`/` 提示只会误导，窄格里还会折成两行。
      'paragraph' when diaryNodeInTableCell(node) => ' ',
      'paragraph' when editable => context.l10n.diaryEditorEmptyLineHint,
      _ => ' ',
    },
    placeholderTextStyle: (_, {textSpan}) =>
        TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
    textAlign: diaryBlockTextAlign,
  );
}

/// 文字块的排版对齐。上游各文字块（段落、标题、列表、待办、引用，以及
/// [DiaryParagraphBlock]）按 `data.align` 只认 left / center / right，认出时
/// 直接用它；`justify` 认不出，回落到块配置的 `textAlign`，所以两端对齐只在
/// 这里给出。其余情况与上游默认（[TextAlign.start]）相同，不设对齐的正文
/// 排版不变。代码块另行固定为 start（见 `buildDiaryEditorBlocks`）。
TextAlign diaryBlockTextAlign(af.Node node) =>
    node.attributes['align'] == 'justify' ? TextAlign.justify : TextAlign.start;
