import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/glass/glass_reveal.dart';
import '../viewmodels/diary_card_surface_spec.dart';
import 'diary_card_outer_shadow_decoration.dart';

/// 日记卡片的统一选中表面。
///
/// 输入为页面层已经确定的选中状态和解析好的表面参数 [spec]（底色、渐变、
/// 描边、阴影，均已按主题、置顶与卡片样式算好）；输出只包含视觉与语义
/// 反馈，不持有或修改业务选择状态。短促缩放仅发生在状态切换过程中，避免
/// 改变卡片的最终尺寸或瀑布流布局。
///
/// 两种材质（[DiaryCardSurfaceSpec.glass]）：
/// - 实色：`Transform.scale → Container(底色 / 渐变 + 圆角 + 投影, 前景描边)`，
///   结构与像素同改版前；
/// - 玻璃：在同一个 Container 之下垫一层按卡片圆角裁切的背景模糊，即
///   `Transform.scale → Stack[Positioned.fill(ClipRRect(BackdropFilter)),
///   Container]`。圆角裁切只包模糊层、不包 Container——包住 Container 会把
///   外侧投影一起裁掉。模糊共用页面的 `AppPageBackdrop.contentBackdropKey`：
///   一屏十几张卡片若各自回读背景（独立 BackdropFilter），滚动会卡顿（见
///   `DiaryCardLockedContent` 的注释），共用一个键只读一次背景。只在页面
///   有背景图、模糊半径大于 0、非高对比度且有键时开启（纯色背景模糊了也
///   看不出差别，白白回读）；节点始终在树里，只切 `enabled`，背景图淡入
///   淡出时卡片内容不重建。
///
/// 玻璃不能放进 Opacity / FadeTransition（模糊采不到页面，见 [GlassReveal]）：
/// 列表的进出场与刷新淡入改由祖先 [GlassReveal] 给出进度，这里按进度缩放
/// 底色、描边、投影与模糊强度，并把内容放进模糊之上的一层 Opacity 一起淡入。
class DiarySelectionSurface extends StatelessWidget {
  const DiarySelectionSurface({
    super.key,
    required this.diaryId,
    required this.selected,
    required this.compact,
    required this.spec,
    required this.child,
  });

  static const Duration transitionDuration = ExpressiveMotion.medium;

  final String diaryId;
  final bool selected;
  final bool compact;
  final DiaryCardSurfaceSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final highlightAlpha = isLight ? 0.14 : 0.22;
    final borderRadius = BorderRadius.circular(spec.radius);
    final glass = spec.glass;
    // 只有玻璃才依赖显现作用域：实色卡片仍由外层 Opacity 淡入，不建立依赖。
    final reveal = glass ? GlassReveal.of(context) : 1.0;
    Color fade(Color color) =>
        reveal >= 1 ? color : color.withValues(alpha: color.a * reveal);

    return Semantics(
      container: true,
      selected: selected,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: ExpressiveMotion.duration(context, transitionDuration),
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, double progress, Widget? child) {
          Color highlight(Color base) => Color.alphaBlend(
            colorScheme.primary.withValues(alpha: highlightAlpha * progress),
            base,
          );
          // 渐变表面上 BoxDecoration.color 不生效，选中高亮逐个混入色标。
          final gradientColors = spec.gradientColors;
          final gradient = gradientColors == null
              ? null
              : LinearGradient(
                  begin: spec.gradientBegin,
                  end: spec.gradientEnd,
                  colors: <Color>[
                    for (final c in gradientColors) fade(highlight(c)),
                  ],
                );
          final effectiveBorderColor = Color.lerp(
            spec.borderColor,
            colorScheme.primary.withValues(alpha: 0.82),
            progress,
          )!;
          final effectiveBorderWidth = spec.borderWidth + 1.2 * progress;
          // 圆角表面使用完整描边，避免单侧边框与圆角裁切不一致；静止态宽度为
          // 0 时不画（宽 0 的 BorderSide 会被绘制成一像素细线）。
          final accentBorder = effectiveBorderWidth > 0
              ? Border.all(
                  color: effectiveBorderColor,
                  width: effectiveBorderWidth,
                )
              : null;
          final pulseDepth = compact ? 0.016 : 0.008;
          final scale = 1 - math.sin(math.pi * progress) * pulseDepth;

          final selectionShadows = compact && progress > 0
              ? <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: 0.16 * progress,
                    ),
                    blurRadius: 12 * progress,
                    spreadRadius: 0.5 * progress,
                    offset: Offset(0, 3 * progress),
                  ),
                ]
              : const <BoxShadow>[];

          if (!glass) {
            return Transform.scale(
              key: ValueKey<String>('diary_selection_motion_$diaryId'),
              scale: scale,
              child: Container(
                key: ValueKey<String>('diary_selection_surface_$diaryId'),
                decoration: _decoration(
                  spec: spec,
                  color: gradient == null ? highlight(spec.color) : null,
                  gradient: gradient,
                  borderRadius: borderRadius,
                  shadows: <BoxShadow>[...spec.shadows, ...selectionShadows],
                ),
                foregroundDecoration: BoxDecoration(
                  border: accentBorder,
                  borderRadius: borderRadius,
                ),
                child: child,
              ),
            );
          }

          // 玻璃：底色、描边与投影随显现进度缩放透明度（代替外层 Opacity）。
          final glassBorder = accentBorder == null || reveal >= 1
              ? accentBorder
              : Border.all(
                  color: fade(effectiveBorderColor),
                  width: effectiveBorderWidth,
                );
          return Transform.scale(
            key: ValueKey<String>('diary_selection_motion_$diaryId'),
            scale: scale,
            // passthrough：卡片收到的约束原样交给 Container（瀑布流的紧约束
            // 不能被 Stack 放松）；Clip.none：投影画在卡片外侧，不能被裁。
            child: Stack(
              fit: StackFit.passthrough,
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: _DiaryCardBackdropBlur(
                    diaryId: diaryId,
                    borderRadius: borderRadius,
                    sigma: spec.blurSigma * reveal,
                    translucent: _isTranslucent(spec),
                  ),
                ),
                Container(
                  key: ValueKey<String>('diary_selection_surface_$diaryId'),
                  decoration: _decoration(
                    spec: spec,
                    color: gradient == null
                        ? fade(highlight(spec.color))
                        : null,
                    gradient: gradient,
                    borderRadius: borderRadius,
                    shadows: <BoxShadow>[
                      for (final shadow in <BoxShadow>[
                        ...spec.shadows,
                        ...selectionShadows,
                      ])
                        reveal >= 1
                            ? shadow
                            : BoxShadow(
                                color: fade(shadow.color),
                                offset: shadow.offset,
                                blurRadius: shadow.blurRadius,
                                spreadRadius: shadow.spreadRadius,
                                blurStyle: shadow.blurStyle,
                              ),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    border: glassBorder,
                    borderRadius: borderRadius,
                  ),
                  child: child,
                ),
              ],
            ),
          );
        },
        // 祖先 GlassReveal 代替了外层透明度层，内容的淡入由这里负责：这层
        // Opacity 在模糊层之上（不是 BackdropFilter 的祖先），不妨碍模糊采样。
        // 与 GlassSurface 相同，只在有作用域时才包，没有作用域时树结构不变。
        child: glass && GlassReveal.hasScope(context)
            ? Opacity(opacity: reveal, child: child)
            : child,
      ),
    );
  }

  /// 卡片表面的装饰。半透明（投影已解析为只画外侧）或玻璃卡片改用
  /// [DiaryCardOuterShadowDecoration]：`BlurStyle.outer` 的圆角矩形投影会
  /// 把离边缘较远的内部整块涂上阴影色，透过半透明底色露成一块深色矩形（见
  /// 该类注释）。选中投影一并画在外侧。不透明的实色卡片仍是原来的
  /// BoxDecoration，像素不变；同一个 Container 只换 decoration，不重建内容。
  static Decoration _decoration({
    required DiaryCardSurfaceSpec spec,
    required Color? color,
    required Gradient? gradient,
    required BorderRadius borderRadius,
    required List<BoxShadow> shadows,
  }) {
    final outerOnly =
        spec.glass ||
        spec.shadows.any((BoxShadow s) => s.blurStyle == BlurStyle.outer);
    if (!outerOnly) {
      return BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: shadows,
      );
    }
    return DiaryCardOuterShadowDecoration(
      base: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: borderRadius,
      ),
      shadows: shadows,
    );
  }

  /// 底色是否透出背景；完全不透明的玻璃卡片模糊了也看不见，不必回读背景。
  static bool _isTranslucent(DiaryCardSurfaceSpec spec) {
    final colors = spec.gradientColors;
    if (colors == null) {
      return spec.color.a < 1;
    }
    return colors.any((Color c) => c.a < 1);
  }
}

/// 玻璃卡片底下的背景模糊层：按卡片圆角裁切，共用页面的共享背景键。
///
/// 单独成一个组件，是为了只让这一层依赖页面背景（[AppPageBackdrop]）与
/// 高对比度：背景图换成纯色或高对比度切换时只重建它，卡片内容不动。
class _DiaryCardBackdropBlur extends StatelessWidget {
  const _DiaryCardBackdropBlur({
    required this.diaryId,
    required this.borderRadius,
    required this.sigma,
    required this.translucent,
  });

  final String diaryId;
  final BorderRadius borderRadius;
  final double sigma;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final backdrop = AppPageBackdrop.of(context);
    final key = backdrop.contentBackdropKey;
    final enabled =
        key != null &&
        backdrop.hasImage &&
        translucent &&
        sigma > 0 &&
        !MediaQuery.highContrastOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        key: ValueKey<String>('diary_selection_blur_$diaryId'),
        enabled: enabled,
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        backdropGroupKey: key,
        child: const SizedBox.expand(),
      ),
    );
  }
}
