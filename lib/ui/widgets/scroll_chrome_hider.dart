import 'package:flutter/widgets.dart';

/// “滚动时隐藏外壳”的判定（纯逻辑，不持有界面状态）：首页悬浮底栏与日记
/// 页的浮岛顶栏共用。
///
/// 输入：页面里冒泡上来的滚动通知；输出：外壳应隐藏（true）、应显示
/// （false），或维持现状（null）。无副作用，状态只有按方向累计的滚动量。
///
/// 规则：
/// - 只看纵向的 [ScrollUpdateNotification]：左右翻页的 PageView、页内的
///   横向标签条都会冒泡上来，不能让它们触发显隐；
/// - 同一方向连续累计，方向一变就从这一笔重新累计：手指来回小幅抖动不会
///   让外壳反复闪动，要朝一个方向滚过 [threshold] 才算数；
/// - 往下滚（内容上移，delta > 0）超过阈值时隐藏，但仍贴在顶端时不隐藏
///   （内容很短或刚开始拖动，藏起来反而找不到操作）；
/// - 往回滚超过阈值、或回到顶端时显示；[revealAtEnd] 时滚到底端也显示
///   （读完一篇时顺手就能点到返回与“更多”）；
/// - 每次给出结论后清零，下一次显隐要重新累计满阈值。
class ScrollChromeHider {
  ScrollChromeHider({this.revealAtEnd = false});

  /// 同一方向累计超过这个距离（dp）才改变显隐。
  static const double threshold = 8;

  /// 滚到底端时是否显示。
  final bool revealAtEnd;

  double _accumulated = 0;

  /// 清空累计量（切页、提示出现等外部原因让外壳显示时调用）。
  void reset() => _accumulated = 0;

  bool? handle(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) {
      return null;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return null;
    }
    if (metrics.pixels <= metrics.minScrollExtent ||
        revealAtEnd &&
            metrics.maxScrollExtent > metrics.minScrollExtent &&
            metrics.pixels >= metrics.maxScrollExtent) {
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
