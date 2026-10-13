import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_loading_indicator.dart';

/// 日历页「选中日内容」的切换容器。
///
/// 输入：当前日内容 [child]（以 key 区分日期/空态）、加载态 [loading]、
/// 错误文案 [errorMessage]。无副作用。
///
/// 过渡策略：
/// - 新旧内容交叉淡入时顶部对齐：默认 AnimatedSwitcher 以居中 Stack 叠放，
///   从长列表切到空态时新内容会先在旧高度里垂直居中，旧内容移除后再猛地上移；
/// - 外层 AnimatedSize 让高度变化连续，避免下方内容随高度突变跳动；
/// - 加载遮罩经 [DelayedLoadingGate] 延迟出现：换日后的本地查询通常几毫秒
///   即返回，立即显示遮罩只会造成每次点日期都闪一下。
class CalendarDayContentSwitcher extends StatelessWidget {
  const CalendarDayContentSwitcher({
    super.key,
    required this.loading,
    required this.errorMessage,
    required this.child,
  });

  static const double refreshIndicatorSize = 18;

  final bool loading;
  final String? errorMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = ExpressiveMotion.duration(context);
    final fastDuration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.fast,
    );
    return Stack(
      children: <Widget>[
        AnimatedSize(
          duration: duration,
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          // 时间线卡片带外阴影，默认 hardEdge 裁剪会切出硬边；高度过渡期间
          // 溢出部分只会画到下方的留白 sliver 上。
          clipBehavior: Clip.none,
          child: AnimatedSwitcher(
            duration: fastDuration,
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.effects,
            layoutBuilder: topAlignedSwitcherLayout,
            child: child,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DelayedLoadingGate(
              loading: loading,
              builder: (context, showLoading) => AnimatedSwitcher(
                duration: fastDuration,
                child: showLoading
                    ? const _CalendarInlineRefreshScrim(
                        key: ValueKey<String>('day_loading'),
                      )
                    : const SizedBox.shrink(key: ValueKey<String>('day_idle')),
              ),
            ),
          ),
        ),
        if (errorMessage != null)
          Positioned(
            left: AppSpacing.m,
            right: AppSpacing.m,
            top: 0,
            child: _CalendarErrorBanner(message: errorMessage!),
          ),
      ],
    );
  }

  /// AnimatedSwitcher 顶部对齐布局：新旧子项都贴顶叠放，高度取二者最大值。
  static Widget topAlignedSwitcherLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[...previousChildren, ?currentChild],
    );
  }
}

class _CalendarInlineRefreshScrim extends StatelessWidget {
  const _CalendarInlineRefreshScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.32),
      ),
      child: const Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.m),
          child: ExpressiveLoadingIndicator(
            size: CalendarDayContentSwitcher.refreshIndicatorSize,
          ),
        ),
      ),
    );
  }
}

class _CalendarErrorBanner extends StatelessWidget {
  const _CalendarErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
