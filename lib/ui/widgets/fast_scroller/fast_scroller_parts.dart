import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/expressive_motion.dart';
import 'fast_scroller_geometry.dart';

/// 快速滚动条各部件的尺寸（逻辑像素），布局与绘制共用。
abstract final class FastScrollMetrics {
  /// 按钮在轨道上占的高度：位置按它换算，按下形变不影响换算。
  static const double slot = 56;

  /// 按钮距右缘的间距。
  static const double edge = 4;

  static const double idleWidth = 6;
  static const double idleHeight = 44;
  static const double grabbedWidth = 20;
  static const double grabbedHeight = 56;

  /// 按钮中线到右缘的距离（轨道线与刻度点画在这条线上）。
  static const double axis = edge + grabbedWidth / 2;

  /// 气泡到右缘的距离：留出按住时的按钮宽度与间隙。
  static const double labelInset = edge + grabbedWidth + 12;

  /// 刻度标签到右缘的距离：紧挨轨道上的刻度点，读作滚动条的一部分（按钮
  /// 经过时它们淡出让开）。
  static const double markerInset = axis + 9;

  /// 按钮的按压区域：比看得见的部分宽，上下各多出 [hitPadding]。
  static const double hitWidth = 44;
  static const double hitPadding = 10;

  /// 刻度标签之间的最小竖直间距，更密的刻度不显示。
  static const double markerSpacing = 22;
}

/// 滚动条按钮：平时是一根细胶囊；桌面悬停时略加粗加深；按住时以 `spatial`
/// 形变为带上下箭头的主色胶囊。形变只改宽高与颜色，位置由调用方定。
class FastScrollThumb extends StatelessWidget {
  const FastScrollThumb({
    super.key,
    required this.grabbed,
    required this.hovered,
  });

  final bool grabbed;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shadows = AppEffects.softShadow(scheme);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: grabbed
            ? 1
            : hovered
            ? 0.35
            : 0,
      ),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.spatial,
      builder: (BuildContext context, double t, Widget? icon) {
        // 弹簧曲线会略冲过 1：尺寸跟着回弹，颜色与透明度夹在范围内。
        final c = t.clamp(0.0, 1.0);
        final width = _lerp(
          FastScrollMetrics.idleWidth,
          FastScrollMetrics.grabbedWidth,
          t,
        );
        return Container(
          width: width,
          height: _lerp(
            FastScrollMetrics.idleHeight,
            FastScrollMetrics.grabbedHeight,
            t,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color.lerp(
              scheme.onSurfaceVariant.withValues(alpha: 0.5),
              scheme.primary,
              c,
            ),
            borderRadius: BorderRadius.circular(width / 2),
            boxShadow: <BoxShadow>[
              for (final shadow in shadows)
                shadow.copyWith(
                  color: shadow.color.withValues(alpha: shadow.color.a * c),
                ),
            ],
          ),
          child: Opacity(opacity: ((c - 0.5) * 2).clamp(0.0, 1.0), child: icon),
        );
      },
      child: FaIcon(FontAwesomeIcons.sort, size: 11, color: scheme.onPrimary),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// 拖动时按钮左侧的气泡：小字（年份等）在上、大字在下；左侧整圆、朝向
/// 按钮的右侧小圆角，`primaryContainer` 底。文字放大到 1.3 倍为止。
class FastScrollBubble extends StatelessWidget {
  const FastScrollBubble({super.key, required this.label});

  final FastScrollLabel label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caption = label.caption;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, maxWidth: 232),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(24),
            right: Radius.circular(10),
          ),
          boxShadow: AppEffects.softShadow(scheme),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (caption != null)
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
                ),
              ),
            Text(
              label.primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 轨道上的分段刻度标签（年份、首字母、章节）：小号粗体，衬
/// `surfaceContainerHighest` 小圆角底，在页面任何背景上都看得清。
class FastScrollMarkerLabel extends StatelessWidget {
  const FastScrollMarkerLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 刻度在轨道上的小圆点。
class FastScrollMarkerDot extends StatelessWidget {
  const FastScrollMarkerDot({super.key});

  static const double size = 5;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: size),
    );
  }
}

/// 按住或悬停时显示的轨道线。
class FastScrollTrackLine extends StatelessWidget {
  const FastScrollTrackLine({super.key});

  static const double width = 4;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(width / 2),
      ),
      child: const SizedBox(width: width),
    );
  }
}
