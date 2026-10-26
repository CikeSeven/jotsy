import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_block_drop_targets.dart';
import 'diary_block_handle.dart';
import 'diary_block_marker_metrics.dart';

/// 编辑态的段落把手：整篇正文只有一个，浮在光标所在块的首行左侧。
///
/// 为什么不给每个块各包一个把手：常驻的把手满屏都是，正文还要让出 24dp
/// 沟槽，与标题对不齐、嵌套块缩进翻倍。这一层叠在编辑器之上，不改变任何
/// 块的布局：
/// - 位置：光标所在块（嵌套时为最内层的块）首行的字形中线（与行首标记同一
///   口径，见 [_DiaryBlockHandleLayerState._firstLineCenter]），水平固定在
///   页面左边距里，不随缩进右移：缩进的块也在同一竖列找到把手，把手不会
///   挤进上一级的行首标记列。选区跨块、没有焦点或块滚出视口时隐藏；出现时
///   `fast` 淡入。
/// - 点按：Expressive 菜单上移 / 长按拖动 / 下移（见 [DiaryBlockHandle]）。
/// - 长按把手或菜单里的“长按拖动”：拖动整棵子树，实时预览——落点随手指
///   逐帧计算（自动滚动时手指不动也会变），保持拖动开始时的缩进层级（见
///   [resolveDiaryBlockDrop]），一变就经 [DiaryBlockDragSession]
///   把块真的挪过去，正文即是松手后的样子；不能落到自身及后代上。被拖的块
///   衬一块圆角底表示“拿在手里”。松手只记一步撤销；指针被系统取消时放回
///   原处。
/// - 手里拿着的东西跟着手指走：长按把手时是把手（只随手指上下）；从菜单
///   发起时菜单收起，“长按拖动”这一项变成跟手的拖动条
///   （[DiaryBlockDragChip]，经 [OverlayPortal] 画在页面浮层里），把手隐去。
/// - 落点按手指的位移找（见 [_DiaryBlockHandleLayerState._grabOffset]），
///   并夹在可见区域里；块不会在开始拖动的瞬间跳到手指下面，也不会挪到
///   视口外还建着的缓存块那里。块靠近可见区域上下 48dp 时自动滚动。
/// - 每次预览移动后经 [DiaryBlockHandleLayer.pinPath] 让列表以一个不受影响
///   的块为锚点停在原处（见 [diaryBlockDragAnchor]），整页不会错开。
/// - 拖动由本层直接跟踪指针（全局指针路由），不用 `Draggable`：拖动途中
///   把手可能随块滚出视口而卸载，`Draggable` 的回调绑在它自己的元素上，
///   卸载后全部丢失。全局路由与发起拖动的组件无关，两个入口共用同一条链路。
///
/// 输入：编辑控制器与焦点；输出：只读写选区与块位置事务，没有其他副作用。
class DiaryBlockHandleLayer extends StatefulWidget {
  const DiaryBlockHandleLayer({
    super.key,
    required this.controller,
    required this.child,
    this.focusNode,
    this.contentLeft = 0,
    this.childIndent = 28,
    this.coveredHeight = 0,
    this.pinPath,
  });

  final DiaryEditorController controller;
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

  @override
  State<DiaryBlockHandleLayer> createState() => _DiaryBlockHandleLayerState();
}

class _HandlePlacement {
  const _HandlePlacement(this.node, this.center);

  final af.Node node;

  /// 把手中心，本层的局部坐标。
  final Offset center;
}

/// 块进入可见区域上下这么近时自动滚动。
const double _autoScrollZone = 48;

/// 自动滚动速度：每步最多 20px、用时 1000 / 它 毫秒，即最快约 400px/s。
const double _autoScrollVelocity = 20;

class _DiaryBlockHandleLayerState extends State<DiaryBlockHandleLayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<af.EditorTransactionValue>? _transactions;
  bool _scheduled = false;
  _HandlePlacement? _placement;

  /// 按块样式与缩放缓存的首行字形中心（到文字顶端的距离）：把手可见期间
  /// 每帧都要核对位置，样式只在换块或改排版时才变。
  final Map<(TextStyle, TextScaler), double> _glyphCenters = {};

  // ---- 拖动状态 ----
  DiaryBlockDragSession? _session;

  /// 正在跟踪的指针；非 null 期间全局指针路由已登记。
  int? _dragPointer;

  /// 手指的全局位置。
  Offset? _pointer;

  /// 把手中线（[_handleCenterY]）减去手指的纵坐标，开始拖动时量好：落点按
  /// “手指位置 + 它”找，即跟随手指的位移而不是绝对位置。从把手发起时接近
  /// 0；从菜单发起时手指在块下方几行，按绝对位置找，手指一动块就会跳过去。
  double _grabOffset = 0;

  /// 长按把手时：把手中心减去手指（本层局部坐标），把手据此跟着手指走。
  Offset _handleGrab = Offset.zero;

  /// 从菜单发起时：“长按拖动”这一项开始时的全局矩形；拖动条的左上角为
  /// 手指位置加 [_chipGrab]。null 表示不是从菜单发起。
  Rect? _chipItem;
  Offset _chipGrab = Offset.zero;

  /// 拖动条里那一项的宽度：松手后淡出期间 [_chipItem] 已清空，仍按它画。
  double _chipWidth = 0;
  final OverlayPortalController _chip = OverlayPortalController();

  /// 拖动中的自动滚动。不用上游的滚动服务：编辑态关掉了上游自动滚动
  /// （光标揭示由 `DiaryEditorViewport` 负责），它的触发区也太大。
  EdgeDraggingAutoScroller? _autoScroller;

  /// 拖动条左上角（全局）：拖动条只随它重建。
  final ValueNotifier<Offset> _chipAt = ValueNotifier(Offset.zero);

  /// 拖动条的显隐：拿起时直接为 1（接替菜单里那一项，不能闪），松手后
  /// 淡出。玻璃表面只能经它的 reveal 渐隐，不能放进透明度层。
  late final AnimationController _chipReveal = AnimationController(
    vsync: this,
    value: 0,
  );
  late final CurvedAnimation _chipCurve = CurvedAnimation(
    parent: _chipReveal,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );

  /// 拿起的底板每帧重画一次：块的位置可能因预览移动或自动滚动而变，底板
  /// 在绘制阶段才读块的几何。
  final ValueNotifier<int> _liftedFrame = ValueNotifier(0);
  late final Ticker _dragTicker = createTicker((_) => _trackDrag());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  void _bind() {
    final state = widget.controller.state;
    state.selectionNotifier.addListener(_schedule);
    widget.focusNode?.addListener(_schedule);
    _transactions = state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after) _schedule();
    });
    _schedule();
  }

  void _unbind(DiaryBlockHandleLayer old) {
    old.controller.state.selectionNotifier.removeListener(_schedule);
    old.focusNode?.removeListener(_schedule);
    _transactions?.cancel();
  }

  @override
  void didUpdateWidget(DiaryBlockHandleLayer old) {
    super.didUpdateWidget(old);
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
    WidgetsBinding.instance.removeObserver(this);
    // 拖动中页面被移除（如返回）：撤掉全局路由，块放回原处。
    if (_dragPointer != null) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    }
    _session?.cancel();
    _autoScroller?.stopAutoScroll();
    _dragTicker.dispose();
    _liftedFrame.dispose();
    _chipAt.dispose();
    _chipCurve.dispose();
    _chipReveal.dispose();
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
    // 拖动中把手由 [_trackDrag] 逐帧摆放（跟着手指）或停在原处隐去，不随
    // 选区换块。
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
    if (controller.isDisposed || controller.readOnly || !_focused) return null;
    final selection = controller.state.selection;
    if (selection == null || !selection.start.path.equals(selection.end.path)) {
      return null;
    }
    final node = controller.state.getNodeAtPath(selection.end.path);
    return node == null ? null : _placementFor(node);
  }

  /// [node] 首行那一行、页面左边距里的把手位置；块不在视口里时为 null。
  _HandlePlacement? _placementFor(af.Node node) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    if (node.rect == Rect.zero) return null;
    final y = box.globalToLocal(Offset(0, _handleCenterY(node))).dy;
    // 滚出视口（被页头或底部浮层挡住的部分照常显示，交给上层裁切）。
    if (y < 0 || y > box.size.height) return null;
    final x = math.max(widget.contentLeft - diaryBlockHandleWidth / 2, 8.0);
    return _HandlePlacement(node, Offset(x, y));
  }

  /// 把手中线的全局纵坐标：文字块为首行字形中心，媒体等没有文字的块为
  /// 块顶下方 20dp（矮于 40dp 时取块的中线）。
  double _handleCenterY(af.Node node) {
    final rect = node.rect;
    return _firstLineCenter(node) ?? rect.top + math.min(rect.height / 2, 20);
  }

  /// 块的左边界（本层局部坐标），按结构算：顶层块为页面左边距，子块为
  /// 父块左边界加缩进。代码块等组件的节点几何只覆盖内部文字区（行号
  /// 右侧），直接取它的 left 会把拿起的底板压进块里面。
  double _blockLeft(af.Node node, RenderBox box, {required double fallback}) {
    final parent = node.parent;
    if (parent == null || parent.type == af.PageBlockKeys.type) {
      return widget.contentLeft;
    }
    final parentRect = parent.rect;
    return parentRect == Rect.zero
        ? fallback
        : box.globalToLocal(parentRect.topLeft).dx + widget.childIndent;
  }

  /// 文字块首行字形中心的全局纵坐标：基线上方 0.37em，与列表圆点、待办框
  /// 同一口径（见 [DiaryMarkerMetrics]）。媒体等没有文字的块返回 null。
  ///
  /// 为什么不取首行光标矩形的中线：正文首行上方的半个行距被裁掉、下方的
  /// 保留（`kDiaryTextHeightBehavior`），多行段落的首行光标比文字多出下方
  /// 半个行距，中线偏低，行距越大偏得越多。这里改读块里的占位文字段落——
  /// 它带着与正文相同的块样式（标题字号、代码字体）与缩放，叠在正文同一
  /// 位置，首行顶端就是文字顶端——按它的样式量出字形中心。
  double? _firstLineCenter(af.Node node) {
    if (node.delta == null) return null;
    final paragraph = _placeholderParagraph(node);
    final style = paragraph?.text.style;
    if (paragraph == null || style == null || !paragraph.hasSize) return null;
    final scaler = paragraph.textScaler;
    final center = _glyphCenters.putIfAbsent((style, scaler), () {
      if (_glyphCenters.length >= 16) _glyphCenters.clear();
      return DiaryMarkerMetrics.measure(style, scaler).glyphCenter;
    });
    return paragraph.localToGlobal(Offset(0, center)).dy;
  }

  /// 块自身文字的占位段落：块里第一个 [af.AppFlowyRichText]（子块排在自身
  /// 文字之后）中的第一个 [RichText]——上游先画占位、再画正文。
  static RenderParagraph? _placeholderParagraph(af.Node node) {
    final root = node.key.currentContext;
    if (root is! Element) return null;
    Element? richText;
    void findRichText(Element element) {
      if (richText != null) return;
      if (element.widget is af.AppFlowyRichText) {
        richText = element;
      } else {
        element.visitChildElements(findRichText);
      }
    }

    RenderParagraph? paragraph;
    void findParagraph(Element element) {
      if (paragraph != null) return;
      final object = element.renderObject;
      if (element.widget is RichText && object is RenderParagraph) {
        paragraph = object;
      } else {
        element.visitChildElements(findParagraph);
      }
    }

    findRichText(root);
    richText?.visitChildElements(findParagraph);
    return paragraph;
  }

  // ---- 拖动 ----

  /// 长按生效：从此按 [pointer] 跟踪这根手指，直到抬起或被系统取消。
  /// [menuItem] 非空表示从菜单发起，见 [DiaryBlockDragStart]。
  void _startDrag(
    af.Node node,
    int pointer,
    Offset position, {
    Rect? menuItem,
  }) {
    final box = context.findRenderObject();
    if (_session != null ||
        widget.controller.readOnly ||
        box is! RenderBox ||
        !box.hasSize) {
      return;
    }
    HapticFeedback.mediumImpact();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_routePointer);
    _dragPointer = pointer;
    _pointer = position;
    _grabOffset = _handleCenterY(node) - position.dy;
    final placement = _placement;
    _handleGrab = placement == null
        ? Offset.zero
        : placement.center - box.globalToLocal(position);
    _chipItem = menuItem;
    if (menuItem != null) {
      _chipGrab = menuItem.topLeft - position;
      _chipWidth = menuItem.width;
      _chipAt.value = menuItem.topLeft;
      _chipReveal.value = 1;
      _chip.show();
    }
    setState(() => _session = DiaryBlockDragSession(widget.controller, node));
    _dragTicker.start();
  }

  void _routePointer(PointerEvent event) {
    if (event.pointer != _dragPointer) return;
    if (event is PointerMoveEvent) {
      _pointer = event.position;
      if (_chipItem != null) _chipAt.value = event.position + _chipGrab;
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
    _dragTicker.stop();
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    setState(() => _session = null);
    if (commit) {
      if (session.commit()) HapticFeedback.lightImpact();
    } else {
      session.cancel();
    }
    if (_chipItem != null) {
      _chipItem = null;
      _chipReveal.duration = ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      );
      // 淡出途中又从菜单拿起：value 被直接设回 1，这次的 future 不再完成。
      _chipReveal.reverse().whenComplete(() {
        if (mounted && _chipItem == null) _chip.hide();
      });
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
      session.node,
      dy,
      depth: session.depth,
    );
    if (destination != null) {
      final list = viewport?.list;
      final anchor = list == null
          ? null
          : diaryBlockDragAnchor(
              root,
              from: session.node.path,
              destination: destination,
              viewportTop: list.top,
              viewportHeight: list.height,
              itemInset: widget.controller.state.editorStyle.padding.top,
            );
      if (session.preview(destination)) {
        if (anchor != null) widget.pinPath?.call(anchor.$1.path, anchor.$2);
        HapticFeedback.selectionClick();
      }
    }
    _liftedFrame.value++;
    _autoScroll();
    // 长按把手时把手跟着手指上下走；从菜单发起时它停在原处隐去（正在收起
    // 的菜单以它为锚点）。
    final box = context.findRenderObject();
    final placement = _placement;
    if (_chipItem == null && placement != null && box is RenderBox) {
      final y = box.globalToLocal(pointer).dy + _handleGrab.dy;
      _setPlacement(
        _HandlePlacement(session.node, Offset(placement.center.dx, y)),
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

  /// 块（手指位置加 [_grabOffset]）靠近可见区域上下 [_autoScrollZone] 时
  /// 朝那一边自动滚动，越靠外越快；离开边缘即停。每帧（[_trackDrag]）与
  /// 滚动器每滚一步都按当前位置重新给一次目标，手指不动也接着滚：预览移动
  /// 后列表换锚点、滚动范围要到下一次布局才更新，滚动器若恰在这时判断
  /// “滚不动了”会自己停下，只靠它自己的回调接不上。
  void _autoScroll() {
    // 停下后滚动器还在途中的那一步会再回调一次。
    if (!mounted || _session == null) return;
    final finger = _pointer;
    final scrollable = widget.controller.state.scrollableState;
    final viewport = _viewport();
    if (finger == null || scrollable == null || viewport == null) return;
    final x = finger.dx;
    final y = finger.dy + _grabOffset;
    final list = viewport.list;
    // 拖动目标矩形越出视口边多少就滚多少：向上量 [_autoScrollZone]，向下
    // 还要越过被盖住的部分才碰到视口底边。
    final Rect? target = y < viewport.top + _autoScrollZone
        ? Rect.fromLTRB(x, y - _autoScrollZone, x + 1, y)
        : y > viewport.bottom - _autoScrollZone
        ? Rect.fromLTRB(
            x,
            y,
            x + 1,
            y + _autoScrollZone + list.top + list.height - viewport.bottom,
          )
        : null;
    if (target == null) {
      _autoScroller?.stopAutoScroll();
      return;
    }
    final scroller = _autoScroller ??= EdgeDraggingAutoScroller(
      scrollable,
      onScrollViewScrolled: _autoScroll,
      velocityScalar: _autoScrollVelocity,
    );
    scroller.startAutoScrollIfNecessary(target);
  }

  /// 块（含子块）在本层的矩形，左边界按 [_blockLeft]。
  Rect? _localBlockRect(af.Node node) {
    final global = node.rect;
    final box = context.findRenderObject();
    if (global == Rect.zero || box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(global.topLeft) & global.size;
    final left = math.min(
      local.left,
      _blockLeft(node, box, fallback: local.left),
    );
    return Rect.fromLTRB(left, local.top, local.right, local.bottom);
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
      child: OverlayPortal(
        controller: _chip,
        overlayChildBuilder: _buildChip,
        child: CustomPaint(
          painter: session == null
              ? null
              : _LiftedBlockPainter(
                  rect: () => _localBlockRect(session.node),
                  color: colors.surfaceContainerHigh,
                  repaint: _liftedFrame,
                ),
          // 子层都带 key：把手出现或消失时不按位置复用元素，把手连同它的
          // 菜单不会被重建。
          child: Stack(
            children: [
              KeyedSubtree(key: const ValueKey('editor'), child: widget.child),
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
                    node: placement.node,
                    controller: widget.controller,
                    dragging: session != null,
                    hidden: session != null && _chipItem != null,
                    onDragStart: (pointer, position, {menuItem}) => _startDrag(
                      placement.node,
                      pointer,
                      position,
                      menuItem: menuItem,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 跟手的拖动条铺在页面浮层里（不被正文区域裁切），只随手指位置重建。
  Widget _buildChip(BuildContext context) {
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    return ValueListenableBuilder<Offset>(
      valueListenable: _chipAt,
      builder: (context, at, child) {
        final local = overlay is RenderBox && overlay.hasSize
            ? overlay.globalToLocal(at)
            : at;
        const inset = DiaryBlockDragChip.padding;
        return Stack(
          children: [
            Positioned(
              left: local.dx - inset,
              top: local.dy - inset,
              child: child!,
            ),
          ],
        );
      },
      child: DiaryBlockDragChip(width: _chipWidth, reveal: _chipCurve),
    );
  }
}

/// 被拖的块下面衬一块 12dp 圆角底（左右各多出 8dp），表示“拿在手里”。
/// 画在正文之下，不盖住文字；在绘制阶段才读块的几何——块挪到新位置的
/// 那一帧布局已经更新，底板与文字同帧到位，不会在旧位置多留一帧。
class _LiftedBlockPainter extends CustomPainter {
  _LiftedBlockPainter({
    required this.rect,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Rect? Function() rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final block = rect();
    if (block == null) return;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            block.left - 8,
            block.top,
            block.right + 8,
            block.bottom,
          ),
          const Radius.circular(12),
        ),
        Paint()..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LiftedBlockPainter old) =>
      old.color != color || old.rect != rect;
}
