import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../core/database/rich_text/inline_rich_text.dart';

/// 留言文字一段格式在正文样式之上的覆盖（写留言的输入框与时间线共用）：
/// 粗体 w700、斜体、下划线与删除线；链接为主色 + 主色下划线（与正文的链接
/// 同一外观），[linkActive] 为 false（日记本功能关闭时的日记本链接）时按
/// 普通文字绘制。颜色等其余属性不显示：留言只写这几种。
TextStyle diaryCommentRunStyle(
  ColorScheme scheme,
  InlineTextMarks marks, {
  bool linkActive = true,
}) {
  final link = marks.href != null && linkActive;
  final decorations = <TextDecoration>[
    if (marks.underline == true || link) TextDecoration.underline,
    if (marks.strike == true) TextDecoration.lineThrough,
  ];
  return TextStyle(
    fontWeight: marks.bold == true ? FontWeight.w700 : null,
    fontStyle: marks.italic == true ? FontStyle.italic : null,
    color: link ? scheme.primary : null,
    decoration: decorations.isEmpty
        ? null
        : TextDecoration.combine(decorations),
    decorationColor: link ? scheme.primary.withValues(alpha: 0.6) : null,
  );
}

/// 日记本功能关闭时，日记本链接按普通文字绘制、不可点（与正文一致）。
bool diaryCommentLinkActive(String href, {required bool notebooksEnabled}) =>
    notebooksEnabled ||
    DiaryLinkTarget.tryParse(href)?.kind != DiaryLinkKind.notebook;

/// 没有设链接的文字里能直接点开的网址（http / https），去掉结尾的标点。
final RegExp _bareUrl = RegExp(r'''https?://[^\s<>"'，。；！？、）】》」』]+''');
const String _trailingPunctuation = '.,;:!?)]}\'"';

/// 一段无链接文字里的网址范围（[start, end)），按出现顺序。
List<({int start, int end})> diaryCommentBareUrls(String text) {
  final out = <({int start, int end})>[];
  for (final match in _bareUrl.allMatches(text)) {
    var end = match.end;
    while (end > match.start && _trailingPunctuation.contains(text[end - 1])) {
      end--;
    }
    final url = Uri.tryParse(text.substring(match.start, end));
    if (url != null && url.host.isNotEmpty) {
      out.add((start: match.start, end: end));
    }
  }
  return out;
}

/// 留言文字：按格式分好的段 [runs] 画成富文本；设了链接的字与文字里直接
/// 写出的网址可以点按，经 [onOpenLink] 打开（日记 / 日记本链接与网址的
/// 分流由调用方负责）。[onOpenLink] 为 null 时（设置页的样式预览）只显示
/// 外观、不可点。
///
/// 片段与点按识别器按输入（各段、日记本开关、主色、可不可点）缓存，输入
/// 变了才重建，旧识别器随之释放，卸载时全部释放；识别器点按时才读
/// [onOpenLink]，父级每次构建换一个回调不必重建。长按不经过这里：外层条目
/// 的长按菜单照常生效（识别器在长按胜出时被拒绝）。
class DiaryCommentText extends StatefulWidget {
  const DiaryCommentText({
    super.key,
    required this.runs,
    required this.style,
    this.onOpenLink,
    this.notebookLinks = true,
  });

  final List<InlineTextRun> runs;

  /// 日记本功能是否开着：关着时日记本链接按普通文字绘制、不可点。
  final bool notebookLinks;
  final TextStyle? style;
  final ValueChanged<String>? onOpenLink;

  @override
  State<DiaryCommentText> createState() => _DiaryCommentTextState();
}

class _DiaryCommentTextState extends State<DiaryCommentText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  Object? _cacheKey;
  List<InlineTextRun>? _cachedRuns;
  TextSpan? _cached;

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  InlineSpan _link(String text, String href, TextStyle style) {
    if (widget.onOpenLink == null) return TextSpan(text: text, style: style);
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onOpenLink?.call(href);
    _recognizers.add(recognizer);
    return TextSpan(
      text: text,
      style: style,
      recognizer: recognizer,
      mouseCursor: SystemMouseCursors.click,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notebooks = widget.notebookLinks;
    final key = (notebooks, scheme.primary, widget.onOpenLink != null);
    if (_cached == null ||
        key != _cacheKey ||
        !listEquals(widget.runs, _cachedRuns)) {
      _cacheKey = key;
      _cachedRuns = widget.runs;
      _cached = _buildSpan(scheme, notebooks: notebooks);
    }
    return Text.rich(_cached!, style: widget.style);
  }

  TextSpan _buildSpan(ColorScheme scheme, {required bool notebooks}) {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    for (final run in widget.runs) {
      final marks = run.marks;
      final href = marks.href;
      if (href != null) {
        final active = diaryCommentLinkActive(
          href,
          notebooksEnabled: notebooks,
        );
        final style = diaryCommentRunStyle(scheme, marks, linkActive: active);
        spans.add(
          active
              ? _link(run.text, href, style)
              : TextSpan(text: run.text, style: style),
        );
        continue;
      }
      final style = diaryCommentRunStyle(scheme, marks);
      var cursor = 0;
      for (final url in diaryCommentBareUrls(run.text)) {
        if (url.start > cursor) {
          spans.add(
            TextSpan(text: run.text.substring(cursor, url.start), style: style),
          );
        }
        final text = run.text.substring(url.start, url.end);
        spans.add(
          _link(text, text, diaryCommentRunStyle(scheme, marks.withHref(text))),
        );
        cursor = url.end;
      }
      if (cursor < run.text.length) {
        spans.add(TextSpan(text: run.text.substring(cursor), style: style));
      }
    }
    return TextSpan(children: spans);
  }
}
