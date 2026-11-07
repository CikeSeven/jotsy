import 'package:flutter/widgets.dart';

/// 按所在位置的可用高度算出悬浮工具栏面板的上限，写进 [limit]；[child]
/// 原样交回，不随高度重建。
///
/// 为什么不用普通 LayoutBuilder 把上限直接当参数传给工具栏：可用高度随
/// 软键盘升降逐帧变化，那样整条工具栏（玻璃底板、全部按钮）会在键盘动画
/// 的每一帧重建，真机上每帧多出 5ms 以上。面板收着时根本用不到上限：
/// 工具栏只在面板展开时监听 [limit]（见 `DiaryFloatingToolbar.maxPanelExtent`），
/// 展开时读到的是最近一次布局写入的值。
///
/// [extentOf] 拿的是布局回调的 context：其中读的 MediaQuery 等依赖变化时
/// 本层重新计算，子树照样不重建。
class DiaryToolbarPanelLimit extends StatelessWidget {
  const DiaryToolbarPanelLimit({
    super.key,
    required this.limit,
    required this.extentOf,
    required this.child,
  });

  final ValueNotifier<double> limit;
  final double Function(BuildContext context, BoxConstraints constraints)
  extentOf;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      limit.value = extentOf(context, constraints);
      return child;
    },
  );
}
