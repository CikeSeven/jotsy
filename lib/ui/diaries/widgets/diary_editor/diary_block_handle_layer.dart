import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_block_handle.dart';
import 'diary_block_marker_metrics.dart';

/// 编辑态的段落把手：整篇正文只有一个，浮在光标所在块的首行左侧。
///
/// 为什么不给每个块各包一个把手：常驻的把手满屏都是，正文还要让出 24dp
/// 沟槽，与标题对不齐、嵌套块缩进翻倍。这一层叠在编辑器之上，不改变任何
/// 块的布局：
/// - 位置：光标所在块（嵌套时为最内层的块）首行的字形中线（与行首标记同一
///   口径，见 [_DiaryBlockHandleLayerState._firstLineCenter]），水平落在块
///   左侧——顶层块在页面左边距里，子块在父块的缩进里。选区跨块、没有焦点或
///   块滚出视口时隐藏；出现时 `fast` 淡入。
/// - 点按：Expressive 菜单上移 / 拖动段落 / 下移（见 [DiaryBlockHandle]）。
/// - 长按把手或菜单里的“拖动段落”：拖动整棵子树。落点随手指逐帧计算（自动
///   滚动时手指不动也会变），以 2dp `primary` 线标在目标块上沿或下沿；不能
///   落到自身及后代上。原块盖一层半透明页面底色表示“已拿起”，把手留在原块
///   上、随它滚动（滚出视口时隐藏）。松手经 [moveDiaryEditorBlock] 一次事务
///   完成，可撤销。
/// - 拖动由本层直接跟踪指针（全局指针路由），跟手卡片经 [OverlayPortal]
///   画在页面浮层里，不用 `Draggable`：菜单项在长按生效时随菜单收起而卸载，
///   `Draggable` 的回调绑在它自己的元素上，卸载后全部丢失。全局路由与发起
///   拖动的组件无关，两个入口因此共用同一条链路。
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
  });

  final DiaryEditorController controller;
  final FocusNode? focusNode;
  final Widget child;

  /// 编辑器的左内边距（页面左边距）：顶层块的左边界。
  final double contentLeft;

  /// 子块相对父块的缩进（编辑器块配置的 indentPadding，即行首标记列宽）。
  final double childIndent;

  @override
  State<DiaryBlockHandleLayer> createState() => _DiaryBlockHandleLayerState();
}

/// 跟手卡片左上角相对手指的位置：浮在手指右上方，落点线就在手指所在的
/// 块边上，不能被盖住。
const Offset _feedbackOffset = Offset(12, -84);

class _HandlePlacement {
  const _HandlePlacement(this.node, this.center);

  final af.Node node;

  /// 把手中心，本层的局部坐标。
  final Offset center;
}

class _DropTarget {
  const _DropTarget(this.destination, this.line);

  /// 移动前的树里的目标路径（见 [moveDiaryEditorBlock]）。
  final af.Path destination;

  /// 落点线：本层局部坐标，左端、宽度与竖直位置。
  final Rect line;
}

class _DiaryBlockHandleLayerState extends State<DiaryBlockHandleLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<af.EditorTransactionValue>? _transactions;
  bool _scheduled = false;
  _HandlePlacement? _placement;

  /// 按块样式与缩放缓存的首行字形中心（到文字顶端的距离）：把手可见期间
  /// 每帧都要核对位置，样式只在换块或改排版时才变。
  final Map<(TextStyle, TextScaler), double> _glyphCenters = {};

  // ---- 拖动状态 ----
  af.Node? _dragging;

  /// 正在跟踪的指针；非 null 期间全局指针路由已登记。
  int? _dragPointer;
  String _dragLabel = '';

  /// 手指的全局位置：驱动落点计算与跟手卡片（卡片只随它重建）。
  final ValueNotifier<Offset?> _pointer = ValueNotifier(null);
  final OverlayPortalController _feedback = OverlayPortalController();
  _DropTarget? _target;
  Rect? _sourceRect;
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
    // 拖动中页面被移除（如返回）：撤掉全局路由，不再提交落点。
    if (_dragPointer != null) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    }
    _dragTicker.dispose();
    _pointer.dispose();
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
    // 拖动中把手只跟着原块走（[_trackDrag] 逐帧更新），不随选区换块。
    if (_dragging != null) return;
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

  /// [node] 首行左侧的把手位置；块不在视口里时为 null。
  _HandlePlacement? _placementFor(af.Node node) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final rect = node.rect;
    if (rect == Rect.zero) return null;
    final centerY =
        _firstLineCenter(node) ?? rect.top + math.min(rect.height / 2, 20);
    final local = box.globalToLocal(Offset(rect.left, centerY));
    final left = _blockLeft(node, box, fallback: local.dx);
    final center = Offset(left - diaryBlockHandleWidth / 2, local.dy);
    // 滚出视口（被页头或底部浮层挡住的部分照常显示，交给上层裁切）。
    if (center.dy < 0 || center.dy > box.size.height) return null;
    return _HandlePlacement(node, Offset(math.max(center.dx, 8), center.dy));
  }

  /// 块的左边界（本层局部坐标），按结构算：顶层块为页面左边距，子块为
  /// 父块左边界加缩进。代码块等组件的节点几何只覆盖内部文字区（行号
  /// 右侧），直接取它的 left 会把把手与落点线压进块里面。
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
  void _startDrag(af.Node node, int pointer, Offset position) {
    if (_dragging != null || widget.controller.readOnly) return;
    HapticFeedback.mediumImpact();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_routePointer);
    _dragPointer = pointer;
    _pointer.value = position;
    final text = node.delta?.toPlainText().trim() ?? '';
    setState(() {
      _dragging = node;
      _dragLabel = text.isEmpty ? context.l10n.diaryEditorDragBlock : text;
      _target = null;
      _sourceRect = _localBlockRect(node);
    });
    _feedback.show();
    _dragTicker.start();
  }

  void _routePointer(PointerEvent event) {
    if (event.pointer != _dragPointer) return;
    if (event is PointerMoveEvent) {
      _pointer.value = event.position;
      widget.controller.state.scrollService?.startAutoScroll(event.position);
    } else if (event is PointerUpEvent) {
      _endDrag(commit: true);
    } else if (event is PointerCancelEvent) {
      _endDrag(commit: false);
    }
  }

  /// [commit] 为 false（指针被系统取消）时只放下、不移动。
  void _endDrag({required bool commit}) {
    final source = _dragging;
    if (source == null) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    _dragPointer = null;
    _dragTicker.stop();
    widget.controller.state.scrollService?.stopAutoScroll();
    _feedback.hide();
    // 按抬起时的位置重算：最后一次移动与抬起可能落在同一帧里，还没轮到
    // 逐帧计算。
    final pointer = _pointer.value;
    final target = commit && pointer != null
        ? _resolveTarget(source, pointer)
        : null;
    _pointer.value = null;
    setState(() {
      _dragging = null;
      _target = null;
      _sourceRect = null;
    });
    if (target != null &&
        moveDiaryEditorBlock(widget.controller, source, target.destination)) {
      HapticFeedback.lightImpact();
    }
    _schedule();
  }

  /// 每帧按手指位置重算落点：自动滚动时手指不动，内容仍在移动。
  void _trackDrag() {
    final source = _dragging;
    final pointer = _pointer.value;
    if (source == null || !mounted) return;
    final target = pointer == null ? null : _resolveTarget(source, pointer);
    final sourceRect = _localBlockRect(source);
    if (target?.line != _target?.line || sourceRect != _sourceRect) {
      setState(() {
        _target = target;
        _sourceRect = sourceRect;
      });
    }
    // 把手随原块滚动；滚出视口即移除，拖动由全局指针路由跟踪，不受影响。
    _setPlacement(_placementFor(source));
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

  /// 找手指所在的块（嵌套时取最内层），按上下半区决定落在它之前还是之后。
  /// 带子块的块只能落在它之前：它“之后”的位置由下一个同级块的上沿给出。
  _DropTarget? _resolveTarget(af.Node source, Offset pointer) {
    final root = widget.controller.state.document.root;
    final hit =
        _hitBlock(root.children, pointer.dy) ?? _edgeBlock(root, pointer);
    if (hit == null) return null;
    if (hit == source || source.isParentOf(hit)) return null;
    final rect = hit.rect;
    final ownBottom = hit.children.isEmpty
        ? rect.bottom
        : _firstVisibleTop(hit.children) ?? rect.bottom;
    final after =
        hit.children.isEmpty && pointer.dy >= (rect.top + ownBottom) / 2;
    final block = _localBlockRect(hit);
    if (block == null) return null;
    final edge = after ? block.bottom : block.top;
    final local = Rect.fromLTRB(
      block.left - 4,
      edge - 1,
      block.right,
      edge + 1,
    );
    final destination = after ? hit.path.next : hit.path;
    // 落在自己紧邻的前后位置等于没动：不画线。
    final sourcePath = source.path;
    if (destination.equals(sourcePath) || destination.equals(sourcePath.next)) {
      return null;
    }
    return _DropTarget(destination, local);
  }

  af.Node? _hitBlock(Iterable<af.Node> nodes, double dy) {
    for (final node in nodes) {
      final rect = node.rect;
      if (rect == Rect.zero || dy < rect.top || dy >= rect.bottom) continue;
      return _hitBlock(node.children, dy) ?? node;
    }
    return null;
  }

  double? _firstVisibleTop(Iterable<af.Node> nodes) {
    for (final node in nodes) {
      final rect = node.rect;
      if (rect != Rect.zero) return rect.top;
    }
    return null;
  }

  /// 手指在全部可见块的上方或下方（页头、末尾留白）：落到最近的顶层块。
  af.Node? _edgeBlock(af.Node root, Offset pointer) {
    af.Node? first;
    af.Node? last;
    for (final node in root.children) {
      if (node.rect == Rect.zero) continue;
      first ??= node;
      last = node;
    }
    if (first == null || last == null) return null;
    return pointer.dy < first.rect.top ? first : last;
  }

  @override
  Widget build(BuildContext context) {
    final placement = _placement;
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _schedule();
        return false;
      },
      child: OverlayPortal(
        controller: _feedback,
        overlayChildBuilder: _buildFeedback,
        // 子层都带 key：拖动开始时淡化层插在把手之前，不带 key 会按位置把
        // 把手的元素复用给淡化层，把手连同它的菜单被重建。
        child: Stack(
          children: [
            KeyedSubtree(key: const ValueKey('editor'), child: widget.child),
            if (_sourceRect case final rect?)
              Positioned.fromRect(
                key: const ValueKey('source'),
                rect: rect,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: colors.surface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (_target case final target?)
              Positioned.fromRect(
                key: const ValueKey('target'),
                rect: target.line,
                child: IgnorePointer(
                  child: DiaryBlockDropLine(color: colors.primary),
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
                  node: placement.node,
                  controller: widget.controller,
                  dragging: _dragging != null,
                  onDragStart: (pointer, position) =>
                      _startDrag(placement.node, pointer, position),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 跟手卡片铺在页面浮层里（不被正文区域裁切），只随手指位置重建。
  Widget _buildFeedback(BuildContext context) {
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    return IgnorePointer(
      child: ValueListenableBuilder<Offset?>(
        valueListenable: _pointer,
        builder: (context, pointer, _) {
          if (pointer == null) return const SizedBox.shrink();
          final local = overlay is RenderBox && overlay.hasSize
              ? overlay.globalToLocal(pointer)
              : pointer;
          final at = local + _feedbackOffset;
          return Stack(
            children: [
              Positioned(
                left: at.dx,
                top: at.dy,
                child: DiaryBlockDragFeedback(text: _dragLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}
