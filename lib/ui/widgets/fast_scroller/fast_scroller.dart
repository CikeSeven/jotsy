import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'fast_scroller_geometry.dart';
import 'fast_scroller_overlay.dart';
import 'fast_scroller_parts.dart';
import 'fast_scroller_seek.dart';

export 'fast_scroller_geometry.dart' show FastScrollLabel, FastScrollSection;

/// 长列表右侧的快速滚动条：按住拖动即在整份列表里跳转，左侧气泡显示所到
/// 位置的标签（日期、首字母、章节），轨道上标出分段刻度。
///
/// 输入：滚动视图 [child]（只认它自己的竖向滚动，嵌套的滚动不算）、列表
/// sliver 外层的 [listKey]、整份列表的项数 [itemCount]（可多于已加载的
/// [loadedCount]）、每项的标签 [labelBuilder] 与分段 [sections]；输出：经
/// [FastScrollSeek] 驱动滚动，目标落在还没加载的部分时经 [onNeedItems]
/// 请求加载。
///
/// - 位置按“第几项”换算（见 [FastScrollListGeometry]）：按钮位置 = 顶线
///   所在项 / 总项数，拖到哪里就把那一项带到顶线，气泡标签与刻度都精确；
///   全部加载完时，最后一屏里按钮再平滑走到底。
/// - 显隐：列表滚动时滑入，停下 [_hideDelay] 后淡出；按住、桌面悬停时保持。
///   内容不足 [_minScreens] 屏或 [enabled] 为 false 时不出现。隐藏时不接收
///   触摸，靠边的滑动照常交给列表。
/// - 只有按钮本身可以拖（轨道不响应触摸），滚动时误触右缘不会跳走；桌面
///   上点按轨道跳到该处，轨道上的滚轮转交给列表。
/// - 按住时轻震一次，拖过分段边界（如换了一年）再各震一次。
/// - 布局区域为本组件减去 [padding]（让出顶栏、底部按钮），右缘贴边。
class FastScroller extends StatefulWidget {
  const FastScroller({
    super.key,
    required this.child,
    required this.listKey,
    required this.itemCount,
    required this.loadedCount,
    required this.labelBuilder,
    this.sections = const <FastScrollSection>[],
    this.onNeedItems,
    this.listIdentity,
    this.pinnedExtent = 0,
    this.padding = EdgeInsets.zero,
    this.enabled = true,
  });

  final Widget child;
  final GlobalKey listKey;
  final int itemCount;

  /// 已交给列表 sliver 的项数（[itemCount] 的前段）。
  final int loadedCount;
  final FastScrollLabel Function(int index) labelBuilder;
  final List<FastScrollSection> sections;
  final ValueChanged<int>? onNeedItems;

  /// 列表的身份（筛选、排序、范围）：变化时放弃进行中的跳转——还在等数据
  /// 的目标属于旧列表，不能套到新列表上。
  final Object? listIdentity;

  /// 滚动视图顶部始终固定的栏（标签栏等）的高度：项滚到它的下缘才算在
  /// 最上面。会浮动收起的栏不算在内。须是常量，不能随滚动位置变化（见
  /// [FastScrollListGeometry]）。
  final double pinnedExtent;
  final EdgeInsets padding;
  final bool enabled;

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller>
    with TickerProviderStateMixin {
  /// 停止滚动后多久淡出（显隐计时，不是动画时长）。
  static const Duration _hideDelay = Duration(milliseconds: 1500);
  static const double _minScreens = 4;

  /// 按钮的拖动阈值：系统默认 18dp 要拖出小半个按钮才开始跟手。
  static const double _touchSlop = 2;

  final GlobalKey _trackKey = GlobalKey();
  final ValueNotifier<double> _thumbFraction = ValueNotifier<double>(0);
  late final AnimationController _visibility = AnimationController(vsync: this);
  late final AnimationController _bubble = AnimationController(vsync: this);
  late final Animation<double> _bubbleOpacity = CurvedAnimation(
    parent: _bubble,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );
  late final Animation<double> _bubbleScale = Tween<double>(begin: 0.8, end: 1)
      .animate(
        CurvedAnimation(
          parent: _bubble,
          curve: ExpressiveMotion.spatial,
          reverseCurve: ExpressiveMotion.exit,
        ),
      );
  late final FastScrollSeek _seek = FastScrollSeek(
    vsync: this,
    positionOf: () => _position,
    geometryOf: _geometry,
    itemCount: () => widget.itemCount,
    reduceMotion: () => mounted && ExpressiveMotion.reduceMotion(context),
    onNeedItems: (int count) => widget.onNeedItems?.call(count),
    onSettled: _scheduleHide,
  );

  /// 最近一次滚动通知的 context（在滚动视图内部），每次用时经它取当前的
  /// 滚动位置：切换布局换了滚动视图后旧的已卸载，不会拿到释放了的位置。
  BuildContext? _scrollContext;
  Timer? _hideTimer;

  bool _grabbed = false;

  /// 桌面：指针在右缘的轨道区或按钮上（两块各自记，从一块移到另一块时
  /// 不会先判为离开）。
  bool _stripHovered = false;
  bool _thumbHovered = false;
  double _grabOffset = 0;
  int _labelIndex = 0;
  int _section = -1;

  bool get _hovered => _stripHovered || _thumbHovered;

  ScrollPosition? get _position {
    final context = _scrollContext;
    if (context == null || !context.mounted) {
      return null;
    }
    return context.findAncestorStateOfType<ScrollableState>()?.position;
  }

  FastScrollListGeometry? _geometry() => FastScrollListGeometry.of(
    widget.listKey.currentContext,
    widget.loadedCount,
    pinnedExtent: widget.pinnedExtent,
  );

  @override
  void didUpdateWidget(covariant FastScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _seek.cancel();
      _hide(force: true);
    }
    if (widget.listIdentity != oldWidget.listIdentity && !_grabbed) {
      _seek.cancel();
    }
    if (widget.itemCount != oldWidget.itemCount ||
        widget.loadedCount != oldWidget.loadedCount) {
      _seek.resume();
      if (!_grabbed) {
        _syncThumb();
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seek.dispose();
    _visibility.dispose();
    _bubble.dispose();
    _thumbFraction.dispose();
    super.dispose();
  }

  // ==================== 滚动通知 ====================

  bool _handleMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _scrollContext = notification.context;
    _seek.resume();
    if (!_grabbed) {
      _syncThumb();
    }
    return false;
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _scrollContext = notification.context;
    // 用户按住列表拖动：放弃还在等数据的跳转。
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        !_grabbed) {
      _seek.cancel();
    }
    if (notification is ScrollUpdateNotification) {
      if (!_grabbed) {
        _syncThumb();
      }
      _show();
      _scheduleHide();
    }
    return false;
  }

  // ==================== 位置换算 ====================

  /// 当前滚动位置对应的按钮位置（0–1）。
  double _currentFraction() {
    final position = _position;
    if (position == null || !position.hasContentDimensions) {
      return 0;
    }
    return FastScrollListGeometry.fractionFor(
      position,
      _geometry(),
      widget.itemCount,
    );
  }

  void _syncThumb() {
    if (_visibility.isDismissed && !_hovered) {
      return;
    }
    _thumbFraction.value = _currentFraction();
  }

  /// 内容是否够长（整份列表的估计滚动范围至少 [_minScreens] − 1 屏）。
  bool get _longEnough {
    final position = _position;
    if (position == null || !position.hasContentDimensions) {
      return false;
    }
    final range = FastScrollListGeometry.estimatedRange(
      position,
      _geometry(),
      widget.itemCount,
    );
    return range >= position.viewportDimension * (_minScreens - 1);
  }

  // ==================== 显隐 ====================

  void _show() {
    _hideTimer?.cancel();
    if (_visibility.status == AnimationStatus.forward ||
        _visibility.isCompleted) {
      return;
    }
    if (!widget.enabled || !_longEnough) {
      return;
    }
    _thumbFraction.value = _currentFraction();
    unawaited(
      _visibility.animateTo(
        1,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
      ),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!mounted || _grabbed || _hovered) {
      return;
    }
    _hideTimer = Timer(_hideDelay, _hide);
  }

  void _hide({bool force = false}) {
    if (!mounted) {
      return;
    }
    if (!force && (_grabbed || _hovered || _seek.isActive)) {
      return;
    }
    unawaited(
      _visibility.animateBack(
        0,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        curve: ExpressiveMotion.exit,
      ),
    );
  }

  // ==================== 拖动 ====================

  /// 轨道（本组件减去 padding）里可供按钮移动的高度。
  double get _travel {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return 0;
    }
    return math.max(0, box.size.height - FastScrollMetrics.slot);
  }

  double _trackY(Offset globalPosition) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? 0 : box.globalToLocal(globalPosition).dy;
  }

  void _handleGrab(DragDownDetails details) {
    final travel = _travel;
    if (travel <= 0 || widget.itemCount <= 0) {
      return;
    }
    _hideTimer?.cancel();
    final thumbTop = _thumbFraction.value * travel;
    _grabOffset = _trackY(details.globalPosition) - thumbTop;
    _section = -1;
    _bubble.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.fast,
    );
    unawaited(_bubble.forward());
    unawaited(HapticFeedback.selectionClick());
    setState(() => _grabbed = true);
    _seekToFraction(_thumbFraction.value, holding: true);
  }

  void _handleDrag(DragUpdateDetails details) {
    if (!_grabbed) {
      return;
    }
    final travel = _travel;
    if (travel <= 0) {
      return;
    }
    final top = _trackY(details.globalPosition) - _grabOffset;
    _seekToFraction((top / travel).clamp(0.0, 1.0), holding: true);
  }

  void _handleRelease() {
    if (!_grabbed) {
      return;
    }
    _seek.release();
    unawaited(_bubble.reverse());
    setState(() => _grabbed = false);
    _syncThumb();
    _scheduleHide();
  }

  /// 桌面上点按轨道：跳到点按处（按钮中心对准指针）。
  void _handleTrackTap(TapUpDetails details) {
    final travel = _travel;
    if (travel <= 0) {
      return;
    }
    final top = _trackY(details.globalPosition) - FastScrollMetrics.slot / 2;
    _seekToFraction((top / travel).clamp(0.0, 1.0), holding: false);
  }

  /// 轨道挡住了下面的列表：桌面滚轮转交给列表。
  void _forwardPointerSignal(PointerSignalEvent event) {
    final position = _position;
    if (event is PointerScrollEvent && position != null) {
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (PointerSignalEvent event) => position.pointerScroll(
          (event as PointerScrollEvent).scrollDelta.dy,
        ),
      );
    }
  }

  void _seekToFraction(double fraction, {required bool holding}) {
    final total = widget.itemCount;
    if (total <= 0) {
      return;
    }
    _thumbFraction.value = fraction;
    final index = fraction * total;
    _seek.seekTo(index, holding: holding);
    _updateLabel(math.min(index.floor(), total - 1));
  }

  void _updateLabel(int index) {
    final section = _sectionOf(index);
    if (_grabbed && section != _section && _section >= 0) {
      unawaited(HapticFeedback.selectionClick());
    }
    _section = section;
    if (index != _labelIndex) {
      setState(() => _labelIndex = index);
    }
  }

  /// [index] 所在分段的序号（第一段之前为 -1）。
  int _sectionOf(int index) {
    final sections = widget.sections;
    var low = 0;
    var high = sections.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (sections[mid].index <= index) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  void _setHovered({bool? strip, bool? thumb}) {
    final was = _hovered;
    setState(() {
      _stripHovered = strip ?? _stripHovered;
      _thumbHovered = thumb ?? _thumbHovered;
    });
    if (_hovered == was) {
      return;
    }
    if (_hovered) {
      _show();
    } else {
      _scheduleHide();
    }
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _handleMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            widget.child,
            Positioned.fill(
              child: Padding(
                padding: widget.padding,
                child: ExcludeSemantics(
                  child: SizedBox.expand(
                    key: _trackKey,
                    child: FastScrollerOverlay(
                      visibility: _visibility,
                      thumbFraction: _thumbFraction,
                      bubbleOpacity: _bubbleOpacity,
                      bubbleScale: _bubbleScale,
                      // 气泡淡出期间列表可能已变空（换了筛选）。
                      label:
                          (_grabbed || !_bubble.isDismissed) &&
                              widget.itemCount > 0
                          ? widget.labelBuilder(
                              math.min(_labelIndex, widget.itemCount - 1),
                            )
                          : null,
                      sections: widget.sections,
                      itemCount: widget.itemCount,
                      grabbed: _grabbed,
                      hovered: _hovered,
                      desktop: AppPlatform.isDesktop,
                      touchSlop: _touchSlop,
                      onGrab: _handleGrab,
                      onDrag: _handleDrag,
                      onRelease: _handleRelease,
                      onTrackTap: _handleTrackTap,
                      onPointerSignal: _forwardPointerSignal,
                      onStripHover: (bool hovered) =>
                          _setHovered(strip: hovered),
                      onThumbHover: (bool hovered) =>
                          _setHovered(thumb: hovered),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
