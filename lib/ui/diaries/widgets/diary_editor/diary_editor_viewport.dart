import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../controllers/diary_editor_controller.dart';

/// 精确避让叠在原生编辑器之上的面板。上游自动滚动使用固定边缘距离，无法
/// 得知工具栏的实际高度；这里按光标全局矩形与本帧视口校正，只在文字/选区
/// 变化、键盘升高或遮挡增长时工作，用户滚动和单纯调色不会被拉回光标。
class DiaryEditorViewport extends StatefulWidget {
  const DiaryEditorViewport({
    super.key,
    required this.controller,
    required this.coveredHeight,
    required this.revealPath,
    required this.child,
    this.focusNode,
  });
  final DiaryEditorController controller;
  final double coveredHeight;
  final FocusNode? focusNode;
  final void Function(af.Path) revealPath;
  final Widget child;
  @override
  State<DiaryEditorViewport> createState() => _DiaryEditorViewportState();
}

class _DiaryEditorViewportState extends State<DiaryEditorViewport>
    with WidgetsBindingObserver {
  StreamSubscription<af.EditorTransactionValue>? _transactions;
  af.Selection? _selection;
  bool _scheduled = false;
  double _keyboard = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  void _bind() {
    widget.controller.state.selectionNotifier.addListener(_selectionChanged);
    widget.focusNode?.addListener(_focusChanged);
    _selection = widget.controller.state.selection;
    _transactions = widget.controller.state.transactionStream.listen((event) {
      if (event.$1 != af.TransactionTime.after) return;
      if (event.$2.operations.any(
        (op) =>
            op is af.InsertOperation ||
            op is af.DeleteOperation ||
            (op is af.UpdateOperation &&
                _text(op.attributes['delta']) !=
                    _text(op.oldAttributes['delta'])),
      )) {
        _schedule();
      }
    });
  }

  String? _text(Object? delta) => delta is List
      ? delta
            .whereType<Map>()
            .map((op) => op['insert'] is String ? op['insert'] : '')
            .join()
      : null;
  void _unbind(DiaryEditorViewport old) {
    old.controller.state.selectionNotifier.removeListener(_selectionChanged);
    old.focusNode?.removeListener(_focusChanged);
    _transactions?.cancel();
  }

  void _focusChanged() {
    if (widget.focusNode?.hasFocus == true) _schedule();
  }

  void _selectionChanged() {
    final next = widget.controller.state.selection;
    if (next == _selection) return;
    _selection = next;
    _schedule();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final grew = inset > _keyboard;
    _keyboard = inset;
    if (grew) _schedule();
  }

  @override
  void didUpdateWidget(DiaryEditorViewport old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.focusNode != widget.focusNode) {
      _unbind(old);
      _bind();
    }
    if (widget.coveredHeight > old.coveredHeight) _schedule();
  }

  bool get _focused {
    if (widget.focusNode != null) return widget.focusNode!.hasFocus;
    return primaryFocus?.context
            ?.findAncestorWidgetOfExactType<af.AppFlowyEditor>()
            ?.editorState ==
        widget.controller.state;
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _reveal();
    });
  }

  void _reveal() {
    if (!_focused || widget.controller.isDisposed) return;
    final state = widget.controller.state;
    final selection = state.selection;
    if (selection == null || !selection.isCollapsed) return;
    final rects = state.selectionRects();
    if (rects.isEmpty) {
      widget.revealPath(selection.end.path);
      // 虚拟列表要等目标块布局后才有光标几何；下一帧再精确校正。
      _schedule();
      return;
    }
    final box = state.renderBox;
    final position = state.scrollableState?.position;
    if (box == null || position == null || !position.hasContentDimensions) {
      return;
    }
    final view = View.of(context);
    final keyboardTop =
        (view.physicalSize.height - view.viewInsets.bottom) /
        view.devicePixelRatio;
    final origin = box.localToGlobal(Offset.zero);
    final bottom =
        math.min(origin.dy + box.size.height, keyboardTop) -
        widget.coveredHeight;
    final caret = rects.first;
    final delta = caret.bottom > bottom
        ? caret.bottom - bottom
        : caret.top < origin.dy
        ? caret.top - origin.dy
        : 0.0;
    if (delta.abs() < 0.5) return;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() > 0.5) {
      position.jumpTo(target);
      // 虚拟列表会在滚动后把锚定段落重新定位；再核对一次最终几何，避免
      // 第一帧的估计高度让光标仍压在工具栏边缘。
      _schedule();
    }
  }

  @override
  void dispose() {
    _unbind(widget);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
