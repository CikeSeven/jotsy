import 'package:flutter/widgets.dart';

/// “滚动时隐藏底栏”的判定（纯逻辑，不持有界面状态）。
///
/// 输入：首页 PageView 之下冒泡上来的滚动通知；输出：底栏应隐藏（true）、
/// 应显示（false），或维持现状（null）。无副作用，状态只有按方向累计的
/// 滚动量。
///
/// 规则：
/// - 只看纵向的 [ScrollUpdateNotification]：PageView 自己左右翻页、页内的
///   横向标签条都会冒泡上来，不能让它们触发显隐；
/// - 同一方向连续累计，方向一变就从这一笔重新累计：手指来回小幅抖动不会
///   让底栏反复闪动，要朝一个方向滚过 [threshold] 才算数；
/// - 往下滚（内容上移，delta > 0）超过阈值时隐藏，但仍贴在顶端时不隐藏
///   （列表很短或刚开始拖动，藏起来反而找不到导航）；
/// - 往回滚超过阈值、或回到顶端时显示；
/// - 每次给出结论后清零，下一次显隐要重新累计满阈值。
class HomeBarScrollHider {
  /// 同一方向累计超过这个距离（dp）才改变显隐。
  static const double threshold = 8;

  double _accumulated = 0;

  /// 清空累计量（切 Tab、提示出现等外部原因让底栏显示时调用）。
  void reset() => _accumulated = 0;

  bool? handle(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) {
      return null;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return null;
    }
    if (metrics.pixels <= metrics.minScrollExtent) {
      _accumulated = 0;
      return false;
    }
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) {
      return null;
    }
    if (_accumulated != 0 && delta.sign != _accumulated.sign) {
      _accumulated = 0;
    }
    _accumulated += delta;
    if (_accumulated > threshold) {
      _accumulated = 0;
      return true;
    }
    if (_accumulated < -threshold) {
      _accumulated = 0;
      return false;
    }
    return null;
  }
}
