import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../controllers/mind_map_viewport_controller.dart';
import '../layout/mind_map_layout.dart';
import '../layout/mind_map_scene.dart';
import '../layout/mind_map_text_cache.dart';
import '../viewmodels/mind_map_drop_planner.dart';
import '../viewmodels/mind_map_frame.dart';
import '../viewmodels/mind_map_hit_test.dart';
import '../viewmodels/mind_map_look.dart';
import 'mind_map_node_editor.dart';
import 'mind_map_painter.dart';

/// 无限画布：画出导图，处理平移 / 缩放 / 选中 / 拖动换位 / 文字编辑。
///
/// 输入：编辑会话 [controller]（文档、选中、编辑中的节点）与视口 [viewport]；
/// 输出：用户操作经 [controller] 改文档，右键 / 长按菜单经 [onNodeMenu] 交给
/// 宿主。状态机：
/// - 空闲：单指拖动平移、双指捏合缩放；桌面滚轮平移、Ctrl / ⌘ + 滚轮缩放；
/// - 点按：节点 → 选中，再点同一节点（双击）→ 编辑文字；徽标 → 收起 / 展开；
///   空白 → 取消选中，双击空白 → 适应屏幕；
/// - 拖动节点：手机长按拿起（`mediumImpact`），桌面鼠标直接拖；途中按
///   [planMindMapDrop] 显示落点，松手挪过去，落点无效时原位放回；
/// - 编辑：节点上叠一个随缩放的输入框（[MindMapNodeEditor]），绘制时跳过该
///   节点的文字。
/// 文档或外观变化时同步重新布局；带动画时新旧布局按节点 id 弹簧插值
/// （[MindMapFrame.lerp]），减少动态效果时直接到位。
class MindMapCanvas extends StatefulWidget {
  const MindMapCanvas({
    super.key,
    required this.controller,
    required this.viewport,
    this.padding = EdgeInsets.zero,
    this.keyboardInset,
    this.onNodeMenu,
    this.onCanvasMenu,
    this.interactive = true,
  });

  final MindMapEditingController controller;
  final MindMapViewportController viewport;

  /// 被顶栏、底部工具坞等浮层盖住的边距：适应屏幕与跟随选中都让开它们。
  final EdgeInsets padding;

  /// 软键盘高度（由宿主里只读 viewInsets 的一小层写入）：编辑文字时让节点
  /// 停在键盘之上。
  final ValueListenable<double>? keyboardInset;

  /// 节点的右键 / 长按菜单（全局坐标）。
  final void Function(String id, Offset globalPosition)? onNodeMenu;

  /// 空白处的右键菜单（全局坐标）。
  final void Function(Offset globalPosition)? onCanvasMenu;

  /// 为假时只能平移缩放（只读查看）。
  final bool interactive;

  @override
  State<MindMapCanvas> createState() => MindMapCanvasState();
}

class MindMapCanvasState extends State<MindMapCanvas>
    with TickerProviderStateMixin {
  final MindMapTextCache _texts = MindMapTextCache();
  late final AnimationController _transition = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  final ValueNotifier<int> _interaction = ValueNotifier<int>(0);

  MindMapScene? _scene;
  MindMapScene? _from;
  MindMapFrame? _stillFrame;
  Object? _layoutDocument;
  MindMapLook? _layoutLook;
  MindMapLook? _look;
  Size _size = Size.zero;

  String? _hoverId;
  String? _revealedSelection;
  String? _lastEditingId;

  // 点按与双击（不经 GestureDetector 的双击识别：那会让单击晚 300ms）。
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  Offset _lastTapPosition = Offset.zero;

  // 手势：平移缩放或拖动节点。
  double _lastGestureScale = 1;
  _NodeDrag? _drag;
  Offset? _longPressStart;
  bool _longPressMoved = false;

  MindMapScene? get scene => _scene;

  MindMapFrame get _frame {
    final scene = _scene;
    if (scene == null) return MindMapFrame.still(_emptyScene);
    final from = _from;
    if (from != null && _transition.isAnimating) {
      return MindMapFrame.lerp(from, scene, _transition.value);
    }
    return _stillFrame ??= MindMapFrame.still(scene);
  }

  static final MindMapScene _emptyScene = MindMapScene(
    nodes: const <MindMapSceneNode>[],
    edges: const <MindMapSceneEdge>[],
    guides: const <MindMapSceneGuide>[],
    structure: MindMapLook.fallbackStructure,
    line: MindMapLook.fallbackLine,
  );

  @override
  void initState() {
    super.initState();
    widget.viewport.attach(this);
    widget.controller.addListener(_onControllerChanged);
    widget.keyboardInset?.addListener(_onKeyboardChanged);
    _transition.addStatusListener((status) {
      if (!_transition.isAnimating) {
        _from = null;
        _stillFrame = null;
        _interaction.value++;
      }
    });
  }

  @override
  void didUpdateWidget(MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.viewport != widget.viewport) {
      oldWidget.viewport.detach();
      widget.viewport.attach(this);
    }
    if (oldWidget.keyboardInset != widget.keyboardInset) {
      oldWidget.keyboardInset?.removeListener(_onKeyboardChanged);
      widget.keyboardInset?.addListener(_onKeyboardChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.keyboardInset?.removeListener(_onKeyboardChanged);
    widget.viewport.detach();
    _transition.dispose();
    _interaction.dispose();
    _texts.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onKeyboardChanged() {
    final editing = widget.controller.editingId;
    if (editing != null) _reveal(editing, animate: false);
  }

  // ---------------- 布局 ----------------

  void _relayoutIfNeeded(MindMapLook look) {
    final document = widget.controller.document;
    if (identical(document, _layoutDocument) && look == _layoutLook) return;
    final next = layoutMindMap(document, look.config(_texts));
    final previous = _scene;
    final animate =
        previous != null &&
        widget.controller.animateNextLayout &&
        !ExpressiveMotion.reduceMotion(context);
    widget.controller.animateNextLayout = true;
    if (animate) {
      // 转场中途又变：以当前画面为新的起点，接着弹过去。
      final current = _frame;
      _from = MindMapScene(
        nodes: <MindMapSceneNode>[
          for (final node in current.nodes)
            if (previous.byId.containsKey(node.id)) node.scene.at(node.rect),
        ],
        edges: previous.edges,
        guides: previous.guides,
        structure: previous.structure,
        line: previous.line,
        spineY: previous.spineY,
      );
      _transition.value = 0;
      ExpressiveMotion.springTo(
        context,
        _transition,
        1,
        spring: ExpressiveMotion.springSpatial,
        tolerance: const Tolerance(distance: 0.002, velocity: 0.01),
      );
    } else {
      _from = null;
      _transition.value = 1;
    }
    _scene = next;
    _stillFrame = null;
    _layoutDocument = document;
    _layoutLook = look;
  }

  EdgeInsets get _revealPadding {
    final keyboard = widget.keyboardInset?.value ?? 0;
    final base = widget.padding;
    return EdgeInsets.fromLTRB(
      base.left + 24,
      base.top + 24,
      base.right + 24,
      math.max(base.bottom, keyboard + 72) + 24,
    );
  }

  Duration get _cameraDuration =>
      ExpressiveMotion.duration(context, ExpressiveMotion.standard);

  /// 让节点 [id] 露在可见区里。
  void _reveal(String id, {bool animate = true}) {
    final node = _scene?.byId[id];
    if (node == null || _size.isEmpty) return;
    widget.viewport.ensureVisible(
      node.rect,
      _size,
      padding: _revealPadding,
      duration: animate ? _cameraDuration : Duration.zero,
    );
  }

  /// 适应屏幕。
  void fitToScreen() {
    final scene = _scene;
    if (scene == null || _size.isEmpty) return;
    widget.viewport.fit(
      scene.bounds,
      _size,
      padding: widget.padding + const EdgeInsets.all(32),
      duration: _cameraDuration,
      curve: ExpressiveMotion.effects,
    );
  }

  /// 以视口中心为焦点缩放。
  void zoomBy(double factor) {
    if (_size.isEmpty) return;
    final area = widget.padding.deflateRect(Offset.zero & _size);
    final center = area.center;
    final viewport = widget.viewport;
    final target = (viewport.scale * factor).clamp(
      MindMapViewportController.minScale,
      MindMapViewportController.maxScale,
    );
    final content = viewport.toContent(center);
    viewport.animateTo(
      target,
      center - content * target,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
    );
  }

  /// 以 100% 显示选中的节点（没有选中时为根）。
  void zoomToActual() {
    final id =
        widget.controller.selectedId ?? widget.controller.document.root.id;
    final node = _scene?.byId[id];
    if (node == null || _size.isEmpty) return;
    widget.viewport.centerOn(
      node.rect.center,
      _size,
      scale: 1,
      padding: widget.padding,
      duration: _cameraDuration,
      curve: ExpressiveMotion.effects,
    );
  }

  /// 节点 [id] 当前在屏幕（画布本地坐标）上的矩形。
  Rect? screenRectOf(String id) {
    final node = _frame.byId[id];
    if (node == null) return null;
    return widget.viewport.toScreenRect(node.rect);
  }

  // ---------------- 手势 ----------------

  double get _touchSlop => 8 / widget.viewport.scale;

  MindMapHit _hitAt(Offset local, {bool touch = false}) => hitTestMindMap(
    _frame,
    widget.viewport.toContent(local),
    slop: touch ? _touchSlop : 2 / widget.viewport.scale,
    selectedId: widget.interactive ? widget.controller.selectedId : null,
  );

  void _onTapUp(TapUpDetails details) {
    final now = DateTime.now();
    final doubleTap =
        now.difference(_lastTapAt) < kDoubleTapTimeout &&
        (details.localPosition - _lastTapPosition).distance < kDoubleTapSlop;
    _lastTapAt = doubleTap ? DateTime.fromMillisecondsSinceEpoch(0) : now;
    _lastTapPosition = details.localPosition;
    final touch = details.kind == PointerDeviceKind.touch;
    final hit = _hitAt(details.localPosition, touch: touch);
    final controller = widget.controller;
    switch (hit) {
      case MindMapToggleHit(:final id):
        if (!widget.interactive) return;
        controller.select(id);
        controller.toggleCollapsed(id);
      case MindMapNodeHit(:final id):
        if (!widget.interactive) {
          if (doubleTap) _focusNode(id);
          return;
        }
        // 双击，或在触屏上再点一下已选中的节点：编辑文字。
        final tapSelected =
            touch &&
            controller.selectedId == id &&
            controller.editingId == null;
        if (doubleTap || tapSelected) {
          controller.startEditing(id);
          return;
        }
        if (controller.editingId != null && controller.editingId != id) {
          controller.stopEditing();
        }
        controller.select(id);
      case MindMapEmptyHit():
        if (controller.editingId != null) {
          controller.stopEditing();
          return;
        }
        if (doubleTap) {
          fitToScreen();
          return;
        }
        controller.select(null);
    }
  }

  void _focusNode(String id) {
    final node = _scene?.byId[id];
    if (node == null) return;
    widget.viewport.centerOn(
      node.rect.center,
      _size,
      padding: widget.padding,
      duration: _cameraDuration,
      curve: ExpressiveMotion.effects,
    );
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    if (!widget.interactive) return;
    final hit = _hitAt(details.localPosition);
    switch (hit) {
      case MindMapNodeHit(:final id) || MindMapToggleHit(:final id):
        widget.controller.select(id);
        widget.onNodeMenu?.call(id, details.globalPosition);
      case MindMapEmptyHit():
        widget.onCanvasMenu?.call(details.globalPosition);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastGestureScale = 1;
    if (!widget.interactive || details.pointerCount != 1) return;
    // 桌面上鼠标按在节点上拖：直接拖动节点（不必长按）。
    if (details.kind == PointerDeviceKind.mouse ||
        details.kind == PointerDeviceKind.stylus && AppPlatform.isDesktop) {
      final hit = _hitAt(details.localFocalPoint);
      if (hit case MindMapNodeHit(:final id)) {
        _beginDrag(id, details.localFocalPoint, haptic: false);
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_drag != null) {
      _updateDrag(details.localFocalPoint);
      return;
    }
    final viewport = widget.viewport;
    viewport.panBy(details.focalPointDelta);
    if (details.pointerCount > 1 || details.scale != 1) {
      final factor = details.scale / _lastGestureScale;
      _lastGestureScale = details.scale;
      if (factor != 1) viewport.zoomAt(details.localFocalPoint, factor);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_drag != null) {
      _endDrag();
      return;
    }
    final scene = _scene;
    if (scene == null) return;
    // 松手后顺着速度滑一段（减速），再保证内容没整个跑出视口。
    final velocity = details.velocity.pixelsPerSecond;
    final viewport = widget.viewport;
    if (velocity.distance > 400 && !ExpressiveMotion.reduceMotion(context)) {
      viewport.animateTo(
        viewport.scale,
        viewport.translation + velocity * 0.22,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
        curve: Curves.decelerate,
      );
    } else {
      viewport.settle(scene.bounds, _size, duration: _cameraDuration);
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.interactive) return;
    final hit = _hitAt(details.localPosition, touch: true);
    _longPressStart = details.localPosition;
    _longPressMoved = false;
    if (hit case MindMapNodeHit(:final id)) {
      widget.controller.select(id);
      final isRoot = widget.controller.document.root.id == id;
      if (!isRoot) {
        _beginDrag(id, details.localPosition, haptic: true);
      } else {
        unawaited(HapticFeedback.mediumImpact());
      }
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final start = _longPressStart;
    if (start != null && (details.localPosition - start).distance > 8) {
      _longPressMoved = true;
    }
    if (_drag != null && _longPressMoved) _updateDrag(details.localPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final drag = _drag;
    final moved = _longPressMoved;
    _longPressStart = null;
    if (drag != null && moved) {
      _endDrag();
      return;
    }
    // 长按没挪动：放下节点，改为弹出菜单。
    _cancelDrag();
    final hit = _hitAt(details.localPosition, touch: true);
    if (hit case MindMapNodeHit(:final id)) {
      widget.onNodeMenu?.call(id, details.globalPosition);
    }
  }

  void _beginDrag(String id, Offset local, {required bool haptic}) {
    final node = _scene?.byId[id];
    if (node == null || widget.controller.document.root.id == id) return;
    if (haptic) unawaited(HapticFeedback.mediumImpact());
    widget.controller.stopEditing();
    _drag = _NodeDrag(
      id: id,
      start: widget.viewport.toContent(local),
      offset: Offset.zero,
      target: null,
    );
    _interaction.value++;
  }

  void _updateDrag(Offset local) {
    final drag = _drag;
    final scene = _scene;
    if (drag == null || scene == null) return;
    final point = widget.viewport.toContent(local);
    final target = planMindMapDrop(
      scene: scene,
      document: widget.controller.document,
      dragId: drag.id,
      point: point,
    );
    if (_targetKey(target) != _targetKey(drag.target) && target != null) {
      unawaited(HapticFeedback.selectionClick());
    }
    _drag = _NodeDrag(
      id: drag.id,
      start: drag.start,
      offset: point - drag.start,
      target: target,
    );
    _autoPan(local);
    _interaction.value++;
  }

  /// 拖到视口边缘时画布跟着走一点。
  void _autoPan(Offset local) {
    const edge = 48.0;
    var dx = 0.0;
    var dy = 0.0;
    if (local.dx < edge) dx = (edge - local.dx) * 0.25;
    if (local.dx > _size.width - edge) {
      dx = -(local.dx - _size.width + edge) * 0.25;
    }
    if (local.dy < edge) dy = (edge - local.dy) * 0.25;
    if (local.dy > _size.height - edge) {
      dy = -(local.dy - _size.height + edge) * 0.25;
    }
    if (dx != 0 || dy != 0) widget.viewport.panBy(Offset(dx, dy));
  }

  void _endDrag() {
    final drag = _drag;
    _drag = null;
    _interaction.value++;
    final target = drag?.target;
    if (drag == null || target == null) return;
    widget.controller.move(drag.id, target);
  }

  void _cancelDrag() {
    if (_drag == null) return;
    _drag = null;
    _interaction.value++;
  }

  static Object? _targetKey(MindMapDropTarget? target) =>
      target == null ? null : (target.parentId, target.index, target.side);

  void _onPointerSignal(PointerSignalEvent event) {
    if (!AppPlatform.isDesktop || event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent event,
    ) {
      final scroll = event as PointerScrollEvent;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        final factor = math.exp(-scroll.scrollDelta.dy / 300);
        widget.viewport.zoomAt(scroll.localPosition, factor);
        return;
      }
      final delta = keys.isShiftPressed
          ? Offset(scroll.scrollDelta.dy, scroll.scrollDelta.dx)
          : scroll.scrollDelta;
      widget.viewport.panBy(-delta);
    });
  }

  void _onHover(PointerHoverEvent event) {
    if (!widget.interactive) return;
    final hit = _hitAt(event.localPosition);
    final id = switch (hit) {
      MindMapNodeHit(:final id) => id,
      _ => null,
    };
    if (id != _hoverId) {
      _hoverId = id;
      _interaction.value++;
    }
  }

  MindMapPaintOptions _paintOptions() {
    final look = _look!;
    final controller = widget.controller;
    final drag = _drag;
    return MindMapPaintOptions(
      palette: look.palette,
      selectedIds: <String>{?controller.selectedId},
      editingId: controller.editingId,
      hoverId: _hoverId,
      grid: look.grid,
      drag: drag == null
          ? null
          : MindMapDragPaint(
              id: drag.id,
              offset: drag.offset,
              target: drag.target,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final look = MindMapLook.of(context, widget.controller.document);
    _look = look;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _size = constraints.biggest;
        _relayoutIfNeeded(look);
        final scene = _scene!;
        final viewport = widget.viewport;
        if (!viewport.initialized && !_size.isEmpty) {
          viewport.initializeSilently(
            scene.bounds,
            _size,
            scene.byId[widget.controller.document.root.id]?.rect ??
                scene.bounds,
            widget.padding + const EdgeInsets.all(32),
          );
        }
        _scheduleReveal();
        final editingId = widget.controller.editingId;
        final canvas = CustomPaint(
          size: Size.infinite,
          painter: MindMapCanvasPainter(
            frame: () => _frame,
            options: _paintOptions,
            transform: () => widget.viewport.transform,
            repaint: Listenable.merge(<Listenable>[
              widget.viewport,
              _transition,
              _interaction,
            ]),
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Listener(
              onPointerSignal: _onPointerSignal,
              child: MouseRegion(
                onHover: AppPlatform.isDesktop ? _onHover : null,
                onExit: (_) {
                  if (_hoverId == null) return;
                  _hoverId = null;
                  _interaction.value++;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onTapUp,
                  onSecondaryTapUp: _onSecondaryTapUp,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onLongPressStart: widget.interactive
                      ? _onLongPressStart
                      : null,
                  onLongPressMoveUpdate: widget.interactive
                      ? _onLongPressMoveUpdate
                      : null,
                  onLongPressEnd: widget.interactive ? _onLongPressEnd : null,
                  onLongPressCancel: _cancelDrag,
                  child: RepaintBoundary(child: canvas),
                ),
              ),
            ),
            if (editingId != null && scene.byId[editingId] != null)
              MindMapNodeEditor(
                key: ValueKey<String>('mind-map-editor-$editingId'),
                controller: widget.controller,
                viewport: widget.viewport,
                node: scene.byId[editingId]!,
              ),
          ],
        );
      },
    );
  }

  /// 选中换了（新建节点、方向键、撤销）或开始编辑时，镜头跟过去。
  void _scheduleReveal() {
    final selected = widget.controller.selectedId;
    final editing = widget.controller.editingId;
    if (selected == _revealedSelection && editing == _lastEditingId) return;
    _revealedSelection = selected;
    _lastEditingId = editing;
    final target = editing ?? selected;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal(target);
    });
  }
}

final class _NodeDrag {
  const _NodeDrag({
    required this.id,
    required this.start,
    required this.offset,
    required this.target,
  });

  final String id;

  /// 拿起时指针的导图坐标。
  final Offset start;
  final Offset offset;
  final MindMapDropTarget? target;
}
