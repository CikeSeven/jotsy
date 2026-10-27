import 'package:flutter/material.dart';

import '../../diaries/viewmodels/diary_card_colors.dart';
import '../models/app_surface_settings.dart';

/// 一块背景在当前明暗主题下的实际画法。
///
/// - 输入：已按 follow / off / custom 解析好的 [AppBackground]（见
///   `appAreaBackgroundProvider`）与当前 [ColorScheme]；
/// - 输出：三种之一——[none]（不画，沿用主题表面色）、纯色（[color]）、
///   图片（托管文件名 [image] + 焦点 [alignment] + 模糊 [blur] + 遮罩
///   [scrimColor]）；
/// - 无副作用，纯数据，按值比较：渲染层据 `==` 判断“背景是否变了”，决定
///   是否交叉淡入。
///
/// 模型里各字段互不清除（从图片切到纯色再切回，图片仍在），这里只取当前
/// 种类用得到的字段；种类对但缺值（纯色没有颜色、图片没有文件名）一律按
/// [none] 处理，渲染层不必再判断半残的设置。图片文件是否真的存在、能否
/// 解码在加载时才知道，失败同样按无背景显示（设置原样保留）。
@immutable
class AppResolvedBackground {
  const AppResolvedBackground._({
    required this.kind,
    this.color,
    this.image,
    this.alignment = Alignment.center,
    this.blur = 0,
    this.scrimColor,
  });

  /// 纯色背景。
  const AppResolvedBackground.color(Color color)
    : this._(kind: AppBackgroundKind.color, color: color);

  /// 图片背景。
  const AppResolvedBackground.image({
    required String image,
    required Alignment alignment,
    required double blur,
    required Color scrimColor,
  }) : this._(
         kind: AppBackgroundKind.image,
         image: image,
         alignment: alignment,
         blur: blur,
         scrimColor: scrimColor,
       );

  /// 不画背景。
  static const AppResolvedBackground none = AppResolvedBackground._(
    kind: AppBackgroundKind.none,
  );

  /// 由设置与当前配色解析。
  ///
  /// - 纯色：浅色主题用浅色值；深色主题优先用户给的深色值，没有时经
  ///   [DiaryCardColors.deriveDark] 按“表面”角色推导（与卡片、导航栏自定义
  ///   底色同一口径：带一点原色调的深灰，而不是刺眼的高饱和色块）；
  /// - 图片：遮罩色为 `surface` 叠上对应明暗的遮罩不透明度——浅色主题提亮、
  ///   深色主题压暗，上层文字按主题色的 onSurface 绘制时仍然可读。
  factory AppResolvedBackground.resolve(
    AppBackground background,
    ColorScheme scheme,
  ) {
    final light = scheme.brightness == Brightness.light;
    switch (background.kind) {
      case AppBackgroundKind.none:
        return none;
      case AppBackgroundKind.color:
        final colorLight = background.colorLight;
        if (colorLight == null) return none;
        if (light) return AppResolvedBackground.color(Color(colorLight));
        final colorDark = background.colorDark;
        return AppResolvedBackground.color(
          colorDark != null
              ? Color(colorDark)
              : DiaryCardColors.deriveDark(
                  Color(colorLight),
                  DiaryCardColorRole.surface,
                ),
        );
      case AppBackgroundKind.image:
        final name = background.image;
        if (name == null || name.isEmpty) return none;
        return AppResolvedBackground.image(
          image: name,
          alignment: Alignment(background.alignX, background.alignY),
          blur: background.blur,
          scrimColor: scheme.surface.withValues(
            alpha: light ? background.scrimLight : background.scrimDark,
          ),
        );
    }
  }

  final AppBackgroundKind kind;

  /// 纯色背景的颜色；其余种类为 null。
  final Color? color;

  /// 图片背景的托管文件名；其余种类为 null。
  final String? image;

  /// 图片的焦点（cover 裁切时保留的位置）。
  final Alignment alignment;

  /// 图片模糊半径（逻辑像素下的 sigma），0 为不模糊。
  final double blur;

  /// 叠在图片上的遮罩色（已带不透明度）；其余种类为 null。
  final Color? scrimColor;

  bool get isNone => kind == AppBackgroundKind.none;
  bool get isColor => kind == AppBackgroundKind.color;
  bool get isImage => kind == AppBackgroundKind.image;

  @override
  bool operator ==(Object other) {
    return other is AppResolvedBackground &&
        other.kind == kind &&
        other.color == color &&
        other.image == image &&
        other.alignment == alignment &&
        other.blur == blur &&
        other.scrimColor == scrimColor;
  }

  @override
  int get hashCode =>
      Object.hash(kind, color, image, alignment, blur, scrimColor);

  @override
  String toString() => switch (kind) {
    AppBackgroundKind.none => 'AppResolvedBackground.none',
    AppBackgroundKind.color => 'AppResolvedBackground.color($color)',
    AppBackgroundKind.image =>
      'AppResolvedBackground.image($image, $alignment, blur: $blur, '
          'scrim: $scrimColor)',
  };
}
