import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../glass/glass_reveal.dart';
import 'floating_island.dart';

/// 右侧的动作胶囊：一排图标按钮（可带一颗 [FloatingIslandPill]）。
///
/// 变形：会随状态出现 / 消失的按钮包一层 [FloatingIslandSlot]，它沿横向展开
/// 或收起并淡入淡出，胶囊宽度随之一起变化；其余按钮原地不动、不重建。看起来
/// 是同一颗岛原地长成新的样子，而不是换了一颗（编辑页：[分享 · 更多] ⇄
/// [更多 | 完成]）。
class FloatingActionIsland extends StatelessWidget {
  const FloatingActionIsland({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FloatingIsland(
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// 动作胶囊里随状态出现 / 消失的一格：[visible] 变化时沿横向从 0 宽展开
/// （或收起到 0 宽）并淡入淡出，时长取 `medium`、位移曲线 `spatial`；减少
/// 动画时直接出现或消失。收起后不挂载，不在树上留一份按钮。
class FloatingIslandSlot extends StatefulWidget {
  const FloatingIslandSlot({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<FloatingIslandSlot> createState() => _FloatingIslandSlotState();
}

class _FloatingIslandSlotState extends State<FloatingIslandSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late final CurvedAnimation _size = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.spatial,
    reverseCurve: ExpressiveMotion.spatial.flipped,
  );
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );

  /// 收起动画播完前仍保留上一次可见时的内容，收起途中看到的是它在缩小。
  late Widget _shown = widget.child;

  @override
  void didUpdateWidget(FloatingIslandSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _shown = widget.child;
    }
    if (widget.visible == oldWidget.visible) {
      return;
    }
    _controller.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink();
        }
        final settled = _controller.isCompleted;
        return IgnorePointer(
          ignoring: !widget.visible,
          child: ClipRect(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              widthFactor: settled ? 1 : _size.value.clamp(0.0, 1.0),
              child: settled
                  ? _shown
                  : Opacity(opacity: _fade.value, child: _shown),
            ),
          ),
        );
      },
    );
  }
}

/// 中间一颗静态的文字岛（封存页的标题）：一直显示、不可
/// 点按，文字一行省略。[child] 通常是一个 Text（可自己随内容刷新）。
class FloatingIslandLabel extends StatelessWidget {
  const FloatingIslandLabel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FloatingIsland(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Center(
        widthFactor: 1,
        child: DefaultTextStyle.merge(
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      ),
    );
  }
}

/// 中间的标题胶囊：正文标题滚出视野后浮出（[visible]），点按回到顶部。
///
/// 显隐是淡入 + 从 0.92 放大，玻璃时经 [GlassReveal]（不套 Opacity）；淡出
/// 途中不接收点按，完全隐藏时不挂载。
class FloatingTitleChip extends StatelessWidget {
  const FloatingTitleChip({
    super.key,
    required this.title,
    required this.visible,
    this.onTap,
    this.tooltip,
    this.semanticsLabel,
  });

  final String title;

  /// 标题的读屏文字（如位置“3 / 57”读作“第 3 篇，共 57 篇”）；null 时读标题。
  final String? semanticsLabel;
  final bool visible;
  final VoidCallback? onTap;

  /// 点按动作的说明（如“回到顶部”）。
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.topBars);
    final chip = FloatingIsland(
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Center(
            widthFactor: 1,
            child: Text(
              title,
              semanticsLabel: semanticsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = this.tooltip;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: visible ? ExpressiveMotion.effects : ExpressiveMotion.exit,
      child: tooltip == null ? chip : Tooltip(message: tooltip, child: chip),
      builder: (BuildContext context, double value, Widget? child) {
        // 完全隐藏时不挂载：省掉一块玻璃，也不在树上留一份标题文字。
        if (value == 0) {
          return const SizedBox.shrink();
        }
        final faded = glass
            ? GlassReveal(progress: value, child: child!)
            : Opacity(opacity: value, child: child);
        return IgnorePointer(
          ignoring: !visible,
          child: Transform.scale(scale: 0.92 + 0.08 * value, child: faded),
        );
      },
    );
  }
}
