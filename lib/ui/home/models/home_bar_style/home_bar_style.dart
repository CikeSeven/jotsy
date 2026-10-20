import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';
import 'home_bar_line_style.dart';
import 'home_bar_style_enums.dart';
import 'home_bar_style_limits.dart';

export 'home_bar_line_style.dart';
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
///   [tint]、[tintColor]、[tintColorDark]、[border]、[borderLine]、
///   [topBarHairline]、[topBarLine]；只在玻璃材质下生效；
/// - 悬浮底栏几何：[shadow]、[barHeight]、[cornerRadius]、[sideMargin]、
///   [bottomGap]、[fabPlacement]；实色底栏贴底铺满，不用这些；
/// - 导航项：[labelMode]、[iconSize]、[labelGap]、[indicator]、
///   [blockPadding]；两种材质都适用。
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
    this.borderLine = HomeBarLineStyle.borderDefaults,
    this.topBarHairline = false,
    this.topBarLine = HomeBarLineStyle.topBarDefaults,
    this.shadow = true,
    this.barHeight = 64,
    this.cornerRadius = 32,
    this.sideMargin = 16,
    this.bottomGap = 12,
    this.fabPlacement = HomeBarFabPlacement.above,
    this.labelMode = HomeBarLabelMode.always,
    this.iconSize = 20,
    this.indicator = HomeBarIndicator.capsule,
    this.labelGap = 4,
    this.blockPadding = 6,
  });

  static const HomeBarStyle defaults = HomeBarStyle();

  /// 玻璃材质下推荐的图标与文字间距：玻璃悬浮栏默认只有 64 高，圆角块
  /// 还要在内容四周留出内边距，M3 的 4dp 间距会让文字贴住块的下沿。
  static const double glassLabelGap = 2;

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

  /// 悬浮底栏的细描边：在与底色相近的内容上勾出栏的边界。只管底栏，
  /// 顶栏的分隔线另由 [topBarHairline] 控制。
  final bool border;

  /// 底栏描边的颜色、不透明度与粗细；只在 [border] 打开时生效，关掉开关
  /// 时保留，重新打开即恢复。
  final HomeBarLineStyle borderLine;

  /// 玻璃顶栏底部的细分隔线。与 [border] 分开、默认关闭：顶栏贴着屏幕
  /// 上沿铺满，靠模糊与底色已能和内容区分开，常驻的细线反而显得割裂；
  /// 想要清晰边界的用户可以单独打开，不必连带改动底栏描边。
  final bool topBarHairline;

  /// 顶栏分隔线的颜色、不透明度与粗细；只在 [topBarHairline] 打开时生效。
  final HomeBarLineStyle topBarLine;

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

  /// 文字与图标框之间的距离（与 M3 `labelPadding.top` 同义）；默认 4 即 M3，
  /// 实色栏才能与改版前逐像素一致。
  final double labelGap;

  /// 圆角块指示器在内容（图标框 + 文字）四周留出的内边距；只对
  /// [HomeBarIndicator.block] 生效，块放不下时渲染层会先收窄它。
  final double blockPadding;

  bool get isDefault => this == defaults;

  /// 稀疏 JSON：默认样式编码为空对象。
  Map<String, Object> toJson() => _homeBarStyleToJson(this);

  /// 换材质，并联动图标与文字间距：玻璃栏更矮、又常配圆角块，默认的 4dp
  /// 会让内容撑满块，所以切到玻璃时把仍是实色默认值的间距收紧到
  /// [glassLabelGap]，切回实色时把仍是玻璃默认值的间距还原。用户调过的
  /// 其他值一律保留——联动只替换“没人动过”的默认值，不覆盖用户的选择。
  HomeBarStyle withMaterial(HomeBarMaterial material) {
    var gap = labelGap;
    if (material == HomeBarMaterial.glass && gap == defaults.labelGap) {
      gap = glassLabelGap;
    } else if (material == HomeBarMaterial.solid && gap == glassLabelGap) {
      gap = defaults.labelGap;
    }
    return copyWith(material: material, labelGap: gap);
  }

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
    HomeBarLineStyle? borderLine,
    bool? topBarHairline,
    HomeBarLineStyle? topBarLine,
    bool? shadow,
    double? barHeight,
    double? cornerRadius,
    double? sideMargin,
    double? bottomGap,
    HomeBarFabPlacement? fabPlacement,
    HomeBarLabelMode? labelMode,
    double? iconSize,
    HomeBarIndicator? indicator,
    double? labelGap,
    double? blockPadding,
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
      borderLine: borderLine ?? this.borderLine,
      topBarHairline: topBarHairline ?? this.topBarHairline,
      topBarLine: topBarLine ?? this.topBarLine,
      shadow: shadow ?? this.shadow,
      barHeight: barHeight ?? this.barHeight,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      sideMargin: sideMargin ?? this.sideMargin,
      bottomGap: bottomGap ?? this.bottomGap,
      fabPlacement: fabPlacement ?? this.fabPlacement,
      labelMode: labelMode ?? this.labelMode,
      iconSize: iconSize ?? this.iconSize,
      indicator: indicator ?? this.indicator,
      labelGap: labelGap ?? this.labelGap,
      blockPadding: blockPadding ?? this.blockPadding,
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
        other.borderLine == borderLine &&
        other.topBarHairline == topBarHairline &&
        other.topBarLine == topBarLine &&
        other.shadow == shadow &&
        other.barHeight == barHeight &&
        other.cornerRadius == cornerRadius &&
        other.sideMargin == sideMargin &&
        other.bottomGap == bottomGap &&
        other.fabPlacement == fabPlacement &&
        other.labelMode == labelMode &&
        other.iconSize == iconSize &&
        other.indicator == indicator &&
        other.labelGap == labelGap &&
        other.blockPadding == blockPadding;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    material,
    glassTopBars,
    blurSigma,
    tintOpacity,
    tint,
    tintColor,
    tintColorDark,
    border,
    borderLine,
    topBarHairline,
    topBarLine,
    shadow,
    barHeight,
    cornerRadius,
    sideMargin,
    bottomGap,
    fabPlacement,
    labelMode,
    iconSize,
    indicator,
    labelGap,
    blockPadding,
  ]);
}
