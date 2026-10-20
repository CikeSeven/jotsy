import 'package:flutter/widgets.dart';

import '../../models/home_bar_style/home_bar_behavior.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';

/// 把首页栏已解析的外观与行为向下传给底栏与四个 Tab 的顶栏。
///
/// 首页在主题、高对比度与用户样式变化时解析一次 [HomeBarResolvedStyle]，
/// 各栏只读这里，不再各自 watch provider 或重复解析。不在首页之下的
/// 用法（独立使用的页头、单页测试）读不到 scope，一律按实色栏渲染。
class HomeChromeScope extends InheritedWidget {
  const HomeChromeScope({
    super.key,
    required this.style,
    this.behavior = HomeBarBehavior.defaults,
    required super.child,
  });

  final HomeBarResolvedStyle style;
  final HomeBarBehavior behavior;

  static HomeChromeScope? _maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeChromeScope>();

  /// 首页栏外观；不在首页之下时为 null。
  static HomeBarResolvedStyle? maybeStyleOf(BuildContext context) =>
      _maybeOf(context)?.style;

  /// 首页栏行为；不在首页之下时为默认行为。
  static HomeBarBehavior behaviorOf(BuildContext context) =>
      _maybeOf(context)?.behavior ?? HomeBarBehavior.defaults;

  /// 顶栏是否用玻璃；没有 scope 时为 false（实色）。
  static bool glassTopBarsOf(BuildContext context) =>
      maybeStyleOf(context)?.glassTopBars ?? false;

  @override
  bool updateShouldNotify(HomeChromeScope oldWidget) =>
      style != oldWidget.style || behavior != oldWidget.behavior;
}
