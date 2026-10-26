import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/app_platform.dart';

/// 让横向滚动条带在桌面上能用鼠标操作：包住一个横向的 `ListView` /
/// `SingleChildScrollView`（[child] 里第一个横向滚动视图）。
///
/// 为什么需要：Flutter 默认的 [ScrollBehavior] 在桌面上不允许鼠标拖动滚动，
/// 普通鼠标滚轮只给出纵向位移，横向列表收不到——鼠标用户既拖不动、也滚
/// 不动这些条带。
///
/// 行为（只在桌面，手机上原样返回 [child]，结构与改版前一致）：
/// - 拖动：子树的滚动行为复制一份，把鼠标加进 `dragDevices`，按住拖动即可
///   横向滚动（点按仍是点按：拖动要越过触控斜率才开始）；
/// - 滚轮：纵向滚轮位移换算成横向滚动（下滚 = 往后），只在条带还能朝那个
///   方向滚时接管；已经到头（或条带放得下、不能滚）时不接管，事件照常交给
///   外层，页面继续纵向滚动。横向位移为主的事件（触控板横扫、Shift + 滚轮）
///   本就由条带自己处理，这里不管。
///
/// 滚轮的接管经 [PointerSignalResolver]：命中测试里条带比外层的纵向滚动视图
/// 更深，这里先登记，外层的登记即被忽略；不能滚时不登记，外层照常拿到。
class DesktopHorizontalScroll extends StatelessWidget {
  const DesktopHorizontalScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop) return child;
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: <PointerDeviceKind>{
          ...behavior.dragDevices,
          PointerDeviceKind.mouse,
        },
      ),
      child: Builder(
        builder: (BuildContext context) => Listener(
          onPointerSignal: (PointerSignalEvent event) =>
              _handleSignal(context, event),
          child: child,
        ),
      ),
    );
  }

  static void _handleSignal(BuildContext context, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta;
    if (delta.dy == 0 || delta.dx.abs() >= delta.dy.abs()) return;
    final position = _horizontalPosition(context);
    if (position == null || !position.hasContentDimensions) return;
    final target = (position.pixels + delta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent event,
    ) {
      if (position.hasPixels) position.pointerScroll(delta.dy);
    });
  }

  /// [context] 之下第一个横向滚动视图的位置（只在滚轮事件到来时查找）。
  static ScrollPosition? _horizontalPosition(BuildContext context) {
    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement) {
        final state = element.state;
        if (state is ScrollableState &&
            axisDirectionToAxis(state.axisDirection) == Axis.horizontal) {
          found = state.position;
          return;
        }
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }
}
