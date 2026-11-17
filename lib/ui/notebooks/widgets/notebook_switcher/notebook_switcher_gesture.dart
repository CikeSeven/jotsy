import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../widgets/directional_drag_recognizer.dart';
import '../../controllers/notebook_switcher_controller.dart';

/// 日记页列表栏外面的右滑手势层：朝行尾方向（LTR 向右）的横向拖动交给
/// [NotebookSwitcherController] 拉出日记本卡组。
///
/// 竞争：
/// - 只接朝行尾的拖动（[DirectionalHorizontalDragGestureRecognizer]），往行首
///   的拖动留给首页翻页的 PageView 与卡片左滑归档；它比 PageView 深，同一次
///   移动里先越过溢出距离，所以朝行尾时先接手；
/// - 纵向滚动照旧：谁先越过自己方向的溢出距离谁接手；
/// - 只认触屏与手写笔：鼠标与触控板拖动不触发（桌面经切换胶囊打开）；
/// - 系统手势边缘（Android 手势导航的返回区）里起手的不参与，交给系统返回。
///
/// 起手方式为 [DragStartBehavior.down]：拉动距离从按下的位置算起，胶囊的
/// 长度与手指走过的距离一一对应。[enabled] 为 false 时（日记本功能关闭、
/// 多选、标签栏展开）不挂识别器，子树结构不变。
class NotebookSwitcherGesture extends StatelessWidget {
  const NotebookSwitcherGesture({
    super.key,
    required this.controller,
    required this.enabled,
    this.onDragStart,
    required this.child,
  });

  final NotebookSwitcherController controller;
  final bool enabled;

  /// 接手一次右滑时（拉动提示据此记一次交互）。
  final VoidCallback? onDragStart;
  final Widget child;

  static const Set<PointerDeviceKind> _devices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final edgeInsets = MediaQuery.systemGestureInsetsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sign = textDirection == TextDirection.ltr ? 1.0 : -1.0;
    bool acceptsPointer(Offset position) => textDirection == TextDirection.ltr
        ? position.dx > edgeInsets.left
        : position.dx < screenWidth - edgeInsets.right;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        if (enabled)
          DirectionalHorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                DirectionalHorizontalDragGestureRecognizer
              >(
                () => DirectionalHorizontalDragGestureRecognizer(
                  debugOwner: this,
                  supportedDevices: _devices,
                  acceptsDirection: (double s) => s == sign,
                ),
                (DirectionalHorizontalDragGestureRecognizer instance) {
                  instance
                    ..acceptsDirection = ((double s) => s == sign)
                    ..acceptsPointer = acceptsPointer
                    ..gestureSettings = gestureSettings
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = (DragStartDetails details) {
                      onDragStart?.call();
                      controller.dragStart(
                        details.globalPosition,
                        textDirection: textDirection,
                      );
                    }
                    ..onUpdate = (DragUpdateDetails details) {
                      controller.dragUpdate(
                        details.globalPosition,
                        details.delta.dx,
                      );
                    }
                    ..onEnd = (DragEndDetails details) {
                      controller.dragEnd(details.velocity.pixelsPerSecond.dx);
                    }
                    ..onCancel = controller.dragCancel;
                },
              ),
      },
      child: child,
    );
  }
}
