part of 'package:node_diary/ui/home/pages/home_page.dart';

/// Home 页控制器。
///
/// 职责边界：
/// - 处理底部导航页切换与进度同步；
/// - 处理启动提示仅展示一次逻辑；
/// - 不直接构建 UI。
class HomePageController {
  HomePageController(this._state);

  static const Duration _pageSwitchDuration = Duration(milliseconds: 270);
  static const Curve _pageSwitchCurve = Curves.easeOutCirc;

  final _HomePageState _state;
  late final PageController pageController;

  void init() {
    pageController = PageController(initialPage: _state._currentIndex);
    pageController.addListener(_onPageScroll);
    _showStartupNoticeIfNeeded();
  }

  void handleWidgetUpdate(HomePage oldWidget) {
    if (oldWidget.startupNotice != _state.widget.startupNotice) {
      _showStartupNoticeIfNeeded();
    }
  }

  void dispose() {
    pageController.removeListener(_onPageScroll);
    pageController.dispose();
  }

  /// 响应底部导航点击并执行页面切换动画。
  void onTap(int index) {
    if (index == _state._currentIndex) {
      return;
    }
    pageController.animateToPage(
      index,
      duration: _pageSwitchDuration,
      curve: _pageSwitchCurve,
    );
  }

  void _onPageScroll() {
    final value = pageController.page ?? _state._currentIndex.toDouble();
    if ((value - _state._pageProgress).abs() < 0.0001) {
      return;
    }
    _state.setState(() {
      _state._pageProgress = value;
    });
  }

  /// 若存在启动提示并且尚未展示，则在首帧后展示一次。
  void _showStartupNoticeIfNeeded() {
    final notice = _state.widget.startupNotice?.trim();
    if (notice == null || notice.isEmpty || notice == _state._shownStartupNotice) {
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
