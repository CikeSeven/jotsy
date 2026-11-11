import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';
import 'home_bar_style_enums.dart';
import 'home_bar_style_limits.dart';

export 'home_bar_style_enums.dart';
export 'home_bar_style_limits.dart';

/// 首页栏（底部导航栏 + 日记 / 待办 / 日历 / 探索各 Tab 的顶栏）的外观。
///
/// 输入：持久化的 JSON（单键 `homeBarStyleRaw` 中的 `current`，或样式码）；
/// 输出：不可变的样式对象。无副作用，也不依赖 Flutter 的 `Color`——解析为
/// 具体颜色与尺寸由渲染层（`HomeBarResolvedStyle`）负责，那里还会处理高
/// 对比度回退。
///
/// 底栏只有一种形态：居中的悬浮玻璃胶囊，每个导航项等宽。字段分三组：
/// - 玻璃：[tint]（中性 / 主题色）、[tintOpacity]（通透程度，模糊强度随它
///   变化，见 `HomeBarResolvedStyle.blurSigma`）、[topBarHairline]（顶栏
///   底缘的分隔线）——各 Tab 的顶栏恒为与底栏同一配方的玻璃；
/// - 形状与导航项：[roundness]（圆角程度）、[itemWidth]、[itemInset]
///   （指示器到胶囊内壁的缝）、[itemIconSize]、[itemLabelSize]、
///   [itemLabelGap]；
/// - 布局：[labelMode]（文字怎么显示）、[fabPlacement]（新建按钮的位置）。
///
/// 为什么没有“栏高”与“指示器圆角”：它们由上面几项推导（见
/// `HomeBarMetrics`），保证比例不失衡——格高 = 图标 + 间距 + 文字 + 上下
/// 留白，栏高 = 格高 + 两倍的缝；指示器与胶囊同心，圆角 = 胶囊圆角 − 缝。
/// 圆角按比例存（[roundness]），栏随图标与文字变高时形状不走样。
///
/// 兼容策略：
/// - 解码逐字段容错：缺失、类型不符、未知枚举名或越界的数值只让该字段回退
///   到默认值（越界夹到边界），见 [StyleJson]；
/// - 编码是稀疏的：只写与默认值不同的字段；
/// - 旧版本写下的其余字段（材质、栏高、`cornerRadius`、边距、`iconSize`、
///   `labelGap`、指示器形态、`blockPadding`、描边与分隔线的颜色粗细、投影、
///   模糊、自定义色调、顶栏是否用玻璃等）一律忽略：形状与导航项的字段用了
///   新的键名（`roundness`、`item*`），旧数据里同义的旧键是按另一套栏高与
///   默认值存的，读进来会得到意料之外的比例。旧设置、旧备份与旧样式码不需要
///   迁移，照常读取；旧数据里的自定义色调（`tint: custom`）按未知枚举值
///   回退中性；
/// - [tintOpacity] 的默认值从 0.72 调到 0.50（玻璃配方重做时）：没改过它的
///   用户（稀疏 JSON 里没有这个字段）有意跟着新默认走；明确存过的值照常
///   保留，超出新范围的（旧“浓雾”的 0.88）夹到上限。
@immutable
class HomeBarStyle {
  const HomeBarStyle({
    this.tintOpacity = 0.5,
    this.tint = HomeBarTint.neutral,
    this.topBarHairline = false,
    this.roundness = 1,
    this.itemWidth = 72,
    this.itemInset = 6,
    this.itemIconSize = 22,
    this.itemLabelSize = 11,
    this.itemLabelGap = 3,
    this.fabPlacement = HomeBarFabPlacement.above,
    this.labelMode = HomeBarLabelMode.always,
  });

  /// 默认样式：中性色调的悬浮玻璃胶囊，图标下方始终显示文字（视觉规格见
  /// DESIGN.md §5.19）。
  static const HomeBarStyle defaults = HomeBarStyle();

  /// 从已解码的 JSON 构造；不是对象时返回默认样式。
  factory HomeBarStyle.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) {
      return defaults;
    }
    const d = defaults;
    double number(String key, double fallback, StyleRange range) =>
        StyleJson.number(json[key], fallback, range);
    return HomeBarStyle(
      tintOpacity: number(
        'tintOpacity',
        d.tintOpacity,
        HomeBarStyleLimits.tintOpacity,
      ),
      tint: StyleJson.enumByName(HomeBarTint.values, json['tint'], d.tint),
      topBarHairline: StyleJson.boolean(
        json['topBarHairline'],
        d.topBarHairline,
      ),
      roundness: number('roundness', d.roundness, HomeBarStyleLimits.roundness),
      itemWidth: number('itemWidth', d.itemWidth, HomeBarStyleLimits.itemWidth),
      itemInset: number('itemInset', d.itemInset, HomeBarStyleLimits.itemInset),
      itemIconSize: number(
        'itemIconSize',
        d.itemIconSize,
        HomeBarStyleLimits.itemIconSize,
      ),
      itemLabelSize: number(
        'itemLabelSize',
        d.itemLabelSize,
        HomeBarStyleLimits.itemLabelSize,
      ),
      itemLabelGap: number(
        'itemLabelGap',
        d.itemLabelGap,
        HomeBarStyleLimits.itemLabelGap,
      ),
      fabPlacement: StyleJson.enumByName(
        HomeBarFabPlacement.values,
        json['fabPlacement'],
        d.fabPlacement,
      ),
      labelMode: StyleJson.enumByName(
        HomeBarLabelMode.values,
        json['labelMode'],
        d.labelMode,
      ),
    );
  }

  /// 玻璃底色的不透明度（叠在模糊后的内容上）：越低越通透。
  final double tintOpacity;
  final HomeBarTint tint;

  /// 顶栏底部的细分隔线，默认关闭：顶栏贴着屏幕上沿铺满，靠模糊与底色
  /// 已能和内容区分开，常驻的细线反而显得割裂；想要清晰边界的用户可以
  /// 打开。
  final bool topBarHairline;

  /// 圆角程度：胶囊圆角 = 它 × 栏高的一半（1 为完整胶囊，0 为直角）。
  /// 选中指示器、并排的新建按钮跟着同心变化。
  final double roundness;

  /// 每个导航项（与选中指示器）的首选宽度；屏幕放不下时等比收窄。
  final double itemWidth;

  /// 导航项与胶囊内壁的缝：指示器四周离胶囊边都是这么宽。
  final double itemInset;

  /// 导航项的图标大小、文字字号与两者间距（只有图标时后两项不起作用）。
  final double itemIconSize;
  final double itemLabelSize;
  final double itemLabelGap;

  final HomeBarFabPlacement fabPlacement;
  final HomeBarLabelMode labelMode;

  bool get isDefault => this == defaults;

  /// 稀疏 JSON：默认样式编码为空对象。
  Map<String, Object> toJson() {
    const d = defaults;
    final json = <String, Object>{};
    StyleJson.put(json, 'tintOpacity', tintOpacity, d.tintOpacity);
    StyleJson.putEnum(json, 'tint', tint, d.tint);
    StyleJson.put(json, 'topBarHairline', topBarHairline, d.topBarHairline);
    StyleJson.put(json, 'roundness', roundness, d.roundness);
    StyleJson.put(json, 'itemWidth', itemWidth, d.itemWidth);
    StyleJson.put(json, 'itemInset', itemInset, d.itemInset);
    StyleJson.put(json, 'itemIconSize', itemIconSize, d.itemIconSize);
    StyleJson.put(json, 'itemLabelSize', itemLabelSize, d.itemLabelSize);
    StyleJson.put(json, 'itemLabelGap', itemLabelGap, d.itemLabelGap);
    StyleJson.putEnum(json, 'fabPlacement', fabPlacement, d.fabPlacement);
    StyleJson.putEnum(json, 'labelMode', labelMode, d.labelMode);
    return json;
  }

  HomeBarStyle copyWith({
    double? tintOpacity,
    HomeBarTint? tint,
    bool? topBarHairline,
    double? roundness,
    double? itemWidth,
    double? itemInset,
    double? itemIconSize,
    double? itemLabelSize,
    double? itemLabelGap,
    HomeBarFabPlacement? fabPlacement,
    HomeBarLabelMode? labelMode,
  }) {
    return HomeBarStyle(
      tintOpacity: tintOpacity ?? this.tintOpacity,
      tint: tint ?? this.tint,
      topBarHairline: topBarHairline ?? this.topBarHairline,
      roundness: roundness ?? this.roundness,
      itemWidth: itemWidth ?? this.itemWidth,
      itemInset: itemInset ?? this.itemInset,
      itemIconSize: itemIconSize ?? this.itemIconSize,
      itemLabelSize: itemLabelSize ?? this.itemLabelSize,
      itemLabelGap: itemLabelGap ?? this.itemLabelGap,
      fabPlacement: fabPlacement ?? this.fabPlacement,
      labelMode: labelMode ?? this.labelMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarStyle &&
        other.tintOpacity == tintOpacity &&
        other.tint == tint &&
        other.topBarHairline == topBarHairline &&
        other.roundness == roundness &&
        other.itemWidth == itemWidth &&
        other.itemInset == itemInset &&
        other.itemIconSize == itemIconSize &&
        other.itemLabelSize == itemLabelSize &&
        other.itemLabelGap == itemLabelGap &&
        other.fabPlacement == fabPlacement &&
        other.labelMode == labelMode;
  }

  @override
  int get hashCode => Object.hash(
    tintOpacity,
    tint,
    topBarHairline,
    roundness,
    itemWidth,
    itemInset,
    itemIconSize,
    itemLabelSize,
    itemLabelGap,
    fabPlacement,
    labelMode,
  );

  @override
  String toString() =>
      'HomeBarStyle($tint, $tintOpacity, topBarHairline: $topBarHairline, '
      'roundness: $roundness, item: ${itemWidth}w inset $itemInset '
      'icon $itemIconSize label $itemLabelSize gap $itemLabelGap, '
      '$labelMode, $fabPlacement)';
}
