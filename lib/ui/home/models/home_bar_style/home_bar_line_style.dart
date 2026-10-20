import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';
import 'home_bar_style_enums.dart';
import 'home_bar_style_limits.dart';

/// 一条细线（悬浮底栏的描边、玻璃顶栏底部的分隔线）的外观：颜色来源、
/// 自定义色、不透明度与粗细。是否画这条线不在这里，由 `HomeBarStyle` 的
/// `border` / `topBarHairline` 开关决定——关掉开关时保留这里的调整，再打开
/// 时原样恢复。
///
/// 两条线共用这一个类型，但默认值不同（底栏描边更明显、顶栏分隔线更淡），
/// 所以 JSON 的读写都以“这条线自己的默认值”为基准：解码时缺失或无效的字段
/// 回退到它，编码时只写与它不同的字段（与默认相同时整个对象都不写）。
///
/// 颜色与玻璃底色一样以 ARGB 整数保存、一律不透明：透明度只由 [opacity]
/// 表达，避免两处透明度叠乘。解析为具体颜色由 `HomeBarLineColors` 负责。
@immutable
class HomeBarLineStyle {
  const HomeBarLineStyle({
    this.color = HomeBarLineColor.theme,
    this.customColor,
    this.customColorDark,
    required this.opacity,
    required this.width,
  });

  /// 悬浮底栏描边的默认值：与改版前浅色主题下的描边相同（outlineVariant、
  /// 60% 不透明、1dp）。
  ///
  /// 改版前深色主题的描边是 50%，统一为一个不透明度后深色略微变亮；玻璃
  /// 材质尚未发布、实色栏没有描边，这个差异可以接受。
  static const HomeBarLineStyle borderDefaults = HomeBarLineStyle(
    opacity: 0.6,
    width: 1.0,
  );

  /// 玻璃顶栏分隔线的默认值：与改版前浅色主题下的分隔线相同（35%、0.6dp）。
  /// 改版前深色为 20%，同样统一后略微变亮，理由同 [borderDefaults]。
  static const HomeBarLineStyle topBarDefaults = HomeBarLineStyle(
    opacity: 0.35,
    width: 0.6,
  );

  /// 从已解码的 JSON 构造；不是对象时返回 [fallback]，各字段缺失或无效时
  /// 只让该字段回退到 [fallback] 的值（数值越界夹到边界）。
  factory HomeBarLineStyle.fromJson(
    Object? raw, {
    required HomeBarLineStyle fallback,
  }) {
    final json = StyleJson.map(raw);
    if (json == null) {
      return fallback;
    }
    return HomeBarLineStyle(
      color: StyleJson.enumByName(
        HomeBarLineColor.values,
        json['color'],
        fallback.color,
      ),
      customColor: StyleJson.argb(json['customColor']) ?? fallback.customColor,
      customColorDark:
          StyleJson.argb(json['customColorDark']) ?? fallback.customColorDark,
      opacity: StyleJson.number(
        json['opacity'],
        fallback.opacity,
        HomeBarStyleLimits.lineOpacity,
      ),
      width: StyleJson.number(
        json['width'],
        fallback.width,
        HomeBarStyleLimits.lineWidth,
      ),
    );
  }

  final HomeBarLineColor color;

  /// [HomeBarLineColor.custom] 的浅色主题颜色（不透明 ARGB）；为 null 时按
  /// 跟随主题解读，但解码保留原样，不改写用户的选择。
  final int? customColor;

  /// 深色主题颜色；为 null 时由 [customColor] 推导。
  final int? customColorDark;
  final double opacity;
  final double width;

  /// 相对 [fallback] 的稀疏 JSON：与它相同的字段不写。
  Map<String, Object> toJson(HomeBarLineStyle fallback) {
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'color', color, fallback.color);
    StyleJson.putColor(json, 'customColor', customColor, fallback.customColor);
    StyleJson.putColor(
      json,
      'customColorDark',
      customColorDark,
      fallback.customColorDark,
    );
    StyleJson.put(json, 'opacity', opacity, fallback.opacity);
    StyleJson.put(json, 'width', width, fallback.width);
    return json;
  }

  /// 可空颜色用 [ValueGetter] 传入，才能区分“不改”（不传）与“清除”
  /// （`() => null`）。
  HomeBarLineStyle copyWith({
    HomeBarLineColor? color,
    ValueGetter<int?>? customColor,
    ValueGetter<int?>? customColorDark,
    double? opacity,
    double? width,
  }) {
    return HomeBarLineStyle(
      color: color ?? this.color,
      customColor: customColor == null ? this.customColor : customColor(),
      customColorDark: customColorDark == null
          ? this.customColorDark
          : customColorDark(),
      opacity: opacity ?? this.opacity,
      width: width ?? this.width,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarLineStyle &&
        other.color == color &&
        other.customColor == customColor &&
        other.customColorDark == customColorDark &&
        other.opacity == opacity &&
        other.width == width;
  }

  @override
  int get hashCode =>
      Object.hash(color, customColor, customColorDark, opacity, width);

  @override
  String toString() =>
      'HomeBarLineStyle($color, $customColor, $customColorDark, '
      '$opacity, $width)';
}
