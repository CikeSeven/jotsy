import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Brightness, Color, ColorScheme;
import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../../../core/database/code_block_codec.dart';
import '../models/diary_code_block/diary_code_block_style.dart';
import '../models/diary_code_block/diary_code_highlighter.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import '../models/diary_text_colors.dart';
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
  /// 背景色（Word、网页用；PDF 走 [colorDeltaCodeLines]）。
  List<List<DiaryExportCodeRun>?> highlightBlocks(List<ExportBlock> blocks) {
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
        result[i] = _withInlineColors(lines[i - start], blocks[i].inlines);
      }
      start = end;
    }
    return result;
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

  /// PDF 用：把正文 Delta 里代码行的文字按着色片段拆开，记号片段写上纸面
  /// 配色的不透明 `color`、注释另加 `italic`，交给 PDF 块写出器按行内样式渲染。用户手动设过文字色的片段保留原色、只加注释的斜体，
  /// 与应用里一致。
  ///
  /// 按行拆开时以换行所在的 op 的属性为行属性（Quill 把块属性挂在换行上）；
  /// 含嵌入的代码行（正常编辑不会出现）原样保留、不着色。输出经 [Delta] 合并
  /// 相邻同样式的文字，非代码行与原来等价。没有代码行时直接返回 [ops]；
  /// 不改动 [ops] 里的任何对象。
  List<dynamic> colorDeltaCodeLines(List<dynamic> ops) {
    if (!ops.any(_hasCodeBlockAttribute)) {
      return ops;
    }
    final lines = <_DeltaLine>[];
    var pieces = <_DeltaPiece>[];
    for (final op in ops) {
      if (op is! Map) {
        continue;
      }
      final rawAttributes = op['attributes'];
      final attributes = rawAttributes is Map && rawAttributes.isNotEmpty
          ? Map<String, dynamic>.from(rawAttributes)
          : null;
      final insert = op['insert'];
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            pieces.add(_DeltaPiece(parts[i], attributes));
          }
          if (i < parts.length - 1) {
            lines.add(_DeltaLine(pieces, attributes));
            pieces = <_DeltaPiece>[];
          }
        }
      } else if (insert != null) {
        pieces.add(_DeltaPiece(insert, attributes));
      }
    }

    final out = Delta();
    var start = 0;
    while (start < lines.length) {
      final line = lines[start];
      if (!line.isPlainCode) {
        line.writeTo(out);
        start++;
        continue;
      }
      final language = line.language;
      var end = start + 1;
      while (end < lines.length &&
          lines[end].isPlainCode &&
          lines[end].language == language) {
        end++;
      }
      final colored = highlightLines(<String>[
        for (var i = start; i < end; i++) lines[i].text,
      ], language);
      for (var i = start; i < end; i++) {
        _writeColoredLine(out, lines[i], colored[i - start]);
      }
      start = end;
    }
    // 结尾没有换行的残余片段（Delta 不完整时）原样带上。
    for (final piece in pieces) {
      out.insert(piece.insert, piece.attributes);
    }
    return out.toJson();
  }

  /// 把 [runs] 叠到这一行原有的片段上：片段边界与着色边界都保留，各段
  /// 属性 = 原片段属性 + 记号的颜色与斜体。
  void _writeColoredLine(
    Delta out,
    _DeltaLine line,
    List<DiaryExportCodeRun> runs,
  ) {
    var runIndex = 0;
    var runOffset = 0;
    for (final piece in line.pieces) {
      final text = piece.insert as String;
      var position = 0;
      while (position < text.length) {
        final run = runs[runIndex];
        final length = math.min(
          text.length - position,
          run.text.length - runOffset,
        );
        out.insert(
          text.substring(position, position + length),
          _codeAttributes(piece.attributes, run.role),
        );
        position += length;
        runOffset += length;
        if (runOffset == run.text.length) {
          runIndex++;
          runOffset = 0;
        }
      }
    }
    out.insert('\n', line.attributes);
  }

  Map<String, dynamic>? _codeAttributes(
    Map<String, dynamic>? attributes,
    DiaryCodeTokenRole? role,
  ) {
    if (role == null) {
      return attributes;
    }
    final ownColor = attributes?['color'] != null;
    final italic = italicFor(role);
    if (ownColor && !italic) {
      return attributes;
    }
    return <String, dynamic>{
      ...?attributes,
      if (!ownColor) 'color': encodeDiaryColor(paper.tokens[role]!),
      if (italic) 'italic': true,
    };
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

  static bool _hasCodeBlockAttribute(dynamic op) {
    if (op is! Map) {
      return false;
    }
    final attributes = op['attributes'];
    return attributes is Map && _isCodeBlockValue(attributes['code-block']);
  }

  static bool _isCodeBlockValue(Object? value) =>
      value != null && value != false;
}

/// 一行里的一段：文字或嵌入，带原有的行内属性。
class _DeltaPiece {
  const _DeltaPiece(this.insert, this.attributes);

  final Object insert;
  final Map<String, dynamic>? attributes;
}

/// 一行：若干片段加上换行的属性（块属性）。
class _DeltaLine {
  _DeltaLine(this.pieces, this.attributes);

  final List<_DeltaPiece> pieces;
  final Map<String, dynamic>? attributes;

  /// 只含文字的代码行；含嵌入的代码行不着色。
  bool get isPlainCode =>
      DiaryExportCodeTheme._isCodeBlockValue(attributes?['code-block']) &&
      pieces.every((_DeltaPiece piece) => piece.insert is String);

  /// [ExportBlock.codeLanguage] 口径的语言。
  String? get language => codeBlockExplicitLanguage(attributes?['code-block']);

  String get text =>
      pieces.map((_DeltaPiece piece) => piece.insert as String).join();

  void writeTo(Delta out) {
    for (final piece in pieces) {
      out.insert(piece.insert, piece.attributes);
    }
    out.insert('\n', attributes);
  }
}
