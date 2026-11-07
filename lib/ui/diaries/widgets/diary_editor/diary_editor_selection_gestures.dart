import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
// 上游公开的 selectionService.onPan* 参数使用了未导出的枚举，手机选区服务的
// widget 也未导出；这里只桥接固定版本的原生把手服务，选区、跨块定位、放大镜
// 与拖动结束仍由上游维护。
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show MobileSelectionDragMode, MobileSelectionServiceWidget;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../controllers/diary_editor_controller.dart';
import 'diary_edge_auto_scroll.dart';
import 'diary_editor_keyboard_hold.dart';

enum DiarySelectionHandleSide { start, end }

/// 选区把手触控区从正文边缘向外伸出的距离（Android 两个水滴都挂在文字下方，
/// iOS 起点圆点在首行上方、终点在末行下方）。收缩嵌入阅读页的正文在下方留出
/// 同样的高度（`DiaryEditorInteractionLayer`），末行的把手才按得到。
const double kDiarySelectionHandleOverhang = 48;

/// 触控区宽度，以水滴为中心。
const double _kHandleTouchWidth = 56;

/// 触控区从水滴中心朝正文延伸的距离：连同所在行靠近水滴的一半也算按住把手。
const double _kHandleTouchInward = 24;

/// 一端把手的水滴中心与触控区（都是全局坐标）。[caret] 为该端插入点的全局
/// 矩形，[ball] 为上游 `mobileDragHandleBallSize.width`。
///
/// 水滴位置与上游 `MobileSelectionHandle` 的绘制一致：Android 起点水滴在插入点
/// 左下、终点在右下，各 2×[ball] 见方；iOS 起点圆点在首行上方、终点在末行
/// 下方，直径 [ball]。上游自己的把手只在水滴下方留出水滴本身那十几像素
/// 可按（#190），这里按水滴向外扩成 56×(24 + 水滴到正文边缘 + 48) 的区域。
@visibleForTesting
({Offset ball, Rect zone}) diarySelectionHandleTarget(
  Rect caret,
  DiarySelectionHandleSide side, {
  required bool ios,
  required double ball,
}) {
  final start = side == DiarySelectionHandleSide.start;
  final above = ios && start;
  final center = ios
      ? (start
            ? caret.topCenter - Offset(0, ball / 2)
            : caret.bottomCenter + Offset(0, ball / 2))
      : caret.bottomCenter + Offset(start ? -ball : ball, ball);
  final left = center.dx - _kHandleTouchWidth / 2;
  final right = center.dx + _kHandleTouchWidth / 2;
  return (
    ball: center,
    zone: above
        ? Rect.fromLTRB(
            left,
            caret.top - kDiarySelectionHandleOverhang,
            right,
            center.dy + _kHandleTouchInward,
          )
        : Rect.fromLTRB(
            left,
            center.dy - _kHandleTouchInward,
            right,
            caret.bottom + kDiarySelectionHandleOverhang,
          ),
  );
}

/// 把手拖动的去向。默认交给上游手机选区服务；测试注入假实现，在桌面宿主上
/// （上游按 `dart:io` 选择桌面服务、不画把手）也能验证触控区与拖动换算。
abstract class DiarySelectionHandleDriver {
  const DiarySelectionHandleDriver();

  /// 上游此刻是否装着手机选区服务（只有它画把手、实现 onPan*）。
  bool get available;

  void start(DragStartDetails details, DiarySelectionHandleSide side);

  /// 返回拖动后的选区（定位失败时为 null）。
  af.Selection? update(
    DragUpdateDetails details,
    DiarySelectionHandleSide side,
  );

  void end(DragEndDetails details, DiarySelectionHandleSide side);
}

class _UpstreamHandleDriver extends DiarySelectionHandleDriver {
  _UpstreamHandleDriver(this.controller);
  final DiaryEditorController controller;

  static MobileSelectionDragMode _mode(DiarySelectionHandleSide side) =>
      side == DiarySelectionHandleSide.start
      ? MobileSelectionDragMode.leftSelectionHandle
      : MobileSelectionDragMode.rightSelectionHandle;

  /// 已卸载的编辑器（拖动中退出页面时，正文先于本手势层卸载）取不到服务，
  /// 这时不再转交。
  af.AppFlowySelectionService? get _service {
    if (controller.isDisposed) return null;
    final state = controller.state.service.selectionServiceKey.currentState;
    return state is af.AppFlowySelectionService
        ? state as af.AppFlowySelectionService
        : null;
  }

  /// 上游按宿主系统而不是目标平台选择选区服务，桌面服务的 onPan* 直接抛
  /// UnimplementedError；按实际装上的服务判断，而不是再猜一次平台。只在
  /// 指针事件里调用（遍历子元素不能发生在构建期间）。
  @override
  bool get available {
    if (controller.isDisposed) return false;
    var mobile = false;
    controller.state.service.selectionServiceKey.currentContext
        ?.visitChildElements((element) {
          mobile = element.widget is MobileSelectionServiceWidget;
        });
    return mobile;
  }

  @override
  void start(DragStartDetails details, DiarySelectionHandleSide side) =>
      _service?.onPanStart(details, _mode(side));

  @override
  af.Selection? update(
    DragUpdateDetails details,
    DiarySelectionHandleSide side,
  ) => _service?.onPanUpdate(details, _mode(side));

  @override
  void end(DragEndDetails details, DiarySelectionHandleSide side) =>
      _service?.onPanEnd(details, _mode(side));
}

/// 手机正文（编辑与只读）的选区把手手势：按上游水滴几何划出放大的触控区，
/// 按下即接管触点，再把拖动交回 AppFlowy；不写正文、不改页面的滚动或翻页
/// 阈值。[enabled] 为 false（桌面、不可选字）时不接管任何触点，但始终挂着，
/// 开关切换时不改变外层结构、不重建编辑器。
///
/// 拖动按“按下处到该端插入点中心的偏移”平移：按在触控区哪里（水滴下方的
/// 空白、所在行的文字上），选区端点都从原处开始跟手，不会一按就跳到手指
/// 所在的行或字；放大镜也因此跟着端点所在的文字，而不是手指。只按下、没有
/// 移动就抬起时什么也不做（不交给正文的点按把选区收成光标）。
///
/// 拖到看得见的范围上下边缘时自动滚动（上游手机选区服务不做这件事；参数与
/// 段落拖动相同，见 [diaryEdgeAutoScrollTarget]）：编辑页滚正文自己的列表
/// （[pageScroll] 为 false，底部去掉键盘与悬浮工具栏 [coveredHeight]），嵌入
/// 阅读页的收缩正文滚外层页面（[pageScroll] 为 true，顶部去掉盖在正文上的
/// 顶栏与状态栏、底部去掉导航条）。手指不动、内容在滚时逐帧按手指位置重新
/// 取选区，选区跟着内容一路扩展；交给上游的位置夹在看得见的范围里，拖到
/// 栏或键盘上也只选到边缘那一行。
class DiaryEditorSelectionGestures extends StatefulWidget {
  const DiaryEditorSelectionGestures({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.pageScroll = false,
    this.coveredHeight = 0,
    @visibleForTesting this.driver,
  });

  final DiaryEditorController controller;
  final Widget child;
  final bool enabled;

  /// 正文嵌在外层页面的滚动视图里（收缩正文），自动滚动滚外层页面。
  final bool pageScroll;

  /// 正文底部被悬浮工具栏等盖住的高度（不含键盘），见 `DiaryEditorViewport`。
  final double coveredHeight;
  final DiarySelectionHandleDriver? driver;

  @override
  State<DiaryEditorSelectionGestures> createState() =>
      _DiaryEditorSelectionGesturesState();
}

class _DiaryEditorSelectionGesturesState
    extends State<DiaryEditorSelectionGestures>
    with SingleTickerProviderStateMixin {
  late DiarySelectionHandleDriver _driver = _createDriver();

  /// 按下处到该端插入点中心的偏移，见类注释。
  Offset _grab = Offset.zero;

  /// 按下尚未移动时的起点；第一次移动才开始上游拖动（见类注释）。
  DragStartDetails? _pending;
  DiarySelectionHandleSide? _dragging;
  af.Selection? _lastSelection;

  /// 开始拖动时软键盘收着：整次拖动（含自动滚动时的重新取选区与松手）都
  /// 不接上输入法，否则上游每换一次选区就把收起的键盘拉起来。开始时就定下，
  /// 松手（也可能发生在卸载途中）不再查询窗口。
  bool _holdKeyboard = false;

  /// 最近一次手指的全局位置（未加 [_grab]）。
  Offset? _finger;

  /// 上次交给上游时滚动视图的位置；逐帧比较，内容滚过才重新取选区。
  double? _draggedPixels;

  /// 拖动期间逐帧运行：自动滚动时手指不动，内容仍在移动；滚动器在列表
  /// 估算的滚动范围处停下后也由它接上（与段落拖动同理）。
  Ticker? _ticker;
  EdgeDraggingAutoScroller? _autoScroller;

  DiarySelectionHandleDriver _createDriver() =>
      widget.driver ?? _UpstreamHandleDriver(widget.controller);

  @override
  void didUpdateWidget(DiaryEditorSelectionGestures old) {
    super.didUpdateWidget(old);
    if (old.driver != widget.driver || old.controller != widget.controller) {
      _driver = _createDriver();
    }
  }

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _ticker?.dispose();
    super.dispose();
  }

  bool get _ios => Theme.of(context).platform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) => DiarySelectionHandleGestureRegion(
    key: ObjectKey(widget.controller),
    resolveHandle: _resolveHandle,
    onStart: (details, side) {
      if (widget.controller.isDisposed) return;
      final anchor = _caretRect(side)?.center;
      _grab = anchor == null ? Offset.zero : anchor - details.globalPosition;
      _pending = DragStartDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        globalPosition: details.globalPosition + _grab,
        localPosition: details.localPosition + _grab,
        kind: details.kind,
      );
    },
    onUpdate: (details, side) {
      if (widget.controller.isDisposed) return;
      final pending = _pending;
      if (pending != null) {
        _pending = null;
        _dragging = side;
        _lastSelection = widget.controller.state.selection;
        _holdKeyboard = diaryShouldHoldKeyboard(context);
        _toUpstream(() => _driver.start(pending, side));
        final ticker = _ticker ??= createTicker((_) => _onTick());
        if (!ticker.isActive) ticker.start();
      }
      _finger = details.globalPosition;
      _drag(
        timeStamp: details.sourceTimeStamp,
        delta: details.delta,
        primaryDelta: details.primaryDelta,
      );
      _autoScroll();
    },
    onEnd: (details, side) => _finish(details),
    // 父路由退出或系统取消触点时，同样结束原生拖动，避免残留扩选模式。
    onCancel: (side) => _finish(DragEndDetails()),
    child: widget.child,
  );

  void _finish(DragEndDetails details) {
    _pending = null;
    _finger = null;
    _draggedPixels = null;
    _autoScroller?.stopAutoScroll();
    _ticker?.stop();
    final side = _dragging;
    _dragging = null;
    if (side == null || widget.controller.isDisposed) return;
    _toUpstream(() => _driver.end(details, side));
    _holdKeyboard = false;
  }

  /// 调用上游把手服务；开始拖动时软键盘收着就让它保持收起（见
  /// [_holdKeyboard]）。
  T _toUpstream<T>(T Function() call) =>
      _holdKeyboard ? widget.controller.holdingKeyboard(call) : call();

  /// 把手指位置（加 [_grab]、夹进看得见的范围）交给上游；端点换了位置时
  /// 与上游 Android 把手一样轻震一下。
  void _drag({
    Duration? timeStamp,
    Offset delta = Offset.zero,
    double? primaryDelta,
  }) {
    final side = _dragging;
    final finger = _finger;
    if (side == null || finger == null || widget.controller.isDisposed) {
      return;
    }
    var point = finger + _grab;
    final visible = _visible();
    if (visible != null) {
      point = Offset(
        point.dx,
        point.dy.clamp(
          visible.top + 1,
          math.max(visible.top + 1, visible.bottom - 1),
        ),
      );
    }
    _draggedPixels = _scrollable()?.position.pixels;
    final selection = _toUpstream(
      () => _driver.update(
        DragUpdateDetails(
          sourceTimeStamp: timeStamp,
          globalPosition: point,
          delta: delta,
          primaryDelta: primaryDelta,
        ),
        side,
      ),
    );
    if (selection != null && selection != _lastSelection) {
      _lastSelection = selection;
      if (Theme.of(context).platform == TargetPlatform.android &&
          widget.controller.state.editorStyle.enableHapticFeedbackOnAndroid) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onTick() {
    if (!mounted || _dragging == null) {
      _ticker?.stop();
      return;
    }
    final pixels = _scrollable()?.position.pixels;
    if (pixels != null && pixels != _draggedPixels) _drag();
    _autoScroll();
  }

  /// 拖动点（手指加 [_grab]，不夹取：越出边缘越多滚得越快）靠近看得见的
  /// 范围上下边缘时朝那一边滚动，离开边缘即停。每帧与滚动器每滚一步都按
  /// 当前位置重新给一次目标。
  void _autoScroll() {
    // 停下后滚动器还在途中的那一步会再回调一次。
    if (!mounted || _dragging == null) return;
    final finger = _finger;
    final scrollable = _scrollable();
    final visible = _visible();
    final target = finger == null || scrollable == null || visible == null
        ? null
        : diaryEdgeAutoScrollTarget(
            finger + _grab,
            visibleTop: visible.top,
            visibleBottom: visible.bottom,
            viewportTop: visible.viewportTop,
            viewportBottom: visible.viewportBottom,
          );
    if (target == null || scrollable == null) {
      _autoScroller?.stopAutoScroll();
      return;
    }
    var scroller = _autoScroller;
    if (scroller == null || scroller.scrollable != scrollable) {
      scroller?.stopAutoScroll();
      scroller = _autoScroller = EdgeDraggingAutoScroller(
        scrollable,
        onScrollViewScrolled: _autoScroll,
        velocityScalar: kDiaryAutoScrollVelocity,
      );
    }
    scroller.startAutoScrollIfNecessary(target);
  }

  /// 自动滚动的对象：编辑页为正文自己的列表，嵌入阅读页时为外层页面的
  /// 纵向滚动视图。
  ScrollableState? _scrollable() {
    if (widget.controller.isDisposed) return null;
    final scrollable = widget.pageScroll
        ? Scrollable.maybeOf(context, axis: Axis.vertical)
        : widget.controller.state.scrollableState;
    if (scrollable == null ||
        !scrollable.mounted ||
        axisDirectionToAxis(scrollable.axisDirection) != Axis.vertical) {
      return null;
    }
    return scrollable;
  }

  /// 看得见的范围与滚动视图本身（全局纵坐标）。
  ({double top, double bottom, double viewportTop, double viewportBottom})?
  _visible() {
    final box = _scrollable()?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final viewportTop = box.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + box.size.height;
    final view = View.of(context);
    final ratio = view.devicePixelRatio;
    final screen = view.physicalSize.height / ratio;
    var top = viewportTop;
    var bottom =
        math.min(viewportBottom, screen - view.viewInsets.bottom / ratio) -
        widget.coveredHeight;
    if (widget.pageScroll) {
      top = math.max(
        viewportTop + _headerOverlap(),
        view.viewPadding.top / ratio,
      );
      bottom = math.min(bottom, screen - view.viewPadding.bottom / ratio);
    }
    if (bottom <= top) return null;
    return (
      top: top,
      bottom: bottom,
      viewportTop: viewportTop,
      viewportBottom: viewportBottom,
    );
  }

  /// 嵌入阅读页时，固定或浮出的顶栏（`SliverAppBar`）盖在正文所在 sliver
  /// 上的高度。
  double _headerOverlap() {
    for (
      RenderObject? node = context.findRenderObject();
      node != null;
      node = node.parent
    ) {
      // 只在指针事件与帧回调里读取上一次布局的约束，不参与布局。
      if (node is RenderSliver) return math.max(0, node.constraints.overlap);
    }
    return 0;
  }

  DiarySelectionHandleSide? _resolveHandle(Offset point) {
    final controller = widget.controller;
    if (!widget.enabled || controller.isDisposed || !_driver.available) {
      return null;
    }
    final selection = controller.state.selection;
    if (selection == null || selection.isCollapsed) return null;
    // editorStyle 在子编辑器挂载时初始化，按下触点时再读取其最终把手尺寸。
    final ball = controller.state.editorStyle.mobileDragHandleBallSize.width;
    DiarySelectionHandleSide? closest;
    var distance = double.infinity;
    for (final side in DiarySelectionHandleSide.values) {
      final caret = _caretRect(side);
      if (caret == null) continue;
      final target = diarySelectionHandleTarget(
        caret,
        side,
        ios: _ios,
        ball: ball,
      );
      final candidateDistance = (point - target.ball).distanceSquared;
      // 短选区的两块触控区可能相交，按水滴距离确定抓住的是哪一端；按下后
      // 识别器会固定这一端，穿过另一把手或暂时折叠时也不会换边。
      if (target.zone.contains(point) && candidateDistance < distance) {
        closest = side;
        distance = candidateDistance;
      }
    }
    return closest;
  }

  /// 该端插入点的全局矩形。
  Rect? _caretRect(DiarySelectionHandleSide side) {
    final controller = widget.controller;
    final selection = controller.state.selection?.normalized;
    if (selection == null) return null;
    final position = side == DiarySelectionHandleSide.start
        ? selection.start
        : selection.end;
    final selectable = controller.document
        .nodeAtPath(position.path)
        ?.selectable;
    final local = selectable?.getCursorRectInPosition(position);
    if (selectable == null || local == null) return null;
    return selectable.transformRectToGlobal(local);
  }
}

/// 只在把手触控区参与竞技场，按下即认领触点。原生 pan 要移动单方向滚动阈值
/// 的两倍才认定拖动，等到那时外层阅读滚动 / 翻页已经先胜出，按住不动超过
/// 长按时间又会被正文的长按选词抢走；按下即认领后，触控区里的触点只属于
/// 把手，区外的正文滚动、长按选字与媒体控件手感不变。
class DiarySelectionHandleGestureRegion extends StatelessWidget {
  const DiarySelectionHandleGestureRegion({
    super.key,
    required this.resolveHandle,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });

  final DiarySelectionHandleSide? Function(Offset) resolveHandle;
  final void Function(DragStartDetails, DiarySelectionHandleSide) onStart;
  final void Function(DragUpdateDetails, DiarySelectionHandleSide) onUpdate;
  final void Function(DragEndDetails, DiarySelectionHandleSide) onEnd;
  final ValueChanged<DiarySelectionHandleSide> onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    excludeFromSemantics: true,
    gestures: {
      _SelectionHandlePanRecognizer:
          GestureRecognizerFactoryWithHandlers<_SelectionHandlePanRecognizer>(
            _SelectionHandlePanRecognizer.new,
            (recognizer) {
              recognizer
                ..resolveHandle = resolveHandle
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = (details) {
                  recognizer.started = true;
                  onStart(details, recognizer.side!);
                }
                ..onUpdate = (details) {
                  onUpdate(details, recognizer.side!);
                }
                ..onEnd = (details) {
                  onEnd(details, recognizer.side!);
                }
                ..onCancel = () {
                  if (recognizer.started) onCancel(recognizer.side!);
                };
            },
          ),
    },
    child: child,
  );
}

class _SelectionHandlePanRecognizer extends PanGestureRecognizer {
  late DiarySelectionHandleSide? Function(Offset) resolveHandle;
  DiarySelectionHandleSide? side;
  bool started = false;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event is PointerDownEvent &&
      side == null &&
      resolveHandle(event.position) != null &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    side = resolveHandle(event.position);
    started = false;
    super.addAllowedPointer(event);
    // 竞技场关闭前声明胜出：其余识别器（正文点按 / 长按 / 横滑、上游把手、
    // 外层滚动与翻页）在按下这一刻就全部出局，onStart 随即以按下位置触发。
    resolve(GestureDisposition.accepted);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    side = null;
    started = false;
  }

  @override
  void dispose() {
    if (started) onCancel?.call();
    side = null;
    started = false;
    super.dispose();
  }
}
