// Markdown 里的代码块（AI 回答、更新说明共用）：顶部一条写语言名与“复制”
// 按钮，下面是可横向滚动的等宽代码（不折行，长行不会被拆得难读）。
//
// - 配色取代码块的“跟随应用”主题（`DiaryCodeThemes`，由主题色推导，明暗
//   自动适配、各记号对底色有对比度兜底），高亮复用编辑器的
//   `DiaryCodeHighlighter`（22 种语言，带缓存与长度上限）。
// - 语言取围栏上写的（常见别名换成语言表里的 id）；没写或不认识时按内容
//   识别，识别不出就按纯文本显示。
// - [highlight] 为 false 时不识别也不高亮：流式生成中、还在变长的那一块每帧
//   都在变，等它写完（定稿）再上色，免得每帧重新解析整段代码。
// - 复制的是代码原文；点了之后图标换成对勾两秒。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../diaries/models/diary_code_block/diary_code_highlighter.dart';
import '../../diaries/models/diary_code_block/diary_code_language.dart';
import '../../diaries/models/diary_code_block/diary_code_theme.dart';
import '../desktop_horizontal_scroll.dart';

/// 围栏上常见的语言写法到语言表 id 的对应；表里本来就有的 id 原样返回，
/// 不认识的返回 null。
String? markdownCodeLanguageId(String? raw) {
  if (raw == null) return null;
  final name = raw.trim().toLowerCase();
  if (name.isEmpty) return null;
  final id = _languageAliases[name] ?? name;
  return diaryCodeLanguageById(id) == null ? null : id;
}

const Map<String, String> _languageAliases = <String, String>{
  'js': 'javascript',
  'jsx': 'javascript',
  'mjs': 'javascript',
  'node': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'py': 'python',
  'python3': 'python',
  'kt': 'kotlin',
  'c': 'cpp',
  'c++': 'cpp',
  'h': 'cpp',
  'hpp': 'cpp',
  'cc': 'cpp',
  'c#': 'cs',
  'csharp': 'cs',
  'golang': 'go',
  'rs': 'rust',
  'rb': 'ruby',
  'sh': 'bash',
  'shell': 'bash',
  'zsh': 'bash',
  'console': 'bash',
  'jsonc': 'json',
  'json5': 'json',
  'yml': 'yaml',
  'html': 'xml',
  'svg': 'xml',
  'md': 'markdown',
  'patch': 'diff',
};

class MarkdownCodeBlock extends StatefulWidget {
  const MarkdownCodeBlock({
    super.key,
    required this.code,
    this.language,
    this.highlight = true,
  });

  final String code;

  /// 围栏上写的语言（原样）；null 时按内容识别。
  final String? language;

  /// 是否识别语言并上色（还在变长的块传 false）。
  final bool highlight;

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  String? _languageId;
  DiaryCodeTokens _tokens = DiaryCodeTokens.empty;
  bool _copied = false;
  Timer? _copiedReset;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(MarkdownCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language ||
        oldWidget.highlight != widget.highlight) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    super.dispose();
  }

  /// 定下语言与着色区间。只在代码、语言或 [MarkdownCodeBlock.highlight] 变了
  /// 时算一次；高亮器自己按（语言, 原文）缓存，回滚出屏幕再回来也不重算。
  void _resolve() {
    final highlighter = DiaryCodeHighlighter.instance;
    _languageId = markdownCodeLanguageId(widget.language);
    if (!widget.highlight) {
      _tokens = DiaryCodeTokens.empty;
      return;
    }
    _languageId ??= highlighter.detect(widget.code);
    final id = _languageId;
    _tokens = id == null
        ? DiaryCodeTokens.empty
        : highlighter.tokens(widget.code, id);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    // 提示用的计时（不是动画）：两秒后图标换回“复制”。
    _copiedReset?.cancel();
    _copiedReset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// 按着色区间把代码拼成一串文字片段；区间之间的空隙用正文色。
  TextSpan _codeSpan(DiaryCodePalette palette, TextStyle? base) {
    final code = widget.code;
    if (_tokens.isEmpty) return TextSpan(text: code, style: base);
    final children = <TextSpan>[];
    var index = 0;
    for (final token in _tokens.tokens) {
      if (token.start >= code.length) break;
      final end = token.end > code.length ? code.length : token.end;
      if (token.start > index) {
        children.add(TextSpan(text: code.substring(index, token.start)));
      }
      children.add(
        TextSpan(
          text: code.substring(token.start, end),
          style: TextStyle(
            color: palette.tokens[token.role],
            fontStyle:
                palette.commentItalic &&
                    token.role == DiaryCodeTokenRole.comment
                ? FontStyle.italic
                : null,
          ),
        ),
      );
      index = end;
    }
    if (index < code.length) {
      children.add(TextSpan(text: code.substring(index)));
    }
    return TextSpan(style: base, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = DiaryCodeThemes.palette(
      DiaryCodeThemeId.app,
      theme.brightness,
      theme.colorScheme,
    );
    final id = _languageId;
    final label = id == null
        ? (widget.language ?? '')
        : diaryCodeLanguageById(id)!.name;
    final codeStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: palette.foreground,
      height: 1.45,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ColoredBox(
              color: palette.header,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.lineNumber,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _copied
                          ? l10n.markdownCodeCopied
                          : l10n.markdownCopyCode,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      onPressed: () => unawaited(_copy()),
                      icon: FaIcon(
                        _copied
                            ? FontAwesomeIcons.check
                            : FontAwesomeIcons.copy,
                        size: 12,
                        color: palette.lineNumber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DesktopHorizontalScroll(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Text.rich(
                  _codeSpan(palette, codeStyle),
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
