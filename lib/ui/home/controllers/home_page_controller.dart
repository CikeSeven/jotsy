part of 'package:node_diary/ui/home/pages/home_page.dart';

/// Home 页控制器。
///
/// 职责边界：
/// - 处理底部导航页切换；
/// - 功能管理开关改变可见 Tab 时，对齐页面下标并回收被关闭的 Tab；
/// - 处理启动提示仅展示一次逻辑；
/// - 不直接构建 UI。
class _HomePageController {
  _HomePageController(this._state);

  static const Duration _pageSwitchDuration = ExpressiveMotion.medium;
  static const Duration _scrollToTopDuration = ExpressiveMotion.standard;

  final _HomePageState _state;
  late final PageController pageController;
  Curve pageSwitchCurve = SettingsService.defaultHomeTabSwitchCurveType.curve;

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
      final controller = _state._tabScrollControllers.remove(tab);
      if (controller != null) {
        _retiredScrollControllers.add(controller);
      }
    }

    _state._tabs = List<HomeTab>.unmodifiable(next);
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

  /// 响应底部导航点击：切到其他 Tab 时执行切页动画；重复点击当前 Tab 时
  /// 把它的主列表滚回顶部（移动端通用的“回到顶部”手势）。
  Future<void> onTap(int index) {
    if (index == _state._targetIndex && !_state._isTabSwitching) {
      return _scrollTabToTop(index);
    }
    return _switchToTab(index, allowDuringSwitch: false);
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
  /// 底部导航点击不允许打断正在进行的切页，避免多段动画竞争；系统返回
  /// 则允许回到日记页，因为 PopScope 已经基于目标态拦截了本次退出。
  Future<void> _switchToTab(
    int index, {
    required bool allowDuringSwitch,
  }) async {
    if (_state._isTabSwitching && !allowDuringSwitch) {
      return;
    }
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

  /// 切页动画：
  /// - 宽窗口直接跳页并淡入（见上）；
  /// - 减少动画时直接跳页；
  /// - 跨多页时先无动画跳到目标的相邻页，只动画最后一页，避免 250ms 内
  ///   把中间的日历/探索页整页滑过（既晃眼又要额外布局绘制中间页）。
  ///   下标是当前可见列表中的位置，关闭了中间的 Tab 时自然只剩一步。
  Future<void> _animateToTab(int index) async {
    // 宽窗口不滑动：直接跳到目标页，由 HomeTabEntrance 播放淡入与轻微放大
    // （减少动画时它直接到位）。
    if (_state._wide) {
      _state._playWideEntrance();
      pageController.jumpToPage(index);
      return;
    }
    if (ExpressiveMotion.reduceMotion(_state.context)) {
      pageController.jumpToPage(index);
      return;
    }
    final currentPage = (pageController.page ?? _state._currentIndex).round();
    if ((index - currentPage).abs() > 1) {
      pageController.jumpToPage(index > currentPage ? index - 1 : index + 1);
    }
    await pageController.animateToPage(
      index,
      duration: _pageSwitchDuration,
      curve: pageSwitchCurve,
    );
  }

  /// 切到第 [index] 个可见 Tab（快捷键 Ctrl/⌘+数字）；越界或已在该 Tab
  /// 时什么也不做（不像点按底栏那样回到顶部）。
  Future<void> switchToIndex(int index) {
    if (!_state._isValidTabIndex(index)) {
      return Future<void>.value();
    }
    return _switchToTab(index, allowDuringSwitch: false);
  }

  Future<void> switchToDiariesTab() {
    return _switchToTab(
      _state._tabs.indexOf(HomeTab.diaries),
      allowDuringSwitch: true,
    );
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
