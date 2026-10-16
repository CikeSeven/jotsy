import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_effects.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 发布时间胶囊时的封存卡片：遮罩淡入，卡片带回弹地缩放入场。
///
/// 只在封存时插入树中，插入即播放 0→1 补间（AnimatedOpacity 首帧即为目标
/// 值、从不淡入）。减少动画时两段补间时长为 0，直接显示。不拦截触摸，
/// 页面在封存期间本就不接受返回与再次发布。
class TimeCapsuleSealOverlay extends StatelessWidget {
  const TimeCapsuleSealOverlay({super.key});

  /// 卡片入场（缩放回弹）时长，页面据此计算退场前的等待。
  static const Duration entranceDuration = ExpressiveMotion.long;

  /// 入场完成后的停留时间，让用户读到“正在封存”再退场。它是阅读停留而
  /// 不是动画时长，减少动画时同样保留。
  static const Duration holdDuration = Duration(milliseconds: 260);

  /// 从插入到可以退场的总等待（减少动画时只剩停留时间）。
  static Duration totalWait(BuildContext context) =>
      ExpressiveMotion.duration(context, entranceDuration) + holdDuration;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          curve: ExpressiveMotion.effects,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: ColoredBox(
            color: colorScheme.scrim.withValues(alpha: 0.36),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.88, end: 1),
                duration: ExpressiveMotion.duration(context, entranceDuration),
                curve: ExpressiveMotion.spatial,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppEffects.softShadow(colorScheme),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FaIcon(
                          FontAwesomeIcons.lock,
                          size: 34,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.l10n.timeCapsuleSealing,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
