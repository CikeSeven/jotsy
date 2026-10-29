import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/code_block_codec.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_code_block/diary_code_highlighter.dart';
import '../../models/diary_text_style_options.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_script_spans.dart';

/// AppFlowy 按行内片段给出 UTF-16 偏移，组字前、中、后的片段都据此切高亮；
/// 不改文档 Delta，不让语法着色污染用户的颜色、撤销或输入法状态。
///
/// 代码块之外只改行内片段的画法：字号档位 `size` 改字号，上标 / 下标
/// `script` 逐字换成占位（见 `diaryScriptSpan`，码元与文档一一对应）；日记
/// 链接（`href` 为内部地址）由 [links] 接管点按（见 [diaryLinkTextSpan]），
/// 网址链接仍交给上游。
af.TextSpanDecoratorForAttribute diaryEditorSpanDecorator(
  DiaryCodeBlockLook code,
  DiaryBlockLanguageTracker tracker,
  double fontSize, {
  DiaryLinkSpanOptions? links,
}) {
  return (context, node, index, insert, before, after) {
    if (node.type != 'code') {
      final target = links == null
          ? null
          : DiaryLinkTarget.tryParse(insert.attributes?[kDiaryInlineHref]);
      final decorated = target != null
          ? diaryLinkTextSpan(node, index, insert, before, target, links!)
          : af.defaultTextSpanDecoratorForAttribute(
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

/// 日记链接的点按与外观（[diaryEditorSpanDecorator] 的 `links`）。
class DiaryLinkSpanOptions {
  const DiaryLinkSpanOptions({
    required this.state,
    required this.onOpen,
    required this.notebooksEnabled,
    required this.plainColor,
  });

  final af.EditorState state;

  /// 打开链接目标（编辑态是否打开日记本由它决定，见 `openDiaryLinkTarget`）。
  final ValueChanged<DiaryLinkTarget> onOpen;

  /// 日记本功能关闭时，日记本链接按普通文字绘制、不可点。
  final bool notebooksEnabled;

  /// 正文墨色：按普通文字绘制时代替链接色。
  final Color? plainColor;
}

/// 日记链接的片段。手势沿用上游网址链接（`defaultTextSpanDecoratorForAttribute`）
/// 的分工，只把“打开”换成应用内跳转：
/// - 只读正文（预览页）：点按即打开；
/// - 编辑态：单击选中整段链接文字（工具栏「链接」随之高亮，可编辑或移除），
///   200ms 内再点一次或按住 Ctrl / ⌘ 点按才打开，不打断正常的点按定位。
/// 识别器与上游一样随每次构建新建：片段的生命周期由上游的文字渲染管理。
TextSpan diaryLinkTextSpan(
  af.Node node,
  int index,
  af.TextInsert insert,
  TextSpan before,
  DiaryLinkTarget target,
  DiaryLinkSpanOptions links,
) {
  if (target.kind == DiaryLinkKind.notebook && !links.notebooksEnabled) {
    return TextSpan(
      text: insert.text,
      style: _plainLinkStyle(before.style, insert.attributes, links.plainColor),
    );
  }
  final state = links.state;
  Timer? timer;
  var taps = 0;
  final recognizer = TapGestureRecognizer()
    ..onTap = () {
      if (state.isDisposed) return;
      if (!state.editable) {
        links.onOpen(target);
        return;
      }
      taps += 1;
      timer?.cancel();
      final keyboard = HardwareKeyboard.instance;
      if (taps >= 2 || keyboard.isControlPressed || keyboard.isMetaPressed) {
        taps = 0;
        links.onOpen(target);
        return;
      }
      // 双击的判定窗口（非动画计时），与上游网址链接相同。
      timer = Timer(const Duration(milliseconds: 200), () {
        taps = 0;
        if (state.isDisposed) return;
        state.updateSelectionWithReason(
          af.Selection.single(
            path: node.path,
            startOffset: index,
            endOffset: index + insert.text.length,
          ),
          reason: af.SelectionUpdateReason.uiEvent,
        );
      });
    };
  return TextSpan(
    text: insert.text,
    style: before.style,
    recognizer: recognizer,
    mouseCursor: SystemMouseCursors.click,
  );
}

/// 去掉链接色与链接下划线，保留用户自己设的文字色、下划线与删除线。
TextStyle? _plainLinkStyle(
  TextStyle? style,
  Map<String, dynamic>? attributes,
  Color? plainColor,
) {
  if (style == null) return null;
  final decorations = [
    if (attributes?[kDiaryInlineUnderline] == true) TextDecoration.underline,
    if (attributes?[kDiaryInlineStrikethrough] == true)
      TextDecoration.lineThrough,
  ];
  return style.copyWith(
    color: attributes?[kDiaryInlineTextColor] != null
        ? style.color
        : plainColor,
    decoration: TextDecoration.combine(decorations),
    decorationColor: plainColor,
  );
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
