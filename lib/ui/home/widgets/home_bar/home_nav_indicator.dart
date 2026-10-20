import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import 'home_nav_layout.dart';

/// 选中指示器。用 [Ink] 画在外层 Material 上（与 M3 相同），点按的水波纹
/// 才会盖在指示器上面而不是被它挡住。
///
/// - 未跟随滑动：选中时先跳到 40% 宽再横向长满（ExpressiveMotion.spatial），
///   取消选中时缩回并消失；
/// - 跟随滑动：只有锚点项显示（其余缩放为 0），位置由布局 delegate 平移。
class HomeNavIndicator extends StatelessWidget {
  const HomeNavIndicator({
    super.key,
    required this.selection,
    required this.position,
    required this.index,
    required this.count,
    required this.shape,
    required this.color,
  });

  final Animation<double> selection;
  final ValueListenable<double>? position;
  final int index;
  final int count;
  final ShapeBorder shape;
  final Color color;

  double _scale() {
    final position = this.position;
    if (position != null) {
      return HomeNavGeometry.followAnchor(position.value, count) == index
          ? 1
          : 0;
    }
    if (selection.isDismissed) {
      return 0;
    }
    return 0.4 + 0.6 * ExpressiveMotion.spatial.transform(selection.value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: position ?? selection,
      builder: (BuildContext context, Widget? child) => Transform(
        alignment: Alignment.center,
        // 只横向缩放。
        transform: Matrix4.diagonal3Values(_scale(), 1, 1),
        child: child,
      ),
      child: Ink(
        decoration: ShapeDecoration(shape: shape, color: color),
      ),
    );
  }
}
