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
/// 具体颜色由渲染层（`HomeBarResolvedStyle`）负责，那里还会处理高对比度
/// 回退。
///
/// 底栏只有一种形态：居中的悬浮玻璃胶囊，每个导航项固定宽度。它的几何
/// （高度、圆角、项宽、图标与文字的大小和间距、指示器、描边、投影、模糊）
/// 全部写死在 `HomeBarMetrics`，不开放调节——这些数值互相牵制（指示器要与
/// 胶囊同心、内容要在指示器里居中），放开任何一个都很容易调出失衡的栏。
/// 只留下不破坏比例的五项：
/// - 玻璃：[tint]（中性 / 主题色）、[tintOpacity]（通透程度，模糊强度随它
///   变化，见 `HomeBarResolvedStyle.blurSigma`）；
/// - 顶栏：[topBarHairline]（顶栏底缘的分隔线）——各 Tab 的顶栏恒为与底栏
///   同一配方的玻璃，不再有实色顶栏的开关；
/// - 布局：[labelMode]（文字怎么显示）、[fabPlacement]（新建按钮的位置）。
///
/// 兼容策略：
/// - 解码逐字段容错：缺失、类型不符、未知枚举名或越界的数值只让该字段回退
///   到默认值（越界夹到边界），见 [StyleJson]；
/// - 编码是稀疏的：只写与默认值不同的字段；
/// - 旧版本写下的其余字段（材质、栏高、圆角、边距、图标大小、指示器形态、
///   描边与分隔线的颜色粗细、投影、模糊、自定义色调、顶栏是否用玻璃等）
///   一律忽略，旧设置、旧备份与旧样式码不需要迁移，照常读取；旧数据里的
///   自定义色调（`tint: custom`）按未知枚举值回退中性；
/// - [tintOpacity] 的默认值从 0.72 调到 0.50（玻璃配方重做时）：没改过它的
///   用户（稀疏 JSON 里没有这个字段）有意跟着新默认走；明确存过的值照常
///   保留，超出新范围的（旧“浓雾”的 0.88）夹到上限。
@immutable
class HomeBarStyle {
  const HomeBarStyle({
    this.tintOpacity = 0.5,
    this.tint = HomeBarTint.neutral,
    this.topBarHairline = false,
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
    return HomeBarStyle(
      tintOpacity: StyleJson.number(
        json['tintOpacity'],
        d.tintOpacity,
        HomeBarStyleLimits.tintOpacity,
      ),
      tint: StyleJson.enumByName(HomeBarTint.values, json['tint'], d.tint),
      topBarHairline: StyleJson.boolean(
        json['topBarHairline'],
        d.topBarHairline,
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
    StyleJson.putEnum(json, 'fabPlacement', fabPlacement, d.fabPlacement);
    StyleJson.putEnum(json, 'labelMode', labelMode, d.labelMode);
    return json;
  }

  HomeBarStyle copyWith({
    double? tintOpacity,
    HomeBarTint? tint,
    bool? topBarHairline,
    HomeBarFabPlacement? fabPlacement,
    HomeBarLabelMode? labelMode,
  }) {
    return HomeBarStyle(
      tintOpacity: tintOpacity ?? this.tintOpacity,
      tint: tint ?? this.tint,
      topBarHairline: topBarHairline ?? this.topBarHairline,
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
        other.fabPlacement == fabPlacement &&
        other.labelMode == labelMode;
  }

  @override
  int get hashCode =>
      Object.hash(tintOpacity, tint, topBarHairline, fabPlacement, labelMode);

  @override
  String toString() =>
      'HomeBarStyle($tint, $tintOpacity, topBarHairline: $topBarHairline, '
      '$labelMode, $fabPlacement)';
}
