part of 'package:node_diary/ui/home/pages/home_page.dart';

/// Home 页控制器。
///
/// 职责边界：
/// - 处理底部导航页切换（弹簧推动、跨页折叠、途中改道，见 [_animateToTab]）；
/// - 功能管理开关改变可见 Tab 时，对齐页面下标并回收被关闭的 Tab；
/// - 处理启动提示仅展示一次逻辑；
/// - 不直接构建 UI。
class _HomePageController {
  _HomePageController(this._state);

  static const Duration _scrollToTopDuration = ExpressiveMotion.standard;

  final _HomePageState _state;
  late final PageController pageController;

  /// 点按切页的弹簧；连点时带着上一段的速度改道。
  final PageSpringDriver _pageSpring = PageSpringDriver();

  /// 被关闭的 Tab 留下的滚动控制器：页面在本帧末尾才卸载、解除挂载，
  /// 帧后（或首页销毁时）再释放，避免释放仍挂着位置的控制器。
  final List<ScrollController> _retiredScrollControllers = <ScrollController>[];

  void init() {
    pageController = PageController(initialPage: _state._currentIndex);
    _showStartupNoticeIfNeeded();
  }

  void handleWidgetUpdate(HomePage oldWidget) {
    if (oldWidget.startupNotice != _state.widget.startupNotice) {
      _showStartupNoticeIfNeeded();
    }
  }

  void dispose() {
    pageController.dispose();
    _disposeRetiredScrollControllers();
  }

  void _disposeRetiredScrollControllers() {
    for (final controller in _retiredScrollControllers) {
      controller.dispose();
    }
    _retiredScrollControllers.clear();
  }

  /// 把可见 Tab 对齐到 [next]（在 build 中、组装底栏与页面之前调用）。
  ///
  /// 列表未变时什么也不做。变化时（设置 → 功能管理关闭或开启日历 / 探索，
  /// 或恢复备份带来不同的开关）：
  /// 1. 保持目标 Tab 不变，换算它在新列表中的下标；目标 Tab 自己被关闭时
  ///    （如停在日历时恢复了关掉日历的备份）回到日记页。取目标而不是动画中
  ///    的当前页，与底栏高亮一致。
  /// 2. 递增切页代次并结束切页态：进行中的切页动画结束后 `_settleTabSwitch`
  ///    因代次不符而不再改写下标。
  /// 3. 页面下标前移 / 后移时立即校正 PageView 的像素位置（`correctPixels`
  ///    不发通知，可在 build 中调用），使本帧布局直接落在新下标上，不会
  ///    闪出别的页或回弹；帧后再 `jumpToPage` 兜底（同时停下仍在跑的切页
  ///    动画）。页面本身靠 Tab 身份 key 在 PageView 中搬到新下标，状态保留。
  /// 4. 被关闭 Tab 的页面移出缓存，本帧即被卸载；滚动控制器帧后释放。
  ///
  /// 直接改字段而不 setState：调用时 HomePage 正在 build，随后的组装读的
  /// 就是新值；`_visibleTabs` 的监听者都在首页子树内，build 期间允许标脏。
  void syncVisibleTabs(List<HomeTab> next) {
    final previous = _state._tabs;
    if (listEquals(previous, next)) {
      return;
    }
    final previousTarget = previous[_state._targetIndex];
    final kept = next.contains(previousTarget)
        ? previousTarget
        : HomeTab.diaries;
    final keptIndex = next.indexOf(kept);

    for (final tab in previous) {
      if (next.contains(tab)) {
        continue;
      }
      _state._pages.remove(tab);
      _state._snapshotReadyTabs.remove(tab);
      final controller = _state._tabScrollControllers.remove(tab);
      if (controller != null) {
        _retiredScrollControllers.add(controller);
      }
    }

    _state._tabs = List<HomeTab>.unmodifiable(next);
    // 折叠途中的显示序作废：新列表一律从规范序开始（下面按规范下标校正）。
    _state._pageOrder = HomeTabPageOrder.canonical(next);
    _state._tabSwitchGeneration++;
    _state._isTabSwitching = false;
    _state._currentIndex = keptIndex;
    _state._targetIndex = keptIndex;

    if (pageController.hasClients) {
      final position = pageController.position;
      if (position.hasViewportDimension) {
        position.correctPixels(
          keptIndex *
              position.viewportDimension *
              pageController.viewportFraction,
        );
      }
    }
    _state._visibleTabs.value = _VisibleTabRange(keptIndex, keptIndex);
    // 切页途中改了可见 Tab：区间直接回到一页，同样等收尾后放开快照。
    _state._scheduleSnapshotRelease();
    // correctPixels 不发通知：背景插值、景深与底栏位置按新页码刷新（监听者
    // 都在首页子树内，build 期间允许标脏）。
    _state._displayPosition.refresh();
    _state._pagePosition.refresh();

    final generation = _state._tabSwitchGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 首页已销毁时控制器已在 [dispose] 中释放。
      if (!_state.mounted) {
        return;
      }
      _disposeRetiredScrollControllers();
      if (generation != _state._tabSwitchGeneration ||
          !pageController.hasClients) {
        return;
      }
      final index = _state._currentIndex;
      if (pageController.page != index.toDouble()) {
        pageController.jumpToPage(index);
      }
    });
  }

  /// 响应底部导航点击：切到其他 Tab 时执行切页动画（切页途中点别的 Tab
  /// 即改道）；重复点击当前 Tab 时把它的主列表滚回顶部（移动端通用的
  /// “回到顶部”手势）。
  Future<void> onTap(int index) {
    if (index == _state._targetIndex && !_state._isTabSwitching) {
      return _scrollTabToTop(index);
    }
    return _switchToTab(index);
  }

  /// 把 [index] 对应 Tab 的主列表滚回顶部。
  ///
  /// - 已在顶部时不做任何事；
  /// - 减少动画时直接跳到顶部；
  /// - 距顶部超过约 3 屏时先无动画跳到 1 屏处，再用 standard 动画收尾：长列表
  ///   若在 350ms 内整段滚过，几十张卡片飞驰而过既晃眼又要逐帧布局大量条目。
  Future<void> _scrollTabToTop(int index) async {
    if (!_state._isValidTabIndex(index)) {
      return;
    }
    // 刚落位、还在画快照时：先换回实时页面，回到顶部的滚动才看得见。
    _state._releaseSnapshots();
    final controller = _state._tabScrollControllers[_state._tabs[index]];
    if (controller == null || !controller.hasClients) {
      return;
    }
    final reduceMotion = ExpressiveMotion.reduceMotion(_state.context);
    // 布局切换的交叉淡入期间可能短暂挂着两个位置，逐个处理。
    await Future.wait<void>(<Future<void>>[
      for (final position in controller.positions.toList(growable: false))
        _scrollPositionToTop(position, reduceMotion: reduceMotion),
    ]);
  }

  Future<void> _scrollPositionToTop(
    ScrollPosition position, {
    required bool reduceMotion,
  }) async {
    final top = position.minScrollExtent;
    if (position.pixels <= top) {
      return;
    }
    if (reduceMotion) {
      position.jumpTo(top);
      return;
    }
    final viewport = position.viewportDimension;
    if (position.pixels - top > viewport * 3) {
      position.jumpTo(top + viewport);
    }
    await position.animateTo(
      top,
      duration: _scrollToTopDuration,
      curve: ExpressiveMotion.effects,
    );
  }

  /// 统一维护目标态、重复点击拦截与动画结束校正。
  ///
  /// 切页途中可以再次切换（点按、快捷键、返回键都一样）：新的一次递增代次、
  /// 接手页面运动（弹簧带着速度改道），上一次的结算因代次不符而作废，只有
  /// 最后一次在停稳后结算。
  Future<void> _switchToTab(int index) async {
    if (index == _state._targetIndex) {
      return;
    }
    if (!_state._isValidTabIndex(index) || !pageController.hasClients) {
      return;
    }

    final generation = _state._beginTabSwitch(index);
    try {
      await _animateToTab(index);
    } finally {
      _state._settleTabSwitch(index, generation);
    }
  }

  /// 切页运动：
  /// - 宽窗口：直接跳页，由 HomeTabEntrance 沿侧边栏方向播放入场（减少
  ///   动画时它直接到位）；
  /// - 减少动画：直接跳页；
  /// - 其余：先按 [HomeTabPageOrder.routeTo] 求路线——目标不在行进方向的
  ///   隔壁时临时换序（可见的页原地不动，必要时同步平移页码），再由
  ///   [PageSpringDriver] 从当前位置、当前速度用弹簧推到目标。跨几个 Tab
  ///   也只滑一页，中间页一帧都不出现；停稳后由 `_settleTabSwitch` 换回
  ///   底栏顺序。
  Future<void> _animateToTab(int index) async {
    if (_state._wide || ExpressiveMotion.reduceMotion(_state.context)) {
      // 跳页不经过中间页，用不着折叠；途中改道到这里时可能仍是折叠的显示
      // 序，先换回（跳页会通知监听者，按新页码刷新）。
      _state._applyPageOrder(_state._pageOrder.restored);
      if (_state._wide) {
        _state._playWideEntrance((index - _state._currentIndex).sign);
      }
      pageController.jumpToPage(index);
      return;
    }
    final position = pageController.position;
    if (!position.hasViewportDimension) {
      _state._applyPageOrder(_state._pageOrder.restored);
      pageController.jumpToPage(index);
      return;
    }
    final route = _state._pageOrder.routeTo(
      _state._tabs[index],
      page: pageController.page ?? _state._currentDisplayIndex().toDouble(),
      velocity: _pageSpring.velocity,
    );
    _state._applyPageOrder(route.order, pageShift: route.pageShift);
    final extent = position.viewportDimension * pageController.viewportFraction;
    await _pageSpring.springTo(position, route.targetPage * extent);
  }

  /// 切到第 [index] 个可见 Tab（快捷键 Ctrl/⌘+数字）；越界或已在该 Tab
  /// 时什么也不做（不像点按底栏那样回到顶部）。
  Future<void> switchToIndex(int index) {
    if (!_state._isValidTabIndex(index)) {
      return Future<void>.value();
    }
    return _switchToTab(index);
  }

  Future<void> switchToDiariesTab() => switchToHomeTab(HomeTab.diaries);

  /// 切到 [tab]；它因功能关闭不可见时什么也不做。
  Future<void> switchToHomeTab(HomeTab tab) {
    final index = _state._tabs.indexOf(tab);
    if (index < 0) return Future<void>.value();
    return _switchToTab(index);
  }

  /// 若存在启动提示并且尚未展示，则在首帧后展示一次。
  void _showStartupNoticeIfNeeded() {
    final notice = _state.widget.startupNotice?.trim();
    if (notice == null ||
        notice.isEmpty ||
        notice == _state._shownStartupNotice) {
      return;
    }
    _state._shownStartupNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_state.mounted) {
        return;
      }
      unawaited(() async {
        await HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: SnackBar(
            content: Text(notice),
            duration: const Duration(seconds: 2),
          ),
        );
      }());
    });
  }
}
