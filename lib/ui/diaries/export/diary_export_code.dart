import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Brightness, Color, ColorScheme;

import '../../../core/database/code_block_codec.dart';
import '../models/diary_code_block/diary_code_block_style.dart';
import '../models/diary_code_block/diary_code_highlighter.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import 'diary_export_blocks.dart';

/// 一段同色的代码文字；[role] 为 null 时用配色的正文字色。
@immutable
class DiaryExportCodeRun {
  const DiaryExportCodeRun(this.text, [this.role, this.color, this.background]);

  final String text;
  final DiaryCodeTokenRole? role;

  /// 用户在这段代码上设过的文字色与背景色（[ExportInline] 的口径，保留
  /// 透明度）；文字色优先于记号色，与应用里一致。
  final Color? color;
  final Color? background;
}

/// 导出文件里的代码高亮，PDF、Word 与网页共用（Markdown 只在围栏上写语言，
/// 由阅读端着色；纯文本与 CSV 不着色）。
///
/// - 配色与应用同源：取用户在“代码块样式”里选的主题（[DiaryCodeThemes]，
///   已过对比度兜底）。纸面（PDF、Word、网页浅色模式）用 [paper]，网页深色
///   模式用 [night]。明暗“跟随主题”时纸面取浅色、深色模式取深色；固定浅色
///   或深色时两处都用那一套，与应用里固定明暗的代码块一致。
/// - 语言与应用一致：明确指定的语言照用，纯文本不着色；未指定时按“自动
///   识别语言”开关取 [DiaryCodeHighlighter.detect] 的结果。导出是一次性
///   生成，直接识别整块，不经编辑器里带防抖的识别跟踪器。
/// - 以整块为单位着色（多行字符串、块注释会跨行）：语言相同的相邻代码行
///   合成一块，着色后再按行切开交给写出器。超过 [DiaryCodeHighlighter]
///   行数或字数上限的块先按行数与长度跳过，不为它拼接整块文字。
/// 纯计算，无 IO；高亮结果走 [DiaryCodeHighlighter.instance] 的有界缓存。
@immutable
class DiaryExportCodeTheme {
  const DiaryExportCodeTheme({
    required this.paper,
    required this.night,
    this.autoDetect = true,
  });

  /// 按代码块样式与应用配色解析；[scheme] 只用于“跟随应用”主题。
  factory DiaryExportCodeTheme.resolve(
    DiaryCodeBlockStyle style,
    ColorScheme scheme,
  ) {
    DiaryCodePalette palette(Brightness brightness) =>
        DiaryCodeThemes.palette(style.theme, brightness, scheme);
    final paper = palette(
      style.brightness == DiaryCodeBrightness.dark
          ? Brightness.dark
          : Brightness.light,
    );
    return DiaryExportCodeTheme(
      paper: paper,
      // 固定明暗时直接复用同一套：网页据此省掉深色模式的那组变量。
      night: style.brightness == DiaryCodeBrightness.system
          ? palette(Brightness.dark)
          : paper,
      autoDetect: style.autoDetect,
    );
  }

  /// 纸面上的配色：PDF、Word 与网页的浅色模式。
  final DiaryCodePalette paper;

  /// 网页深色模式的配色；与 [paper] 是同一个对象时不区分明暗。
  final DiaryCodePalette night;

  /// 未指定语言的代码块是否自动识别语言（关闭时不着色）。
  final bool autoDetect;

  /// 该角色的文字是否斜体（注释）。
  bool italicFor(DiaryCodeTokenRole? role) =>
      role == DiaryCodeTokenRole.comment && paper.commentItalic;

  /// 一个代码块（语言相同的相邻代码行）的着色片段，按行切开：结果与
  /// [lines] 一一对应，每行的片段依次拼接即为原行，空行没有片段。
  ///
  /// [language] 取 [ExportBlock.codeLanguage] 的口径：null 为未指定，
  /// [kCodeBlockPlain] 为纯文本，其余为语言 id。不着色时每行只有一段无
  /// 角色的原文。
  List<List<DiaryExportCodeRun>> highlightLines(
    List<String> lines,
    String? language,
  ) {
    final tokens = _tokensFor(lines, language);
    final result = <List<DiaryExportCodeRun>>[];
    var lineStart = 0;
    for (final line in lines) {
      final lineEnd = lineStart + line.length;
      final runs = <DiaryExportCodeRun>[];
      var position = lineStart;
      void take(int to, DiaryCodeTokenRole? role) {
        if (to <= position) {
          return;
        }
        runs.add(
          DiaryExportCodeRun(
            line.substring(position - lineStart, to - lineStart),
            role,
          ),
        );
        position = to;
      }

      // 区间按起点排好、互不重叠；跨行的区间（块注释）在每行各取一段。
      for (final token in tokens.overlapping(lineStart, lineEnd)) {
        take(math.max(token.start, lineStart), null);
        take(math.min(token.end, lineEnd), token.role);
      }
      take(lineEnd, null);
      result.add(runs);
      lineStart = lineEnd + 1;
    }
    return result;
  }

  /// [blocks] 里每个代码行的着色片段，下标与 [blocks] 对应，非代码块为
  /// null。语言相同的相邻代码行合成一块着色（与网页、Markdown 分段的口径
  /// 一致）；用户设过颜色的文字按行内片段的边界切开，带上它的文字色与
  /// 背景色（Word、网页用；PDF 走 [colorCodeBlocks]）。
  List<List<DiaryExportCodeRun>?> highlightBlocks(List<ExportBlock> blocks) {
    final lines = _roleRuns(blocks);
    return <List<DiaryExportCodeRun>?>[
      for (final (index, runs) in lines.indexed)
        runs == null ? null : _withInlineColors(runs, blocks[index].inlines),
    ];
  }

  /// PDF 用：把代码行的行内片段按着色片段切开，记号片段写上纸面配色的
  /// 不透明文字色、注释另加斜体，交给 PDF 块写出器按行内样式渲染。片段的
  /// 其余格式原样保留；用户手动设过文字色的片段保留原色、只加注释的斜体，
  /// 与应用里一致。分组口径同 [highlightBlocks]。没有代码行时直接返回
  /// [blocks]；块与片段都不可变，结果是新列表，不改动调用方的正文。
  List<ExportBlock> colorCodeBlocks(List<ExportBlock> blocks) {
    if (!blocks.any(
      (ExportBlock block) => block.kind == ExportBlockKind.code,
    )) {
      return blocks;
    }
    final lines = _roleRuns(blocks);
    return <ExportBlock>[
      for (final (index, block) in blocks.indexed)
        lines[index] == null
            ? block
            : block.copyWith(
                inlines: _colorInlines(block.inlines, lines[index]!),
              ),
    ];
  }

  /// 每个代码行只带角色的着色片段（下标与 [blocks] 对应，非代码块为 null）。
  List<List<DiaryExportCodeRun>?> _roleRuns(List<ExportBlock> blocks) {
    final result = List<List<DiaryExportCodeRun>?>.filled(blocks.length, null);
    var start = 0;
    while (start < blocks.length) {
      final language = blocks[start].codeLanguage;
      if (blocks[start].kind != ExportBlockKind.code) {
        start++;
        continue;
      }
      var end = start + 1;
      while (end < blocks.length &&
          blocks[end].kind == ExportBlockKind.code &&
          blocks[end].codeLanguage == language) {
        end++;
      }
      final lines = highlightLines(<String>[
        for (var i = start; i < end; i++) blocks[i].plainText,
      ], language);
      for (var i = start; i < end; i++) {
        result[i] = lines[i - start];
      }
      start = end;
    }
    return result;
  }

  /// 把着色片段 [runs] 叠到一行原有的行内片段 [inlines] 上：两边的边界都
  /// 保留，各段 = 原片段的格式 + 记号的颜色与斜体。两者拼接后是同一行原文
  /// （[highlightLines] 的约定），按长度对齐即可。
  List<ExportInline> _colorInlines(
    List<ExportInline> inlines,
    List<DiaryExportCodeRun> runs,
  ) {
    final result = <ExportInline>[];
    var runIndex = 0;
    var runOffset = 0;
    for (final inline in inlines) {
      var position = 0;
      while (position < inline.text.length && runIndex < runs.length) {
        final run = runs[runIndex];
        final length = math.min(
          inline.text.length - position,
          run.text.length - runOffset,
        );
        result.add(
          _coloredPiece(
            inline,
            inline.text.substring(position, position + length),
            run.role,
          ),
        );
        position += length;
        runOffset += length;
        if (runOffset == run.text.length) {
          runIndex++;
          runOffset = 0;
        }
      }
    }
    return result;
  }

  ExportInline _coloredPiece(
    ExportInline inline,
    String text,
    DiaryCodeTokenRole? role,
  ) {
    if (role == null) {
      return text == inline.text ? inline : inline.copyWith(text: text);
    }
    final ownColor = inline.color != null;
    return inline.copyWith(
      text: text,
      color: ownColor ? null : paper.tokens[role],
      italic: italicFor(role) ? true : null,
    );
  }

  /// 把一行的着色片段 [runs] 按行内片段 [inlines] 的边界切开，带上各自的
  /// 文字色与背景色；整行都没设颜色时原样返回。两者拼接后都是同一行原文
  /// （[highlightLines] 的约定），按长度对齐即可。
  static List<DiaryExportCodeRun> _withInlineColors(
    List<DiaryExportCodeRun> runs,
    List<ExportInline> inlines,
  ) {
    if (!inlines.any(
      (ExportInline inline) =>
          inline.color != null || inline.background != null,
    )) {
      return runs;
    }
    final result = <DiaryExportCodeRun>[];
    var inlineIndex = 0;
    var inlineOffset = 0;
    for (final run in runs) {
      var position = 0;
      while (position < run.text.length && inlineIndex < inlines.length) {
        final inline = inlines[inlineIndex];
        final length = math.min(
          run.text.length - position,
          inline.text.length - inlineOffset,
        );
        result.add(
          DiaryExportCodeRun(
            run.text.substring(position, position + length),
            run.role,
            inline.color,
            inline.background,
          ),
        );
        position += length;
        inlineOffset += length;
        if (inlineOffset == inline.text.length) {
          inlineIndex++;
          inlineOffset = 0;
        }
      }
    }
    return result;
  }

  /// 不着色时的结果：不识别、不拼接整块。
  DiaryCodeTokens _tokensFor(List<String> lines, String? language) {
    if (language == kCodeBlockPlain || (language == null && !autoDetect)) {
      return DiaryCodeTokens.empty;
    }
    // 与编辑器同一上限；先按行数与长度判断，超限的块不拼接整块文字。
    if (lines.length > DiaryCodeHighlighter.maxLines) {
      return DiaryCodeTokens.empty;
    }
    var length = lines.length - 1;
    for (final line in lines) {
      length += line.length;
      if (length > DiaryCodeHighlighter.maxLength) {
        return DiaryCodeTokens.empty;
      }
    }
    final text = lines.join('\n');
    final highlighter = DiaryCodeHighlighter.instance;
    final id = language ?? highlighter.detect(text);
    return id == null ? DiaryCodeTokens.empty : highlighter.tokens(text, id);
  }
}
