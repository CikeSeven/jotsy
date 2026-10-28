import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';

/// 图表首次出现时的共享进度：首次构建从 0 走到 1（long），之后数据变化直接
/// 落位、不重播；减少动画（或 [enabled] 为 false）时直接为 1。
///
/// 一张卡里的条、柱、格子共用这一个进度，只插值高度、长度与颜色，不为每一项
/// 叠一层 Opacity；外面包 [RepaintBoundary]，生长期间只重绘这张卡。探索页与
/// 日记本统计页的图表共用同一节奏（DESIGN §4.3）。
class ExploreReveal extends StatelessWidget {
  const ExploreReveal({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, double reveal) builder;

  /// 为 false 时不播放生长动画（探索页外观里关掉了图表动画）。
  final bool enabled;

  /// 第 [index] 项在共享进度 [reveal] 下的局部进度：各项依次起步（总时长的
  /// 前 40% 内错开），各自用 60% 的时长走完 effects 曲线。
  static double staggered(double reveal, int index, int count) {
    final start = count <= 1 ? 0.0 : 0.4 * index / (count - 1);
    final local = ((reveal - start) / 0.6).clamp(0.0, 1.0);
    return ExpressiveMotion.effects.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: enabled
            ? ExpressiveMotion.duration(context, ExpressiveMotion.long)
            : Duration.zero,
        builder: (BuildContext context, double reveal, Widget? _) =>
            builder(context, reveal),
      ),
    );
  }
}

/// 图表共用的颜色档位：只取 colorScheme 语义色的不透明度，不用渐变。
abstract final class ExploreChartColors {
  /// 条形 / 柱形的空轨道色。
  static Color track(ColorScheme scheme) =>
      scheme.surfaceContainerHighest.withValues(alpha: 0.45);

  /// 占比 → 不透明度档位：<15% / <30% / <50% / 其余（与日历年视图热力同一组
  /// 档位）。
  static double alphaForShare(double share) {
    if (share < 0.15) return 0.3;
    if (share < 0.3) return 0.5;
    if (share < 0.5) return 0.72;
    return 1;
  }
}
