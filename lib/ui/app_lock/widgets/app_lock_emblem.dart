import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_state_blend.dart';

/// 锁屏与密码页顶部的圆形徽章（DESIGN.md §5.31）。
///
/// - 平时 `primaryContainer` 底、`onPrimaryContainer` 图标；
/// - [error] 时底色与图标经 [ExpressiveStateBlend] 补间到 error 容器色，
///   恢复时同样补间回去（颜色不硬切）；
/// - [icon] 变化（上锁 → 开锁、钥匙 → 盾牌）经 [ExpressiveIconSwap] 弹性替换。
///
/// 纯装饰：读屏跳过（标题与说明文字已经说明状态）。
class AppLockEmblem extends StatelessWidget {
  const AppLockEmblem({
    super.key,
    this.icon = FontAwesomeIcons.lock,
    this.error = false,
    this.size = 64,
  });

  final FaIconData icon;
  final bool error;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: ExpressiveStateBlend(
        active: error,
        builder: (BuildContext context, double t, Widget? child) {
          final background = Color.lerp(
            scheme.primaryContainer,
            scheme.errorContainer,
            t,
          )!;
          final foreground = Color.lerp(
            scheme.onPrimaryContainer,
            scheme.onErrorContainer,
            t,
          )!;
          return SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: ExpressiveIconSwap(
                  switchKey: icon,
                  child: FaIcon(icon, size: size * 0.38, color: foreground),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
