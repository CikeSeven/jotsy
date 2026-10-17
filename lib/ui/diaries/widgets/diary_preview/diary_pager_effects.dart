import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';

/// 翻页灵敏度对应的起滑距离倍数与甩动阈值。
///
/// 手势竞技场里谁先越过自己的起滑距离谁赢：翻页器把横向起滑距离放大为
/// “系统值 × [touchSlopRatio]”，页内的竖向滚动与横向控件仍是系统值，于是
/// 只有足够水平的滑动才翻页（标准约 34° 以内、防误触约 22° 以内）。
/// [minFlingVelocity] 为 null 时沿用平台默认的甩动阈值。
extension DiaryPagerSensitivity on DiaryPreviewSwipeSensitivity {
  double get touchSlopRatio => switch (this) {
    DiaryPreviewSwipeSensitivity.sensitive => 1.0,
    DiaryPreviewSwipeSensitivity.standard => 1.5,
    DiaryPreviewSwipeSensitivity.strict => 2.5,
  };

  double? get minFlingVelocity => switch (this) {
    DiaryPreviewSwipeSensitivity.strict => 800,
    _ => null,
  };
}

/// 只覆盖甩动阈值的 physics：轻轻一甩不再翻页，要拖过半屏才翻。链路为
/// `PageScrollPhysics → 本类 → 平台默认`，越界与回弹仍按平台。
class DiaryPagerFlingPhysics extends ScrollPhysics {
  const DiaryPagerFlingPhysics({required this.flingVelocity, super.parent});

  final double flingVelocity;

  @override
  DiaryPagerFlingPhysics applyTo(ScrollPhysics? ancestor) {
    return DiaryPagerFlingPhysics(
      flingVelocity: flingVelocity,
      parent: buildParent(ancestor),
    );
  }

  @override
  double get minFlingVelocity => flingVelocity;
}

/// 一页随翻页进度的过渡。[offset] 为这一页相对视口的位置（0 为正当中，
/// -1 / 1 为左右相邻一整页，RTL 下方向由 [PageView] 自己翻转）。
///
/// - 平移：不加变换，由 [PageView] 自身排布；
/// - 层叠：位于前方（offset < 0）的一页原地不动并缩小、压暗，后一页照常
///   滑入盖在它上面（[PageView] 按序号从小到大绘制）；
/// - 淡入：两页都原地不动，按距离交叉淡入淡出；离开一半以上的那页不接收
///   点按，免得点到正在淡出的页。
///
/// 三种效果共用同一套部件结构（变换 → 忽略点按 → 透明度 → 压暗），只改参数：
/// 切换效果或过渡回到原位时页面不会被重新挂载、丢掉状态。透明度为 1、变换
/// 只有平移时都不产生额外图层。命中测试以页面原本的位置为准，过渡结束
/// （offset 回到 0）后与普通页面一致。
class DiaryPagerTransition extends StatelessWidget {
  const DiaryPagerTransition({
    super.key,
    required this.transition,
    required this.offset,
    required this.width,
    required this.child,
  });

  final DiaryPreviewPageTransition transition;
  final double offset;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.rtl ? 1 : -1;
    final distance = offset.abs().clamp(0.0, 1.0);
    var hold = 0.0;
    var scale = 1.0;
    var opacity = 1.0;
    var shade = 0.0;
    switch (transition) {
      case DiaryPreviewPageTransition.slide:
        break;
      case DiaryPreviewPageTransition.stack:
        if (offset < 0) {
          hold = offset * width * direction;
          scale = 1 - 0.08 * distance;
          shade = 0.16 * distance;
        }
      case DiaryPreviewPageTransition.fade:
        hold = offset * width * direction;
        opacity = 1 - distance;
    }
    final scrim = Theme.of(context).colorScheme.scrim;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(hold, 0, 0),
      child: IgnorePointer(
        ignoring:
            transition == DiaryPreviewPageTransition.fade && distance >= 0.5,
        child: Opacity(
          opacity: opacity,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(color: scrim.withValues(alpha: shade)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 翻到头时的越界距离：负数在第一篇之前，正数在最后一篇之后。[released]
/// 为松手（或回弹）后的淡出阶段，[atEnd] 记住最后一次越界在哪一端，淡出时
/// 文字不跳到另一端。
@immutable
class DiaryPagerEdgePull {
  const DiaryPagerEdgePull(
    this.distance, {
    this.atEnd = true,
    this.released = false,
  });

  static const DiaryPagerEdgePull none = DiaryPagerEdgePull(0, released: true);

  final double distance;
  final bool atEnd;
  final bool released;

  @override
  bool operator ==(Object other) =>
      other is DiaryPagerEdgePull &&
      other.distance == distance &&
      other.atEnd == atEnd &&
      other.released == released;

  @override
  int get hashCode => Object.hash(distance, atEnd, released);
}

/// 到头提示：“已经是第一篇 / 最后一篇”，贴在越界的那一侧。拖动中透明度
/// 直接跟随越界距离（跟手，不补间），松手后 `fast` 淡出。不拦截点按。
class DiaryPagerEdgeHint extends StatelessWidget {
  const DiaryPagerEdgeHint({super.key, required this.pull});

  final ValueListenable<DiaryPagerEdgePull> pull;

  /// 越界多少以后开始出现、到多少完全不透明。
  static const double _start = 8;
  static const double _full = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer);
    return IgnorePointer(
      child: ValueListenableBuilder<DiaryPagerEdgePull>(
        valueListenable: pull,
        builder: (BuildContext context, DiaryPagerEdgePull value, _) {
          final opacity = ((value.distance.abs() - _start) / (_full - _start))
              .clamp(0.0, 1.0);
          return AnimatedOpacity(
            opacity: opacity,
            duration: value.released
                ? ExpressiveMotion.duration(context, ExpressiveMotion.fast)
                : Duration.zero,
            curve: ExpressiveMotion.exit,
            child: Align(
              alignment: value.atEnd
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      value.atEnd
                          ? l10n.diaryPreviewLastDiary
                          : l10n.diaryPreviewFirstDiary,
                      style: textStyle,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
