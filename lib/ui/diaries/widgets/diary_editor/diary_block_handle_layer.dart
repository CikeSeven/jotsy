import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../controllers/diary_block_drag_session.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_table_editing.dart';
import 'diary_block_drop_targets.dart';
import 'diary_block_handle.dart';
import 'diary_block_line_geometry.dart';
import 'diary_block_select_target.dart';
import 'diary_block_selection_layer.dart';
import 'diary_edge_auto_scroll.dart';

/// 编辑态的段落把手：整篇正文只有一个，浮在光标所在块的首行左侧；段落
/// 选择模式（[DiaryBlockSelectionLayer]）也挂在这一层。
///
/// 为什么不给每个块各包一个把手：常驻的把手满屏都是，正文还要让出 24dp
/// 沟槽，与标题对不齐、嵌套块缩进翻倍。这一层叠在编辑器之上，不改变任何
/// 块的布局：
/// - 位置：光标所在块（嵌套时为最内层的块）首行的字形中线（与行首标记同一
///   口径，见 [DiaryBlockLineGeometry]），水平固定在页面左边距里，不随缩进
///   右移：缩进的块也在同一竖列找到把手，把手不会挤进上一级的行首标记列。
///   选区跨块、没有焦点、块滚出视口或处在段落选择模式时隐藏；出现时
///   `fast` 淡入。
/// - 点按：进入段落选择模式并选中这一块（见 `DiaryBlockSelection`）。
/// - 长按把手：拖动整棵子树，实时预览——落点随手指逐帧计算（自动滚动时
///   手指不动也会变），保持拖动开始时的缩进层级（见 [resolveDiaryBlockDrop]），
///   一变就经 [DiaryBlockDragSession] 把块真的挪过去，正文即是松手后的
///   样子；不能落到自身及后代上。被拖的块衬一块圆角底表示“拿在手里”，把手
///   只随手指上下。松手只记一步撤销；指针被系统取消时放回原处。
/// - 段落选择模式里长按块或左侧页边距（经 [DiaryBlockDragRelay]）：拖动选中的
///   整组，同一条链路；不连续的几块在第一次预览时聚到一起，正文选区保持
///   为空。
/// - 落点按手指的位移找（见 [_DiaryBlockHandleLayerState._grabOffset]），
///   并夹在可见区域里；块不会在开始拖动的瞬间跳到手指下面，也不会挪到
///   视口外还建着的缓存块那里。块靠近可见区域上下 48dp 时自动滚动。
/// - 每次预览移动后经 [DiaryBlockHandleLayer.pinPath] 让列表以一个不受影响
///   的块为锚点停在原处（见 [diaryBlockDragAnchor]），整页不会错开。
/// - 拖动由本层直接跟踪指针（全局指针路由），不用 `Draggable`：拖动途中
///   把手或块可能滚出视口而卸载，`Draggable` 的回调绑在它自己的元素上，
///   卸载后全部丢失。全局路由与发起拖动的组件无关，各个入口共用同一条链路。
///
/// 输入：编辑控制器与焦点；输出：只读写选区与块位置事务，没有其他副作用。
class DiaryBlockHandleLayer extends StatefulWidget {
  const DiaryBlockHandleLayer({
    super.key,
    required this.controller,
    required this.relay,
    required this.child,
    this.focusNode,
    this.contentLeft = 0,
    this.childIndent = 28,
    this.coveredHeight = 0,
    this.pinPath,
    this.revealPath,
  });

  final DiaryEditorController controller;

  /// 段落选择模式里块上的长按交到这里开始拖动整组。
  final DiaryBlockDragRelay relay;
  final FocusNode? focusNode;
  final Widget child;

  /// 编辑器的左内边距（页面左边距）：顶层块的左边界，把手固定在它左侧。
  final double contentLeft;

  /// 子块相对父块的缩进（编辑器块配置的 indentPadding，即行首标记列宽）。
  final double childIndent;

  /// 编辑器底部被浮层（工具栏）盖住的高度：拖动的落点与自动滚动不计入。
  final double coveredHeight;

  /// 让 [af.Path] 所在的顶层块停在列表视口的给定比例处（以它为锚点）；
  /// 不是长列表时为 null。
  final void Function(af.Path path, double alignment)? pinPath;

  /// 跳到某一块（段落选择模式揭示远在视口外的块）。
  final void Function(af.Path path)? revealPath;

  @override
  State<DiaryBlockHandleLayer> createState() => _DiaryBlockHandleLayerState();
}

class _HandlePlacement {
  const _HandlePlacement(this.node, this.center);

  final af.Node node;

  /// 把手中心，本层的局部坐标。
  final Offset center;
}

class _DiaryBlockHandleLayerState extends State<DiaryBlockHandleLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<af.EditorTransactionValue>? _transactions;
  bool _scheduled = false;
  _HandlePlacement? _placement;
  final DiaryBlockLineGeometry _geometry = DiaryBlockLineGeometry();

  // ---- 拖动状态 ----
  DiaryBlockDragSession? _session;

  /// 正在跟踪的指针；非 null 期间全局指针路由已登记。
  int? _dragPointer;

  /// 手指的全局位置。
  Offset? _pointer;

  /// 手指按着的那一块的首行中线减去手指的纵坐标，开始拖动时量好：落点按
  /// “手指位置 + 它”找，即跟随手指的位移而不是绝对位置。从把手发起时接近
  /// 0；在段落选择模式里长按块的中部时手指在首行下方几行，按绝对位置找，
  /// 手指一动块就会跳过去。整组里不连续的几块按手指按着的那一块算，组
  /// 落到它被拖到的地方。
  double _grabOffset = 0;

  /// 长按把手时：把手中心减去手指（本层局部坐标），把手据此跟着手指走。
  /// 从段落选择模式发起时为 null（把手不在）。
  Offset? _handleGrab;

  /// 拖动中的自动滚动。不用上游的滚动服务：编辑态关掉了上游自动滚动
  /// （光标揭示由 `DiaryEditorViewport` 负责），它的触发区也太大。
  late final DiaryEdgeAutoScrollDriver _autoScroll = DiaryEdgeAutoScrollDriver(
    _autoScrollStep,
  );

  /// 拿起的底板每帧重画一次：块的位置可能因预览移动或自动滚动而变，底板
  /// 在绘制阶段才读块的几何。
  final ValueNotifier<int> _liftedFrame = ValueNotifier(0);
  late final Ticker _dragTicker = createTicker((_) => _trackDrag());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.relay.start = _startGroupDrag;
    _bind();
  }

  void _bind() {
    final controller = widget.controller;
    final state = controller.state;
    state.selectionNotifier.addListener(_schedule);
    controller.blockSelection.active.addListener(_schedule);
    widget.focusNode?.addListener(_schedule);
    _transactions = state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after) _schedule();
    });
    _schedule();
  }

  void _unbind(DiaryBlockHandleLayer old) {
    old.controller.state.selectionNotifier.removeListener(_schedule);
    old.controller.blockSelection.active.removeListener(_schedule);
    old.focusNode?.removeListener(_schedule);
    _transactions?.cancel();
  }

  @override
  void didUpdateWidget(DiaryBlockHandleLayer old) {
    super.didUpdateWidget(old);
    if (old.relay != widget.relay) {
      if (old.relay.start == _startGroupDrag) old.relay.start = null;
      widget.relay.start = _startGroupDrag;
    }
    if (old.controller != widget.controller ||
        old.focusNode != widget.focusNode) {
      _unbind(old);
      _bind();
    }
  }

  @override
  void didChangeMetrics() => _schedule();

  @override
  void dispose() {
    _unbind(widget);
    if (widget.relay.start == _startGroupDrag) widget.relay.start = null;
    WidgetsBinding.instance.removeObserver(this);
    // 拖动中页面被移除（如返回）：撤掉全局路由，块放回原处。
    if (_dragPointer != null) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    }
    _session?.cancel();
    _autoScroll.stop();
    _dragTicker.dispose();
    _liftedFrame.dispose();
    super.dispose();
  }

  bool get _focused {
    final node = widget.focusNode;
    if (node != null) return node.hasFocus;
    return primaryFocus?.context
            ?.findAncestorWidgetOfExactType<af.AppFlowyEditor>()
            ?.editorState ==
        widget.controller.state;
  }

  /// 布局（滚动、键盘、文字变化、页头里建议条的收起动画）之后才有准确
  /// 几何：统一在帧尾计算。把手可见期间每帧结束都重新核对一次——帧尾回调
  /// 本身不请求新帧，界面静止时不产生任何开销，动画进行中则逐帧跟随。
  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _place();
      if (_placement != null) _schedule();
    });
  }

  void _place() {
    // 拖动中把手由 [_trackDrag] 逐帧摆放（跟着手指），不随选区换块。
    if (_session != null) return;
    _setPlacement(_computePlacement());
  }

  void _setPlacement(_HandlePlacement? next) {
    if (next?.node != _placement?.node ||
        (next?.center ?? Offset.zero) != (_placement?.center ?? Offset.zero)) {
      setState(() => _placement = next);
    }
  }

  _HandlePlacement? _computePlacement() {
    final controller = widget.controller;
    if (controller.isDisposed ||
        controller.readOnly ||
        controller.blockSelection.isActive ||
        !_focused) {
      return null;
    }
    final selection = controller.state.selection;
    if (selection == null || !selection.start.path.equals(selection.end.path)) {
      return null;
    }
    final node = controller.state.getNodeAtPath(selection.end.path);
    if (node == null) return null;
    // 光标在表格的格子里：把手属于整个表格（格子与格内段落不单独移动）。
    return _placementFor(diaryTableOf(node) ?? node);
  }

  /// [node] 首行那一行、页面左边距里的把手位置；块不在视口里时为 null。
  _HandlePlacement? _placementFor(af.Node node) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    if (node.rect == Rect.zero) return null;
    final y = box.globalToLocal(Offset(0, _geometry.centerY(node))).dy;
    // 滚出视口（被页头或底部浮层挡住的部分照常显示，交给上层裁切）。
    if (y < 0 || y > box.size.height) return null;
    final x = DiaryBlockLineGeometry.columnCenterX(
      widget.contentLeft,
      diaryBlockHandleWidth,
    );
    return _HandlePlacement(node, Offset(x, y));
  }

  /// 轻点把手：进入段落选择模式并选中这一块；记下软键盘此刻是否弹着
  /// （「完成」后据此决定是否重新弹出）。
  void _select(af.Node node) {
    final controller = widget.controller;
    if (controller.readOnly || node.parent == null) return;
    unawaited(HapticFeedback.selectionClick());
    controller.blockSelection.enter([
      node,
    ], keyboardVisible: View.of(context).viewInsets.bottom > 0);
  }

  // ---- 拖动 ----

  /// 段落选择模式里的长按：拖动选中的整组，落点跟着手指按着的 [held] 走。
  void _startGroupDrag(int pointer, Offset position, af.Node held) {
    final selection = widget.controller.blockSelection;
    if (!selection.isActive || selection.roots.isEmpty) return;
    _startDrag(
      selection.roots,
      pointer,
      position,
      fromHandle: false,
      held: held,
    );
  }

  /// 长按生效：从此按 [pointer] 跟踪这根手指，直到抬起或被系统取消。
  /// [held] 为手指按着的那一块（缺省为第一块）：落点按它首行的位移找。
  void _startDrag(
    List<af.Node> nodes,
    int pointer,
    Offset position, {
    required bool fromHandle,
    af.Node? held,
  }) {
    final box = context.findRenderObject();
    if (_session != null ||
        widget.controller.readOnly ||
        nodes.isEmpty ||
        box is! RenderBox ||
        !box.hasSize) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    GestureBinding.instance.pointerRouter.addGlobalRoute(_routePointer);
    _dragPointer = pointer;
    _pointer = position;
    final session = DiaryBlockDragSession(
      widget.controller,
      nodes,
      selection: fromHandle
          ? DiaryBlockMoveSelection.caretAtEnd
          : DiaryBlockMoveSelection.none,
    );
    _grabOffset = _geometry.centerY(held ?? session.nodes.first) - position.dy;
    final placement = _placement;
    _handleGrab = fromHandle && placement != null
        ? placement.center - box.globalToLocal(position)
        : null;
    setState(() => _session = session);
    unawaited(_dragTicker.start());
  }

  void _routePointer(PointerEvent event) {
    if (event.pointer != _dragPointer) return;
    if (event is PointerMoveEvent) {
      _pointer = event.position;
    } else if (event is PointerUpEvent) {
      _endDrag(commit: true);
    } else if (event is PointerCancelEvent) {
      _endDrag(commit: false);
    }
  }

  /// [commit] 为 false（指针被系统取消）时放回原处。松手时正文已经是预览
  /// 的样子，按它提交，不再按抬起时的位置另算。
  void _endDrag({required bool commit}) {
    final session = _session;
    if (session == null) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    _dragPointer = null;
    _pointer = null;
    _handleGrab = null;
    _dragTicker.stop();
    _autoScroll.stop();
    setState(() => _session = null);
    if (commit) {
      if (session.commit()) unawaited(HapticFeedback.lightImpact());
    } else {
      session.cancel();
    }
    _schedule();
  }

  /// 每帧按手指位置重算落点并预览：自动滚动时手指不动，内容仍在移动。
  void _trackDrag() {
    final session = _session;
    final pointer = _pointer;
    if (session == null || pointer == null || !mounted) return;
    final viewport = _viewport();
    var dy = pointer.dy + _grabOffset;
    if (viewport != null) {
      dy = dy.clamp(
        viewport.top + 1,
        math.max(viewport.top + 1, viewport.bottom - 1),
      );
    }
    final root = widget.controller.document.root;
    final destination = resolveDiaryBlockDrop(
      root,
      session.nodes,
      dy,
      depth: session.depth,
    );
    if (destination != null) {
      final list = viewport?.list;
      final (low, high) = diaryBlockMoveRange(session.nodes, destination);
      final anchor = list == null
          ? null
          : diaryBlockDragAnchor(
              root,
              low: low,
              high: high,
              viewportTop: list.top,
              viewportHeight: list.height,
              itemInset: widget.controller.state.editorStyle.padding.top,
            );
      if (session.preview(destination)) {
        if (anchor != null) widget.pinPath?.call(anchor.$1.path, anchor.$2);
        unawaited(HapticFeedback.selectionClick());
      }
    }
    _liftedFrame.value++;
    _autoScrollStep();
    // 长按把手时把手跟着手指上下走。
    final box = context.findRenderObject();
    final placement = _placement;
    final grab = _handleGrab;
    if (grab != null && placement != null && box is RenderBox) {
      final y = box.globalToLocal(pointer).dy + grab.dy;
      _setPlacement(
        _HandlePlacement(placement.node, Offset(placement.center.dx, y)),
      );
    }
  }

  /// 可见区域（全局纵坐标）：列表视口去掉底部被键盘与浮层盖住的部分；
  /// [list] 为列表视口本身，锚点比例按它算。
  ({double top, double bottom, ({double top, double height}) list})?
  _viewport() {
    final box = widget.controller.state.scrollableState?.context
        .findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    final view = View.of(context);
    final keyboardTop =
        (view.physicalSize.height - view.viewInsets.bottom) /
        view.devicePixelRatio;
    final bottom =
        math.min(top + box.size.height, keyboardTop) - widget.coveredHeight;
    return (
      top: top,
      bottom: bottom,
      list: (top: top, height: box.size.height),
    );
  }

  /// 块（手指位置加 [_grabOffset]）靠近可见区域上下 [kDiaryAutoScrollZone] 时
  /// 朝那一边自动滚动，越靠外越快；离开边缘即停（见 [DiaryEdgeAutoScrollDriver]）。
  void _autoScrollStep() {
    // 停下后滚动器还在途中的那一步会再回调一次。
    if (!mounted || _session == null) return;
    final finger = _pointer;
    final scrollable = widget.controller.state.scrollableState;
    final viewport = _viewport();
    if (finger == null || scrollable == null || viewport == null) return;
    final list = viewport.list;
    _autoScroll.update(
      scrollable,
      Offset(finger.dx, finger.dy + _grabOffset),
      visibleTop: viewport.top,
      visibleBottom: viewport.bottom,
      viewportTop: list.top,
      viewportBottom: list.top + list.height,
    );
  }

  /// 块（含子块）在本层的矩形，左边界按结构算（见
  /// [DiaryBlockLineGeometry.blockRect]）。
  Rect? _localBlockRect(af.Node node) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    return DiaryBlockLineGeometry.blockRect(
      node,
      box,
      contentLeft: widget.contentLeft,
      childIndent: widget.childIndent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final placement = _placement;
    final session = _session;
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _schedule();
        return false;
      },
      child: CustomPaint(
        painter: session == null
            ? null
            : _LiftedBlockPainter(
                rects: () => [
                  for (final node in session.nodes) ?_localBlockRect(node),
                ],
                color: colors.surfaceContainerHigh,
                repaint: _liftedFrame,
              ),
        // 子层都带 key：把手出现或消失时不按位置复用元素，编辑器不会被
        // 重建。
        child: Stack(
          children: [
            KeyedSubtree(
              key: const ValueKey('editor'),
              child: DiaryBlockSelectionLayer(
                controller: widget.controller,
                relay: widget.relay,
                geometry: _geometry,
                focusNode: widget.focusNode,
                contentLeft: widget.contentLeft,
                childIndent: widget.childIndent,
                coveredHeight: widget.coveredHeight,
                pinPath: widget.pinPath,
                revealPath: widget.revealPath,
                child: widget.child,
              ),
            ),
            if (placement != null)
              Positioned(
                key: const ValueKey('handle'),
                left:
                    placement.center.dx -
                    diaryBlockHandleWidth / 2 -
                    diaryBlockHandleHitSlop.left,
                top:
                    placement.center.dy -
                    diaryBlockHandleHeight / 2 -
                    diaryBlockHandleHitSlop.top,
                child: DiaryBlockHandle(
                  key: ObjectKey(placement.node),
                  dragging: session != null,
                  onTap: () => _select(placement.node),
                  onDragStart: (pointer, position) => _startDrag(
                    [placement.node],
                    pointer,
                    position,
                    fromHandle: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 被拖的块下面衬一块 12dp 圆角底（左右各多出 8dp），表示“拿在手里”。
/// 画在正文之下，不盖住文字；在绘制阶段才读块的几何——块挪到新位置的
/// 那一帧布局已经更新，底板与文字同帧到位，不会在旧位置多留一帧。
class _LiftedBlockPainter extends CustomPainter {
  _LiftedBlockPainter({
    required this.rects,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<Rect> Function() rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final paint = Paint()..color = color;
    for (final block in rects()) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            block.left - 8,
            block.top,
            block.right + 8,
            block.bottom,
          ),
          const Radius.circular(12),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiftedBlockPainter old) =>
      old.color != color || old.rects != rects;
}
