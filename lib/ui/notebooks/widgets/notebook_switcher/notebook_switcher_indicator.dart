import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 左缘胶囊里的指示：叠放图标随拉动从 0.5 放大到 1；拉过阈值（武装）时
/// 背后弹出一个 `primary` 实色圆底（[armPop]，弹簧可略越过 1），图标从胶囊
/// 底色（次要容器色）上的前景色换成 `onPrimary`——“松手就打开”要一眼看出。
///
/// 只负责画，进度由浮层逐帧传入。
class NotebookSwitcherIndicator extends StatelessWidget {
  const NotebookSwitcherIndicator({
    super.key,
    required this.progress,
    required this.armPop,
  });

  /// 胶囊长出的进度（0–1）。
  final double progress;

  /// 武装圆底的弹出程度（0–1，可略越界）。
  final double armPop;

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final armed = armPop.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (armPop > 0)
            Transform.scale(
              scale: armPop.clamp(0.0, 1.4),
              child: SizedBox.square(
                dimension: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          Transform.scale(
            scale: 0.5 + 0.5 * progress.clamp(0.0, 1.0),
            child: FaIcon(
              FontAwesomeIcons.layerGroup,
              size: 15,
              color: Color.lerp(
                scheme.onSecondaryContainer,
                scheme.onPrimary,
                armed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
