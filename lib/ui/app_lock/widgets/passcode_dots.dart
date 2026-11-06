import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';

/// 数字密码的进度圆点（DESIGN.md §5.31）：[length] 个 14dp 圆点，间距 16。
///
/// - 未输入：1.5dp `outline` 描边的空心点；
/// - 已输入：`primary` 实心，填入的那一下从 1.35 倍弹回原大小（`spatial`），
///   删掉时从 0.8 倍弹回，按键有看得见的回应；
/// - [error]（被拒）：全部变成 `error` 实心，配合外层抖动。
///
/// 读屏读作“已输入 N 位，共 M 位”。
class PasscodeDots extends StatelessWidget {
  const PasscodeDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
  });

  static const double dotSize = 14;
  static const double spacing = 16;

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.passcodeDotsSemantics(filled, length),
      child: ExcludeSemantics(
        child: SizedBox(
          // 弹起时圆点放大，留出余量不被裁切。
          height: dotSize * 1.5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: spacing),
                _Dot(filled: error || i < filled, error: error),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled, required this.error});

  final bool filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    final fast = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    return TweenAnimationBuilder<double>(
      // 每次填入 / 清空换一个 key，从起点重新弹一次。
      key: ValueKey<bool>(filled),
      tween: Tween<double>(begin: filled ? 1.35 : 0.8, end: 1),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.spatial,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: fast,
        curve: ExpressiveMotion.effects,
        width: PasscodeDots.dotSize,
        height: PasscodeDots.dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : scheme.surface.withValues(alpha: 0),
          border: Border.all(
            color: filled ? color : scheme.outline,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
