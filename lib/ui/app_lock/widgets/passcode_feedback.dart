import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 输错时的横向抖动：[trigger] 每变化一次播放一次衰减正弦（幅度 10dp，
/// `standard`）。减少动画时不抖。
///
/// 抖动只是位移，子树的状态（图案板的连线、圆点）不受影响。
class PasscodeShake extends StatefulWidget {
  const PasscodeShake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<PasscodeShake> createState() => _PasscodeShakeState();
}

class _PasscodeShakeState extends State<PasscodeShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// 最大位移（dp）。
  static const double _amplitude = 10;

  @override
  void didUpdateWidget(PasscodeShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == oldWidget.trigger) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.standard,
    );
    if (duration == Duration.zero) return;
    _controller.duration = duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final t = _controller.value;
        final dx = t == 0 || t == 1
            ? 0.0
            : math.sin(t * math.pi * 6) * _amplitude * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// 固定高度的提示行（解锁视图与设置密码页共用）：居中；内容变化时交叉
/// 淡入，出现、消失都不推动下面的键盘或图案。[error] 为 true 时用 error 色。
class PasscodeStatusLine extends StatelessWidget {
  const PasscodeStatusLine({super.key, this.text, this.error = true});

  static const double height = 32;

  final String? text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = this.text;
    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        child: text == null
            ? const SizedBox.shrink()
            : Center(
                key: ValueKey<String>(text),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// 标题与说明（解锁视图与设置页共用）。[switchKey] 变化时（设置页换步）新
/// 的一行从右侧滑入并淡入，旧的一行向左滑出淡出（`medium` + `spatial`）。
class PasscodeHeader extends StatelessWidget {
  const PasscodeHeader({
    super.key,
    required this.title,
    required this.message,
    this.switchKey = 0,
  });

  final String title;
  final String message;
  final Object switchKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final entering = child.key == ValueKey<Object>(switchKey);
        final from = Offset(entering ? 0.12 : -0.12, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: from,
                end: Offset.zero,
              ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
            ),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey<Object>(switchKey),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
