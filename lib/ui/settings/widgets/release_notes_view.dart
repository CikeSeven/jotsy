import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/markdown/markdown_code_block.dart';
import '../../widgets/markdown/markdown_table.dart';
import '../models/release_notes_document.dart';
import '../models/release_notes_incremental.dart';

/// 渲染 Markdown（子集，见 [parseReleaseNotes]）：更新说明与 AI 回答共用。
///
/// 标题、段落与列表沿用应用字阶；链接为主色可点按文字，交给 [onOpenLink]。
/// 每个链接地址只建一个点按识别器（点按时再读取最新的回调），随组件销毁。
///
/// 重建开销：每个块建好的组件按块对象记着，块没变就交回同一个组件实例，
/// 框架不再往下重建与排版。整段解析时（[streaming] 为 false）内容不变就
/// 全部复用；流式时（[streaming] 为 true）经 [ReleaseNotesIncrementalParser]
/// 只重新解析末尾还在变的那一段，前面定稿的块原样复用——回答再长，一帧也
/// 只重排最后一块。主题、正文字样或是否画引用胶囊变了时整份重建。
class ReleaseNotesView extends StatefulWidget {
  const ReleaseNotesView({
    super.key,
    required this.markdown,
    this.onOpenLink,
    this.bodyStyle,
    this.onCitation,
    this.streaming = false,
  });

  final String markdown;
  final ValueChanged<String>? onOpenLink;

  /// 正文字样；为 null 时取 `bodyMedium`（更新说明的默认外观）。AI 回答等
  /// 嵌在别处时传入，与所在区域的字阶一致。
  final TextStyle? bodyStyle;

  /// 给出时，正文里的引用标记 `[D3]` 画成可点的小胶囊，点按回调编号
  /// （`D3`）。AI 对话与回顾用它跳到被引用的日记；更新说明不传。
  final ValueChanged<String>? onCitation;

  /// 内容正在流式变长（AI 回答生成中）：增量解析；之后新出现的块淡入上移
  /// （组件建立时已经有的块不动，滚出屏幕再回来不会整段重播）；还在变长的
  /// 代码块先不高亮，定稿后再上色。
  final bool streaming;

  @override
  State<ReleaseNotesView> createState() => _ReleaseNotesViewState();
}

class _ReleaseNotesViewState extends State<ReleaseNotesView> {
  ReleaseNotesIncrementalParser? _parser;
  List<ReleaseNoteBlock> _blocks = const <ReleaseNoteBlock>[];

  /// 前多少块已经定稿（组件可以记住）；整段解析时为全部。
  int _stableCount = 0;

  /// 流式时，组件建立那一刻已经有的块数：它们不播入场动画。
  int _initialCount = 0;

  /// 定稿的块建好的组件（含块前的间距与入场动画的外壳），按块的位置记：
  /// 定稿之后同一位置的块不再变。不按块对象记——分隔线是同一个常量对象，
  /// 出现两次时会拿到同一份带着别处间距的组件。
  final Map<int, Widget> _built = <int, Widget>{};

  final Map<String, TapGestureRecognizer> _recognizers =
      <String, TapGestureRecognizer>{};

  @override
  void initState() {
    super.initState();
    _parse();
    _initialCount = _blocks.length;
  }

  @override
  void didUpdateWidget(covariant ReleaseNotesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streaming != widget.streaming) {
      _parser = null;
      _built.clear();
      _parse();
    } else if (oldWidget.markdown != widget.markdown) {
      _parse();
    }
    // 记住的组件里带着当时的字样，以及引用画不画成胶囊、链接能不能点。
    if (oldWidget.bodyStyle != widget.bodyStyle ||
        (oldWidget.onCitation == null) != (widget.onCitation == null) ||
        (oldWidget.onOpenLink == null) != (widget.onOpenLink == null)) {
      _built.clear();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 主题变了（明暗、配色、字体）：记住的组件带着旧颜色，全部重建。
    _built.clear();
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _parse() {
    if (!widget.streaming) {
      _built.clear();
      _blocks = parseReleaseNotes(widget.markdown);
      _stableCount = _blocks.length;
      return;
    }
    final parser = _parser ??= ReleaseNotesIncrementalParser();
    _blocks = parser.update(widget.markdown);
    // 定稿的块变少了：内容不是原来的延长（解析器从头来过），旧组件作废。
    if (parser.stableCount < _stableCount) _built.clear();
    _stableCount = parser.stableCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body =
        widget.bodyStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.55,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < _blocks.length; i++)
          if (i < _stableCount)
            _built.putIfAbsent(i, () => _item(context, i, body))
          else
            _item(context, i, body),
      ],
    );
  }

  /// 第 [index] 块连同它前面的间距；流式时新出现的块外面套一层入场动画
  /// （同一位置始终是同一种外壳，块从“末尾”转为“定稿”时动画状态不丢）。
  Widget _item(BuildContext context, int index, TextStyle? body) {
    final block = _blocks[index];
    final item = Padding(
      padding: EdgeInsets.only(
        top: _gapBefore(block, index == 0 ? null : _blocks[index - 1]),
      ),
      child: _buildBlock(context, block, body, settled: index < _stableCount),
    );
    if (!widget.streaming || index < _initialCount) return item;
    return ExpressiveEntrance(duration: ExpressiveMotion.fast, child: item);
  }

  /// 标题前留出段落感，同一列表内的条目紧凑排列。
  double _gapBefore(ReleaseNoteBlock block, ReleaseNoteBlock? previous) {
    if (previous == null) {
      return 0;
    }
    return switch (block.kind) {
      ReleaseNoteBlockKind.heading => block.level <= 2 ? 18 : 14,
      ReleaseNoteBlockKind.listItem
          when previous.kind == ReleaseNoteBlockKind.listItem =>
        6,
      _ when previous.kind == ReleaseNoteBlockKind.heading => 8,
      _ => 10,
    };
  }

  Widget _buildBlock(
    BuildContext context,
    ReleaseNoteBlock block,
    TextStyle? body, {
    required bool settled,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    switch (block.kind) {
      case ReleaseNoteBlockKind.heading:
        final style =
            (block.level <= 2 ? textTheme.titleMedium : textTheme.titleSmall)
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                );
        return Semantics(
          header: true,
          child: Text.rich(_spans(block.spans, style)),
        );
      case ReleaseNoteBlockKind.paragraph:
        return Text.rich(_spans(block.spans, body));
      case ReleaseNoteBlockKind.listItem:
        final marker = block.marker;
        return Padding(
          padding: EdgeInsets.only(left: block.level * 18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: marker == null ? 18 : 24,
                child: marker == null
                    ? Padding(
                        // 圆点对齐首行文字的视觉中线。
                        padding: EdgeInsets.only(
                          top: ((body?.fontSize ?? 14) * 1.55 - 6) / 2,
                          right: 8,
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: block.level == 0
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        marker,
                        style: body?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
              ),
              Expanded(child: Text.rich(_spans(block.spans, body))),
            ],
          ),
        );
      case ReleaseNoteBlockKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colorScheme.outlineVariant, width: 3),
            ),
          ),
          child: Text.rich(
            _spans(
              block.spans,
              body?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        );
      case ReleaseNoteBlockKind.code:
        return MarkdownCodeBlock(
          code: block.text,
          language: block.language,
          // 还在变长的块每帧都变，写完再识别语言、上色。
          highlight: settled,
        );
      case ReleaseNoteBlockKind.table:
        final header = body?.copyWith(fontWeight: FontWeight.w600);
        return MarkdownTable(
          rows: <List<InlineSpan>>[
            for (final (index, row) in block.rows.indexed)
              <InlineSpan>[
                for (final cell in row)
                  _spans(cell, index == 0 ? header : body),
              ],
          ],
          alignments: <TextAlign>[
            for (final align in block.alignments)
              switch (align) {
                ReleaseNoteColumnAlign.start => TextAlign.start,
                ReleaseNoteColumnAlign.center => TextAlign.center,
                ReleaseNoteColumnAlign.end => TextAlign.end,
              },
          ],
        );
      case ReleaseNoteBlockKind.rule:
        return Divider(height: 8, color: colorScheme.outlineVariant);
    }
  }

  TextSpan _spans(List<ReleaseNoteSpan> spans, TextStyle? base) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextSpan(
      style: base,
      children: <InlineSpan>[
        for (final span in spans)
          if (widget.onCitation != null &&
              !span.code &&
              _citation.hasMatch(span.text))
            ..._citationSpans(span.text)
          else
            TextSpan(
              text: span.text,
              recognizer: _recognizerFor(span.link),
              style: TextStyle(
                fontWeight: span.bold ? FontWeight.w700 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
                fontFamily: span.code ? 'monospace' : null,
                backgroundColor: span.code
                    ? colorScheme.surfaceContainerHighest
                    : null,
                color: span.link != null ? colorScheme.primary : null,
                // 链接的下划线与删除线可以同时出现。
                decoration: span.link == null && !span.strike
                    ? null
                    : TextDecoration.combine(<TextDecoration>[
                        if (span.link != null) TextDecoration.underline,
                        if (span.strike) TextDecoration.lineThrough,
                      ]),
                decorationColor: span.link != null
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : null,
              ),
            ),
      ],
    );
  }

  static final RegExp _citation = RegExp(r'\[(D\d{1,3})\]');

  /// 把一段文字里的 `[Dn]` 换成可点的小胶囊，其余文字原样。
  List<InlineSpan> _citationSpans(String text) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _citation.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final ref = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: colors.primaryContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => widget.onCitation?.call(ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  child: Text(
                    ref.substring(1),
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return spans;
  }

  GestureRecognizer? _recognizerFor(String? link) {
    if (link == null || widget.onOpenLink == null) {
      return null;
    }
    return _recognizers.putIfAbsent(
      link,
      () => TapGestureRecognizer()..onTap = () => widget.onOpenLink?.call(link),
    );
  }
}
