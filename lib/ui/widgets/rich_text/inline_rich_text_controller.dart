import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/rich_text/inline_rich_text.dart';
import '../../../core/services/app_platform.dart';

/// 整条文字四种开关样式的取值（导图由界面层按节点外观推出；留言没有整条
/// 样式，全为 false）。
typedef InlineBaseMarks = ({
  bool bold,
  bool italic,
  bool underline,
  bool strike,
});

/// 按 [style]（整条文字的样式）推出四种开关样式的取值。
InlineBaseMarks inlineBaseMarksOf(TextStyle? style) {
  final decoration = style?.decoration ?? TextDecoration.none;
  return (
    bold: (style?.fontWeight ?? FontWeight.w400).value >= 600,
    italic: style?.fontStyle == FontStyle.italic,
    underline: decoration.contains(TextDecoration.underline),
    strike: decoration.contains(TextDecoration.lineThrough),
  );
}

/// 桌面上设局部样式的快捷键：Ctrl / ⌘ + B / I / U，Ctrl / ⌘ + Shift + S
/// （与正文编辑器一致）。导图的画布、大纲与留言的输入框共用；不是快捷键时
/// 为 null。
InlineMark? inlineFormatShortcut(KeyEvent event) {
  if (!AppPlatform.isDesktop || event is! KeyDownEvent) return null;
  final keys = HardwareKeyboard.instance;
  if (!(keys.isControlPressed || keys.isMetaPressed) || keys.isAltPressed) {
    return null;
  }
  final key = event.logicalKey;
  if (keys.isShiftPressed) {
    return key == LogicalKeyboardKey.keyS ? InlineMark.strike : null;
  }
  if (key == LogicalKeyboardKey.keyB) return InlineMark.bold;
  if (key == LogicalKeyboardKey.keyI) return InlineMark.italic;
  if (key == LogicalKeyboardKey.keyU) return InlineMark.underline;
  return null;
}

/// 带局部样式的输入框控制器（导图主题的画布输入框与大纲编辑行、写留言
/// 面板共用）：文字之外还持有局部样式 [runs]。
///
/// - 打字（含输入法组字、粘贴、剪切）经 [value] 进来：文字变了就经
///   [remapRunsAfterEdit] 把样式挪到新文字上，再经 [onChanged] 交给使用方
///   （导图写进文档，同一节点连续输入合并为一步撤销）；
/// - 设样式（[toggle] / [setColor] / [setLink]）：有选区时改选中的字，经
///   [onChanged]（`format: true`）交出；没有选区时开关与颜色只记下“接下来
///   打的字”的样式 [pending]，不动文字。pending 在打出字或光标挪走时清掉；
/// - 整段替换（[replaceRange]，如 `@` 候选写入链接）同时改文字、样式与
///   光标，经 [onChanged] 交出；
/// - 显示经 [buildTextSpan]：各段样式由 [runStyle]（使用方按自己的配色
///   解析）覆盖在输入框的样式上，输入法组字区另加下划线，组字时样式不闪；
/// - 设样式只 `notifyListeners`，不改文字与选区，输入法状态不受影响。
class InlineRichTextController extends TextEditingController {
  InlineRichTextController({
    required List<InlineTextRun> runs,
    required this.onChanged,
    this.runStyle,
    InlineBaseMarks? base,
  }) : _runs = runs,
       base =
           base ??
           (bold: false, italic: false, underline: false, strike: false),
       super(text: inlineRunsText(runs));

  /// 文字或样式变了（只挪光标不调）：[format] 为设样式（不与打字合并）。
  final void Function(String text, List<InlineTextRun> runs, {bool format})
  onChanged;

  /// 一段样式在输入框样式之上的覆盖；null 时不画局部样式。
  TextStyle? Function(InlineTextMarks marks)? runStyle;

  /// 整条文字的取值：判断按钮状态、切换时去冗余都以它为准。
  InlineBaseMarks base;

  List<InlineTextRun> _runs;
  List<InlineTextRun> get runs => _runs;

  InlineTextMarks? _pending;

  /// 没有选区时设下的“接下来打的字”的样式；null 为随前一个字。
  InlineTextMarks? get pending => _pending;

  bool _baseOf(InlineMark mark) => switch (mark) {
    InlineMark.bold => base.bold,
    InlineMark.italic => base.italic,
    InlineMark.underline => base.underline,
    InlineMark.strike => base.strike,
  };

  @override
  set value(TextEditingValue newValue) {
    final old = super.value;
    final textChanged = newValue.text != old.text;
    if (textChanged) {
      _runs = remapRunsAfterEdit(_runs, newValue.text, pending: _pending);
      // 打出的字已经带上 pending，后面接着打的字继承它，不必再留着。
      _pending = null;
    } else if (newValue.selection != old.selection) {
      _pending = null;
    }
    super.value = newValue;
    if (textChanged) onChanged(newValue.text, _runs);
  }

  /// 光标处“接下来打的字”的样式。
  InlineTextMarks get _caretMarks =>
      _pending ?? inlineMarksForInsertion(_runs, selection.start);

  /// [mark] 在选区（没有选区时为接下来打的字）上是否开着。
  bool isActive(InlineMark mark) {
    final range = selection;
    if (!range.isValid) return false;
    if (range.isCollapsed) return _caretMarks.flag(mark) ?? _baseOf(mark);
    return inlineMarkActive(
      _runs,
      range.start,
      range.end,
      mark,
      base: _baseOf(mark),
    );
  }

  /// 选区（没有选区时为接下来打的字）局部设的 [mark] 颜色；不一致或没设
  /// 时为 null。
  String? colorOf(InlineColorMark mark) {
    final range = selection;
    if (!range.isValid) return null;
    if (range.isCollapsed) return _caretMarks.colorOf(mark);
    return inlineCommonColor(_runs, range.start, range.end, mark);
  }

  /// 切换 [mark]：选区里每个字实际都开着就关掉，否则打开。
  void toggle(InlineMark mark) {
    final range = selection;
    if (!range.isValid) return;
    final base = _baseOf(mark);
    if (range.isCollapsed) {
      final current = _caretMarks;
      final on = !(current.flag(mark) ?? base);
      _pending = current.withFlag(mark, inlineFlagFor(on, base: base));
      notifyListeners();
      return;
    }
    _apply(toggleMark(_runs, range.start, range.end, mark, base: base));
  }

  /// 设 [mark] 颜色（`#AARRGGBB`，按原色显示；null 为随整条样式）。
  void setColor(InlineColorMark mark, String? color) {
    final range = selection;
    if (!range.isValid) return;
    if (range.isCollapsed) {
      _pending = _caretMarks.withColor(mark, color);
      notifyListeners();
      return;
    }
    _apply(
      formatRuns(
        _runs,
        range.start,
        range.end,
        (marks) => marks.withColor(mark, color),
      ),
    );
  }

  /// 选区所在或光标紧挨着的那段链接（见 [inlineLinkRangeAt]）；没有时为
  /// null。
  InlineLinkRange? get linkRange {
    final range = selection;
    if (!range.isValid) return null;
    return inlineLinkRangeAt(_runs, range.start, range.end);
  }

  /// 给 [start, end) 设链接 [href]（null 为去掉）。空范围什么也不做。
  void setLink(int start, int end, String? href) {
    if (start >= end) return;
    _apply(setRunsLink(_runs, start, end, href));
  }

  /// 把 [start, end) 换成 [text]（样式为 [marks]），光标停在新字之后。
  void replaceRange(
    int start,
    int end,
    String text, {
    InlineTextMarks marks = InlineTextMarks.none,
  }) {
    final length = this.text.length;
    final from = start.clamp(0, length);
    final to = end.clamp(from, length);
    _runs = replaceRunsRange(_runs, from, to, text, marks);
    _pending = null;
    final newText = inlineRunsText(_runs);
    // 绕过 [value] 的改写：样式已经算好，不能再按公共前后缀挪一遍。
    super.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: from + text.length),
    );
    onChanged(newText, _runs);
  }

  void _apply(List<InlineTextRun> runs) {
    if (_listEquals(runs, _runs)) return;
    _runs = runs;
    notifyListeners();
    onChanged(text, _runs, format: true);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final resolve = runStyle;
    final runs = _runs;
    if (resolve == null ||
        runs.every((run) => run.marks.isEmpty) ||
        inlineRunsText(runs) != text) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final below = style?.decoration;
    List<InlineSpan> spans(int start, int end, {bool composing = false}) =>
        <InlineSpan>[
          for (final run in sliceInlineRuns(runs, start, end))
            TextSpan(
              text: run.text,
              style: composing
                  ? _withUnderline(resolve(run.marks), below)
                  : resolve(run.marks),
            ),
        ];
    final composing = value.composing;
    final length = text.length;
    final children = withComposing && value.isComposingRangeValid
        ? <InlineSpan>[
            ...spans(0, composing.start),
            ...spans(composing.start, composing.end, composing: true),
            ...spans(composing.end, length),
          ]
        : spans(0, length);
    return TextSpan(style: style, children: children);
  }

  /// 组字区的下划线叠在已有的装饰线上（不覆盖删除线）。
  static TextStyle _withUnderline(TextStyle? style, TextDecoration? below) =>
      (style ?? const TextStyle()).copyWith(
        decoration: TextDecoration.combine(<TextDecoration>[
          style?.decoration ?? below ?? TextDecoration.none,
          TextDecoration.underline,
        ]),
      );

  static bool _listEquals(List<InlineTextRun> a, List<InlineTextRun> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
