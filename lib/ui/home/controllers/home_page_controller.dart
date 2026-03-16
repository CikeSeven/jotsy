part of 'package:node_diary/ui/home/pages/home_page.dart';

/// Home 页控制器。
///
/// 职责边界：
/// - 处理底部导航页切换；
/// - 处理启动提示仅展示一次逻辑；
/// - 不直接构建 UI。
class _HomePageController {
  _HomePageController(this._state);

  static const Duration _pageSwitchDuration = Duration(milliseconds: 270);
  static const Curve _pageSwitchCurve = Curves.easeOutCirc;

  final _HomePageState _state;
  late final PageController pageController;

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

  /// 系统返回键回退到日记首页 tab。
  ///
  /// 只在当前不处于日记页时调用，动画与底部导航点击保持一致。
  void switchToDiariesTab() {
    onTap(0);
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
