import 'package:flutter/material.dart';

import 'theme/expressive_motion.dart';

/// 应用锁分层：把应用内容与锁屏遮罩叠放，并在锁定期间隔离内容。
///
/// 输入：[locked] 是否处于锁定（含解锁验证中）；[child] 应用内容；
/// [overlayBuilder] 构建锁屏遮罩。无副作用。
///
/// 设计要点：
/// - 遮罩只挡住指针与视觉；锁定期间还需对下层内容排除语义与焦点，否则
///   TalkBack/键盘仍能逐条读出、聚焦到日记标题与正文；
/// - 遮罩立即出现（淡入过程会短暂透出日记内容），解锁后再淡出；
/// - 内容始终处在同一位置的同类 widget 下，锁定切换不会让应用子树重建。
class AppLockLayer extends StatelessWidget {
  const AppLockLayer({
    super.key,
    required this.locked,
    required this.overlayBuilder,
    required this.child,
  });

  final bool locked;
  final WidgetBuilder overlayBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(excluding: locked, child: child),
        ),
        AnimatedSwitcher(
          duration: Duration.zero,
          reverseDuration: ExpressiveMotion.duration(
            context,
            ExpressiveMotion.fast,
          ),
          switchOutCurve: ExpressiveMotion.exit,
          child: locked
              ? KeyedSubtree(
                  key: const ValueKey<String>('app_lock_overlay'),
                  child: overlayBuilder(context),
                )
              : const SizedBox.shrink(key: ValueKey<String>('app_unlocked')),
        ),
      ],
    );
  }
}
