import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app_surface/widgets/app_glass_fab.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../widgets/glass/glass_reveal.dart';
import '../../../widgets/glass/outer_shadow_painter.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';

/// 与悬浮底栏并排的新建按钮：直径为栏高的圆（与胶囊两端的半圆同一弧度），
/// 主色容器底色 + 加号图标，投影与胶囊同源。
///
/// “小控件”为玻璃时与全局 FAB 同一外壳（[AppGlassFab]：主色玻璃、玻璃
/// 描边与投影，浮在列表上总是模糊），否则为实色。
///
/// [label] 用作长按提示与读屏文字（如“新建”“写进「旅行」”），按钮本身
/// 只有图标。[progress] 为显现进度：实色按钮直接按比例淡入；玻璃按钮不能
/// 放进透明度层，改经 [GlassReveal] 由玻璃自己淡入（调用方的入场同理，见
/// [isGlass]）。
class HomeInlineCreateButton extends StatelessWidget {
  const HomeInlineCreateButton({
    super.key,
    required this.style,
    required this.label,
    required this.onPressed,
    this.progress = 1,
  });

  static const double iconSize = 20;

  final HomeBarResolvedStyle style;
  final String label;
  final VoidCallback onPressed;
  final double progress;

  /// 当前材质下按钮是否为玻璃：调用方据此在入场时用 [GlassReveal] 代替
  /// Opacity。
  static bool isGlass(BuildContext context) =>
      AppGlass.of(context).isGlass(AppGlassComponent.controls);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final side = style.barHeight;
    final radius = BorderRadius.circular(side / 2);
    if (isGlass(context)) {
      return Semantics(
        container: true,
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: GlassReveal(
            progress: progress.clamp(0.0, 1.0),
            child: AppGlassFab(
              borderRadius: radius,
              child: SizedBox.square(
                dimension: side,
                child: InkWell(
                  onTap: onPressed,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: iconSize,
                      color: AppGlassFab.foregroundOf(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: CustomPaint(
            painter: OuterShadowPainter(
              color: style.shadowColor,
              borderRadius: radius,
            ),
            child: SizedBox.square(
              dimension: side,
              child: Material(
                color: scheme.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: iconSize,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
