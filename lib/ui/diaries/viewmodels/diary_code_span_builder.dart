import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../controllers/diary_code_language_tracker.dart';
import '../models/diary_code_block/diary_code_block_newline.dart';
import '../models/diary_code_block/diary_code_highlighter.dart';
import '../models/diary_code_block/diary_code_language.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import 'diary_code_block_look.dart';

// 把代码块的语法高亮、字体与行号接进 flutter_quill 的渲染钩子。
//
// 输入：解析好的 [DiaryCodeBlockLook] 与该控制器的 [DiaryCodeLanguageTracker]。
// 输出：交给 `QuillEditorConfig` 的三个回调——
// - textSpanBuilder：代码块里的文字按高亮区间拆成带颜色的子 span；
// - customStyleBuilder：语言值为字符串的代码块行补上代码字体（见下）；
// - customLeadingBlockBuilder：行号用代码块配色。
// 副作用：无（识别结果的防抖由 tracker 负责）。
//
// flutter_quill 的约束与对策：
// - textSpanBuilder 按叶子（一段同样式的文字）调用，平常 nodeOffset 为 0、
//   text 为整段；输入法组字时同一叶子被调用 3 次，分别是组字前、组字中、
//   组字后的切片，nodeOffset 为切片在叶子内的起点。高亮按“整块文本”的
//   区间计算，切片在块内的位置 = 行在块内的偏移 + 叶子在行内的偏移 +
//   nodeOffset，三次调用都对得上。
// - 带嵌入的行传入的是克隆出来、没有父节点的叶子，定位不到块，按默认
//   方式渲染（只是不着色，文字仍是代码字体）。
// - 高亮必须看整块（多行字符串、块注释跨行），而每一行、每个叶子都会
//   调用一次；整块文本、语言与高亮区间按“帧”缓存在 Block 上，同一帧里
//   只算一次，避免长代码块每帧 O(行数²) 地拼接文本。
// - text_line.dart 只在块属性值恰为 `true` 时给行套代码样式；语言值是字符串
//   （'python'、'plain'）的块会丢掉代码字体。customStyleBuilder 会遍历行
//   属性，在那里为字符串值补上同一份代码样式。

/// 代码块用于高亮的语言：明确指定的语言 id；'plain' 不高亮；未指定时按
/// [autoDetect] 取自动识别结果（关闭时不高亮）。
String? resolveDiaryCodeHighlightLanguage(
  quill.Block block,
  String blockText, {
  required bool autoDetect,
  required DiaryCodeLanguageTracker tracker,
}) {
  final choice = DiaryCodeLanguageChoice.fromAttributeValue(
    block.style.attributes[quill.Attribute.codeBlock.key]?.value,
  );
  if (choice.isPlain) {
    return null;
  }
  final explicit = choice.languageId;
  if (explicit != null) {
    return explicit;
  }
  return autoDetect ? tracker.languageFor(block, blockText) : null;
}

/// 代码块文字的 span 构建器；代码块以外的文字原样交给 quill 默认实现。
quill.TextSpanBuilder buildDiaryCodeSpanBuilder(
  DiaryCodeBlockLook look,
  DiaryCodeLanguageTracker tracker,
) {
  final memo = Expando<_BlockFrame>('diaryCodeBlockFrame');
  final palette = look.palette;
  final tokenStyles = <DiaryCodeTokenRole, TextStyle>{
    for (final role in DiaryCodeTokenRole.values)
      role: palette.tokenStyle(role),
  };
  // 叶子自带文字色（用户手动上色）时尊重用户的颜色，只保留注释的斜体。
  final keepColorStyles = <DiaryCodeTokenRole, TextStyle?>{
    for (final MapEntry(key: role, value: tokenStyle) in tokenStyles.entries)
      role: tokenStyle.fontStyle == null
          ? null
          : TextStyle(fontStyle: tokenStyle.fontStyle),
  };

  DiaryCodeTokens tokensFor(quill.Block block) {
    final epoch = _currentFrameEpoch();
    if (epoch != null) {
      final cached = memo[block];
      if (cached != null && cached.epoch == epoch) {
        return cached.tokens;
      }
    }
    final text = diaryCodeBlockText(block);
    final language = resolveDiaryCodeHighlightLanguage(
      block,
      text,
      autoDetect: look.autoDetect,
      tracker: tracker,
    );
    final tokens = language == null
        ? DiaryCodeTokens.empty
        : DiaryCodeHighlighter.instance.tokens(text, language);
    if (epoch != null) {
      memo[block] = _BlockFrame(epoch, tokens);
    }
    return tokens;
  }

  return (
    BuildContext context,
    quill.Node node,
    int nodeOffset,
    String text,
    TextStyle? style,
    GestureRecognizer? recognizer,
  ) {
    InlineSpan fallback() => quill.defaultSpanBuilder(
      context,
      node,
      nodeOffset,
      text,
      style,
      recognizer,
    );

    if (text.isEmpty || node is! quill.QuillText) {
      return fallback();
    }
    final line = node.parent;
    if (line is! quill.Line) {
      return fallback();
    }
    final block = line.parent;
    if (!isDiaryCodeBlock(block)) {
      return fallback();
    }
    final tokens = tokensFor(block! as quill.Block);
    if (tokens.isEmpty) {
      return fallback();
    }

    final start = line.offset + node.offset + nodeOffset;
    final end = start + text.length;
    final keepColor =
        node.style.attributes[quill.Attribute.color.key]?.value != null;
    final cursor = recognizer == null ? null : SystemMouseCursors.click;
    final children = <InlineSpan>[];
    var position = start;
    // 空隙不设样式，继承外层 span（即 quill 传入的 style，组字时含下划线）。
    TextSpan piece(int from, int to, TextStyle? pieceStyle) => TextSpan(
      text: text.substring(from - start, to - start),
      style: pieceStyle,
      recognizer: recognizer,
      mouseCursor: cursor,
    );
    for (final token in tokens.overlapping(start, end)) {
      final from = math.max(token.start, start);
      final to = math.min(token.end, end);
      if (from > position) {
        children.add(piece(position, from, null));
      }
      children.add(
        piece(
          from,
          to,
          keepColor ? keepColorStyles[token.role] : tokenStyles[token.role],
        ),
      );
      position = to;
    }
    if (children.isEmpty) {
      return fallback();
    }
    if (position < end) {
      children.add(piece(position, end, null));
    }
    return TextSpan(style: style, children: children);
  };
}

/// 语言值为字符串的代码块行补上代码样式（quill 只认值为 `true` 的块）。
TextStyle Function(quill.Attribute) buildDiaryCodeCustomStyleBuilder(
  DiaryCodeBlockLook look,
) {
  final code = look.codeTextStyle;
  return (quill.Attribute attribute) =>
      attribute.key == quill.Attribute.codeBlock.key &&
          attribute.value is String
      ? code
      : const TextStyle();
}

/// 代码块行号：沿用 quill 的行号排版，颜色换成代码块配色的行号色。其余
/// 行（列表、待办）与关闭行号时返回 null，走 quill 默认实现。
quill.LeadingBlockNodeBuilder buildDiaryCodeLeadingBuilder(
  DiaryCodeBlockLook look,
) {
  final color = look.palette.lineNumber;
  return (quill.Node node, quill.LeadingConfig config) {
    if (!look.lineNumbers) {
      return null;
    }
    final value = config.attrs[quill.Attribute.codeBlock.key]?.value;
    if (value == null || value == false) {
      return null;
    }
    final style = config.style;
    final width = config.width;
    final padding = config.padding;
    if (style == null || width == null || padding == null) {
      return null;
    }
    // getIndexNumberByIndent 会改写 indentLevelCounts，必须在确定接管之后
    // 才读，且只读一次（返回 null 时 quill 的默认实现还会再读一遍）。
    final index = config.index == null ? null : config.getIndexNumberByIndent;
    if (index == null) {
      return null;
    }
    return quill.QuillNumberPoint(
      index: index,
      indentLevelCounts: config.indentLevelCounts,
      count: config.count,
      style: style.copyWith(color: color),
      attrs: config.attrs,
      width: width,
      padding: padding,
      // 代码行号不带点（“1” 而非有序列表的 “1.”），与编辑器的行号一致。
      withDot: false,
    );
  };
}

/// 某个块在某一帧算出的高亮区间。
class _BlockFrame {
  const _BlockFrame(this.epoch, this.tokens);

  final int epoch;
  final DiaryCodeTokens tokens;
}

int _frameEpoch = 0;
bool _frameEpochBumpScheduled = false;

/// 当前帧的编号；不在帧的构建阶段（如测试里直接调用）时返回 null，不缓存。
///
/// 只在构建阶段缓存：文档只会在帧与帧之间被改写，同一帧里所有行看到的
/// 是同一份文本。第一次使用时登记一个帧末回调把编号加一，下一帧自然失效。
int? _currentFrameEpoch() {
  final binding = SchedulerBinding.instance;
  if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
    return null;
  }
  if (!_frameEpochBumpScheduled) {
    _frameEpochBumpScheduled = true;
    binding.addPostFrameCallback((_) {
      _frameEpoch++;
      _frameEpochBumpScheduled = false;
    }, debugLabel: 'diaryCodeBlockFrameEpoch');
  }
  return _frameEpoch;
}
