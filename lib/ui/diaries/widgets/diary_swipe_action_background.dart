import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';

/// 列表卡片左滑时露在卡片下面的动作背景（`DiarySwipeActionItem` 内部使用）。
///
/// 输入：卡片滑开比例 [slide]（0~1，占条目宽度）、滑出后的收起进度
/// [collapse]、武装态过渡 [armColor] / [armPop]，以及动作方向 [actionSign]
/// （-1 向左、1 向右，与卡片平移方向一致）。无副作用，只随动画重绘。
///
/// 形状：与卡片同圆角的整条底板，但只画在卡片没有盖住的地方——裁切区为
/// “整条矩形减去当前位置的卡片圆角矩形”。`Dismissible` 的背景按卡片的外接
/// 矩形裁切，卡片圆角处的缺口落在裁切区外，露出的是页面底色，看起来像卡片
/// 多出一块直角挡住了背景；按圆角挖掉卡片后，缺口里同样是背景。卡片本身
/// 半透明（玻璃、带透明度的底色）时也不会透出背景色。
///
/// 外观：未到阈值时是弱化色，图标随拖动距离淡入放大（直接跟手）；越过阈值
/// 切到动作色、图标弹一下。收起时底板随条目高度压扁、保持圆角，图标先淡出。
class DiarySwipeActionBackground extends StatelessWidget {
  const DiarySwipeActionBackground({
    super.key,
    required this.surfaceKey,
    required this.slide,
    required this.collapse,
    required this.armColor,
    required this.armPop,
    required this.actionSign,
    required this.threshold,
    required this.armedIconScale,
    required this.icon,
    required this.actionColor,
    required this.actionIconColor,
    required this.borderRadius,
  });

  /// 底板表面的 key，供回归测试定位。
  final Key surfaceKey;
  final Animation<double> slide;
  final Animation<double> collapse;
  final Animation<double> armColor;
  final Animation<double> armPop;
  final double actionSign;
  final double threshold;
  final double armedIconScale;
  final FaIconData icon;
  final Color actionColor;
  final Color actionIconColor;
  final double borderRadius;

  /// 图标在“滑开距离 / 阈值”的这一段内由透明变为不透明：起点约等于图标开始
  /// 露出，终点在完全露出后不久，避免图标还被卡片压着时就已经是实色。
  static const Interval _iconReveal = Interval(0.15, 0.45);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      // armPop 与 armColor 同一个父动画，合并一个即可。
      animation: Listenable.merge(<Listenable>[slide, collapse, armColor]),
      builder: (BuildContext context, Widget? child) {
        // 静止时不画：卡片完全盖住底板，没必要建裁切层。
        if (slide.value <= 0) {
          return const SizedBox.shrink();
        }
        final armed = armColor.value;
        final reveal = (slide.value / threshold).clamp(0.0, 1.0);
        final iconColor = Color.lerp(
          colorScheme.onSurfaceVariant,
          actionIconColor,
          armed,
        )!;
        // 收起的前半段把图标淡出，压扁的底板里不留半截图标。
        final iconAlpha =
            _iconReveal.transform(reveal) *
            (1 - collapse.value * 2).clamp(0.0, 1.0);
        final scale =
            lerpDouble(0.7, 1, reveal)! *
            (1 + (armedIconScale - 1) * armPop.value);
        return ClipPath(
          clipper: _UncoveredByCardClipper(
            slide: slide.value,
            actionSign: actionSign,
            radius: borderRadius,
          ),
          child: DecoratedBox(
            key: surfaceKey,
            decoration: BoxDecoration(
              color: Color.lerp(
                colorScheme.surfaceContainerHighest,
                actionColor,
                armed,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
                child: Transform.scale(
                  scale: scale,
                  child: FaIcon(
                    icon,
                    size: 18,
                    color: iconColor.withValues(alpha: iconColor.a * iconAlpha),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 裁切区 = 整条矩形 − 当前位置的卡片圆角矩形。
///
/// 卡片圆角矩形向内缩 [_seamInset]：两边都抗锯齿时，圆角边缘的像素会同时
/// 被“背景按覆盖率裁掉一部分”和“卡片按覆盖率盖上一部分”，中间透出一圈
/// 页面底色的细缝。让背景伸进卡片边缘下面一点，边缘像素就只是卡片与背景
/// 的混合；对半透明卡片只多透出一圈不到一像素的背景，看不出来。
class _UncoveredByCardClipper extends CustomClipper<Path> {
  _UncoveredByCardClipper({
    required this.slide,
    required this.actionSign,
    required this.radius,
  });

  static const double _seamInset = 1;

  final double slide;
  final double actionSign;
  final double radius;

  @override
  Path getClip(Size size) {
    final bounds = Offset.zero & size;
    final card = bounds.shift(Offset(actionSign * slide * size.width, 0));
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds),
      Path()..addRRect(
        RRect.fromRectAndRadius(
          card,
          Radius.circular(radius),
        ).deflate(_seamInset),
      ),
    );
  }

  @override
  bool shouldReclip(_UncoveredByCardClipper oldClipper) =>
      oldClipper.slide != slide ||
      oldClipper.actionSign != actionSign ||
      oldClipper.radius != radius;
}
