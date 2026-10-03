import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import '../../l10n/app_localizations.dart';

/// 统一等待反馈。尺寸由外层约束收紧，可同时用于整页、分页尾部与图标槽位。
/// 减少动画时冻结形变，但保留可见图形与读屏标签，不把等待状态变成空白。
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
    return TickerMode(
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: LoadingIndicatorM3E(
        variant: LoadingIndicatorM3EVariant.contained,
        color: colors.onPrimaryContainer,
        containerColor: colors.primaryContainer,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        semanticLabel: semanticLabel ?? context.l10n.autoT0001,
      ),
    );
  }
}
