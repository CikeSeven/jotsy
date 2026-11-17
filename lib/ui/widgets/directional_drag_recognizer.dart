import 'package:flutter/gestures.dart';

/// 只接手朝指定一侧的横向拖动；朝另一侧的拖动留在竞争里不接手，交给外层
/// （首页左右翻页的 PageView、卡片外面的手势）。
///
/// 为什么不直接用 [HorizontalDragGestureRecognizer]：它只看横向位移的绝对值，
/// 朝哪边越过触摸溢出距离都会接手。嵌在 PageView 里的组件只想要一个方向时，
/// 另一个方向也被它吞掉，外层永远拿不到。
///
/// 判定只改“够不够接手”这一步：位移朝允许的一侧且超过溢出距离才接手，
/// 其余行为（速度、更新、取消）与父类一致。同一次按下先往反方向挪了一点
/// 再拐回来，按净位移判定。[acceptsDirection] 每次判定时调用，宿主可以随
/// [TextDirection] 或状态切换允许的方向。
class DirectionalHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  DirectionalHorizontalDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    required this.acceptsDirection,
    this.acceptsPointer,
  });

  /// 净横向位移的方向（全局坐标，+1 向右、-1 向左）是否接手。
  bool Function(double sign) acceptsDirection;

  /// 按下的位置是否参与竞争（null 为都参与）：例如系统手势边缘里起手的
  /// 交给系统返回，不在这里起一个拉不完的手势。
  bool Function(Offset globalPosition)? acceptsPointer;

  @override
  bool isPointerAllowed(PointerEvent event) {
    final filter = acceptsPointer;
    if (filter != null && !filter(event.position)) {
      return false;
    }
    return super.isPointerAllowed(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final moved = globalDistanceMoved;
    if (moved == 0 || !acceptsDirection(moved.sign)) {
      return false;
    }
    return super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    );
  }
}
