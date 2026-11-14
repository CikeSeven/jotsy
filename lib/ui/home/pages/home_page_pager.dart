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
///
/// 景深切页的快照（窄窗口、未减少动画，见 [HomeTabDepth]）：
/// - 两页同时在屏（可见区间跨两页）时 [_HomePageState._snapshotHold] 置为
///   true：各页按快照绘制，这期间所有页的 ticker 暂停（画面反正冻结在快照
///   上，动画继续跑只会白白出帧，落位时还会跳一下）；
/// - 落位后继续保持，每帧之后检查：没有任何动画再请求下一帧（底栏指示器、
///   选中动画都收尾了）、手指按在页面上、或落位超过 [_snapshotHoldLimit]，
///   就放开——这一帧落定的页改画实时页面（与快照逐像素一致）并恢复 ticker。
///   页内按 TickerMode 判断自己是否可见的逻辑（日记页的返回处理、下拉提示）
///   在这最多 400ms 里同样视为不可见；
/// - 只有完整显示过的 Tab 按快照画（[_HomePageState._snapshotReadyTabs]）：
///   第一次切到的页照常实时绘制、ticker 照常跑，数据与入场动画在途中出现；
///   它落定后（放开保持或实时落位时）记为显示过。
extension _HomePagePager on _HomePageState {
  /// 落位后最多再画多久快照：内容的更新（数据、解码好的图片）最多晚这么久
  /// 出现。不是动画时长。
  static const Duration _snapshotHoldLimit = Duration(milliseconds: 400);

  /// 两页同时在屏：开始按快照绘制（已在保持时取消待定的放开）。
  void _holdSnapshots() {
    _snapshotReleaseDeadline = null;
    _snapshotHold.value = true;
  }

  /// 可见区间回到一页：等收尾的动画停下再放开快照（见扩展注释）。
  void _scheduleSnapshotRelease() {
    if (!_snapshotHold.value || _snapshotReleaseScheduled) return;
    _snapshotReleaseScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(_checkSnapshotRelease);
  }

  void _checkSnapshotRelease(Duration _) {
    _snapshotReleaseScheduled = false;
    if (!mounted || !_snapshotHold.value) return;
    final visible = _visibleTabs.value;
    // 又开始移动：等这一轮落位后重新排期。
    if (visible.first != visible.last) return;
    final scheduler = SchedulerBinding.instance;
    final now = scheduler.currentSystemFrameTimeStamp;
    final deadline = _snapshotReleaseDeadline ??= now + _snapshotHoldLimit;
    // 帧回调里各 ticker 已为下一帧重新登记：计数为 0 即没有动画在跑。
    if (scheduler.transientCallbackCount == 0 || now >= deadline) {
      _releaseSnapshots();
      return;
    }
    _snapshotReleaseScheduled = true;
    scheduler.addPostFrameCallback(_checkSnapshotRelease);
  }

  /// 放开快照：落定的页改画实时页面，恢复 ticker。
  void _releaseSnapshots() {
    _snapshotReleaseDeadline = null;
    _markSettledTabReady();
    _snapshotHold.value = false;
  }

  /// 停在正中的页此后按实时绘制，算作完整显示过（[_HomePageState
  /// ._snapshotReadyTabs]），下一次切页起可以按快照画。只记集合，不触发
  /// 重建：下一次可见区间变化时各页随之读到。
  void _markSettledTabReady() {
    final visible = _visibleTabs.value;
    if (visible.first != visible.last) return;
    final order = _pageOrder.order;
    if (visible.first < 0 || visible.first >= order.length) return;
    _snapshotReadyTabs.add(order[visible.first]);
  }

  /// 手指按在页面上：页面马上要响应（滚动、点按、长按），停在正中时立即
  /// 换回实时绘制。移动途中按下（接住页面）不放开，仍按快照画。
  void _handlePagerPointerDown(PointerDownEvent event) {
    final visible = _visibleTabs.value;
    if (_snapshotHold.value && visible.first == visible.last) {
      _releaseSnapshots();
    }
  }

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
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_visibleTabs, _snapshotHold]),
      builder: (BuildContext context, Widget? _) {
        final visible = _visibleTabs.value;
        final order = _pageOrder.order;
        // 景深与快照只在窄窗口：宽窗口不能滑动切页，跳页由入场效果负责；
        // 减少动画时手指滑动仍是普通平移（实时绘制，背景固定在页面下面）。
        final depth = _tabsUseSnapshots;
        final hold = depth && _snapshotHold.value;
        final scheme = Theme.of(context).colorScheme;
        // 景深卡片自带本区域的背景（有背景图时），缝隙一律铺舞台色。
        final paintsBackground = AppPagedBackground.paintsOf(context);
        final stage = depth ? ExpressiveSurfaces.tabStage(scheme) : null;
        return Listener(
          onPointerDown: _handlePagerPointerDown,
          child: PageView.custom(
            controller: _controller.pageController,
            // 宽窗口不能左右滑动切页（鼠标拖动与触控板横滑都不切），只经
            // 侧边栏与快捷键切换。跨页折叠途中显示序不是底栏顺序，此时拖动
            // 会滑到底栏上不相邻的页，同样不接受拖动；其余时候弹簧途中可以
            // 用手指接住。
            physics: _wide || !_pageOrder.isCanonical
                ? const NeverScrollableScrollPhysics()
                : const HomeTabPagePhysics(),
            // 缓存区覆盖全部 Tab：每页一直留在 PageView 的子列表里。默认的
            // 保活会在页面移出视口时把它挪进保活桶、移回时再取出，两次都
            // 对整棵页面子树 detach + attach，真机上起步与落位各卡 8–16ms。
            // 缓存区里的页照常排版，但不在视口内就不画、不接点按；语义由
            // 下面的 ExcludeSemantics 排除，读屏不会顺着隐式滚动进到别的
            // Tab。
            allowImplicitScrolling: true,
            scrollCacheExtent: ScrollCacheExtent.viewport(
              math.max(1, order.length - 1).toDouble(),
            ),
            onPageChanged: _handlePageChanged,
            // 子页不另包重绘边界（PageView 默认每页一个）：页面本身在
            // HomeTabDepth 里有自己的边界，这一层只会让 HomeTabDepth 单独
            // 重绘。重绘按深度从深到浅进行，单独重绘时 sliver 还没把这一页的
            // 图层挪到当帧位置，拍快照时内容玻璃的取样（跟随背景层的
            // FollowerLayer）就按上一帧的位置对齐，落位后与实时画面错开。
            // 不加这层时 HomeTabDepth 随视口一起重绘，拿到的是当帧位置。
            childrenDelegate: SliverChildListDelegate(<Widget>[
              for (var index = 0; index < order.length; index++)
                _buildTabSlot(
                  tab: order[index],
                  index: index,
                  shown: visible.contains(index),
                  depth: depth,
                  hold: hold,
                  stage: stage,
                  scrim: scheme.scrim,
                  paintsBackground: paintsBackground,
                ),
            ], addRepaintBoundaries: false),
          ),
        );
      },
    );
  }

  /// PageView 里的一页。
  ///
  /// - 最外层以 Tab 身份为 key：关闭日历 / 探索后其余 Tab 的下标会前移，
  ///   PageView 的列表代理按 key 把已有页面搬到新下标，页面状态（滚动位置、
  ///   筛选等）不会因为换了位置而重建；
  /// - 不可见的 Tab 静音 ticker：其中仍在播放或循环的动画（加载指示、入场
  ///   动画等）不再在后台逐帧出帧；切回来时从当前时刻续上。按快照画的页
  ///   在移动途中与落位后的保持期间同样静音（见扩展注释）；实时绘制的页
  ///   （第一次显示、减少动画）滑动途中照常启用，不会冻结半露出的内容；
  /// - 同理关闭不可见 Tab 的 Hero：各 Tab 同属一个路由，否则从日历打开预览
  ///   时，会从后台日记列表里同一篇的封面飞出来；
  /// - 页面第一次出现在可见区间时才创建（[_pageFor]），之前是占位；完整显示
  ///   过之后才按快照画（见扩展注释）；
  /// - 景深卡片在有背景图时自带本区域的背景（[AppPagedAreaBackground]）。
  Widget _buildTabSlot({
    required HomeTab tab,
    required int index,
    required bool shown,
    required bool depth,
    required bool hold,
    required Color? stage,
    required Color scrim,
    required bool paintsBackground,
  }) {
    final Widget page = shown || _pages.containsKey(tab)
        ? _pageFor(tab)
        : const SizedBox.expand();
    final snapshot = depth && _snapshotReadyTabs.contains(tab);
    return TickerMode(
      key: ValueKey<HomeTab>(tab),
      enabled: shown && !(snapshot && hold),
      child: HeroMode(
        enabled: shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: HomeTabDepth(
            index: index,
            position: _displayPosition,
            enabled: depth,
            snapshot: snapshot,
            holdSnapshot: hold,
            stageColor: stage,
            scrimColor: scrim,
            background: depth && paintsBackground
                ? AppPagedAreaBackground(area: tab.backgroundArea)
                : null,
            child: page,
          ),
        ),
      ),
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
