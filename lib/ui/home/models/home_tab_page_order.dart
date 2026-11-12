// 首页 PageView 的子页顺序（显示序）与底栏顺序（规范序）。
//
// 为什么要有两种顺序：点按底栏跨过几个 Tab（日历 → 探索）时，如果按底栏
// 顺序滑过去，中间的日记、待办会整页掠过；旧做法是先瞬间跳到目标的隔壁再
// 滑一页，内容会“闪换”一下。改为在切页期间临时把目标排到当前页隔壁（显示
// 序），只滑一页，停稳后再换回底栏顺序（规范序）。PageView 的子页以 Tab
// 身份为 key，换序时按 key 搬家，保活状态不丢。
//
// 输入：规范序（可见 Tab 列表）、当前的小数页码与行进速度；输出：新的显示
// 序与页码平移量。纯数据，无副作用，可单测。

import 'package:flutter/foundation.dart';

import 'home_tab.dart';

/// 首页 PageView 的子页顺序。
///
/// [tabs] 是底栏从左到右的顺序（规范序），[order] 是 PageView 实际的子页
/// 顺序（显示序）；静止时两者相同，只在跨页切换的途中不同。
@immutable
class HomeTabPageOrder {
  /// 显示序等于规范序。
  HomeTabPageOrder.canonical(List<HomeTab> tabs)
    : tabs = List<HomeTab>.unmodifiable(tabs),
      order = List<HomeTab>.unmodifiable(tabs);

  HomeTabPageOrder._(this.tabs, List<HomeTab> order)
    : order = List<HomeTab>.unmodifiable(order);

  /// 规范序：底栏 / 侧边栏的顺序。
  final List<HomeTab> tabs;

  /// 显示序：PageView 子页的顺序。
  final List<HomeTab> order;

  /// 小于它的小数部分视为整页（浮点误差）。
  static const double _pageEpsilon = 1e-6;

  int get length => tabs.length;

  bool get isCanonical => listEquals(tabs, order);

  /// 换回规范序。
  HomeTabPageOrder get restored =>
      isCanonical ? this : HomeTabPageOrder.canonical(tabs);

  /// [tab] 在显示序中的下标；不在可见列表里时为 -1。
  int displayIndexOf(HomeTab tab) => order.indexOf(tab);

  /// 显示下标 [display] 对应的规范下标。
  int barIndexOfDisplay(int display) => tabs.indexOf(order[display]);

  /// 显示序下的小数页码换算到底栏上的小数位置（“指示器跟随滑动”用）。
  ///
  /// 规范序下原样返回（含越界回弹时的负值与超出值）。折叠途中在相邻两个
  /// 显示页的规范下标之间按小数插值：日历(0) → 探索(3) 折叠成隔壁时，页码
  /// 0 → 1 对应底栏 0 → 3，指示器直接滑向探索，不会在中间的项上停留。
  double barPosition(double displayPage) {
    if (isCanonical || length < 2) {
      return displayPage;
    }
    final last = length - 1;
    final floor = displayPage.floor().clamp(0, last);
    final ceil = displayPage.ceil().clamp(0, last);
    final from = barIndexOfDisplay(floor).toDouble();
    if (floor == ceil) {
      // 越界（弹簧在首尾页的微小过冲）：保持单位斜率。
      return from + (displayPage - floor);
    }
    final to = barIndexOfDisplay(ceil).toDouble();
    return from + (displayPage - floor) * (to - from);
  }

  /// 从小数页码 [page]（显示序）出发前往 [target] 的路线。
  ///
  /// 方向取底栏上的方向：`sign(目标的规范下标 − 当前的 barPosition)`，正好
  /// 落在目标上时按 [velocity]（页码方向的速度，只看符号）定，仍为 0 时按
  /// 显示序里的相对位置。目标从指示器移动的那一侧进来，空间上与底栏一致。
  ///
  /// - 目标就在行进方向上、中间不隔着看不见的页（可见的一两页本来就在画面
  ///   里，经过它们不算“掠过”）：显示序不变，直接去；
  /// - 否则把目标从列表中取出，插到可见块（`floor(page)`..`ceil(page)`）的
  ///   行进方向一侧，可见块的相对顺序不变。目标原本在可见块之前时，可见块
  ///   整体前移一格，[HomeTabRoute.pageShift] 给出页码要补的量（调用方
  ///   `correctPixels`），画面不动。
  HomeTabRoute routeTo(
    HomeTab target, {
    required double page,
    double velocity = 0,
  }) {
    final targetDisplay = displayIndexOf(target);
    assert(targetDisplay >= 0, '$target is not a visible tab');
    final last = length - 1;
    final clampedPage = page.clamp(0.0, last.toDouble());
    final rounded = clampedPage.roundToDouble();
    final integral = (clampedPage - rounded).abs() < _pageEpsilon;
    final first = integral ? rounded.toInt() : clampedPage.floor();
    final end = integral ? rounded.toInt() : clampedPage.ceil();

    final barDelta = tabs.indexOf(target) - barPosition(clampedPage);
    var direction = barDelta > _pageEpsilon
        ? 1
        : barDelta < -_pageEpsilon
        ? -1
        : velocity.sign.toInt();
    if (direction == 0) {
      direction = (targetDisplay - clampedPage).sign.toInt();
    }
    final direct = HomeTabRoute(
      order: this,
      pageShift: 0,
      targetPage: targetDisplay,
    );
    if (direction == 0) {
      // 已经停在目标上。
      return direct;
    }
    final reachable = direction > 0
        ? targetDisplay > clampedPage && targetDisplay <= end + 1
        : targetDisplay < clampedPage && targetDisplay >= first - 1;
    if (reachable) {
      return direct;
    }

    final visible = order.sublist(first, end + 1);
    final rest = List<HomeTab>.of(order)..remove(target);
    final blockStart = rest.indexOf(visible.first);
    final insertAt = direction > 0 ? blockStart + visible.length : blockStart;
    rest.insert(insertAt, target);
    final shift = rest.indexOf(visible.first) - first;
    return HomeTabRoute(
      order: HomeTabPageOrder._(tabs, rest),
      pageShift: shift.toDouble(),
      targetPage: rest.indexOf(target),
    );
  }
}

/// [HomeTabPageOrder.routeTo] 的结果。
@immutable
class HomeTabRoute {
  const HomeTabRoute({
    required this.order,
    required this.pageShift,
    required this.targetPage,
  });

  /// 切换途中使用的显示序（不需要换序时为原来的那份）。
  final HomeTabPageOrder order;

  /// 换序后当前页码要加上的量（整页数）；为 0 时不用校正。
  final double pageShift;

  /// 目标在 [order] 中的显示下标，弹簧的终点。
  final int targetPage;
}
