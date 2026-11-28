import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/app_spacing.dart';
import '../home/widgets/home_hint_visibility_scope.dart';

/// 浮动提示条（SnackBar）避让页面内底部浮层 / 操作栏的宿主与区域标记。
///
/// 背景：Flutter 的 `Scaffold` 只会自动把浮动 `SnackBar` 排在
/// `Scaffold.bottomNavigationBar`、`persistentFooterButtons` 与
/// `floatingActionButton` 上方；放在 `Scaffold.body` 里的底部悬浮工具栏、
/// 多选操作栏、查找栏或底部面板，`Scaffold` 一无所知，提示条就会直接压在
/// 它们上面挡住按钮。
///
/// 做法：
/// - 宿主 [SnackBarClearanceHost] 包在页面根 [Scaffold] 外面，通过独立的
///   [SnackBarTheme] 抬高 `insetPadding.bottom`；只有 [Scaffold]（有提示条
///   时）与 [SnackBar] 自身订阅 `SnackBarTheme.of`，页面与正文块不随之重建，
///   且完整保留 `AppGlassSnackBarTheme` 的玻璃配色与首页宽窗口的水平边距。
/// - 子树里的底部可交互浮层包一层 [SnackBarClearanceArea]；宿主把浮层的
///   实际顶边换算到宿主坐标系，对照 `Scaffold` 自己的浮动提示基准底边算出
///   恰好不重复计入手势条与底栏槽位的避让高度，并与 `bottomNavigationBar`
///   同样保留 [SnackBarClearanceHost.defaultGap]（16dp）间隙。
/// - 提示条展示期间若浮层刚收起离场（如待办点击删除后多选操作栏正往下沉），
///   本条提示维持当前避让底线，不让“撤销”按钮在手指点按前突然下跳；若提示
///   停留期间又弹出了新的底部栏（如立刻再长按另一条待办），则立即抬高避让。
/// - 嵌套在已有宿主之内（如双栏日记页右栏里的预览页）时自动透传给最外层
///   宿主，与 `ScaffoldMessenger` 只在根 [Scaffold] 画提示条的口径一致。

/// 包在页面根 [Scaffold] 外面，汇总子树内 [SnackBarClearanceArea] 的高度并
/// 抬高浮动提示条的底部外边距。
class SnackBarClearanceHost extends StatefulWidget {
  const SnackBarClearanceHost({
    super.key,
    required this.child,
    this.resizeToAvoidBottomInset = true,
    this.bottomBarExtent = 0,
  });

  /// 提示条底缘与下方浮层顶缘之间默认保留的间隙，与全局提示条距底栏的
  /// `AppSpacing.l`（16dp）一致。
  static const double defaultGap = AppSpacing.l;

  /// 为提示条本体在顶部状态栏之下至少留出的垂直空间，防止大面板展开或极矮
  /// 窗口里把浮动提示条顶出屏幕上沿（避免触发 Flutter 的 off-screen 断言）。
  static const double _minSnackBarHeadroom = 140;

  final Widget child;

  /// 所包 [Scaffold] 是否随键盘缩小（须与该 `Scaffold` 的同名属性一致）。
  final bool resizeToAvoidBottomInset;

  /// 所包 [Scaffold] 的 `bottomNavigationBar` 槽位高度（如首页窄窗口的悬浮
  /// 底栏槽位高度，其余页面为 0）：Flutter 会先从底边扣掉它再放提示条。
  final double bottomBarExtent;

  @override
  State<SnackBarClearanceHost> createState() => _SnackBarClearanceHostState();
}

class _SnackBarClearanceHostState extends State<SnackBarClearanceHost>
    with WidgetsBindingObserver {
  final Set<_ClearanceObstacle> _obstacles = <_ClearanceObstacle>{};
  final ValueNotifier<double> _clearance = ValueNotifier<double>(0);

  RenderBox? _hostBox;
  HomeHintVisibilityController? _hintController;
  bool _delegated = false;
  bool _measureScheduled = false;
  double _activeHintFloor = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegated = _SnackBarClearanceScope.maybeOf(context) != null;
    if (delegated != _delegated) {
      _delegated = delegated;
      if (delegated) {
        _unbindHintController();
      }
    }
    if (!_delegated) {
      final controller = HomeHintVisibilityScope.maybeController(context);
      if (controller != _hintController) {
        _unbindHintController();
        _hintController = controller;
        controller?.isHintVisibleNotifier.addListener(_onHintVisibilityChanged);
        controller?.hintShownCountNotifier.addListener(_onHintShown);
      }
    }
  }

  @override
  void didUpdateWidget(SnackBarClearanceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_delegated &&
        (oldWidget.resizeToAvoidBottomInset !=
                widget.resizeToAvoidBottomInset ||
            oldWidget.bottomBarExtent != widget.bottomBarExtent)) {
      _scheduleMeasure();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unbindHintController();
    _obstacles.clear();
    _clearance.dispose();
    super.dispose();
  }

  void _unbindHintController() {
    _hintController?.isHintVisibleNotifier.removeListener(
      _onHintVisibilityChanged,
    );
    _hintController?.hintShownCountNotifier.removeListener(_onHintShown);
    _hintController = null;
  }

  @override
  void didChangeMetrics() {
    if (!_delegated) _scheduleMeasure();
  }

  void _register(_ClearanceObstacle obstacle) {
    _obstacles.add(obstacle);
    _scheduleMeasure();
  }

  void _unregister(_ClearanceObstacle obstacle) {
    if (_obstacles.remove(obstacle)) {
      _scheduleMeasure();
    }
  }

  void _onObstacleChanged() => _scheduleMeasure();

  /// 新提示即将弹出（早于 `ScaffoldMessenger.showSnackBar`）：不在构建/布局
  /// 阶段时同步重算一次，保证提示条首帧就落在浮层上方、不闪跳。
  void _onHintShown() {
    if (!mounted || _delegated) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _syncClearance(hintJustShown: true);
    } else {
      _scheduleMeasure(hintJustShown: true);
    }
  }

  void _onHintVisibilityChanged() {
    if (!mounted || _delegated) return;
    final visible = _hintController?.isHintVisibleNotifier.value ?? false;
    if (!visible) {
      _activeHintFloor = 0;
      _scheduleMeasure();
    }
  }

  bool _pendingHintJustShown = false;

  void _scheduleMeasure({bool hintJustShown = false}) {
    if (hintJustShown) _pendingHintJustShown = true;
    if (_measureScheduled || !mounted || _delegated) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      final justShown = _pendingHintJustShown;
      _pendingHintJustShown = false;
      if (mounted && !_delegated) {
        _syncClearance(hintJustShown: justShown);
      }
    });
  }

  void _syncClearance({bool hintJustShown = false}) {
    final live = _computeLiveClearance();
    final hintVisible = _hintController?.isHintVisibleNotifier.value ?? false;
    if (!hintVisible) {
      _activeHintFloor = 0;
    } else if (hintJustShown) {
      _activeHintFloor = live;
    } else if (live > _activeHintFloor) {
      _activeHintFloor = live;
    }
    final effective = hintVisible ? math.max(live, _activeHintFloor) : live;
    if ((effective - _clearance.value).abs() >= 0.5 ||
        (effective == 0 && _clearance.value != 0)) {
      _clearance.value = effective;
    }
  }

  double _computeLiveClearance() {
    final hostBox = _hostBox;
    if (hostBox == null || !hostBox.attached || !hostBox.hasSize) return 0;
    final hostSize = hostBox.size;
    if (hostSize.height <= 0 || hostSize.width <= 0) return 0;

    // 直接读取宿主处的 MediaQuery 而不订阅：软键盘升降动画里宿主不必逐帧重建。
    final media = context.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    final viewInsetsBottom = media?.viewInsets.bottom ?? 0;
    final viewPaddingBottom = media?.viewPadding.bottom ?? 0;
    final viewPaddingTop = media?.viewPadding.top ?? 0;

    // 对齐 Flutter `_ScaffoldLayout.performLayout` 摆放浮动 SnackBar 的基准底边。
    final minInsetBottom = widget.resizeToAvoidBottomInset
        ? viewInsetsBottom
        : 0.0;
    final contentBottom = math.max(
      0.0,
      hostSize.height - math.max(minInsetBottom, widget.bottomBarExtent),
    );
    final safeYOffsetBase = hostSize.height - viewPaddingBottom;
    final snackBarYOffsetBase = math.min(contentBottom, safeYOffsetBase);
    final hostOrigin = hostBox.localToGlobal(Offset.zero);

    var requiredBottom = 0.0;
    for (final obstacle in _obstacles) {
      if (!obstacle.enabled) continue;
      final box = obstacle.renderBox;
      if (box == null || !box.attached || !box.hasSize) continue;
      final size = box.size;
      if (size.height <= 0 || size.width <= 0) continue;

      final topLeft = box.localToGlobal(Offset.zero) - hostOrigin;
      final right = topLeft.dx + size.width;
      // 忽略 PageView 里滑到屏外的保活页，以及沉到底边之外的收起浮层。
      if (right <= 0 || topLeft.dx >= hostSize.width) continue;
      if (topLeft.dy >= hostSize.height) continue;

      final needed = (snackBarYOffsetBase - topLeft.dy) + obstacle.gap;
      if (needed > requiredBottom) requiredBottom = needed;
    }

    if (requiredBottom <= 0) return 0;

    final maxBottom = math.max(
      0.0,
      snackBarYOffsetBase -
          viewPaddingTop -
          SnackBarClearanceHost._minSnackBarHeadroom,
    );
    return math.min(requiredBottom, maxBottom).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (_delegated) return widget.child;
    return _SnackBarClearanceScope(
      host: this,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (ScrollEndNotification notification) {
          // PageView 水平切页时保活页里的底栏尺寸不变但会进出视口，切页结束重算一次。
          if (_obstacles.isNotEmpty &&
              notification.metrics.axis == Axis.horizontal) {
            _scheduleMeasure();
          }
          return false;
        },
        child: _ClearanceBoxProbe(
          onBoxChanged: (RenderBox? box) {
            if (_hostBox == box) return;
            _hostBox = box;
            if (box != null) _scheduleMeasure();
          },
          onGeometryChanged: _scheduleMeasure,
          trackPosition: false,
          // 树结构恒定，始终挂 SnackBarTheme：避让值在 0 与正数之间切换时不会
          // 卸载重建内部 Scaffold，正文控制器与滚动状态完整保留。
          child: ListenableBuilder(
            listenable: _clearance,
            child: widget.child,
            builder: (BuildContext context, Widget? child) {
              final base = SnackBarTheme.of(context);
              final clearance = _clearance.value;
              final baseInset =
                  base.insetPadding ?? const EdgeInsets.fromLTRB(15, 5, 15, 10);
              final data = clearance > baseInset.bottom
                  ? base.copyWith(
                      insetPadding: baseInset.copyWith(bottom: clearance),
                    )
                  : base;
              return SnackBarTheme(data: data, child: child!);
            },
          ),
        ),
      ),
    );
  }
}

/// 标记页面 `Scaffold.body` 里一块需要浮动提示条避让的底部操作栏或浮层。
class SnackBarClearanceArea extends StatefulWidget {
  const SnackBarClearanceArea({
    super.key,
    required this.child,
    this.enabled = true,
    this.gap = SnackBarClearanceHost.defaultGap,
  });

  final Widget child;

  /// 为 false 时不占位（适合常驻树中、按条件显隐的按钮或面板）。
  final bool enabled;

  /// 提示条底缘到本浮层顶缘之间的间隙。
  final double gap;

  @override
  State<SnackBarClearanceArea> createState() => _SnackBarClearanceAreaState();
}

class _SnackBarClearanceAreaState extends State<SnackBarClearanceArea> {
  final _ClearanceObstacle _obstacle = _ClearanceObstacle();
  _SnackBarClearanceHostState? _host;

  @override
  void initState() {
    super.initState();
    _obstacle
      ..enabled = widget.enabled
      ..gap = widget.gap;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextHost = _SnackBarClearanceScope.maybeOf(context);
    if (nextHost == _host) return;
    _host?._unregister(_obstacle);
    _host = nextHost;
    _host?._register(_obstacle);
  }

  @override
  void didUpdateWidget(SnackBarClearanceArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled || oldWidget.gap != widget.gap) {
      _obstacle
        ..enabled = widget.enabled
        ..gap = widget.gap;
      _host?._onObstacleChanged();
    }
  }

  @override
  void dispose() {
    _host?._unregister(_obstacle);
    _obstacle.renderBox = null;
    _host = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ClearanceBoxProbe(
      onBoxChanged: (RenderBox? box) {
        if (_obstacle.renderBox == box) return;
        _obstacle.renderBox = box;
        _host?._onObstacleChanged();
      },
      onGeometryChanged: () => _host?._onObstacleChanged(),
      trackPosition: true,
      child: widget.child,
    );
  }
}

class _ClearanceObstacle {
  RenderBox? renderBox;
  bool enabled = true;
  double gap = SnackBarClearanceHost.defaultGap;
}

class _SnackBarClearanceScope extends InheritedWidget {
  const _SnackBarClearanceScope({required this.host, required super.child});

  final _SnackBarClearanceHostState host;

  static _SnackBarClearanceHostState? maybeOf(BuildContext context) {
    // 只用于登记与注销，不需要在宿主重建时触发子浮层重建。
    final element = context
        .getElementForInheritedWidgetOfExactType<_SnackBarClearanceScope>();
    final widget = element?.widget;
    return widget is _SnackBarClearanceScope ? widget.host : null;
  }

  @override
  bool updateShouldNotify(_SnackBarClearanceScope oldWidget) =>
      oldWidget.host != host;
}

/// 零布局开销的几何探针：只在 `RenderBox` 挂载、卸载、尺寸变化或（当
/// [trackPosition] 为 true 时）实际重绘且顶边位移超过 0.5px 时回调，
/// 覆盖 `SizeTransition` / `SlideTransition` 这类只移位不改尺寸的动画。
class _ClearanceBoxProbe extends SingleChildRenderObjectWidget {
  const _ClearanceBoxProbe({
    required this.onBoxChanged,
    required this.onGeometryChanged,
    required this.trackPosition,
    required super.child,
  });

  final ValueChanged<RenderBox?> onBoxChanged;
  final VoidCallback onGeometryChanged;
  final bool trackPosition;

  @override
  _RenderClearanceBox createRenderObject(BuildContext context) {
    final box = _RenderClearanceBox(
      onGeometryChanged: onGeometryChanged,
      trackPosition: trackPosition,
    );
    onBoxChanged(box);
    return box;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderClearanceBox renderObject,
  ) {
    renderObject
      ..onGeometryChanged = onGeometryChanged
      ..trackPosition = trackPosition;
    onBoxChanged(renderObject);
  }

  @override
  void didUnmountRenderObject(_RenderClearanceBox renderObject) {
    onBoxChanged(null);
  }
}

class _RenderClearanceBox extends RenderProxyBox {
  _RenderClearanceBox({
    required this.onGeometryChanged,
    required this.trackPosition,
  });

  VoidCallback onGeometryChanged;
  bool trackPosition;
  Size? _lastSize;
  Offset? _lastGlobalTopLeft;

  @override
  void performLayout() {
    super.performLayout();
    final next = hasSize ? size : Size.zero;
    if (next != _lastSize) {
      _lastSize = next;
      onGeometryChanged();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (trackPosition && attached && hasSize) {
      final nextTopLeft = localToGlobal(Offset.zero);
      final previous = _lastGlobalTopLeft;
      if (previous == null ||
          (nextTopLeft - previous).distanceSquared >= 0.25) {
        _lastGlobalTopLeft = nextTopLeft;
        onGeometryChanged();
      }
    }
  }
}
