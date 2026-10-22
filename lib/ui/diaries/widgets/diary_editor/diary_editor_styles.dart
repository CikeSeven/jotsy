import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

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
  final typography = appearance.typography;
  final body = DefaultTextStyle.of(context).style.copyWith(
    color: DefaultTextStyle.of(context).style.color ?? colors.onSurface,
    fontFamily: appearance.fontFamily,
    fontSize: typography.fontSize,
    height: typography.lineHeight,
    letterSpacing: typography.letterSpacing,
    fontWeight: FontWeight.normal,
  );
  return af.EditorStyle.mobile(
    padding: padding,
    cursorColor: colors.primary,
    dragHandleColor: colors.primary,
    selectionColor: colors.primary.withValues(alpha: 0.24),
    enableHapticFeedbackOnAndroid: false,
    textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
    textStyleConfiguration: af.TextStyleConfiguration(
      text: body,
      lineHeight: typography.lineHeight,
      href: TextStyle(
        color: colors.primary,
        decoration: TextDecoration.underline,
      ),
      code: code.codeTextStyle.copyWith(
        color: code.inlinePalette.inlineForeground,
        backgroundColor: code.inlinePalette.inlineBackground,
      ),
    ),
    textSpanDecorator: decorator,
  );
}

af.BlockComponentConfiguration diaryTextBlockConfiguration(
  BuildContext context,
  DiaryTextAppearance appearance, {
  String? placeholder,
}) => af.BlockComponentConfiguration(
  padding: (node) => EdgeInsets.only(
    top: 3,
    bottom:
        3 +
        (node.type == 'paragraph' ? appearance.typography.paragraphSpacing : 0),
  ),
  textStyle: (node, {textSpan}) {
    if (node.type != 'heading') return const TextStyle();
    final raw = node.attributes['level'];
    final level = raw is num ? raw.toInt().clamp(1, 6) : 1;
    return TextStyle(
      fontFamily: appearance.fontFamily,
      fontSize:
          appearance.typography.fontSize *
          const [2.0, 1.5, 1.25, 1.1, 1.0, 0.9][level - 1],
      fontWeight: FontWeight.w600,
    );
  },
  placeholderText: (_) => placeholder ?? ' ',
  placeholderTextStyle: (_, {textSpan}) =>
      TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
);
