import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter/widgets.dart';

import '../../controllers/diary_editor_controller.dart';

/// 正文此刻看得见的纵向范围（全局纵坐标）。
///
/// - [top] / [bottom]：真正看得见的部分；
/// - [viewportTop] / [viewportBottom]：滚动视图本身。
typedef DiaryEditorVisibleRange = ({
  double top,
  double bottom,
  double viewportTop,
  double viewportBottom,
});

/// 正文所在的纵向滚动视图：编辑页为正文自己的列表，收缩嵌入阅读页
/// （[pageScroll]）时为外层页面的纵向滚动视图。正文已关闭、还没挂上滚动
/// 视图或滚动方向不是纵向时为 null。
ScrollableState? diaryEditorScrollable(
  BuildContext context,
  DiaryEditorController controller, {
  required bool pageScroll,
}) {
  if (controller.isDisposed) return null;
  final scrollable = pageScroll
      ? Scrollable.maybeOf(context, axis: Axis.vertical)
      : controller.state.scrollableState;
  if (scrollable == null ||
      !scrollable.mounted ||
      axisDirectionToAxis(scrollable.axisDirection) != Axis.vertical) {
    return null;
  }
  return scrollable;
}

/// 正文看得见的范围；拖选区把手的边缘自动滚动与手机选区菜单（跟随、
/// 避让与离开可见范围时隐藏）共用这一口径：
/// - 编辑页（正文自己的列表）：滚动视图的范围，底部去掉键盘与叠在正文底部
///   的浮层 [coveredHeight]（悬浮工具栏连同展开的面板、录音面板等，与
///   `DiaryEditorViewport` 的光标避让同源）；
/// - 收缩嵌入阅读页（[pageScroll]）：顶部再去掉盖在正文所在 sliver 上的固定 /
///   浮出顶栏与状态栏，底部再去掉导航条。
///
/// 只在指针事件与帧回调里调用（读取上一次布局的结果，不参与布局）。滚动
/// 视图还没布局或被盖满时为 null。
DiaryEditorVisibleRange? diaryEditorVisibleRange(
  BuildContext context,
  DiaryEditorController controller, {
  required bool pageScroll,
  required double coveredHeight,
}) {
  final box = diaryEditorScrollable(
    context,
    controller,
    pageScroll: pageScroll,
  )?.context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  final viewportTop = box.localToGlobal(Offset.zero).dy;
  final viewportBottom = viewportTop + box.size.height;
  final view = View.of(context);
  final ratio = view.devicePixelRatio;
  final screen = view.physicalSize.height / ratio;
  var top = viewportTop;
  var bottom =
      math.min(viewportBottom, screen - view.viewInsets.bottom / ratio) -
      coveredHeight;
  if (pageScroll) {
    top = math.max(
      viewportTop + _headerOverlap(context),
      view.viewPadding.top / ratio,
    );
    bottom = math.min(bottom, screen - view.viewPadding.bottom / ratio);
  }
  if (bottom <= top) return null;
  return (
    top: top,
    bottom: bottom,
    viewportTop: viewportTop,
    viewportBottom: viewportBottom,
  );
}

/// 嵌入阅读页时，固定或浮出的顶栏（`SliverAppBar`）盖在正文所在 sliver
/// 上的高度。
double _headerOverlap(BuildContext context) {
  for (
    RenderObject? node = context.findRenderObject();
    node != null;
    node = node.parent
  ) {
    // 只在指针事件与帧回调里读取上一次布局的约束，不参与布局。
    if (node is RenderSliver) return math.max(0, node.constraints.overlap);
  }
  return 0;
}
