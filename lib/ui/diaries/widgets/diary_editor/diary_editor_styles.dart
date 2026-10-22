import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_text_appearance.dart';

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
    textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
    textStyleConfiguration: af.TextStyleConfiguration(
      text: diaryEditorBodyStyle(context, appearance),
      lineHeight: appearance.typography.lineHeight,
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
/// - 列表与待办：上下 2dp，保持列表紧凑；
/// - 引用：上下 4dp，文字为 `onSurfaceVariant`，与正文区分而不刺眼。
af.BlockComponentConfiguration diaryTextBlockConfiguration(
  BuildContext context,
  DiaryTextAppearance appearance, {
  String? placeholder,
  bool editable = true,
}) {
  final colors = Theme.of(context).colorScheme;
  final typography = appearance.typography;
  return af.BlockComponentConfiguration(
    padding: (node) => switch (node.type) {
      'heading' => EdgeInsets.only(
        top: _isFirstBlock(node)
            ? 4
            : _headingTopSpacing[_headingLevel(node) - 1],
        bottom: 4,
      ),
      'bulleted_list' ||
      'numbered_list' ||
      'todo_list' => const EdgeInsets.symmetric(vertical: 2),
      'quote' => const EdgeInsets.symmetric(vertical: 4),
      'paragraph' => EdgeInsets.only(
        top: 3,
        bottom: 3 + typography.paragraphSpacing,
      ),
      _ => const EdgeInsets.symmetric(vertical: 3),
    },
    textStyle: (node, {textSpan}) => switch (node.type) {
      'heading' => TextStyle(
        fontFamily: appearance.fontFamily,
        fontSize:
            typography.fontSize * kDiaryHeadingScales[_headingLevel(node) - 1],
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      'quote' => TextStyle(color: colors.onSurfaceVariant),
      _ => const TextStyle(),
    },
    // 段落的占位只在光标停在这个空段落时显示（上游按选区控制）：整篇只有
    // 这一个空段落时是页面的占位（“开始记录…”），正文中间的空行提示 `/`
    // 命令；只读时不提示。标题与引用、列表的占位上游始终显示：空标题写出
    // 自己的级别，否则只是一块看不出用途的空白；其余不提示。
    placeholderText: (node) => switch (node.type) {
      'heading' => switch (_headingLevel(node)) {
        1 => context.l10n.diaryEditorHeading1,
        2 => context.l10n.diaryEditorHeading2,
        _ => context.l10n.diaryEditorHeading3,
      },
      'paragraph'
          when node.parent?.type == 'page' &&
              node.parent!.children.length == 1 =>
        placeholder ?? ' ',
      'paragraph' when editable => context.l10n.diaryEditorEmptyLineHint,
      _ => ' ',
    },
    placeholderTextStyle: (_, {textSpan}) =>
        TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
  );
}
