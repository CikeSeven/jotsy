import 'package:flutter/widgets.dart';

/// 正文里的拖动（段落把手、选区把手）共用的边缘自动滚动参数与目标矩形。

/// 拖动点进入可见区域上下这么近时自动滚动。
const double kDiaryAutoScrollZone = 48;

/// 自动滚动速度：每步最多 20px、用时 1000 / 它 毫秒，即最快约 400px/s。
const double kDiaryAutoScrollVelocity = 20;

/// 交给 [EdgeDraggingAutoScroller.startAutoScrollIfNecessary] 的目标矩形
/// （全局坐标）；[point] 不在边缘时为 null。
///
/// [visibleTop] / [visibleBottom] 为真正看得见的范围（顶部去掉盖在正文上的
/// 固定顶栏与状态栏，底部去掉键盘、导航条与悬浮工具栏），[viewportTop] /
/// [viewportBottom] 为滚动视图本身。滚动器只按视口边判断越界、越出多少滚
/// 多少，所以目标矩形朝外量 [kDiaryAutoScrollZone]，再补上被盖住的那段：
/// 拖动点一进入看得见的边缘就开始滚，越靠外越快。
Rect? diaryEdgeAutoScrollTarget(
  Offset point, {
  required double visibleTop,
  required double visibleBottom,
  required double viewportTop,
  required double viewportBottom,
}) {
  final x = point.dx;
  final y = point.dy;
  if (y < visibleTop + kDiaryAutoScrollZone) {
    return Rect.fromLTRB(
      x,
      y - kDiaryAutoScrollZone - (visibleTop - viewportTop),
      x + 1,
      y,
    );
  }
  if (y > visibleBottom - kDiaryAutoScrollZone) {
    return Rect.fromLTRB(
      x,
      y,
      x + 1,
      y + kDiaryAutoScrollZone + (viewportBottom - visibleBottom),
    );
  }
  return null;
}

/// 拖动途中的边缘自动滚动（段落拖动与段落选择模式的连选共用）：拖动点进入
/// 看得见的范围上下 [kDiaryAutoScrollZone] 时朝那一边滚，越靠外越快，离开
/// 边缘即停。
///
/// 调用方每帧（拖动的 Ticker）都按当前拖动点调用 [update]，滚动器每滚一步
/// 也回调 [onScrolled] 让调用方再给一次目标，手指不动也接着滚：列表滚动范围
/// 要到下一次布局才更新，滚动器若恰在这时判断“滚不动了”会自己停下，只靠
/// 它自己的回调接不上。
class DiaryEdgeAutoScrollDriver {
  DiaryEdgeAutoScrollDriver(this.onScrolled);

  final VoidCallback onScrolled;
  EdgeDraggingAutoScroller? _scroller;

  /// 按拖动点 [point]（全局坐标）与看得见的范围给一次目标；不在边缘时停下。
  void update(
    ScrollableState scrollable,
    Offset point, {
    required double visibleTop,
    required double visibleBottom,
    required double viewportTop,
    required double viewportBottom,
  }) {
    final target = diaryEdgeAutoScrollTarget(
      point,
      visibleTop: visibleTop,
      visibleBottom: visibleBottom,
      viewportTop: viewportTop,
      viewportBottom: viewportBottom,
    );
    if (target == null) {
      _scroller?.stopAutoScroll();
      return;
    }
    final scroller = _scroller ??= EdgeDraggingAutoScroller(
      scrollable,
      onScrollViewScrolled: onScrolled,
      velocityScalar: kDiaryAutoScrollVelocity,
    );
    scroller.startAutoScrollIfNecessary(target);
  }

  /// 拖动结束：停下并丢掉滚动器（下次拖动重新绑定滚动视图）。
  void stop() {
    _scroller?.stopAutoScroll();
    _scroller = null;
  }
}
