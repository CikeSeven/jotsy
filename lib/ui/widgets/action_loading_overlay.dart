import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import 'delayed_loading_gate.dart';
import 'expressive_loading_indicator.dart';

/// 页面内耗时动作（预览页导出/分享、看图页保存/分享等）的全屏等待遮罩，
/// 淡入淡出均走 [ExpressiveMotion]。
///
/// 输入：[visible] 控制显隐，[label] 为可见文案（[semanticLabel] 未给时也作读屏
/// 标签）；[revealDelay] 大于 0 时画面延迟出现：点击拦截随 [visible] 立即生效，
/// 遮罩只在动作持续超过该时长后才淡入，几十毫秒就完成的本地操作不会闪一下。
/// 副作用：无；可见时拦截下层点击，隐藏时放行。调用方在动作结束时保留最后一条
/// 文案，让它随遮罩一起淡出。
///
/// 遮罩常驻树上以便淡入淡出，但透明度为 0 时 LoadingIndicatorM3E 内部的
/// repeat 控制器仍会逐帧 tick，阅读期间持续出帧耗电，因此隐藏时静音指示器
/// 的 ticker。TickerMode 只包指示器本身：若包住 AnimatedOpacity，淡出动画
/// 自己的 ticker 也会被静音，遮罩会停在不透明状态。
class ActionLoadingOverlay extends StatelessWidget {
  const ActionLoadingOverlay({
    super.key,
    required this.visible,
    required this.label,
    this.semanticLabel,
    this.revealDelay = Duration.zero,
  });

  final bool visible;
  final String label;
  final String? semanticLabel;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: revealDelay == Duration.zero
          ? _buildVeil(context, visible)
          : DelayedLoadingGate(
              loading: visible,
              delay: revealDelay,
              builder: _buildVeil,
            ),
    );
  }

  /// 遮罩画面；不透明度为 0 时仍会接住点击（ColoredBox 不透明命中），延迟显现
  /// 期间下层同样点不到。
  Widget _buildVeil(BuildContext context, bool shown) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      child: ColoredBox(
        color: colorScheme.surface.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TickerMode(
                enabled: shown,
                child: ExpressiveLoadingIndicator(
                  size: 72,
                  semanticLabel: semanticLabel ?? label,
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
    );
  }
}
