import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import 'm3e_cookie_shape.dart';

/// 成功徽章：76dp 十二瓣饼干形（`primary` 实心）里一枚 34dp 对勾
/// （`onPrimary`，即设计稿里的“白色”对勾，暗色主题下随主题取值）。
///
/// 挂载时对勾以 `spatial` 弹性从 0 放大到 1（`medium`）；减少动画时直接显示。
/// 配对成功与同步完成摘要共用（DESIGN.md §5.27）。触觉反馈由调用方在
/// “生效”的那一刻触发，徽章本身只管画。
class LanSyncSuccessBadge extends StatelessWidget {
  const LanSyncSuccessBadge({super.key});

  static const double extent = 76;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.primary,
          shape: const M3eCookieBorder(lobes: 12),
        ),
        child: SizedBox.square(
          dimension: extent,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.spatial,
              builder: (BuildContext context, double scale, Widget? child) =>
                  Transform.scale(scale: scale, child: child),
              child: FaIcon(
                FontAwesomeIcons.check,
                size: 34,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
