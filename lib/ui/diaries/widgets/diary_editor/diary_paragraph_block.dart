import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import 'diary_first_line_indent.dart';

/// 首行缩进的正文段落块：与上游段落块同样的结构与行为，另把首行缩进
/// [firstLineIndent]（逻辑像素，见 `DiaryTypography.firstLineIndentExtent`）。
///
/// 只在缩进大于 0 时注册（[buildDiaryEditorBlocks]），不缩进时仍用上游段落块，
/// 默认排版与改版前逐像素一致。居中、右对齐的段落不缩进，两端对齐的照常
/// 缩进（对齐经块配置的 `textAlign`，见 `diaryBlockTextAlign`）。
///
/// 缩进的画法见 [diaryIndentFirstGlyph]：段首的字被换成“缩进 + 字”的占位，
/// 文字偏移与文档一致，但占位框从行首算起。本类在几何查询上把这段缩进当成
/// 段首之前的空白：
/// - 段首光标画在缩进之后（空段落同样，与缩进过的占位提示对齐）；
/// - 从段首开始的选区不涂缩进；
/// - 点在缩进或首字上时按首字自己的中线落到段首或首字之后（上游按整个
///   占位框的中线，中线落在缩进里）；
/// - 取词按真实文字求词界：占位符会把首字与后文断开（“Hello”只选中
///   “ello”，中文分词也会错位）。
class DiaryParagraphBlockBuilder extends af.BlockComponentBuilder {
  DiaryParagraphBlockBuilder({
    super.configuration,
    required this.firstLineIndent,
  });

  final double firstLineIndent;

  @override
  af.BlockComponentWidget build(
    af.BlockComponentContext blockComponentContext,
  ) {
    final node = blockComponentContext.node;
    return DiaryParagraphBlock(
      key: node.key,
      node: node,
      configuration: configuration,
      firstLineIndent: firstLineIndent,
    );
  }

  @override
  af.BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class DiaryParagraphBlock extends af.BlockComponentStatefulWidget {
  const DiaryParagraphBlock({
    super.key,
    required super.node,
    super.configuration = const af.BlockComponentConfiguration(),
    required this.firstLineIndent,
  });

  final double firstLineIndent;

  @override
  State<DiaryParagraphBlock> createState() => _DiaryParagraphBlockState();
}

class _DiaryParagraphBlockState extends State<DiaryParagraphBlock>
    with
        af.SelectableMixin,
        af.DefaultSelectableMixin,
        af.BlockComponentConfigurable,
        af.BlockComponentBackgroundColorMixin,
        af.NestedBlockComponentStatefulWidgetMixin,
        af.BlockComponentTextDirectionMixin,
        af.BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: af.ParagraphBlockKeys.type,
  );

  @override
  af.BlockComponentConfiguration get configuration => widget.configuration;

  @override
  af.Node get node => widget.node;

  bool _showPlaceholder = false;

  /// 取词用的整段文字排版，按文字缓存：长按 / 双击与拖动选区时会连续取词。
  TextPainter? _wordPainter;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(_onSelectionChange);
    _onSelectionChange();
  }

  @override
  void dispose() {
    editorState.selectionNotifier.removeListener(_onSelectionChange);
    _wordPainter?.dispose();
    super.dispose();
  }

  /// 与上游一致：光标停在本段时才显示占位提示。
  void _onSelectionChange() {
    final selection = editorState.selection;
    final show =
        selection != null &&
        selection.isSingle &&
        selection.start.path.equals(node.path);
    if (show != _showPlaceholder) {
      setState(() => _showPlaceholder = show);
    }
  }

  /// 本段生效的缩进（逻辑像素，未缩放）；居中、右对齐的段落为 0。两端对齐
  /// 照常缩进：它与左对齐一样从起始侧排起（上游 [alignment] 认不出
  /// `justify`、为 null），只是把各行拉满，首行的缩进位置不变。
  double get _indent =>
      alignment == Alignment.center || alignment == Alignment.centerRight
      ? 0
      : widget.firstLineIndent;

  /// 缩进在屏幕上的位移：占位里的内容随正文字体缩放，从行首起向书写方向。
  double get _shift {
    final extent = _indent * editorState.editorStyle.textScaleFactor;
    return textDirection() == TextDirection.rtl ? -extent : extent;
  }

  bool get _hasText => node.delta?.isNotEmpty ?? false;

  /// 段首那个字（字素）的码元数，即首字占位覆盖的文档偏移；空段落为 0。
  int get _leadLength {
    final text = node.delta?.toPlainText() ?? '';
    return text.isEmpty ? 0 : text.characters.first.length;
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final indent = _indent;
    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          af.AppFlowyRichText(
            key: forwardKey,
            delegate: this,
            node: widget.node,
            editorState: editorState,
            textAlign: alignment?.toTextAlign ?? textAlign,
            placeholderText: _showPlaceholder ? placeholderText : ' ',
            textSpanDecorator: (textSpan) => diaryIndentFirstGlyph(
              textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
              ),
              indent: indent,
              direction: textDirection,
            ),
            placeholderTextSpanDecorator: (textSpan) {
              final styled = textSpan.updateTextStyle(
                placeholderTextStyleWithTextSpan(textSpan: textSpan),
              );
              // 有文字时上游把占位清空（只清 text），不能留下子片段。
              return _hasText || indent == 0
                  ? styled
                  : diaryIndentPlaceholder(
                      styled,
                      indent: indent,
                      direction: textDirection,
                    );
            },
            textDirection: textDirection,
            cursorColor: editorState.editorStyle.cursorColor,
            selectionColor: editorState.editorStyle.selectionColor,
            cursorWidth: editorState.editorStyle.cursorWidth,
          ),
        ],
      ),
    );

    child = af.BlockSelectionContainer(
      key: blockComponentKey,
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [af.BlockSelectionType.block],
      child: Padding(padding: padding, child: child),
    );

    final decoration = this.decoration;
    if (withBackgroundColor && decoration != null) {
      child = DecoratedBox(decoration: decoration, child: child);
    }
    return child;
  }

  // ---- 几何：把首字占位里的缩进当成段首之前的空白 ----

  @override
  Rect? getCursorRectInPosition(
    af.Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final rect = super.getCursorRectInPosition(
      position,
      shiftWithBaseOffset: shiftWithBaseOffset,
    );
    if (rect == null || position.offset != 0 || _indent == 0) return rect;
    final caret = rect.shift(Offset(_shift, 0));
    final lead = _leadLength;
    if (lead == 0) return caret;
    // 段首光标取自首字占位框，框里不含行距，比同一行其他位置的光标矮；
    // 纵向改用首字之后的光标，与这一行一致。
    final next = super.getCursorRectInPosition(
      position.copyWith(offset: lead),
      shiftWithBaseOffset: shiftWithBaseOffset,
    );
    return next == null
        ? caret
        : Rect.fromLTRB(caret.left, next.top, caret.right, next.bottom);
  }

  @override
  List<Rect> getRectsInSelection(
    af.Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final rects = super.getRectsInSelection(
      selection,
      shiftWithBaseOffset: shiftWithBaseOffset,
    );
    if (rects.isEmpty || _indent == 0 || !_selectsBlockStart(selection)) {
      return rects;
    }
    // 第一个框从行首（首字占位的起点）开始：空段落是一道细框，整体挪到
    // 缩进之后；有文字时裁掉缩进那一截。
    final first = rects.first;
    final shift = _shift;
    final Rect trimmed;
    if (!_hasText) {
      trimmed = first.shift(Offset(shift, 0));
    } else if (shift > 0) {
      trimmed = Rect.fromLTRB(
        math.min(first.left + shift, first.right),
        first.top,
        first.right,
        first.bottom,
      );
    } else {
      trimmed = Rect.fromLTRB(
        first.left,
        first.top,
        math.max(first.right + shift, first.left),
        first.bottom,
      );
    }
    return <Rect>[trimmed, ...rects.skip(1)];
  }

  /// [selection] 在本段里是否从段首开始（从前面的块延伸过来也算）。
  bool _selectsBlockStart(af.Selection selection) {
    final start = selection.normalized.start;
    if (start.path.equals(node.path)) return start.offset == 0;
    return start.path < node.path;
  }

  @override
  af.Position getPositionInOffset(Offset start) =>
      _snapFirstGlyph(start, super.getPositionInOffset(start));

  @override
  af.Selection getSelectionInRange(Offset start, Offset end) {
    final range = super.getSelectionInRange(start, end);
    return range.copyWith(
      start: _snapFirstGlyph(start, range.start),
      end: _snapFirstGlyph(end, range.end),
    );
  }

  /// 点按落在首字占位（缩进 + 首字）里时，按首字自己的中线取段首或首字之后。
  af.Position _snapFirstGlyph(Offset global, af.Position position) {
    final length = _leadLength;
    if (_indent == 0 || length == 0 || position.offset > length) {
      return position;
    }
    final lead = forward.getCursorRectInPosition(position.copyWith(offset: 0));
    final after = forward.getCursorRectInPosition(
      position.copyWith(offset: length),
    );
    if (lead == null || after == null) return position;
    final local = global - forward.localToGlobal(Offset.zero);
    // 占位总在首行；只有一个字宽的首行之下才可能落到这里。
    if (local.dy > after.bottom) return position;
    final glyphStart = lead.left + _shift;
    final center = (glyphStart + after.left) / 2;
    final beforeGlyph = _shift > 0 ? local.dx < center : local.dx > center;
    return position.copyWith(offset: beforeGlyph ? 0 : length);
  }

  @override
  af.Selection? getWordBoundaryInOffset(Offset offset) {
    final word = _wordAt(getPositionInOffset(offset).offset);
    return word == null ? super.getWordBoundaryInOffset(offset) : _range(word);
  }

  @override
  af.Selection? getWordBoundaryInPosition(af.Position position) {
    final word = _wordAt(position.offset);
    return word == null
        ? super.getWordBoundaryInPosition(position)
        : _range(word);
  }

  @override
  af.Selection? getWordEdgeInOffset(Offset offset) {
    final position = getPositionInOffset(offset);
    final word = _wordAt(position.offset);
    if (word == null) return super.getWordEdgeInOffset(offset);
    return af.Selection.collapsed(
      position.copyWith(
        offset: position.offset <= word.start ? word.start : word.end,
      ),
    );
  }

  af.Selection _range(TextRange word) => af.Selection(
    start: af.Position(path: node.path, offset: word.start),
    end: af.Position(path: node.path, offset: word.end),
  );

  /// 按本段真实文字求 [offset] 处的词界；不缩进或没有文字时为 null（交给
  /// 上游）。词界只取决于文字，不需要正文样式与换行宽度。
  TextRange? _wordAt(int offset) {
    if (_indent == 0 || !_hasText) return null;
    final text = node.delta!.toPlainText();
    var painter = _wordPainter;
    if (painter == null || (painter.text as TextSpan?)?.text != text) {
      painter?.dispose();
      painter = _wordPainter = TextPainter(
        text: TextSpan(text: text),
        textDirection: textDirection(),
      )..layout();
    }
    return painter.getWordBoundary(
      TextPosition(offset: offset.clamp(0, text.length)),
    );
  }
}
