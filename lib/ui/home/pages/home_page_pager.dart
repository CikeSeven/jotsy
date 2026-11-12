part of 'home_page.dart';

/// 首页的切页编排：目标态与结算、PageView 子页顺序（显示序）的切换与复位、
/// PageView 的组装、宽窗口入场的重播。
///
/// 职责边界：
/// - 输入：底栏 / 侧边栏 / 快捷键经 `_HomePageController` 发起的切页、PageView
///   报来的页码变化；
/// - 输出：[_HomePageState] 上的下标（`_currentIndex` / `_targetIndex`，底栏
///   下标）、显示序 `_pageOrder` 与切页态，经 `_setPagerState` 触发重建；
/// - 副作用：换序时校正 PageView 的像素（`correctPixels`），并手动刷新只按
///   滚动通知更新的可见区间与位置监听。
///
/// 页面运动本身（弹簧、折叠路线）在 `_HomePageController._animateToTab`。
extension _HomePagePager on _HomePageState {
  int _beginTabSwitch(int targetIndex) {
    if (!mounted || !_isValidTabIndex(targetIndex)) {
      return _tabSwitchGeneration;
    }
    _tabSwitchGeneration++;
    _barScrollHider.reset();
    _setPagerState(() {
      _targetIndex = targetIndex;
      _isTabSwitching = true;
      _barHiddenByScroll = false;
    });
    return _tabSwitchGeneration;
  }

  /// 切页结束（弹簧停稳、被手指接住或跳页之后）：按停下的页对齐下标，
  /// 换回规范序。代次不符说明已有更新的切页或 Tab 集合变化接手，什么也不做。
  void _settleTabSwitch(int fallbackIndex, int generation) {
    if (!mounted || generation != _tabSwitchGeneration) {
      return;
    }
    final pageController = _controller.pageController;
    final page = pageController.hasClients ? pageController.page : null;
    final settledIndex = page == null
        ? fallbackIndex.clamp(0, _tabs.length - 1).toInt()
        : _pageOrder.barIndexOfDisplay(
            page.round().clamp(0, _tabs.length - 1).toInt(),
          );
    _setPagerState(() {
      _currentIndex = settledIndex;
      _targetIndex = settledIndex;
      _isTabSwitching = false;
    });
    _restoreCanonicalPageOrder();
  }

  /// 换用显示序 [order]，页码同时平移 [pageShift] 页：可见的页换了下标但
  /// 画面不动（PageView 的子页以 Tab 身份为 key，按 key 搬到新下标）。
  ///
  /// 不能在 build 中调用（会通知位置监听者、重建可见区间）。`correctPixels`
  /// 不发通知，本帧之内 tick → build → layout 读到的都是新坐标；随后手动
  /// 刷新只按通知更新的三处：可见区间、背景插值与景深、底栏位置。
  void _applyPageOrder(HomeTabPageOrder order, {double pageShift = 0}) {
    if (identical(order, _pageOrder)) {
      return;
    }
    _setPagerState(() => _pageOrder = order);
    final pageController = _controller.pageController;
    if (pageShift != 0 && pageController.positions.length == 1) {
      final position = pageController.position;
      if (position.hasViewportDimension) {
        position.correctPixels(
          position.pixels +
              pageShift *
                  position.viewportDimension *
                  pageController.viewportFraction,
        );
      }
    }
    _syncVisibleTabs();
    _displayPosition.refresh();
    _pagePosition.refresh();
  }

  /// 切页结束后换回规范序（已是规范序时什么也不做）。
  ///
  /// 正常停稳时页码是整页、位置空闲，平移后原地不动。若别的滚动活动仍在
  /// 进行（弹簧途中窗口尺寸变化，物理改为吸附到最近一页），它的终点还是
  /// 旧坐标：平移后经 `jumpTo` 原地停下它，再由翻页物理在新坐标里吸附。
  void _restoreCanonicalPageOrder() {
    if (_pageOrder.isCanonical) {
      return;
    }
    final previous = _pageOrder;
    final restored = previous.restored;
    final pageController = _controller.pageController;
    final page = pageController.positions.length == 1
        ? pageController.page
        : null;
    if (page == null) {
      _applyPageOrder(restored);
      return;
    }
    final display = page.round().clamp(0, previous.length - 1).toInt();
    final shift = restored.displayIndexOf(previous.order[display]) - display;
    _applyPageOrder(restored, pageShift: shift.toDouble());
    final position = pageController.position;
    if (shift != 0 && position.isScrollingNotifier.value) {
      position.jumpTo(position.pixels);
    }
  }

  /// [displayIndex] 为 PageView 报来的显示下标，换算成 [_tabs] 中的下标。
  void _handlePageChanged(int displayIndex) {
    if (displayIndex < 0 || displayIndex >= _pageOrder.length) {
      return;
    }
    final index = _pageOrder.barIndexOfDisplay(displayIndex);
    _barScrollHider.reset();
    _setPagerState(() {
      _currentIndex = index;
      if (!_isTabSwitching) {
        _targetIndex = index;
      }
      _barHiddenByScroll = false;
    });
  }

  Widget _buildPageView() {
    return ValueListenableBuilder<_VisibleTabRange>(
      valueListenable: _visibleTabs,
      builder: (BuildContext context, _VisibleTabRange visible, Widget? _) {
        final order = _pageOrder.order;
        // 景深只在窄窗口：宽窗口不能滑动切页，跳页由入场效果负责；减少动画
        // 时手指滑动仍是普通平移。区域画背景时页面透明，缝隙直接露出背景，
        // 不铺舞台色。
        final depth = !_wide && !ExpressiveMotion.reduceMotion(context);
        final scheme = Theme.of(context).colorScheme;
        final stage = AppPagedBackground.paintsOf(context)
            ? null
            : ExpressiveSurfaces.tabStage(scheme);
        return PageView(
          controller: _controller.pageController,
          // 宽窗口不能左右滑动切页（鼠标拖动与触控板横滑都不切），只经
          // 侧边栏与快捷键切换。跨页折叠途中显示序不是底栏顺序，此时拖动
          // 会滑到底栏上不相邻的页，同样不接受拖动；其余时候弹簧途中可以
          // 用手指接住。
          physics: _wide || !_pageOrder.isCanonical
              ? const NeverScrollableScrollPhysics()
              : const HomeTabPagePhysics(),
          onPageChanged: _handlePageChanged,
          children: <Widget>[
            for (var index = 0; index < order.length; index++)
              // 被保活但不可见的 Tab 静音 ticker：其中仍在播放或循环的动画
              // （加载指示、入场动画等）不再在后台逐帧出帧；切回来时从当前
              // 时刻续上。滑动途中两侧页面都启用，不会冻结半露出的内容。
              // 同理关闭不可见 Tab 的 Hero：各 Tab 同属一个路由，否则从日历
              // 打开预览时，会从后台日记列表里同一篇的封面飞出来。
              //
              // 最外层以 Tab 身份为 key：关闭日历 / 探索后其余 Tab 的下标会
              // 前移，PageView 的列表代理按 key 把已有页面搬到新下标，保活的
              // 页面状态（滚动位置、筛选等）不会因为换了位置而重建。
              TickerMode(
                key: ValueKey<HomeTab>(order[index]),
                enabled: visible.contains(index),
                child: HeroMode(
                  enabled: visible.contains(index),
                  child: HomeTabDepth(
                    index: index,
                    position: _displayPosition,
                    enabled: depth,
                    stageColor: stage,
                    scrimColor: scheme.scrim,
                    child: _pageFor(order[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 宽窗口切页：重播新 Tab 的入场（见 [HomeTabEntrance]），[direction]
  /// 为在侧边栏上的方向（往下 1、往上 -1）。
  void _playWideEntrance(int direction) {
    if (!mounted) {
      return;
    }
    _setPagerState(() {
      _wideEntranceGeneration++;
      _wideEntranceDirection = direction;
    });
  }
}
