import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/expressive_motion.dart';

/// 色块选择按钮（主题色、标签色等色板共用）。
///
/// 输入：色块颜色 [color]、选中态 [selected]、点击回调 [onTap]、读屏标签
/// [semanticLabel]；[borderRadius] 为空时为圆形色块，否则为圆角方块。
///
/// - 视觉色块保持 [swatchSize]，点击区域扩展到 48dp 并带水波纹，满足 Material
///   最小触控尺寸；按钮与选中状态暴露给读屏；
/// - 选中态用 onSurface 外环 + 色块上的勾选：不用 primary 描边，因为主题色
///   选择器中 primary 正是由该色块派生，二者几乎同色、难以分辨。
class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    this.swatchSize = 32,
    this.borderRadius,
    this.showCheck = true,
  });

  static const double tapTargetSize = 48;

  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final String semanticLabel;
  final double swatchSize;
  final double? borderRadius;

  /// 选中时是否在色块上画勾：色系页签类选择只需外环，避免与具体颜色的勾选混淆。
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius;
    final side = BorderSide(
      color: selected ? colors.onSurface : colors.outlineVariant,
      width: selected ? 2.4 : 1.0,
    );
    final ShapeBorder shape = radius == null
        ? CircleBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: side,
          );
    // 勾选画在任意用户色块上，对比色只能由色块明度决定，不跟随主题
    // （AGENTS §6 例外条款）。
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: tapTargetSize,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            radius: tapTargetSize / 2,
            child: Center(
              child: AnimatedContainer(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                curve: ExpressiveMotion.effects,
                width: swatchSize,
                height: swatchSize,
                decoration: ShapeDecoration(color: color, shape: shape),
                child: selected && showCheck
                    ? Center(
                        child: FaIcon(
                          FontAwesomeIcons.check,
                          size: swatchSize * 0.4,
                          color: checkColor,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 色块读屏用的十六进制颜色值（不含透明度），如 `#E57373`。
String colorSwatchHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
