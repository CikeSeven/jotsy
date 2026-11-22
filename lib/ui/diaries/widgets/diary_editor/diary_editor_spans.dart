import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/code_block_codec.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_code_block/diary_code_highlighter.dart';
import '../../models/diary_text_style_options.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_link_spans.dart';
import 'diary_script_spans.dart';

/// AppFlowy 按行内片段给出 UTF-16 偏移，组字前、中、后的片段都据此切高亮；
/// 不改文档 Delta，不让语法着色污染用户的颜色、撤销或输入法状态。
///
/// 代码块之外只改行内片段的画法：字号档位 `size` 改字号，上标 / 下标
/// `script` 逐字换成占位（见 `diaryScriptSpan`，码元与文档一一对应）；给了
/// [links] 时链接的点按都由这里接管：日记链接（`href` 为内部地址）见
/// [diaryLinkTextSpan]，网址链接见 [diaryWebLinkTextSpan]。
af.TextSpanDecoratorForAttribute diaryEditorSpanDecorator(
  DiaryCodeBlockLook code,
  DiaryBlockLanguageTracker tracker,
  double fontSize, {
  DiaryLinkSpanOptions? links,
}) {
  return (context, node, index, insert, before, after) {
    if (node.type != 'code') {
      final href = insert.attributes?[kDiaryInlineHref];
      final target = DiaryLinkTarget.tryParse(href);
      final decorated = switch (links) {
        null => af.defaultTextSpanDecoratorForAttribute(
          context,
          node,
          index,
          insert,
          before,
          after,
        ),
        final links when target != null => diaryLinkTextSpan(
          node,
          index,
          insert,
          before,
          target,
          links,
        ),
        // 上游的默认装饰只处理链接，其余片段原样返回 before。
        final links when href is String && href.isNotEmpty =>
          diaryWebLinkTextSpan(node, index, insert, before, href, links),
        _ => before,
      };
      // 链接的线色由链接自己定（见 diary_link_spans.dart），其余线条随文字色。
      final ink = insert.attributes?[kDiaryInlineHref] == null
          ? after.style?.color
          : null;
      // 正文档（没有 size）与认不出的值都不改字号；倍数与「字号」面板共用。
      final level = DiaryFontSize.fromAttribute(insert.attributes?['size']);
      final style = _decorationInk(
        level == null || level == DiaryFontSize.normal
            ? decorated.style
            : decorated.style?.copyWith(fontSize: fontSize * level.scale) ??
                  TextStyle(fontSize: fontSize * level.scale),
        ink,
      );
      final sized = identical(style, decorated.style)
          ? decorated
          : TextSpan(
              text: decorated.text,
              children: decorated.children,
              style: style,
              recognizer: decorated.recognizer,
            );
      final script = DiaryScript.fromAttribute(
        insert.attributes?[kDiaryInlineScript],
      );
      if (script == null) return sized;
      return diaryScriptSpan(
        insert.text,
        script: script,
        style: _scriptGlyphStyle(node, sized, before, after, ink),
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
/// 标题按标题字号，与同一行的普通文字一致。线条颜色同正文（[_decorationInk]）。
TextStyle _scriptGlyphStyle(
  af.Node node,
  TextSpan sized,
  TextSpan before,
  TextSpan after,
  Color? ink,
) {
  final style = after.style ?? sized.style ?? const TextStyle();
  final blockSetsSize =
      node.type == kDiaryBlockHeading ||
      after.style?.fontSize != before.style?.fontSize;
  final resolved = blockSetsSize || sized.style?.fontSize == null
      ? style
      : style.copyWith(fontSize: sized.style!.fontSize);
  return _decorationInk(resolved, ink) ?? resolved;
}

/// 下划线与删除线的颜色跟随文字色 [ink]（这段文字最终的颜色，已叠上引用
/// 等块样式），[style] 没有线条或 [ink] 为空时原样返回。
///
/// 正文样式继承自 Material 3 的排版，它把 decorationColor 定成了墨色：不改
/// 的话换了文字色，线条仍是墨色。只把它清空也不行：decorationColor 为空时
/// 引擎把相邻、线型相同的几段文字并成一条线，整条按第一段的颜色画。所以
/// 逐段显式写上。块随后在整段上另定的线色（已勾选待办的划线）仍会覆盖它。
TextStyle? _decorationInk(TextStyle? style, Color? ink) {
  final decoration = style?.decoration;
  if (style == null ||
      ink == null ||
      decoration == null ||
      decoration == TextDecoration.none ||
      style.decorationColor == ink) {
    return style;
  }
  return style.copyWith(decorationColor: ink);
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
