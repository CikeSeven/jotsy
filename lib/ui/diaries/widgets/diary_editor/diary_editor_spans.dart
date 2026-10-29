import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/code_block_codec.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_code_block/diary_code_highlighter.dart';
import '../../models/diary_text_style_options.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_script_spans.dart';

/// AppFlowy 按行内片段给出 UTF-16 偏移，组字前、中、后的片段都据此切高亮；
/// 不改文档 Delta，不让语法着色污染用户的颜色、撤销或输入法状态。
///
/// 代码块之外只改行内片段的画法：字号档位 `size` 改字号，上标 / 下标
/// `script` 逐字换成占位（见 `diaryScriptSpan`，码元与文档一一对应）。
af.TextSpanDecoratorForAttribute diaryEditorSpanDecorator(
  DiaryCodeBlockLook code,
  DiaryBlockLanguageTracker tracker,
  double fontSize,
) {
  return (context, node, index, insert, before, after) {
    if (node.type != 'code') {
      final decorated = af.defaultTextSpanDecoratorForAttribute(
        context,
        node,
        index,
        insert,
        before,
        after,
      );
      // 正文档（没有 size）与认不出的值都不改字号；倍数与「字号」面板共用。
      final level = DiaryFontSize.fromAttribute(insert.attributes?['size']);
      final sized = level == null || level == DiaryFontSize.normal
          ? decorated
          : TextSpan(
              text: decorated.text,
              children: decorated.children,
              style:
                  decorated.style?.copyWith(fontSize: fontSize * level.scale) ??
                  TextStyle(fontSize: fontSize * level.scale),
              recognizer: decorated.recognizer,
            );
      final script = DiaryScript.fromAttribute(
        insert.attributes?[kDiaryInlineScript],
      );
      if (script == null) return sized;
      return diaryScriptSpan(
        insert.text,
        script: script,
        style: _scriptGlyphStyle(node, sized, before, after),
        containerStyle: sized.style,
        recognizer: decorated.recognizer,
        mouseCursor: decorated.mouseCursor,
      );
    }
    final delta = node.delta;
    if (delta == null || delta.length > DiaryCodeHighlighter.maxLength) {
      return before;
    }
    final text = delta.toPlainText();
    final language = diaryBlockHighlightLanguage(node, text, code, tracker);
    if (language == null) return before;
    final tokens = DiaryCodeHighlighter.instance.tokens(text, language);
    final end = index + insert.text.length;
    var cursor = index;
    final spans = <TextSpan>[];
    final userColor = insert.attributes?['font_color'] != null;
    for (final token in tokens.overlapping(index, end)) {
      final start = math.max(token.start, index);
      final stop = math.min(token.end, end);
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      final style = code.palette.tokenStyle(token.role);
      spans.add(
        TextSpan(
          text: text.substring(start, stop),
          style: userColor ? TextStyle(fontStyle: style.fontStyle) : style,
        ),
      );
      cursor = stop;
    }
    if (cursor < end) spans.add(TextSpan(text: text.substring(cursor, end)));
    return TextSpan(style: before.style, children: spans);
  };
}

/// 上下标字最终的样式。块随后在整段片段上叠的样式（引用的次要色、已勾选
/// 待办的划线、标题的字号与字重）叠不进占位里的字，[after]（上游已按块叠好
/// 的同一片段）里有，这里取它；字号档位 `size` 只在块不另定字号时生效——
/// 标题按标题字号，与同一行的普通文字一致。
TextStyle _scriptGlyphStyle(
  af.Node node,
  TextSpan sized,
  TextSpan before,
  TextSpan after,
) {
  final style = after.style ?? sized.style ?? const TextStyle();
  final blockSetsSize =
      node.type == kDiaryBlockHeading ||
      after.style?.fontSize != before.style?.fontSize;
  return blockSetsSize || sized.style?.fontSize == null
      ? style
      : style.copyWith(fontSize: sized.style!.fontSize);
}

String? diaryBlockHighlightLanguage(
  af.Node node,
  String text,
  DiaryCodeBlockLook code,
  DiaryBlockLanguageTracker tracker,
) {
  final raw = node.attributes['language'];
  if (raw == kCodeBlockPlain) {
    tracker.cancelPendingFor(node);
    return null;
  }
  final explicit = codeBlockExplicitLanguage(raw);
  if (explicit != null) {
    tracker.cancelPendingFor(node);
    return explicit;
  }
  if (!code.autoDetect || text.length > DiaryCodeHighlighter.maxLength) {
    tracker.cancelPendingFor(node);
    return null;
  }
  return tracker.languageFor(node, text);
}
