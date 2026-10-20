import 'package:flutter/widgets.dart';

import 'calendar_header.dart';

/// 按月份行已收起的高度（0 ~ [CalendarHeader.monthBarHeight]）构建页头。
typedef CalendarHeaderBuilder =
    Widget Function(BuildContext context, double collapsedExtent);

/// 日历页头 sliver：固定在顶部，月份行随内容滚动收起，只留标题栏。
///
/// 作为页面 CustomScrollView 的第一个 sliver：最大高度为状态栏 + 标题栏 +
/// 月份行，最小高度为状态栏 + 标题栏。下滑的前
/// [CalendarHeader.monthBarHeight] 里，月份行与下方日历同步上移、收进标题栏
/// 下缘；之后页头停在只剩标题栏的高度，内容从它下方滑过（固定的 sliver
/// 画在后面的 sliver 之上，玻璃时内容透出并被模糊）。滚回顶部时月份行随之
/// 展开。不做吸附：停在半途就和内容一样停在半途。
///
/// 收起量直接取自 sliver 布局时的 shrinkOffset，与滚动位置在同一次布局里
/// 算出：
/// - 不需要另挂滚动控制器——日历的主列表要继承首页按 Tab 下发的
///   PrimaryScrollController，“重复点击当前 Tab 回到顶部”才对日历生效；
/// - 内容变矮（切到周视图、换到没有日记的一天）使滚动位置在布局阶段被
///   校正时，页头与内容在同一帧对齐，不会先错开一帧。
class CalendarHeaderSliver extends StatelessWidget {
  const CalendarHeaderSliver({super.key, required this.builder});

  /// 通常返回把收起量传给 [CalendarHeader.collapsedExtent] 的 [CalendarHeader]；
  /// 它的高度必须等于状态栏 + [CalendarHeader.contentHeight] − 收起量。
  final CalendarHeaderBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CalendarHeaderDelegate(
        topInset: MediaQuery.paddingOf(context).top,
        builder: builder,
      ),
    );
  }
}

class _CalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CalendarHeaderDelegate({
    required this.topInset,
    required this.builder,
  });

  /// 页头铺到状态栏下面，状态栏这一段始终在固定高度里。
  final double topInset;
  final CalendarHeaderBuilder builder;

  @override
  double get maxExtent => topInset + CalendarHeader.contentHeight;

  @override
  double get minExtent => topInset + CalendarHeader.titleBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 固定 sliver 的 shrinkOffset 随滚动一直增长到 maxExtent，可收起的
    // 只有月份行，夹到它的高度以内即为月份行被收起的高度。
    return builder(
      context,
      shrinkOffset.clamp(0.0, CalendarHeader.monthBarHeight),
    );
  }

  /// 页面每次重建都会传入新的 builder（其中的标题、提示与筛选状态可能
  /// 已变），按引用比较即可让页头跟着重建；纯滚动不会走到这里。
  @override
  bool shouldRebuild(covariant _CalendarHeaderDelegate oldDelegate) {
    return oldDelegate.topInset != topInset || oldDelegate.builder != builder;
  }
}
