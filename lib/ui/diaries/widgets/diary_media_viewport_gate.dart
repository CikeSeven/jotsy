import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 向上游虚拟列表或内联正文透传布局变化信号，供 [DiaryMediaViewportGate] 在
/// 上方块高度变化导致自身位移时重新判定可见性。
class DiaryMediaViewportScope extends InheritedWidget {
  const DiaryMediaViewportScope({
    super.key,
    this.layoutChanges,
    required super.child,
  });

  final Listenable? layoutChanges;

  static Listenable? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiaryMediaViewportScope>()
      ?.layoutChanges;

  @override
  bool updateShouldNotify(DiaryMediaViewportScope oldWidget) =>
      !identical(oldWidget.layoutChanges, layoutChanges);
}

/// 按与最近真实竖向视口的距离与路由可见性（[TickerMode]）门控重媒体
/// （图片解码、长图分片、视频封面与原生播放器）。
///
/// 为什么：
/// - 预览页与发布页的内联正文（`DiaryInlinePageBuilder`）把整篇放进一个
///   `Column`，不经门控时几十张图与多段视频会同时解码、占满 `ImageCache` 与
///   硬件解码器；
/// - 翻页器的缓存邻页与被压在路由栈下层的页面 `TickerMode` 已关闭，但原先仍
///   保留所有活着的 `Image` 监听与原生播放器。
///
/// 使用滞回区间（[activateMargin] < [deactivateMargin]），避免在视口边缘
/// 轻微来回滚动时反复卸载与重解码。离开视口后调用方仍应保留既有占位高度，
/// 防止回滚时内容跳动。
class DiaryMediaViewportGate extends StatefulWidget {
  const DiaryMediaViewportGate({
    super.key,
    required this.builder,
    this.activateMargin = 0.8,
    this.deactivateMargin = 1.5,
    this.suspendWhenTickerDisabled = true,
    this.onActiveChanged,
  }) : assert(deactivateMargin >= activateMargin);

  final Widget Function(BuildContext context, bool active) builder;

  /// 距离视口上下边界不超过该屏数时激活媒体。
  final double activateMargin;

  /// 距离视口上下边界超过该屏数时释放媒体。
  final double deactivateMargin;

  /// `TickerMode` 关闭（被其他路由遮挡或翻页器非当前页）时是否暂停激活。
  /// 正文视频借用原生播放器进入全屏页时传 false，避免全屏途中被回收。
  final bool suspendWhenTickerDisabled;

  /// 有效激活态发生变化时在帧后回调，供宿主安全释放/回收重资源。
  final ValueChanged<bool>? onActiveChanged;

  @override
  State<DiaryMediaViewportGate> createState() => _DiaryMediaViewportGateState();
}

class _DiaryMediaViewportGateState extends State<DiaryMediaViewportGate> {
  /// 滚动位移超过该阈值（逻辑像素）再重算可见性，避免每帧微滚频繁遍历。
  static const double _scrollStepThreshold = 48;

  ScrollableState? _scrollable;
  ScrollPosition? _position;
  ValueListenable<bool>? _scrolling;
  Listenable? _layoutChanges;
  bool _inRange = false;
  bool _tickerEnabled = true;
  bool _scheduled = false;
  double _lastCheckedPixels = double.nan;
  bool? _notifiedActive;

  bool get _active =>
      _inRange && (!widget.suspendWhenTickerDisabled || _tickerEnabled);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final tickerChanged = tickerEnabled != _tickerEnabled;
    _tickerEnabled = tickerEnabled;

    final scrollable = _findVerticalScrollable(context);
    if (!identical(scrollable, _scrollable)) {
      _detachScroll();
      _scrollable = scrollable;
      _position = scrollable?.position;
      _position?.addListener(_onScroll);
      _scrolling = _position?.isScrollingNotifier;
      _scrolling?.addListener(_onScrollingStateChanged);
      _lastCheckedPixels = double.nan;
      // 外面没有可滚动视口时直接激活；在滚动容器里先保守停用，等帧后测量
      // 位置再只激活视口附近的块，避免首帧整篇同时解码。
      _inRange = scrollable == null;
    }

    final layoutChanges = DiaryMediaViewportScope.maybeOf(context);
    if (!identical(layoutChanges, _layoutChanges)) {
      _layoutChanges?.removeListener(_scheduleCheck);
      _layoutChanges = layoutChanges;
      _layoutChanges?.addListener(_scheduleCheck);
    }

    if (tickerChanged || _scrollable != null || _notifiedActive != _active) {
      _scheduleCheck();
    }
  }

  @override
  void didUpdateWidget(DiaryMediaViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activateMargin != widget.activateMargin ||
        oldWidget.deactivateMargin != widget.deactivateMargin ||
        oldWidget.suspendWhenTickerDisabled !=
            widget.suspendWhenTickerDisabled ||
        oldWidget.onActiveChanged != widget.onActiveChanged) {
      _scheduleCheck();
    }
  }

  void _detachScroll() {
    _position?.removeListener(_onScroll);
    _scrolling?.removeListener(_onScrollingStateChanged);
    _position = null;
    _scrolling = null;
  }

  void _onScroll() {
    final pixels = _position?.pixels;
    if (pixels == null) return;
    if (_lastCheckedPixels.isNaN ||
        (pixels - _lastCheckedPixels).abs() >= _scrollStepThreshold) {
      _scheduleCheck();
    }
  }

  void _onScrollingStateChanged() {
    // 停止滚动时必查一次，兜住小幅拖动未达到阈值的情况。
    if (_scrolling?.value == false) {
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _check();
    });
  }

  void _check() {
    final scrollable = _scrollable;
    if (scrollable == null) {
      _updateRange(true);
      return;
    }
    if (widget.suspendWhenTickerDisabled && !_tickerEnabled) {
      _notifyActiveIfNeeded();
      return;
    }
    final box = context.findRenderObject();
    final viewport = scrollable.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        !viewport.hasSize ||
        viewport.size.height <= 0) {
      _notifyActiveIfNeeded();
      return;
    }
    _lastCheckedPixels = _position?.pixels ?? 0;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final bottom = top + box.size.height;
    final vh = viewport.size.height;
    final margin =
        vh * (_inRange ? widget.deactivateMargin : widget.activateMargin);
    final nextInRange = bottom >= -margin && top <= vh + margin;
    _updateRange(nextInRange);
  }

  void _updateRange(bool nextInRange) {
    if (nextInRange != _inRange) {
      setState(() => _inRange = nextInRange);
    }
    _notifyActiveIfNeeded();
  }

  void _notifyActiveIfNeeded() {
    final current = _active;
    if (_notifiedActive == current) return;
    _notifiedActive = current;
    widget.onActiveChanged?.call(current);
  }

  @override
  void dispose() {
    _detachScroll();
    _layoutChanges?.removeListener(_scheduleCheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _active);

  /// 越过内联正文不可滚动的 `SingleChildScrollView(NeverScrollableScrollPhysics)`，
  /// 找到真正驱动滚动与视口裁切的外层竖向 [ScrollableState]。
  static ScrollableState? _findVerticalScrollable(BuildContext context) {
    ScrollableState? result;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        if ((scrollable.axisDirection == AxisDirection.down ||
                scrollable.axisDirection == AxisDirection.up) &&
            !_isNeverScrollable(scrollable.widget.physics)) {
          result = scrollable;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  static bool _isNeverScrollable(ScrollPhysics? physics) {
    for (var current = physics; current != null; current = current.parent) {
      if (current is NeverScrollableScrollPhysics) return true;
    }
    return false;
  }
}
