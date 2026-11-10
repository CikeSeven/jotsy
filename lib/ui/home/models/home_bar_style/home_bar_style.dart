import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';
import 'home_bar_line_style.dart';
import 'home_bar_style_enums.dart';
import 'home_bar_style_limits.dart';

export 'home_bar_line_style.dart';
export 'home_bar_style_enums.dart';
export 'home_bar_style_limits.dart';

part 'home_bar_style_json.dart';

/// 首页栏（底部导航栏 + 日记 / 待办 / 日历 / 探索各 Tab 的顶栏）的外观。
///
/// 输入：持久化的 JSON（单键 `homeBarStyleRaw` 中的 `current`，或样式码）；
/// 输出：不可变的样式对象。无副作用，也不依赖 Flutter 的 `Color`——颜色以
/// ARGB 整数保存，解析为具体颜色、尺寸由渲染层（`HomeBarResolvedStyle`）
/// 负责，那里还会处理高对比度回退与自定义色的可读性兜底。
///
/// 底栏只有一种形态：悬浮的毛玻璃胶囊（贴底铺满的实色栏已移除）。字段分
/// 三组：
/// - 玻璃：[glassTopBars]、[blurSigma]、[tintOpacity]、[tint]、[tintColor]、
///   [tintColorDark]、[border]、[borderLine]、[topBarHairline]、[topBarLine]；
/// - 悬浮底栏几何：[shadow]、[barHeight]、[cornerRadius]、[sideMargin]、
///   [bottomGap]、[fabPlacement]；
/// - 导航项：[labelMode]、[iconSize]、[labelGap]、[indicator]、
///   [blockPadding]。
///
/// 兼容策略：
/// - 解码逐字段容错：缺失、类型不符、未知枚举名或越界的数值只让该字段回退
///   到默认值（越界夹到边界），见 [StyleJson]；
/// - 编码是稀疏的：只写与默认值不同的字段。因此默认值一变，已保存的稀疏
///   JSON 的含义也跟着变——移除实色栏时默认值整体换过一次，旧数据（设置
///   `v` < 2、样式码 v1）必须经 [HomeBarStyle.fromLegacyJson] 读取，见那里的
///   说明；以后再改默认值同样要提升版本并保留旧默认值。
@immutable
class HomeBarStyle {
  const HomeBarStyle({
    this.glassTopBars = true,
    this.blurSigma = 24,
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
    this.sideMargin = 20,
    this.bottomGap = 12,
    this.fabPlacement = HomeBarFabPlacement.above,
    this.labelMode = HomeBarLabelMode.always,
    this.iconSize = 22,
    this.indicator = HomeBarIndicator.block,
    this.labelGap = 2,
    this.blockPadding = 6,
  });

  /// 默认样式：悬浮玻璃胶囊 + 与胶囊同心的圆角块指示器（视觉规格见
  /// DESIGN.md §5.19）。
  static const HomeBarStyle defaults = HomeBarStyle();

  /// 从已解码的当前格式 JSON 构造；不是对象时返回默认样式。
  factory HomeBarStyle.fromJson(Object? raw) =>
      _homeBarStyleFromJson(raw, HomeBarStyle.defaults);

  /// 读取移除实色栏之前保存的样式（设置 `v` 1、样式码 v1）。
  ///
  /// 旧格式的稀疏 JSON 以当时的默认值（实色栏、胶囊指示器、间距 4……）为
  /// 基准，并带一个 `material` 字段：
  /// - `material` 为 `glass`：用户已经在用悬浮玻璃栏，没写出来的字段按
  ///   **旧默认值**补齐，外观与升级前完全相同；
  /// - 其余（实色或缺失）：实色栏不再存在，改用新的默认样式，只保留用户
  ///   明确改过（写进 JSON）的字段，如文字模式、图标大小。
  factory HomeBarStyle.fromLegacyJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) {
      return defaults;
    }
    return _homeBarStyleFromJson(
      json,
      json['material'] == 'glass' ? _legacyGlassDefaults : defaults,
    );
  }

  /// 顶栏是否也用玻璃（透出下方滚动的内容）；关闭时只有底栏是玻璃，顶栏
  /// 保持实色。
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

  /// 文字与图标框之间的距离（与 M3 `labelPadding.top` 同义）。默认 2：
  /// 悬浮栏只有 64 高，圆角块还要在内容四周留出内边距，M3 的 4dp 会让文字
  /// 贴住块的下沿。
  final double labelGap;

  /// 圆角块指示器在内容（图标框 + 文字）四周留出的内边距；只对
  /// [HomeBarIndicator.block] 生效，块放不下时渲染层会先收窄它。
  final double blockPadding;

  bool get isDefault => this == defaults;

  /// 稀疏 JSON：默认样式编码为空对象。
  Map<String, Object> toJson() => _homeBarStyleToJson(this);

  /// 可空颜色用 [ValueGetter] 传入，才能区分“不改”（不传）与“清除”
  /// （`() => null`）。
  HomeBarStyle copyWith({
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
