part of 'package:node_diary/ui/home/pages/home_page.dart';

/// Home 页控制器。
///
/// 职责边界：
/// - 处理底部导航页切换；
/// - 处理启动提示仅展示一次逻辑；
/// - 不直接构建 UI。
class _HomePageController {
  _HomePageController(this._state);

  static const Duration _pageSwitchDuration = ExpressiveMotion.medium;

  final _HomePageState _state;
  late final PageController pageController;
  Curve pageSwitchCurve = SettingsService.defaultHomeTabSwitchCurveType.curve;

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
  }

  /// 响应底部导航点击并执行页面切换动画。
  Future<void> onTap(int index) {
    return _switchToTab(index, allowDuringSwitch: false);
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
  /// - 减少动画时直接跳页；
  /// - 跨多页时先无动画跳到目标的相邻页，只动画最后一页，避免 250ms 内
  ///   把中间的日历/探索页整页滑过（既晃眼又要额外布局绘制中间页）。
  Future<void> _animateToTab(int index) async {
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

  Future<void> switchToDiariesTab() {
    return _switchToTab(0, allowDuringSwitch: true);
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
