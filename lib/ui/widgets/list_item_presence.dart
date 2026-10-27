import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import 'glass/glass_reveal.dart';

/// 列表条目的进出场容器（收起/展开 + 淡入淡出），日记列表、归档页、回收站共用。
///
/// 输入：
/// - [visible]：false 时收起并淡出（删除/归档等待撤销期间）；
/// - [appearing]：首次构建或由 false 变 true 时从 0 展开（撤销后重新出现）；
/// - [duration]：已经过 `ExpressiveMotion.duration` 解析的时长（减少动画为 0）。
/// 无副作用；动画结束后的列表数据收尾由宿主页负责。
///
/// 为什么不用 AnimatedSwitcher/SizeTransition：此前按“动画中/已完成”返回不同
/// 类型的包装组件，类型一变卡片子树就会被重新挂载，一次出场最多重建 3 次，
/// 卡片内选中高亮等状态也随之丢失。这里结构恒定为
/// FadeTransition → ClipRect → Align，只在动画进行时启用硬边裁剪；静止态使用
/// Clip.none，避免卡片外散阴影被矩形切成直角（见 dfb8442）。
///
/// [glass] 为 true（条目主体是玻璃表面）时以 [GlassRevealTransition] 代替
/// FadeTransition：玻璃放进透明度层后背景模糊采不到页面（见 [GlassReveal]）。
class ListItemPresence extends StatefulWidget {
  const ListItemPresence({
    super.key,
    required this.visible,
    required this.appearing,
    required this.duration,
    this.glass = false,
    required this.child,
  });

  final bool visible;
  final bool appearing;
  final Duration duration;

  /// 条目主体是否为玻璃表面（由调用方按 `AppGlass.of(context).isGlass` 决定）。
  /// 为 true 时淡入淡出交给条目里的 `GlassSurface`，不在玻璃之内的内容会硬切。
  final bool glass;
  final Widget child;

  @override
  State<ListItemPresence> createState() => _ListItemPresenceState();
}

class _ListItemPresenceState extends State<ListItemPresence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.visible && !widget.appearing ? 1 : 0,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible && widget.appearing) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ListItemPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    } else if (widget.visible && widget.appearing && !oldWidget.appearing) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sized = AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final settled = _controller.isCompleted;
        return ClipRect(
          clipBehavior: settled ? Clip.none : Clip.hardEdge,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: settled ? 1 : _progress.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
    if (widget.glass) {
      return GlassRevealTransition(progress: _progress, child: sized);
    }
    return FadeTransition(opacity: _progress, child: sized);
  }
}
