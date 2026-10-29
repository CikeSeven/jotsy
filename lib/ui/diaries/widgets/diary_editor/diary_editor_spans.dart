import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/code_block_codec.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_code_block/diary_code_highlighter.dart';
import '../../models/diary_text_style_options.dart';
import '../../viewmodels/diary_code_block_look.dart';

/// AppFlowy 按行内片段给出 UTF-16 偏移，组字前、中、后的片段都据此切高亮；
/// 不改文档 Delta，不让语法着色污染用户的颜色、撤销或输入法状态。
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
      if (level == null || level == DiaryFontSize.normal) return decorated;
      final size = fontSize * level.scale;
      return TextSpan(
        text: decorated.text,
        children: decorated.children,
        style:
            decorated.style?.copyWith(fontSize: size) ??
            TextStyle(fontSize: size),
        recognizer: decorated.recognizer,
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
