import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 把 [PageController] 的小数页码包装成 `ValueListenable<double>`，交给底栏
/// 让选中指示器跟随滑动。
///
/// - 值：控制器挂着唯一的页面位置且已有尺寸时取 `page`，否则（首帧之前、
///   布局切换的瞬间）退回 [fallbackIndex]，不会读到 null 或触发断言；
/// - 通知：转发控制器的每次变化，值没变时不通知（静止时不让底栏重绘）；
/// - 生命周期：由创建者在控制器释放前 [dispose]，解除对控制器的监听。
class PagePositionListenable extends ChangeNotifier
    implements ValueListenable<double> {
  PagePositionListenable(this._controller, this.fallbackIndex) {
    _last = value;
    _controller.addListener(_handleChange);
  }

  final PageController _controller;

  /// 读不到页码时使用的下标（通常是当前 Tab）。
  final ValueGetter<int> fallbackIndex;
  double _last = 0;

  @override
  double get value {
    final controller = _controller;
    if (controller.positions.length == 1) {
      final page = controller.page;
      if (page != null) {
        return page;
      }
    }
    return fallbackIndex().toDouble();
  }

  void _handleChange() {
    final next = value;
    if (next == _last) {
      return;
    }
    _last = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    super.dispose();
  }
}
