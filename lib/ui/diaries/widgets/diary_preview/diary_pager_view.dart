import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_enums.dart';
import '../../../app_surface/widgets/app_page_background.dart';
import '../../../widgets/desktop_page_arrows.dart';
import '../../models/diary_preview_style/diary_preview_behavior.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import 'diary_pager_effects.dart';
import 'diary_pager_page_frame.dart';

/// 翻页器里一页的位置，以及翻到相邻一页的入口（已在一端时为 null）。
@immutable
class DiaryPagerPosition {
  const DiaryPagerPosition({
    required this.index,
    required this.count,
    this.onPrevious,
    this.onNext,
  });

  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
}

typedef DiaryPagerItemBuilder =
    Widget Function(BuildContext context, DiaryPagerPosition position);

/// 左右滑动切换日记的翻页器：正式预览页（`DiaryPreviewPager`）与设置页的
/// 实时预览共用，两处的手感与效果因此一致。
///
/// 手势冲突的处理（详见 DESIGN.md §5.8）：
/// - 斜着滑不翻页：外面包一层只改 `gestureSettings` 的 [MediaQuery]，把
///   [PageView] 的横向起滑距离放大为系统值 × 灵敏度倍数，每一页里面再还原，
///   正文竖向滚动与页内横向控件（录音波形、视频进度条）照旧先赢；
/// - 页面需自行使用始终可滚动的 physics：正文不满一屏时也要有竖向识别器
///   参与竞争，否则斜着滑也会翻页；
/// - 关闭滑动或 [locked]（导出、分享长图期间）时不接受拖动，`上一篇 /
///   下一篇` 与读屏动作仍可翻页（[locked] 时也不响应）。
///
/// 桌面（[desktopControls]，只有正式预览页打开）：指针悬停时左右边缘淡入
/// 上一篇 / 下一篇按钮，←/→（PageUp/PageDown）翻页、Esc 返回，都走与读屏
/// 动作相同的程序翻页；不额外加拖动识别器（鼠标拖动本来就不翻页）。
///
/// 可见性：照首页 Tab 翻页器的做法，滑动途中露出的页启用 [TickerMode]，其余
/// 缓存页静音（视频自行暂停、后台不出帧）；只有当前页启用 [HeroMode]，各页
/// 头图与正文图的共享元素标签只在单篇内唯一，同时在树上时不会撞标签。
class DiaryPagerView extends StatefulWidget {
  const DiaryPagerView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.initialPage = 0,
    this.navigation = const DiaryPreviewNavigationStyle(),
    this.behavior = DiaryPreviewBehavior.defaults,
    this.locked = false,
    this.cacheNeighbors = true,
    this.desktopControls = false,
    this.onPageChanged,
  });

  final int itemCount;
  final DiaryPagerItemBuilder itemBuilder;
  final int initialPage;
  final DiaryPreviewNavigationStyle navigation;
  final DiaryPreviewBehavior behavior;
  final bool locked;

  /// 预先构建两侧各一页（`allowImplicitScrolling`）。正式页面在路由入场结束
  /// 后才打开，免得打开时同时排版三篇正文。
  final bool cacheNeighbors;

  /// 桌面上的悬停翻页按钮与按键（见类注释）；手机上不起作用。设置页的实时
  /// 预览不开：它嵌在设置页里，Esc 不该关掉设置页。
  final bool desktopControls;
  final ValueChanged<int>? onPageChanged;

  @override
  State<DiaryPagerView> createState() => _DiaryPagerViewState();
}

class _DiaryPagerViewState extends State<DiaryPagerView> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  )..addListener(_syncVisibility);
  late final ValueNotifier<DiaryPagerVisibility> _visibility =
      ValueNotifier<DiaryPagerVisibility>(
        DiaryPagerVisibility.at(widget.initialPage.toDouble()),
      );
  final ValueNotifier<DiaryPagerEdgePull> _edgePull =
      ValueNotifier<DiaryPagerEdgePull>(DiaryPagerEdgePull.none);
  late int _current = widget.initialPage;

  /// 桌面翻页按钮按它显示两侧（只有这一小块随翻页重建）。
  late final ValueNotifier<int> _currentPage = ValueNotifier<int>(
    widget.initialPage,
  );

  @override
  void dispose() {
    _controller
      ..removeListener(_syncVisibility)
      ..dispose();
    _visibility.dispose();
    _currentPage.dispose();
    _edgePull.dispose();
    super.dispose();
  }

  double get _page {
    final controller = _controller;
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.page ?? _current.toDouble();
    }
    return _current.toDouble();
  }

  /// 按实时位置更新可见区间；只有区间变化才通知各页。
  void _syncVisibility() {
    final next = DiaryPagerVisibility.at(_page);
    if (next != _visibility.value) {
      _visibility.value = next;
    }
  }

  void _handlePageChanged(int index) {
    _current = index;
    _currentPage.value = index;
    if (widget.behavior.hapticOnPage) {
      HapticFeedback.lightImpact();
    }
    widget.onPageChanged?.call(index);
  }

  /// 程序翻页（上一篇 / 下一篇、读屏动作）：`medium` + `spatial`，减少动画时
  /// 直接跳到目标页。
  void _goTo(int index) {
    if (widget.locked ||
        index < 0 ||
        index >= widget.itemCount ||
        !_controller.hasClients) {
      return;
    }
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero) {
      _controller.jumpToPage(index);
      return;
    }
    _controller.animateToPage(
      index,
      duration: duration,
      curve: ExpressiveMotion.spatial,
    );
  }

  /// 到头提示：Android 的拉伸越界靠 [OverscrollNotification]，iOS 的回弹看
  /// 越界的位置；只认翻页器自己（depth 0）的横向滚动。
  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal ||
        !widget.navigation.edgeHint) {
      return false;
    }
    final metrics = notification.metrics;
    final current = _edgePull.value;
    if (notification is OverscrollNotification) {
      if (notification.dragDetails != null) {
        _setPull(
          current.released
              ? notification.overscroll
              : current.distance + notification.overscroll,
        );
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null &&
          metrics.pixels < metrics.minScrollExtent) {
        _setPull(metrics.pixels - metrics.minScrollExtent);
      } else if (notification.dragDetails != null &&
          metrics.pixels > metrics.maxScrollExtent) {
        _setPull(metrics.pixels - metrics.maxScrollExtent);
      } else {
        _releasePull();
      }
    } else if (notification is ScrollEndNotification) {
      _releasePull();
    }
    return false;
  }

  void _setPull(double distance) {
    _edgePull.value = DiaryPagerEdgePull(distance, atEnd: distance > 0);
  }

  void _releasePull() {
    final current = _edgePull.value;
    if (!current.released) {
      _edgePull.value = DiaryPagerEdgePull(
        0,
        atEnd: current.atEnd,
        released: true,
      );
    }
  }

  ScrollPhysics? _physics() {
    if (!widget.behavior.swipeBetweenDiaries || widget.locked) {
      return const NeverScrollableScrollPhysics();
    }
    final velocity = widget.behavior.swipeSensitivity.minFlingVelocity;
    return velocity == null
        ? null
        : DiaryPagerFlingPhysics(flingVelocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final pageSettings = mediaQuery.gestureSettings;
    final ratio = widget.behavior.swipeSensitivity.touchSlopRatio;
    final pagerSettings = DeviceGestureSettings(
      touchSlop: (pageSettings.touchSlop ?? kTouchSlop) * ratio,
    );
    final transition = widget.navigation.transition;
    return _withDesktopControls(
      context,
      _buildPager(mediaQuery, pageSettings, pagerSettings, transition),
    );
  }

  Widget _buildPager(
    MediaQueryData mediaQuery,
    DeviceGestureSettings pageSettings,
    DeviceGestureSettings pagerSettings,
    DiaryPreviewPageTransition transition,
  ) {
    // 预览区域画了背景时不铺这层“桌面”：它不透明，会把整页背景盖住；
    // 层叠与淡入时露出的改为背景本身。设置页的实时预览处在设置区域之下，
    // 照旧铺桌面。
    final backdrop = AppPageBackdrop.maybeOf(context);
    final onPreviewBackground =
        backdrop != null &&
        backdrop.area == AppBackgroundArea.preview &&
        backdrop.hasBackground;
    // 滑动时两篇并排、互不重叠，各篇透明、背景不动只有内容滑过；层叠与
    // 淡入时两篇在过渡中叠在一起，透明的页面会让两篇内容互相透出，所以
    // 每篇自己垫一份同样的区域背景（AppPageBackgroundCopy：同一张图、同一
    // 尺寸与 cover 对齐，静止时与下面的背景逐像素重合，看起来不变），跟着
    // 页面一起移动、缩放与淡入淡出。纸张选了颜色时各篇本就不透明，垫的这
    // 一份被纸色盖住，不影响观感。
    final opaquePages =
        onPreviewBackground && transition != DiaryPreviewPageTransition.slide;
    return ColoredBox(
      // 层叠与淡入时页面会缩小或半透明，露出的是这层“桌面”。
      color: onPreviewBackground
          ? Colors.transparent
          : Theme.of(context).colorScheme.surfaceContainer,
      child: Stack(
        children: <Widget>[
          NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: MediaQuery(
              data: mediaQuery.copyWith(gestureSettings: pagerSettings),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return PageView.builder(
                    controller: _controller,
                    physics: _physics(),
                    allowImplicitScrolling: widget.cacheNeighbors,
                    itemCount: widget.itemCount,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (BuildContext context, int index) {
                      final page = widget.itemBuilder(
                        context,
                        DiaryPagerPosition(
                          index: index,
                          count: widget.itemCount,
                          onPrevious: index > 0 ? () => _goTo(index - 1) : null,
                          onNext: index < widget.itemCount - 1
                              ? () => _goTo(index + 1)
                              : null,
                        ),
                      );
                      return DiaryPagerPageFrame(
                        index: index,
                        visibility: _visibility,
                        gestureSettings: pageSettings,
                        onPrevious: index > 0 ? () => _goTo(index - 1) : null,
                        onNext: index < widget.itemCount - 1
                            ? () => _goTo(index + 1)
                            : null,
                        // 始终包一层过渡（平移时不做任何变换），切换效果时
                        // 页面不会重新挂载。
                        child: AnimatedBuilder(
                          animation: _controller,
                          child: _PagerPageBase(
                            opaque: opaquePages,
                            child: page,
                          ),
                          builder: (BuildContext context, Widget? child) {
                            return DiaryPagerTransition(
                              transition: transition,
                              offset: index - _page,
                              width: constraints.maxWidth,
                              child: child!,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (widget.navigation.edgeHint)
            Positioned.fill(child: DiaryPagerEdgeHint(pull: _edgePull)),
        ],
      ),
    );
  }

  /// 桌面的悬停按钮与按键包在整个翻页器外面；不开时原样返回。
  Widget _withDesktopControls(BuildContext context, Widget pager) {
    if (!widget.desktopControls) {
      return pager;
    }
    final l10n = context.l10n;
    void previous() => _goTo(_current - 1);
    void next() => _goTo(_current + 1);
    return DesktopPageKeys(
      onPrevious: previous,
      onNext: next,
      onEscape: () => Navigator.of(context).maybePop(),
      child: ValueListenableBuilder<int>(
        valueListenable: _currentPage,
        child: pager,
        builder: (BuildContext context, int current, Widget? pager) {
          final canPage = !widget.locked;
          return DesktopPageArrows(
            previousTooltip: l10n.diaryPreviewPrevious,
            nextTooltip: l10n.diaryPreviewNext,
            onPrevious: canPage && current > 0 ? previous : null,
            onNext: canPage && current < widget.itemCount - 1 ? next : null,
            child: pager!,
          );
        },
      ),
    );
  }
}

/// 翻页器里一篇页面的底：[opaque] 时在页面下面垫一份区域背景（见
/// `_buildPager` 里的说明），否则什么也不画。
///
/// 结构始终是同一个 Stack，页面挂在带 key 的固定位置：切换转场效果、背景
/// 有无时只增删下面那一层，页面本身不重新挂载（滚动位置、正文控制器保留）。
class _PagerPageBase extends StatelessWidget {
  const _PagerPageBase({required this.opaque, required this.child});

  final bool opaque;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        if (opaque)
          const Positioned.fill(
            key: ValueKey<String>('pageBackground'),
            child: AppPageBackgroundCopy(),
          ),
        KeyedSubtree(key: const ValueKey<String>('page'), child: child),
      ],
    );
  }
}
