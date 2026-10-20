import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';
import 'home_bar_style_enums.dart';
import 'home_bar_style_limits.dart';

export 'home_bar_style_enums.dart';
export 'home_bar_style_limits.dart';

part 'home_bar_style_json.dart';

/// 首页栏（底部导航栏 + 日记 / 日历 / 探索 / 设置四个 Tab 的顶栏）的外观。
///
/// 输入：持久化的 JSON（单键 `homeBarStyleRaw` 中的 `current`，或样式码）；
/// 输出：不可变的样式对象。无副作用，也不依赖 Flutter 的 `Color`——颜色以
/// ARGB 整数保存，解析为具体颜色、尺寸由渲染层（`HomeBarResolvedStyle`）
/// 负责，那里还会处理高对比度回退与自定义色的可读性兜底。
///
/// 字段分三组：
/// - 材质与玻璃：[material]、[glassTopBars]、[blurSigma]、[tintOpacity]、
///   [tint]、[tintColor]、[tintColorDark]、[border]；只在玻璃材质下生效；
/// - 悬浮底栏几何：[shadow]、[barHeight]、[cornerRadius]、[sideMargin]、
///   [bottomGap]、[fabPlacement]；实色底栏贴底铺满，不用这些；
/// - 导航项：[labelMode]、[iconSize]、[indicator]；两种材质都适用。
///
/// 兼容策略：
/// - 默认值即改版前写死的实色栏，未自定义的用户看不到变化；
/// - 解码逐字段容错：缺失、类型不符、未知枚举名或越界的数值只让该字段回退
///   到默认值（越界夹到边界），见 [StyleJson]；
/// - 编码是稀疏的：只写与默认值不同的字段。
@immutable
class HomeBarStyle {
  const HomeBarStyle({
    this.material = HomeBarMaterial.solid,
    this.glassTopBars = true,
    this.blurSigma = 20,
    this.tintOpacity = 0.72,
    this.tint = HomeBarTint.neutral,
    this.tintColor,
    this.tintColorDark,
    this.border = true,
    this.shadow = true,
    this.barHeight = 64,
    this.cornerRadius = 32,
    this.sideMargin = 16,
    this.bottomGap = 12,
    this.fabPlacement = HomeBarFabPlacement.above,
    this.labelMode = HomeBarLabelMode.always,
    this.iconSize = 20,
    this.indicator = HomeBarIndicator.capsule,
  });

  static const HomeBarStyle defaults = HomeBarStyle();

  /// 从已解码的 JSON 构造；不是对象时返回默认样式。
  factory HomeBarStyle.fromJson(Object? raw) => _homeBarStyleFromJson(raw);

  final HomeBarMaterial material;

  /// 玻璃材质下顶栏是否也用玻璃（透出下方滚动的内容）；关闭时只有底栏是
  /// 玻璃，顶栏保持实色。实色材质下不生效。
  final bool glassTopBars;
  final double blurSigma;

  /// 玻璃底色的不透明度（叠在模糊后的内容上）。
  final double tintOpacity;
  final HomeBarTint tint;

  /// [HomeBarTint.custom] 的浅色主题底色（不透明 ARGB）；为 null 时按中性色
  /// 解读，但解码保留原样，不改写用户的选择。
  final int? tintColor;

  /// 深色主题底色；为 null 时由 [tintColor] 推导。
  final int? tintColorDark;

  /// 悬浮底栏与玻璃顶栏的细描边：在与底色相近的内容上勾出栏的边界。
  final bool border;

  /// 悬浮底栏的投影（只用于悬浮底栏）。
  final bool shadow;
  final double barHeight;
  final double cornerRadius;
  final double sideMargin;
  final double bottomGap;
  final HomeBarFabPlacement fabPlacement;
  final HomeBarLabelMode labelMode;
  final double iconSize;
  final HomeBarIndicator indicator;

  bool get isDefault => this == defaults;

  /// 稀疏 JSON：默认样式编码为空对象。
  Map<String, Object> toJson() => _homeBarStyleToJson(this);

  /// 可空颜色用 [ValueGetter] 传入，才能区分“不改”（不传）与“清除”
  /// （`() => null`）。
  HomeBarStyle copyWith({
    HomeBarMaterial? material,
    bool? glassTopBars,
    double? blurSigma,
    double? tintOpacity,
    HomeBarTint? tint,
    ValueGetter<int?>? tintColor,
    ValueGetter<int?>? tintColorDark,
    bool? border,
    bool? shadow,
    double? barHeight,
    double? cornerRadius,
    double? sideMargin,
    double? bottomGap,
    HomeBarFabPlacement? fabPlacement,
    HomeBarLabelMode? labelMode,
    double? iconSize,
    HomeBarIndicator? indicator,
  }) {
    return HomeBarStyle(
      material: material ?? this.material,
      glassTopBars: glassTopBars ?? this.glassTopBars,
      blurSigma: blurSigma ?? this.blurSigma,
      tintOpacity: tintOpacity ?? this.tintOpacity,
      tint: tint ?? this.tint,
      tintColor: tintColor == null ? this.tintColor : tintColor(),
      tintColorDark: tintColorDark == null
          ? this.tintColorDark
          : tintColorDark(),
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      barHeight: barHeight ?? this.barHeight,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      sideMargin: sideMargin ?? this.sideMargin,
      bottomGap: bottomGap ?? this.bottomGap,
      fabPlacement: fabPlacement ?? this.fabPlacement,
      labelMode: labelMode ?? this.labelMode,
      iconSize: iconSize ?? this.iconSize,
      indicator: indicator ?? this.indicator,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarStyle &&
        other.material == material &&
        other.glassTopBars == glassTopBars &&
        other.blurSigma == blurSigma &&
        other.tintOpacity == tintOpacity &&
        other.tint == tint &&
        other.tintColor == tintColor &&
        other.tintColorDark == tintColorDark &&
        other.border == border &&
        other.shadow == shadow &&
        other.barHeight == barHeight &&
        other.cornerRadius == cornerRadius &&
        other.sideMargin == sideMargin &&
        other.bottomGap == bottomGap &&
        other.fabPlacement == fabPlacement &&
        other.labelMode == labelMode &&
        other.iconSize == iconSize &&
        other.indicator == indicator;
  }

  @override
  int get hashCode => Object.hash(
    material,
    glassTopBars,
    blurSigma,
    tintOpacity,
    tint,
    tintColor,
    tintColorDark,
    border,
    shadow,
    barHeight,
    cornerRadius,
    sideMargin,
    bottomGap,
    fabPlacement,
    labelMode,
    iconSize,
    indicator,
  );
}
