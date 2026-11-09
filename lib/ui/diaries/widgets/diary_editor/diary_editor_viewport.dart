import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../controllers/diary_editor_controller.dart';

/// 精确避让叠在原生编辑器之上的面板。上游自动滚动使用固定边缘距离，无法
/// 得知工具栏的实际高度；这里按光标全局矩形与本帧视口校正，只在文字/选区
/// 变化、键盘升高或遮挡增长时工作，用户滚动和单纯调色不会被拉回光标；
/// 拖动段落期间（[DiaryEditorController.draggingBlock]）不工作。
///
/// 选中一段文字时平时不动它（拖选区把手有自己的边缘滚动，见
/// `DiaryEditorSelectionGestures`）；只在遮挡变高（键盘升起、悬浮工具栏
/// 出现、「更多」等面板展开）把它盖住时，把它顶到遮挡上方，选区菜单随之
/// 浮在它上方（#221，见 [_revealSelectionDelta]）。
///
/// 遮挡高度本身变高（[coveredHeight]：面板展开、录音面板打开这类一次性
/// 变化）时滚动带动画（`medium` / `effects`），与浮层的展开同步；键盘逐帧
/// 升高与平时的输入、选区变化仍直接跳到位。
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

  /// 遮挡变高后待核对一次：这一次连选中的文字也要让开（见类注释）。
  bool _coverGrew = false;

  /// 待核对的这一次由 [DiaryEditorViewport.coveredHeight] 变高触发，滚动
  /// 带动画。
  bool _animate = false;
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
    if (grew) {
      _coverGrew = true;
      _schedule();
    }
  }

  @override
  void didUpdateWidget(DiaryEditorViewport old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.focusNode != widget.focusNode) {
      _unbind(old);
      _bind();
    }
    if (widget.coveredHeight > old.coveredHeight) {
      _coverGrew = true;
      _animate = true;
      _schedule();
    }
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
    // 这两个标记只管这一次核对；滚动后的再次核对按需要重新带上。
    final coverGrew = _coverGrew;
    final animate = _animate;
    _coverGrew = false;
    _animate = false;
    final controller = widget.controller;
    if (!_focused || controller.isDisposed || controller.draggingBlock) return;
    final state = widget.controller.state;
    final selection = state.selection;
    if (selection == null || (!selection.isCollapsed && !coverGrew)) return;
    final rects = state.selectionRects();
    if (rects.isEmpty) {
      // 选中的文字不在已布局的范围里：用户把它滚远了，不拉回。
      if (!selection.isCollapsed) return;
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
    final screen = view.physicalSize.height / view.devicePixelRatio;
    final keyboardTop = screen - view.viewInsets.bottom / view.devicePixelRatio;
    final origin = box.localToGlobal(Offset.zero);
    final bottom =
        math.min(origin.dy + box.size.height, keyboardTop) -
        widget.coveredHeight;
    final delta = selection.isCollapsed
        ? _revealDelta(rects.first, origin.dy, bottom)
        : _revealSelectionDelta(rects, origin.dy, bottom, screen);
    if (delta.abs() < 0.5) return;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() <= 0.5) return;
    final duration = animate
        ? ExpressiveMotion.duration(context, ExpressiveMotion.medium)
        : Duration.zero;
    if (duration == Duration.zero) {
      position.jumpTo(target);
      // 虚拟列表会在滚动后把锚定段落重新定位；再核对一次最终几何，避免
      // 第一帧的估计高度让光标仍压在工具栏边缘。
      _recheck(coverGrew);
      return;
    }
    unawaited(
      position
          .animateTo(
            target,
            duration: duration,
            curve: ExpressiveMotion.effects,
          )
          .then((_) {
            // 动画被用户拖动或别的滚动打断时停在半途：不再核对，免得把
            // 用户正在滚的内容拉回来。
            if (mounted && (position.pixels - target).abs() <= 0.5) {
              _recheck(coverGrew);
            }
          }),
    );
  }

  /// 滚动之后在下一帧再核对一次；由遮挡变高触发的核对仍按遮挡变高处理
  /// （选中的文字也让开）。
  void _recheck(bool coverGrew) {
    _coverGrew = _coverGrew || coverGrew;
    _schedule();
  }

  /// 让被遮挡盖住的选中文字（各行矩形 [rects]，全局坐标）露到可见区域
  /// [top]～[bottom] 里所需的滚动量；只往上顶（正数），不需要时为 0。
  ///
  /// 只处理“原本露在屏幕上、被键盘或底部浮层盖住”的选区：顶边要在可见
  /// 区域顶端与屏幕底边 [screen] 之间。整段在可见区域上方或屏幕下方的选区
  /// 是用户自己滚开的，遮挡变高时不拉回。放得下时底边贴着遮挡上沿，选区
  /// 菜单浮在它上方；比可见区域还高时顶边对齐可见区域顶端，尽量多露出来。
  static double _revealSelectionDelta(
    List<Rect> rects,
    double top,
    double bottom,
    double screen,
  ) {
    final selection = rects.reduce((a, b) => a.expandToInclude(b));
    if (selection.top < top || selection.top >= screen) return 0;
    return math.max(0, _revealDelta(selection, top, bottom));
  }

  /// 让光标矩形 [caret] 进入可见区域 [top]～[bottom]（全局纵坐标）所需的
  /// 滚动量，正数向下滚。
  ///
  /// 图片、视频、日记卡片等整块嵌入的“光标”是整个块（见
  /// `DiaryEmbedSelectable`）。折叠长图、竖图在键盘升起或窗口较矮时比可见
  /// 区域还高，上下两头不可能同时露出：若仍按“底边超出就露底、顶边超出就
  /// 露顶”校正，露底后顶边又超出，下一帧再露顶……每帧来回跳，整页一直闪。
  /// 这种块只要求铺满可见区域：顶边低于可见区域顶端（块偏下，如光标往下
  /// 移到它上面）就顶边对齐，底边高于可见区域底端（块偏上）就底边对齐，
  /// 已经铺满就不动。两种校正之后都落在“已铺满”，再次核对时滚动量为 0；
  /// 滚动到头被夹住时由 [_reveal] 的“目标与当前相同就不跳”收住。
  static double _revealDelta(Rect caret, double top, double bottom) {
    if (caret.height > bottom - top) {
      if (caret.top > top) return caret.top - top;
      if (caret.bottom < bottom) return caret.bottom - bottom;
      return 0;
    }
    if (caret.bottom > bottom) return caret.bottom - bottom;
    if (caret.top < top) return caret.top - top;
    return 0;
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
