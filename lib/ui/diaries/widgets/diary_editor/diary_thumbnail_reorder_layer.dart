import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_effects.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_thumbnail_reorder.dart';
import '../../models/diary_thumbnail_reorder_slots.dart';
import '../../models/diary_thumbnail_rows.dart';
import 'diary_edge_auto_scroll.dart';
import 'diary_thumbnail_reorder_cell.dart';
import 'diary_thumbnail_reorder_float.dart';

/// 拿起时画面放大到的倍数。
const double kDiaryThumbnailLiftScale = 1.08;

/// 落点的迟滞（逻辑像素）：另一格要比现在的落点近出这么多才换，手指停在
/// 两格交界处时空槽不来回跳。
const double _slotHysteresis = 6;

/// 编辑页长按拖动小图排序（并排小图见 diary_thumbnail_rows.dart）。
///
/// 只在一串连续的小图里挪：长按其中一张，它的截图浮起来跟着手指走，其余
/// 几张实时让位、空槽跟着落点走；松手后截图飞进空槽，同一帧正文按新顺序
/// 写入一步可撤销的移动。拖到这一串以外时落点停在离手指最近的一格。
///
/// - 拿起：`mediumImpact`，截图经真弹簧放大到 [kDiaryThumbnailLiftScale]、
///   投下 `softShadow`（[AppEffects.softShadow]）；画面直接映射手指，不补间。
/// - 落点：截图中心离哪一格最近就落哪一格（[DiaryThumbnailSlots.nearest]，
///   带迟滞），每换一格 `selectionClick`；格位按拖动开始时的排版量，拖动
///   途中正文不变，格子只是画面平移（[DiaryThumbnailReorderCell]）。
/// - 自动滚动：手指靠近可见区域上下 48dp 时朝那边滚（与段落拖动共用
///   [DiaryEdgeAutoScrollDriver]），截图留在手指下，格子随正文滚动。
/// - 松手：截图从手指处经弹簧飞进落点的格子并缩回原大、阴影收起；落定的
///   那一帧写入正文、撤掉截图、格子归零，画面与写入后的排版逐像素一致。
///   位置变了补一下 `lightImpact`。指针被系统取消时飞回原位、不写入。
/// - 拖动由本层经全局指针路由跟踪，不用 `Draggable`：拖着时被拿起的格子
///   可能随自动滚动滚出列表而卸载，绑在它身上的回调会全部丢失。
/// - 拖动期间 [DiaryEditorController.draggingBlock] 为 true，写入的那一帧
///   结束后才放开：光标在别处时，视口不会因为这次移动把页面拉过去。
///
/// 输入：编辑控制器；输出：一次排序事务，没有其他副作用。
class DiaryThumbnailReorderLayer extends StatefulWidget {
  const DiaryThumbnailReorderLayer({
    super.key,
    required this.controller,
    required this.child,
    this.coveredHeight = 0,
  });

  final DiaryEditorController controller;

  /// 编辑器底部被浮层（工具栏）盖住的高度：自动滚动不计入。
  final double coveredHeight;

  final Widget child;

  @override
  State<DiaryThumbnailReorderLayer> createState() =>
      _DiaryThumbnailReorderLayerState();
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// 一次拖动。
class _Drag {
  _Drag({
    required this.run,
    required this.from,
    required this.image,
    required this.content,
    required this.cell,
    required this.grab,
    required this.finger,
    required this.pointer,
    required this.scrollable,
  }) : target = from;

  /// 拿起时的那一串小图（文档先后）。
  final List<af.Node> run;

  /// 被拿起的是第几张。
  final int from;

  /// 现在的落点（第几格）。
  int target;

  /// 整格的截图。
  final ui.Image image;

  /// 画面在格子里的矩形（截图按整格拍）。
  final Rect content;

  /// 一格的大小。
  final Size cell;

  /// 画面左上角减去手指（全局）：截图跟着手指的位移走，不跳到手指下。
  final Offset grab;

  /// 手指的全局位置。
  Offset finger;

  /// 跟踪的指针；松手（或被取消）后为 null。
  int? pointer;

  /// 自动滚动的滚动视图。
  final ScrollableState? scrollable;

  /// 松手时画面的矩形（未缩放）与拿起的程度：飞向落点的起点。
  Rect? releasedAt;
  double releasedLift = 1;

  /// 落定后是否写入（指针被取消时为 false）。
  bool commit = true;
}

class _DiaryThumbnailReorderLayerState extends State<DiaryThumbnailReorderLayer>
    with TickerProviderStateMixin
    implements DiaryThumbnailReorderHost {
  final Map<af.Node, DiaryThumbnailReorderCellHandle> _cells =
      Map<af.Node, DiaryThumbnailReorderCellHandle>.identity();
  final _Changes _changes = _Changes();
  _Drag? _drag;
  OverlayEntry? _overlay;

  /// 拿起的程度：0 平放、1 拿起（弹簧，可略过冲）。
  late final AnimationController _lift = AnimationController.unbounded(
    vsync: this,
  );

  /// 松手后飞向落点的进度：0 在手指处、1 落进格子（弹簧，可略过冲）。
  late final AnimationController _flight = AnimationController.unbounded(
    vsync: this,
  );

  /// 截图每帧重画一次：手指、自动滚动与飞行都会改它的位置。
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker = createTicker((_) => _tick());
  late final DiaryEdgeAutoScrollDriver _autoScroll = DiaryEdgeAutoScrollDriver(
    _autoScrollStep,
  );

  @override
  Listenable get changes => _changes;

  @override
  bool get active => _drag != null;

  @override
  void attach(af.Node node, DiaryThumbnailReorderCellHandle cell) =>
      _cells[node] = cell;

  @override
  void detach(af.Node node, DiaryThumbnailReorderCellHandle cell) {
    // 换排时新格子先登记、旧格子后注销，不能把新登记的删掉。
    if (identical(_cells[node], cell)) _cells.remove(node);
  }

  @override
  Rect? holeOf(af.Node node) {
    final drag = _drag;
    return drag != null && identical(drag.run[drag.from], node)
        ? drag.content
        : null;
  }

  @override
  Offset offsetOf(af.Node node) {
    final drag = _drag;
    if (drag == null) return Offset.zero;
    final index = drag.run.indexWhere((member) => identical(member, node));
    if (index < 0) return Offset.zero;
    final moved = diaryThumbnailReorderedIndex(
      index,
      from: drag.from,
      to: drag.target,
    );
    if (moved == index) return Offset.zero;
    final slots = _slots(drag);
    final from = slots.origin(index);
    final to = slots.origin(moved);
    return from == null || to == null ? Offset.zero : to - from;
  }

  /// 这一串的格位，按建着的格子此刻的排版量（见 [DiaryThumbnailSlots]）。
  DiaryThumbnailSlots _slots(_Drag drag) => DiaryThumbnailSlots(
    count: drag.run.length,
    known: {
      for (var i = 0; i < drag.run.length; i++)
        if (_cells[drag.run[i]]?.layoutRect case final rect?) i: rect.topLeft,
    },
    cell: drag.cell,
  );

  @override
  bool start(af.Node node, int pointer, Offset position) {
    final controller = widget.controller;
    if (_drag != null ||
        !mounted ||
        controller.isDisposed ||
        controller.readOnly ||
        controller.draggingBlock ||
        controller.blockSelection.isActive) {
      return false;
    }
    final range = diaryThumbnailRunOf(node);
    final cell = _cells[node];
    final layout = cell?.layoutRect;
    final content = cell?.contentRect;
    final overlay = Overlay.maybeOf(context);
    if (range == null ||
        range.end - range.start < 2 ||
        cell == null ||
        layout == null ||
        content == null ||
        content.isEmpty ||
        overlay == null) {
      return false;
    }
    final image = cell.capture();
    if (image == null) return false;
    final siblings = node.parent!.children;
    final drag = _Drag(
      run: [for (var i = range.start; i < range.end; i++) siblings[i]],
      from: node.path.last - range.start,
      image: image,
      content: content,
      cell: layout.size,
      grab: layout.topLeft + content.topLeft - position,
      finger: position,
      pointer: pointer,
      scrollable: _scrollableOf(cell.context),
    );
    _drag = drag;
    controller.draggingBlock = true;
    unawaited(HapticFeedback.mediumImpact());
    GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
    final colors = Theme.of(context).colorScheme;
    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: DiaryThumbnailFloat(
          frame: _floatFrame,
          repaint: _frame,
          shadows: AppEffects.softShadow(colors),
        ),
      ),
    );
    _overlay = entry;
    overlay.insert(entry);
    _flight.value = 0;
    _lift.value = 0;
    ExpressiveMotion.springTo(
      context,
      _lift,
      1,
      spring: ExpressiveMotion.springSpatialFast,
    );
    unawaited(_ticker.start());
    _changes.notify();
    return true;
  }

  /// 格子所在、真能滚动的纵向滚动视图：阅读页式的收缩正文外面还套着一层
  /// 不能滚的 SingleChildScrollView（见 `DiaryInlinePageBuilder`），要越过
  /// 它找外层的页面滚动。
  ScrollableState? _scrollableOf(BuildContext context) {
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      if (scrollable.widget.physics is! NeverScrollableScrollPhysics &&
          axisDirectionToAxis(scrollable.axisDirection) == Axis.vertical) {
        return scrollable;
      }
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    return null;
  }

  void _route(PointerEvent event) {
    final drag = _drag;
    if (drag == null || event.pointer != drag.pointer) return;
    if (event is PointerMoveEvent) {
      drag.finger = event.position;
    } else if (event is PointerUpEvent) {
      _release(drag, cancelled: false);
    } else if (event is PointerCancelEvent) {
      _release(drag, cancelled: true);
    }
  }

  /// 每帧：按手指重找落点、自动滚动、重画截图。
  void _tick() {
    final drag = _drag;
    if (drag == null || !mounted) return;
    if (drag.pointer != null) {
      _retarget(drag);
      _autoScrollStep();
    }
    _frame.value++;
  }

  /// 截图（未缩放）跟着手指时的矩形。
  Rect _heldRect(_Drag drag) => (drag.finger + drag.grab) & drag.content.size;

  void _retarget(_Drag drag) {
    var center = _heldRect(drag).center;
    final visible = _visible(drag);
    // 落点只在看得见的范围里找：列表在视口外还建着缓存的格子，手指拖到
    // 顶栏或工具栏上时不该落到看不见的地方。
    if (visible != null) {
      center = Offset(
        center.dx,
        center.dy.clamp(visible.top, math.max(visible.top, visible.bottom)),
      );
    }
    final next = _slots(drag).nearest(
      center,
      anchor: drag.content.center,
      current: drag.target,
      hysteresis: _slotHysteresis,
    );
    if (next == null || next == drag.target) return;
    drag.target = next;
    unawaited(HapticFeedback.selectionClick());
    _changes.notify();
  }

  /// 可见范围（全局纵坐标）：滚动视图去掉底部被键盘与浮层盖住的部分。
  ({double top, double bottom, double viewportTop, double viewportBottom})?
  _visible(_Drag drag) {
    final scrollable = drag.scrollable;
    if (scrollable == null || !scrollable.mounted) return null;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    final view = View.of(context);
    final keyboardTop =
        (view.physicalSize.height - view.viewInsets.bottom) /
        view.devicePixelRatio;
    return (
      top: top,
      bottom:
          math.min(top + box.size.height, keyboardTop) - widget.coveredHeight,
      viewportTop: top,
      viewportBottom: top + box.size.height,
    );
  }

  void _autoScrollStep() {
    // 停下后滚动器还在途中的那一步会再回调一次。
    final drag = _drag;
    if (!mounted || drag == null || drag.pointer == null) return;
    final scrollable = drag.scrollable;
    final visible = _visible(drag);
    if (scrollable == null || visible == null) return;
    _autoScroll.update(
      scrollable,
      drag.finger,
      visibleTop: visible.top,
      visibleBottom: visible.bottom,
      viewportTop: visible.viewportTop,
      viewportBottom: visible.viewportBottom,
    );
  }

  /// 松手或指针被取消：截图飞进落点（取消时飞回原位），落定后结束。
  void _release(_Drag drag, {required bool cancelled}) {
    if (drag.pointer == null) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
    drag.pointer = null;
    _autoScroll.stop();
    drag.releasedAt = _heldRect(drag);
    drag.releasedLift = _lift.value;
    _lift.stop();
    if (cancelled) {
      drag.commit = false;
      if (drag.target != drag.from) {
        drag.target = drag.from;
        _changes.notify();
      }
    }
    if (ExpressiveMotion.reduceMotion(context)) {
      // 不飞，下一帧直接落定。等到帧尾：媒体块在抬起时登记的焦点恢复
      // （`DiaryPlaybackInteractionGuard`）先跑完，再写入新顺序。
      _flight.value = 1;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (identical(_drag, drag)) _finish();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    _flight.value = 0;
    _flight
        .animateWith(
          SpringSimulation(
            ExpressiveMotion.springSpatial,
            0,
            1,
            0,
            snapToEnd: true,
          ),
        )
        .whenCompleteOrCancel(() {
          if (identical(_drag, drag)) _finish();
        });
  }

  /// 落点那一格里画面的矩形（全局）。
  Rect? _targetRect(_Drag drag) {
    final origin = _slots(drag).origin(drag.target);
    return origin == null ? null : drag.content.shift(origin);
  }

  DiaryThumbnailFloatFrame? _floatFrame() {
    final drag = _drag;
    if (drag == null) return null;
    final released = drag.releasedAt;
    final Rect rect;
    final double lift;
    if (released == null) {
      rect = _heldRect(drag);
      lift = _lift.value;
    } else {
      final p = _flight.value;
      rect = Rect.lerp(released, _targetRect(drag) ?? released, p)!;
      lift = drag.releasedLift * (1 - p);
    }
    final ratio = drag.image.width / drag.cell.width;
    return DiaryThumbnailFloatFrame(
      image: drag.image,
      source: Rect.fromLTRB(
        drag.content.left * ratio,
        drag.content.top * ratio,
        drag.content.right * ratio,
        drag.content.bottom * ratio,
      ),
      rect: rect,
      scale: 1 + (kDiaryThumbnailLiftScale - 1) * lift,
      elevation: lift.clamp(0.0, 1.0),
    );
  }

  /// 落定：写入新顺序、撤掉截图、格子归零，都在同一帧生效。
  void _finish() {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    _ticker.stop();
    _lift.stop();
    _flight.stop();
    _autoScroll.stop();
    _removeOverlay();
    final controller = widget.controller;
    final moved =
        drag.commit &&
        moveDiaryThumbnail(
          controller,
          drag.run,
          from: drag.from,
          to: drag.target,
        );
    _changes.notify();
    // 截图只经 _drag 画出，_drag 已清空，之后的绘制不会再用它。
    drag.image.dispose();
    if (moved) unawaited(HapticFeedback.lightImpact());
    _releaseDraggingAfterFrame();
  }

  /// 移动事务里的增删会让视口在帧尾核对光标（那时还算拖动中、不揭示）；
  /// 核对之后再放开。
  void _releaseDraggingAfterFrame() {
    final controller = widget.controller;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_drag == null && !controller.isDisposed) {
        controller.draggingBlock = false;
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _removeOverlay() {
    final entry = _overlay;
    _overlay = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  @override
  void nudge(af.Node node, int delta) {
    final controller = widget.controller;
    final range = diaryThumbnailRunOf(node);
    if (_drag != null || controller.draggingBlock || range == null) return;
    final siblings = node.parent!.children;
    final from = node.path.last - range.start;
    controller.draggingBlock = true;
    moveDiaryThumbnail(
      controller,
      [for (var i = range.start; i < range.end; i++) siblings[i]],
      from: from,
      to: from + delta,
    );
    _releaseDraggingAfterFrame();
  }

  @override
  void didUpdateWidget(DiaryThumbnailReorderLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了编辑控制器（正文整个换掉）：手里的这一串已不在新正文里。
    if (oldWidget.controller != widget.controller && _drag != null) {
      _abandon(oldWidget.controller);
    }
  }

  /// 不等飞行、立刻结束（页面被移除、换了正文）；[commit] 时按松手时的落点
  /// 写入，否则放回原处。
  void _abandon(DiaryEditorController controller, {bool commit = false}) {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    if (drag.pointer != null) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
    }
    _ticker.stop();
    _autoScroll.stop();
    _removeOverlay();
    if (commit) {
      moveDiaryThumbnail(
        controller,
        drag.run,
        from: drag.from,
        to: drag.target,
      );
    }
    if (!controller.isDisposed) controller.draggingBlock = false;
    _changes.notify();
    drag.image.dispose();
  }

  @override
  void dispose() {
    // 松手后飞回途中页面被移除（如紧接着返回）：照样写入，正文与最后看到
    // 的一致；还按着时页面被移除则放回原处。
    final drag = _drag;
    _abandon(
      widget.controller,
      commit: drag != null && drag.pointer == null && drag.commit,
    );
    _ticker.dispose();
    _lift.dispose();
    _flight.dispose();
    _frame.dispose();
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      DiaryThumbnailReorderScope(host: this, child: widget.child);
}
