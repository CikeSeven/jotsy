import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_effects.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';

/// 编辑态的段落把手：整篇正文只有一个，浮在光标所在块的首行左侧。
///
/// 为什么不给每个块各包一个把手：常驻的把手满屏都是，正文还要让出 24dp
/// 沟槽，与标题对不齐、嵌套块缩进翻倍。这一层叠在编辑器之上，不改变任何
/// 块的布局：
/// - 位置：光标所在块（嵌套时为最内层的块）首行的垂直中线，水平落在块
///   左侧——顶层块在页面左边距里，子块在父块的缩进里。选区跨块、没有焦点或
///   块滚出视口时隐藏；出现时 `fast` 淡入。
/// - 点按：Expressive 菜单上移 / 下移（同级相邻位置）。
/// - 长按：拖动整棵子树。落点随手指逐帧计算（自动滚动时手指不动也会变），
///   以 2dp `primary` 线标在目标块上沿或下沿；不能落到自身及后代上。原块
///   盖一层半透明页面底色表示“已拿起”。松手经 [moveDiaryEditorBlock] 一次
///   事务完成，可撤销。
///
/// 输入：编辑控制器与焦点；输出：只读写选区与块位置事务，没有其他副作用。
class DiaryBlockHandleLayer extends StatefulWidget {
  const DiaryBlockHandleLayer({
    super.key,
    required this.controller,
    required this.child,
    this.focusNode,
    this.contentLeft = 0,
  });

  final DiaryEditorController controller;
  final FocusNode? focusNode;
  final Widget child;

  /// 编辑器的左内边距（页面左边距）：顶层块的左边界。
  final double contentLeft;

  @override
  State<DiaryBlockHandleLayer> createState() => _DiaryBlockHandleLayerState();
}

/// 子块相对父块的缩进（编辑器块配置的默认 indentPadding）。
const double _childIndent = 24;

/// 把手的可见尺寸：竖向小胶囊，宽 16 正好放进 16dp 的页面左边距。
const double _handleWidth = 16;
const double _handleHeight = 26;

/// 触控区域比可见尺寸大：左侧外扩 8dp、上下各 4dp；右侧只外扩 2dp——再多
/// 就压住正文开头，点行首放光标会误触把手。
const EdgeInsets _handleHitSlop = EdgeInsets.fromLTRB(8, 4, 2, 4);

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

  // ---- 拖动状态 ----
  af.Node? _dragging;
  Offset? _pointer;
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
    _dragTicker.dispose();
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
    // 拖动中把手保持在原块上，保证拖动手势所在的组件不被移除。
    if (_dragging != null) return;
    final next = _computePlacement();
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
    final box = context.findRenderObject();
    if (node == null || box is! RenderBox || !box.hasSize) return null;
    final rect = node.rect;
    if (rect == Rect.zero) return null;
    final firstLine = _firstLineRect(node);
    final centerY = firstLine != null
        ? firstLine.center.dy
        : rect.top + math.min(rect.height / 2, 20);
    final local = box.globalToLocal(Offset(rect.left, centerY));
    final left = _blockLeft(node, box, fallback: local.dx);
    final center = Offset(left - _handleWidth / 2, local.dy);
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
        : box.globalToLocal(parentRect.topLeft).dx + _childIndent;
  }

  /// 文字块首行光标的全局矩形；媒体等没有文字的块返回 null。
  Rect? _firstLineRect(af.Node node) {
    if (node.delta == null) return null;
    final selectable = node.selectable;
    final rect = selectable?.getCursorRectInPosition(
      af.Position(path: node.path),
      shiftWithBaseOffset: true,
    );
    if (selectable == null || rect == null) return null;
    return selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true);
  }

  // ---- 拖动 ----

  void _startDrag(af.Node node) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragging = node;
      _target = null;
      _sourceRect = _localBlockRect(node);
    });
    _dragTicker.start();
  }

  void _updateDrag(Offset global) {
    _pointer = global;
    widget.controller.state.scrollService?.startAutoScroll(global);
  }

  void _endDrag() {
    _dragTicker.stop();
    widget.controller.state.scrollService?.stopAutoScroll();
    final source = _dragging;
    final target = _target;
    setState(() {
      _dragging = null;
      _pointer = null;
      _target = null;
      _sourceRect = null;
    });
    if (source != null &&
        target != null &&
        moveDiaryEditorBlock(widget.controller, source, target.destination)) {
      HapticFeedback.lightImpact();
    }
    _schedule();
  }

  /// 每帧按手指位置重算落点：自动滚动时手指不动，内容仍在移动。
  void _trackDrag() {
    final source = _dragging;
    final pointer = _pointer;
    if (source == null || !mounted) return;
    final target = pointer == null ? null : _resolveTarget(source, pointer);
    final sourceRect = _localBlockRect(source);
    if (target?.line != _target?.line || sourceRect != _sourceRect) {
      setState(() {
        _target = target;
        _sourceRect = sourceRect;
      });
    }
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
      // 子层都带 key：拖动开始时淡化层插在把手之前，不带 key 会按位置把
      // 把手的元素复用给淡化层，正在进行的拖动随之被销毁、回调全部丢失。
      child: Stack(
        children: [
          KeyedSubtree(key: const ValueKey('editor'), child: widget.child),
          if (_sourceRect case final rect?)
            Positioned.fromRect(
              key: const ValueKey('source'),
              rect: rect,
              child: IgnorePointer(
                child: ColoredBox(color: colors.surface.withValues(alpha: 0.6)),
              ),
            ),
          if (_target case final target?)
            Positioned.fromRect(
              key: const ValueKey('target'),
              rect: target.line,
              child: IgnorePointer(child: _DropLine(color: colors.primary)),
            ),
          if (placement != null)
            Positioned(
              key: const ValueKey('handle'),
              left:
                  placement.center.dx - _handleWidth / 2 - _handleHitSlop.left,
              top: placement.center.dy - _handleHeight / 2 - _handleHitSlop.top,
              child: _BlockHandle(
                key: ObjectKey(placement.node),
                node: placement.node,
                controller: widget.controller,
                dragging: _dragging != null,
                onDragStarted: () => _startDrag(placement.node),
                onDragUpdate: _updateDrag,
                onDragEnd: _endDrag,
              ),
            ),
        ],
      ),
    );
  }
}

/// 落点线：2dp 圆头横线，左端一个 6dp 圆点标出插入层级的起点。
class _DropLine extends StatelessWidget {
  const _DropLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
      Positioned(
        left: -3,
        top: -2,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    ],
  );
}

class _BlockHandle extends StatelessWidget {
  const _BlockHandle({
    super.key,
    required this.node,
    required this.controller,
    required this.dragging,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final af.Node node;
  final DiaryEditorController controller;
  final bool dragging;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final text = node.delta?.toPlainText().trim() ?? '';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: ExpressiveMenuAnchor(
        placement: ExpressiveMenuPlacement.start,
        menuChildren: [
          ExpressiveMenuItem(
            onPressed: node.previous == null
                ? null
                : () => moveDiaryEditorBlock(
                    controller,
                    node,
                    node.previous!.path,
                  ),
            leadingIcon: const FaIcon(FontAwesomeIcons.angleUp),
            child: Text(l10n.diaryEditorMoveBlockUp),
          ),
          ExpressiveMenuItem(
            onPressed: node.next == null
                ? null
                : () => moveDiaryEditorBlock(
                    controller,
                    node,
                    node.next!.path.next,
                  ),
            leadingIcon: const FaIcon(FontAwesomeIcons.angleDown),
            child: Text(l10n.diaryEditorMoveBlockDown),
          ),
        ],
        builder: (context, menu, _) => Semantics(
          button: true,
          label: l10n.diaryEditorDragBlock,
          onTap: menu.toggle,
          excludeSemantics: true,
          child: LongPressDraggable<af.Node>(
            data: node,
            hapticFeedbackOnStart: false,
            // 卡片浮在手指右上方：落点线就在手指所在的块边上，不能被盖住。
            dragAnchorStrategy: (draggable, context, position) =>
                const Offset(-12, 84),
            onDragStarted: onDragStarted,
            onDragUpdate: (details) => onDragUpdate(details.globalPosition),
            onDragEnd: (_) => onDragEnd(),
            onDraggableCanceled: (_, _) => onDragEnd(),
            feedback: _DragFeedback(
              text: text.isEmpty ? l10n.diaryEditorDragBlock : text,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: menu.toggle,
              child: Padding(
                padding: _handleHitSlop,
                child: ExpressiveStateBlend(
                  active: menu.isExpanded || dragging,
                  builder: (context, t, _) => Container(
                    width: _handleWidth,
                    height: _handleHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer.withValues(alpha: t),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.gripVertical,
                      size: 11,
                      color: Color.lerp(
                        colors.onSurfaceVariant.withValues(alpha: 0.65),
                        colors.onSecondaryContainer,
                        t,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 拖动中跟手的卡片：块的前两行文字（媒体等为“拖动段落”），浮动面板的
/// 表面与投影规格。
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: AppEffects.softShadow(colors),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.gripVertical,
              size: 12,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
