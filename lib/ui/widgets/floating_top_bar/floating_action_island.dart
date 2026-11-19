import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../glass/glass_reveal.dart';
import 'floating_island.dart';

/// 右侧的动作胶囊：一排图标按钮（可带一颗 [FloatingIslandPill]）。
///
/// 变形：[layoutKey] 表示“这是哪一套动作”（如阅读 / 编辑中 / 手动保存）。
/// 它变化时新旧两套交叉淡入淡出，胶囊宽度同时以 spatial 曲线补间，看起来
/// 是同一颗岛原地长成新的样子，而不是换了一颗。同一套动作里按钮的启用、
/// 图标与文字变化不算换套，照常原地更新（宽度变化同样补间）。
class FloatingActionIsland extends StatelessWidget {
  const FloatingActionIsland({
    super.key,
    required this.children,
    this.layoutKey,
  });

  final List<Widget> children;
  final Object? layoutKey;

  @override
  Widget build(BuildContext context) {
    return FloatingIsland(
      child: AnimatedSize(
        // AnimatedSize 不接受 0 时长（见 ExpressiveMotion.durationNonZero）。
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.spatial,
        alignment: AlignmentDirectional.centerEnd,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          // 新旧两套贴着胶囊的末端叠放：宽度补间时旧的一套从起始一侧被裁掉，
          // 而不是挤在中间。
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: <Widget>[...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey<Object?>(layoutKey),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// 中间的标题胶囊：正文标题滚出视野后浮出（[visible]），点按回到顶部。
///
/// 显隐是淡入 + 从 0.92 放大，玻璃时经 [GlassReveal]（不套 Opacity）；完全
/// 隐藏时不接收点按、不进读屏。
class FloatingTitleChip extends StatelessWidget {
  const FloatingTitleChip({
    super.key,
    required this.title,
    required this.visible,
    this.onTap,
    this.tooltip,
  });

  final String title;
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
        final faded = glass
            ? GlassReveal(progress: value, child: child!)
            : Opacity(opacity: value, child: child);
        return IgnorePointer(
          ignoring: value == 0,
          child: ExcludeSemantics(
            excluding: value == 0,
            child: Transform.scale(scale: 0.92 + 0.08 * value, child: faded),
          ),
        );
      },
    );
  }
}
