import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_loading_indicator.dart';

/// 预览页导出/分享等动作的全屏等待遮罩。
///
/// 输入：[visible] 控制显隐，[label] 同时作为可见文案与读屏标签。
/// 副作用：无；可见时拦截下层点击，隐藏时放行。
///
/// 遮罩常驻树上以便淡入淡出，但透明度为 0 时 LoadingIndicatorM3E 内部的
/// repeat 控制器仍会逐帧 tick，阅读期间持续出帧耗电，因此隐藏时静音指示器
/// 的 ticker。TickerMode 只包指示器本身：若包住 AnimatedOpacity，淡出动画
/// 自己的 ticker 也会被静音，遮罩会停在不透明状态。
class DiaryActionLoadingOverlay extends StatelessWidget {
  const DiaryActionLoadingOverlay({
    super.key,
    required this.visible,
    required this.label,
  });

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
        child: ColoredBox(
          color: colorScheme.surface.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TickerMode(
                  enabled: visible,
                  child: ExpressiveLoadingIndicator(
                    size: 72,
                    semanticLabel: label,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
