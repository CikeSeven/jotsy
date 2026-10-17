import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/release_notes_document.dart';

/// 渲染更新说明（Markdown 子集，见 [parseReleaseNotes]）。
///
/// 标题、段落与列表沿用应用字阶；链接为主色可点按文字，交给 [onOpenLink]。
/// 每个链接地址只建一个点按识别器（点按时再读取最新的回调），随组件销毁。
class ReleaseNotesView extends StatefulWidget {
  const ReleaseNotesView({super.key, required this.markdown, this.onOpenLink});

  final String markdown;
  final ValueChanged<String>? onOpenLink;

  @override
  State<ReleaseNotesView> createState() => _ReleaseNotesViewState();
}

class _ReleaseNotesViewState extends State<ReleaseNotesView> {
  late List<ReleaseNoteBlock> _blocks = parseReleaseNotes(widget.markdown);
  final Map<String, TapGestureRecognizer> _recognizers =
      <String, TapGestureRecognizer>{};

  @override
  void didUpdateWidget(covariant ReleaseNotesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _blocks = parseReleaseNotes(widget.markdown);
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final body = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      height: 1.55,
    );
    final children = <Widget>[];
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      final previous = i == 0 ? null : _blocks[i - 1];
      children.add(
        Padding(
          padding: EdgeInsets.only(top: _gapBefore(block, previous)),
          child: _buildBlock(context, block, body),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
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
    TextStyle? body,
  ) {
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
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            block.text,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: colorScheme.onSurface,
              height: 1.45,
            ),
          ),
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
              decoration: span.link != null ? TextDecoration.underline : null,
              decorationColor: span.link != null
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : null,
            ),
          ),
      ],
    );
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
