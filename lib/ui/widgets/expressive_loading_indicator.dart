import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import '../../l10n/app_localizations.dart';

/// 统一等待反馈。尺寸由外层约束收紧，可同时用于整页、分页尾部与图标槽位。
/// 减少动画时冻结形变，但保留可见图形与读屏标签，不把等待状态变成空白。
///
/// 祖先关掉了 TickerMode（被盖住的路由、隐藏的等待遮罩、屏幕外的缓存页）时
/// 不挂 [LoadingIndicatorM3E]，改画同尺寸的静态图形：它内部的形变用
/// `Timer.periodic` 驱动，不受 TickerMode 管，挂着就每约 650ms 改一次动画
/// 值、触发一次重建与整屏光栅——看不见的指示器也会让静止的页面一直出帧。
/// 重新启用时指示器重新挂上，从头开始转。
class ExpressiveLoadingIndicator extends StatelessWidget {
  const ExpressiveLoadingIndicator({
    super.key,
    this.size = 40,
    this.semanticLabel,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = semanticLabel ?? context.l10n.commonLoading;
    if (!TickerMode.valuesOf(context).enabled ||
        MediaQuery.disableAnimationsOf(context)) {
      return Semantics(
        label: label,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.65,
                heightFactor: 0.65,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.onPrimaryContainer,
                    shape: const StarBorder(
                      points: 12,
                      innerRadiusRatio: 0.8,
                      pointRounding: 0.5,
                      valleyRounding: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return LoadingIndicatorM3E(
      variant: LoadingIndicatorM3EVariant.contained,
      color: colors.onPrimaryContainer,
      containerColor: colors.primaryContainer,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      semanticLabel: label,
    );
  }
}
