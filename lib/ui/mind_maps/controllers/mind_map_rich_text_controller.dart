import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_rich_text.dart';

/// 整条主题四种开关样式的取值（输入框所在节点的，由界面层按节点外观推出）。
typedef MindMapBaseMarks = ({
  bool bold,
  bool italic,
  bool underline,
  bool strike,
});

/// 按 [style]（节点文字的整条样式）推出四种开关样式的取值。
MindMapBaseMarks mindMapBaseMarksOf(TextStyle? style) {
  final decoration = style?.decoration ?? TextDecoration.none;
  return (
    bold: (style?.fontWeight ?? FontWeight.w400).value >= 600,
    italic: style?.fontStyle == FontStyle.italic,
    underline: decoration.contains(TextDecoration.underline),
    strike: decoration.contains(TextDecoration.lineThrough),
  );
}

/// 主题文字输入框（画布上的 `MindMapNodeEditor` 与大纲的编辑行）的控制器：
/// 文字之外还持有局部样式 [runs]。
///
/// - 打字（含输入法组字、粘贴、剪切）经 [value] 进来：文字变了就经
///   [remapRunsAfterEdit] 把样式挪到新文字上，再经 [onChanged] 交给编辑
///   会话写进文档（同一节点连续输入合并为一步撤销）；
/// - 设样式（[toggle] / [setColor]）：有选区时改选中的字，经 [onChanged]
///   （`format: true`，各是一步撤销）写入；没有选区时只记下“接下来打的字”
///   的样式 [pending]，不动文档。pending 在打出字或光标挪走时清掉；
/// - 显示经 [buildTextSpan]：各段样式由 [runStyle]（界面层按导图配色解析）
///   覆盖在输入框的样式上，输入法组字区另加下划线，组字时样式不闪；
/// - 设样式只 `notifyListeners`，不改文字与选区，输入法状态不受影响。
class MindMapRichTextController extends TextEditingController {
  MindMapRichTextController({
    required List<MindMapTextRun> runs,
    required this.onChanged,
    this.runStyle,
    MindMapBaseMarks? base,
  }) : _runs = runs,
       base =
           base ??
           (bold: false, italic: false, underline: false, strike: false),
       super(text: mindMapRunsText(runs));

  /// 文字或样式变了（只挪光标不调）：[format] 为设样式（不与打字合并）。
  final void Function(String text, List<MindMapTextRun> runs, {bool format})
  onChanged;

  /// 一段样式在输入框样式之上的覆盖；null 时不画局部样式。
  TextStyle? Function(MindMapTextMarks marks)? runStyle;

  /// 整条主题的取值：判断按钮状态、切换时去冗余都以它为准。
  MindMapBaseMarks base;

  List<MindMapTextRun> _runs;
  List<MindMapTextRun> get runs => _runs;

  MindMapTextMarks? _pending;

  /// 没有选区时设下的“接下来打的字”的样式；null 为随前一个字。
  MindMapTextMarks? get pending => _pending;

  bool _baseOf(MindMapMark mark) => switch (mark) {
    MindMapMark.bold => base.bold,
    MindMapMark.italic => base.italic,
    MindMapMark.underline => base.underline,
    MindMapMark.strike => base.strike,
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
  MindMapTextMarks get _caretMarks =>
      _pending ?? mindMapMarksForInsertion(_runs, selection.start);

  /// [mark] 在选区（没有选区时为接下来打的字）上是否开着。
  bool isActive(MindMapMark mark) {
    final range = selection;
    if (!range.isValid) return false;
    if (range.isCollapsed) return _caretMarks.flag(mark) ?? _baseOf(mark);
    return mindMapMarkActive(
      _runs,
      range.start,
      range.end,
      mark,
      base: _baseOf(mark),
    );
  }

  /// 选区（没有选区时为接下来打的字）局部设的 [mark] 颜色；不一致或没设
  /// 时为 null。
  String? colorOf(MindMapColorMark mark) {
    final range = selection;
    if (!range.isValid) return null;
    if (range.isCollapsed) return _caretMarks.colorOf(mark);
    return mindMapCommonColor(_runs, range.start, range.end, mark);
  }

  /// 切换 [mark]：选区里每个字实际都开着就关掉，否则打开。
  void toggle(MindMapMark mark) {
    final range = selection;
    if (!range.isValid) return;
    final base = _baseOf(mark);
    if (range.isCollapsed) {
      final current = _caretMarks;
      final on = !(current.flag(mark) ?? base);
      _pending = current.withFlag(mark, mindMapFlagFor(on, base: base));
      notifyListeners();
      return;
    }
    _apply(toggleMark(_runs, range.start, range.end, mark, base: base));
  }

  /// 设 [mark] 颜色（`#AARRGGBB`，按原色显示；null 为随整条样式）。
  void setColor(MindMapColorMark mark, String? color) {
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

  void _apply(List<MindMapTextRun> runs) {
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
        mindMapRunsText(runs) != text) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final below = style?.decoration;
    List<InlineSpan> spans(int start, int end, {bool composing = false}) =>
        <InlineSpan>[
          for (final run in sliceMindMapRuns(runs, start, end))
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

  static bool _listEquals(List<MindMapTextRun> a, List<MindMapTextRun> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 当前正在编辑的主题文字输入框（格式条读它），以及格式条所在区域的焦点
/// 与颜色面板的高度。
///
/// 输入框在 initState 时 [attach]、dispose 时 [detach]：两者都可能发生在
/// 构建或卸载树的途中，此时不能同步通知（监听者会在锁住的树里 setState），
/// 所以字段立即改、通知放进微任务。[current] 在 [detach] 后立即为 null，
/// 格式条不会读到已经释放的控制器。
class MindMapTextSession extends ChangeNotifier {
  /// 格式条（含颜色面板）区域的焦点：颜色面板里的颜色代码输入框拿走焦点时
  /// [toolbarFocus] 有焦点，主题输入框不因失焦而结束编辑（见
  /// [keepsEditing]）。只作祖先节点，本身不接收焦点。
  final FocusNode toolbarFocus = FocusNode(
    debugLabel: 'mind-map-format-bar',
    skipTraversal: true,
    canRequestFocus: false,
  );

  /// 颜色面板展开的高度（0 为收起）：画布让正在编辑的节点露出来时一并让开。
  final ValueNotifier<double> panelExtent = ValueNotifier<double>(0);

  /// 主题输入框失焦时是否仍算在编辑：焦点去了格式条（颜色代码输入框）。
  bool get keepsEditing => toolbarFocus.hasFocus;

  MindMapRichTextController? _current;
  bool _disposed = false;
  bool _scheduled = false;

  MindMapRichTextController? get current => _current;

  void attach(MindMapRichTextController controller) {
    if (identical(_current, controller)) return;
    _current = controller;
    _notifyLater();
  }

  void detach(MindMapRichTextController controller) {
    if (!identical(_current, controller)) return;
    _current = null;
    _notifyLater();
  }

  /// 报告颜色面板的高度。可能在构建或卸载途中调用（画布听到后会挪视口），
  /// 一律放进微任务，会话已释放时不再写。
  void setPanelExtent(double extent) {
    scheduleMicrotask(() {
      if (!_disposed) panelExtent.value = extent;
    });
  }

  void _notifyLater() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    toolbarFocus.dispose();
    panelExtent.dispose();
    super.dispose();
  }
}
