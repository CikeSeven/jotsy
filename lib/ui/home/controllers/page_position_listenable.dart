import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 把 [PageController] 的小数页码包装成 `ValueListenable<double>`：交给底栏
/// 让选中指示器跟随滑动，交给首页背景与翻页景深按页位置插值。
///
/// - 值：控制器挂着唯一的页面位置且已有尺寸时取 `page`，否则（首帧之前、
///   布局切换的瞬间）退回 [fallbackIndex]，不会读到 null 或触发断言；有
///   [map] 时再经它换算（首页把显示序的页码换算成底栏上的位置，见
///   `HomeTabPageOrder.barPosition`）；
/// - 通知：转发控制器的每次变化，值没变时不通知（静止时不让底栏重绘）；
///   `correctPixels` 与换序不经过控制器的通知，调用方随后调 [refresh]；
/// - 生命周期：由创建者在控制器释放前 [dispose]，解除对控制器的监听。
class PagePositionListenable extends ChangeNotifier
    implements ValueListenable<double> {
  PagePositionListenable(this._controller, this.fallbackIndex, {this.map}) {
    _last = value;
    _controller.addListener(refresh);
  }

  final PageController _controller;

  /// 读不到页码时使用的下标（与页码同一口径，通常是当前页）。
  final ValueGetter<int> fallbackIndex;

  /// 页码的换算；null 时原样给出。
  final double Function(double page)? map;
  double _last = 0;

  /// 未经 [map] 换算的页码。
  double get page {
    final controller = _controller;
    if (controller.positions.length == 1) {
      final page = controller.page;
      if (page != null) {
        return page;
      }
    }
    return fallbackIndex().toDouble();
  }

  @override
  double get value {
    final map = this.map;
    return map == null ? page : map(page);
  }

  /// 重新读取页码，变化时通知。
  void refresh() {
    final next = value;
    if (next == _last) {
      return;
    }
    _last = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(refresh);
    super.dispose();
  }
}
