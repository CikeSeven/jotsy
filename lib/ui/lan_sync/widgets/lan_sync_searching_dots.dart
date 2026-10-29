// “正在寻找…”：文字后三个点依次闪烁（附近的设备分组标题右侧）。
//
// 只在 TickerMode 开着且没有减少动画时循环（周期取雷达波纹周期的三分之一，
// 与波纹同拍）；否则三个点静止为完全不透明。读屏只读文字，不读点。

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

class LanSyncSearchingDots extends StatefulWidget {
  const LanSyncSearchingDots({super.key, required this.label, this.style});

  final String label;
  final TextStyle? style;

  @override
  State<LanSyncSearchingDots> createState() => _LanSyncSearchingDotsState();
}

class _LanSyncSearchingDotsState extends State<LanSyncSearchingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.pulseLoop ~/ 3,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run =
        TickerMode.valuesOf(context).enabled &&
        !ExpressiveMotion.reduceMotion(context);
    if (run) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 第 [index] 个点在当前进度下的不透明度：三个点各占三分之一周期，轮到
  /// 的那个最亮，其余淡到 25%。静止时全亮。
  double _opacityOf(int index) {
    if (!_controller.isAnimating) return 1;
    final distance = ((_controller.value * 3 - index) % 3 + 3) % 3;
    final lit = distance < 1 ? 1 - distance : 0.0;
    return 0.25 + 0.75 * lit;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(widget.label, style: widget.style),
        ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < 3; i++)
                    Opacity(
                      opacity: _opacityOf(i),
                      child: Text('.', style: widget.style),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
