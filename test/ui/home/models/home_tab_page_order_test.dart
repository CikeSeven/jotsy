import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';
import 'package:node_diary/ui/home/models/home_tab_page_order.dart';

const HomeTab _calendar = HomeTab.calendar;
const HomeTab _diaries = HomeTab.diaries;
const HomeTab _todos = HomeTab.todos;
const HomeTab _explore = HomeTab.explore;

/// 四个 Tab 都开启时的底栏顺序：日历 · 日记 · 待办 · 探索。
final List<HomeTab> _bar = <HomeTab>[_calendar, _diaries, _todos, _explore];

void main() {
  test('the canonical order maps pages to the bar one to one', () {
    final order = HomeTabPageOrder.canonical(_bar);
    expect(order.isCanonical, isTrue);
    expect(order.barPosition(1.25), 1.25);
    // 越界回弹的页码原样给出。
    expect(order.barPosition(-0.1), -0.1);
    expect(order.restored, same(order));
  });

  test('an adjacent target keeps the order and needs no shift', () {
    final order = HomeTabPageOrder.canonical(_bar);
    final route = order.routeTo(_todos, page: 1);
    expect(route.order, same(order));
    expect(route.pageShift, 0);
    expect(route.targetPage, 2);
  });

  test('a far target to the right is folded next to the current page', () {
    final order = HomeTabPageOrder.canonical(_bar);
    final route = order.routeTo(_explore, page: 0);
    expect(route.order.order, <HomeTab>[_calendar, _explore, _diaries, _todos]);
    expect(route.order.tabs, _bar);
    // 当前页的下标不变，不用平移。
    expect(route.pageShift, 0);
    expect(route.targetPage, 1);
    // 页码 0 → 1 对应底栏 0 → 3：指示器直接滑向探索。
    expect(route.order.barPosition(0.5), 1.5);
    expect(route.order.barPosition(1), 3);
    expect(route.order.restored.order, _bar);
  });

  test('a far target to the left is folded on the left side', () {
    final order = HomeTabPageOrder.canonical(_bar);
    final route = order.routeTo(_calendar, page: 3);
    expect(route.order.order, <HomeTab>[_diaries, _todos, _calendar, _explore]);
    expect(route.pageShift, 0);
    expect(route.targetPage, 2);
  });

  test('retargeting mid-flight keeps the visible pages in place', () {
    // 日历 → 探索折叠途中（页码 0.5，日历与探索各露一半），改点待办。
    final folded = HomeTabPageOrder.canonical(
      _bar,
    ).routeTo(_explore, page: 0).order;
    final route = folded.routeTo(_todos, page: 0.5, velocity: 800);
    expect(route.order.order, <HomeTab>[_calendar, _explore, _todos, _diaries]);
    expect(route.pageShift, 0);
    expect(route.targetPage, 2);
  });

  test('a retarget past the last slot shifts the visible pages', () {
    // 探索 → 日历折叠途中（页码 2.5，日历与探索在最后两格），底栏位置 1.5，
    // 改点待办（底栏 2，在右边）：右边没有空位，可见的两页整体前移一格。
    final folded = HomeTabPageOrder.canonical(
      _bar,
    ).routeTo(_calendar, page: 3).order;
    expect(folded.barPosition(2.5), 1.5);
    final route = folded.routeTo(_todos, page: 2.5);
    expect(route.order.order, <HomeTab>[_diaries, _calendar, _explore, _todos]);
    expect(route.pageShift, -1);
    expect(route.targetPage, 3);
    // 平移后画面不变：同样的两页、同样的底栏位置。
    expect(route.order.barPosition(2.5 + route.pageShift), 1.5);
  });

  test(
    'when the bar position already sits on the target, velocity decides',
    () {
      final folded = HomeTabPageOrder.canonical(
        _bar,
      ).routeTo(_explore, page: 0).order;
      // 页码 1/3 处底栏位置正好是日记（1）。
      const page = 1 / 3;
      expect(folded.barPosition(page), closeTo(1, 1e-9));

      final forward = folded.routeTo(_diaries, page: page, velocity: 500);
      expect(forward.order, same(folded));
      expect(forward.targetPage, 2);

      final backward = folded.routeTo(_diaries, page: page, velocity: -500);
      expect(backward.order.order, <HomeTab>[
        _diaries,
        _calendar,
        _explore,
        _todos,
      ]);
      expect(backward.pageShift, 1);
      expect(backward.targetPage, 0);
    },
  );

  test('three tabs fold only across the middle one', () {
    final order = HomeTabPageOrder.canonical(<HomeTab>[
      _calendar,
      _diaries,
      _explore,
    ]);
    expect(order.routeTo(_diaries, page: 0).order, same(order));
    final route = order.routeTo(_explore, page: 0);
    expect(route.order.order, <HomeTab>[_calendar, _explore, _diaries]);
    expect(route.targetPage, 1);
  });
}
