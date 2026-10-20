part of 'home_bar_style.dart';

// HomeBarStyle 的 JSON 读写：逐字段容错解码、稀疏编码。拆出来只为让模型
// 文件保持在拆分阈值以内；规则见 HomeBarStyle 与 StyleJson 的说明。

HomeBarStyle _homeBarStyleFromJson(Object? raw) {
  final json = StyleJson.map(raw);
  if (json == null) {
    return HomeBarStyle.defaults;
  }
  const d = HomeBarStyle.defaults;
  return HomeBarStyle(
    material: StyleJson.enumByName(
      HomeBarMaterial.values,
      json['material'],
      d.material,
    ),
    glassTopBars: StyleJson.boolean(json['glassTopBars'], d.glassTopBars),
    blurSigma: StyleJson.number(
      json['blurSigma'],
      d.blurSigma,
      HomeBarStyleLimits.blurSigma,
    ),
    tintOpacity: StyleJson.number(
      json['tintOpacity'],
      d.tintOpacity,
      HomeBarStyleLimits.tintOpacity,
    ),
    tint: StyleJson.enumByName(HomeBarTint.values, json['tint'], d.tint),
    // 颜色与其他样式一致：接受 ARGB 整数或 `#RRGGBB`，一律存为不透明色——
    // 玻璃的透明度只由 tintOpacity 表达，避免两处透明度叠乘。
    tintColor: StyleJson.argb(json['tintColor']),
    tintColorDark: StyleJson.argb(json['tintColorDark']),
    border: StyleJson.boolean(json['border'], d.border),
    shadow: StyleJson.boolean(json['shadow'], d.shadow),
    barHeight: StyleJson.number(
      json['barHeight'],
      d.barHeight,
      HomeBarStyleLimits.barHeight,
    ),
    cornerRadius: StyleJson.number(
      json['cornerRadius'],
      d.cornerRadius,
      HomeBarStyleLimits.cornerRadius,
    ),
    sideMargin: StyleJson.number(
      json['sideMargin'],
      d.sideMargin,
      HomeBarStyleLimits.sideMargin,
    ),
    bottomGap: StyleJson.number(
      json['bottomGap'],
      d.bottomGap,
      HomeBarStyleLimits.bottomGap,
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
    iconSize: StyleJson.number(
      json['iconSize'],
      d.iconSize,
      HomeBarStyleLimits.iconSize,
    ),
    indicator: StyleJson.enumByName(
      HomeBarIndicator.values,
      json['indicator'],
      d.indicator,
    ),
  );
}

Map<String, Object> _homeBarStyleToJson(HomeBarStyle s) {
  const d = HomeBarStyle.defaults;
  final json = <String, Object>{};
  StyleJson.putEnum(json, 'material', s.material, d.material);
  StyleJson.put(json, 'glassTopBars', s.glassTopBars, d.glassTopBars);
  StyleJson.put(json, 'blurSigma', s.blurSigma, d.blurSigma);
  StyleJson.put(json, 'tintOpacity', s.tintOpacity, d.tintOpacity);
  StyleJson.putEnum(json, 'tint', s.tint, d.tint);
  StyleJson.putColor(json, 'tintColor', s.tintColor, d.tintColor);
  StyleJson.putColor(json, 'tintColorDark', s.tintColorDark, d.tintColorDark);
  StyleJson.put(json, 'border', s.border, d.border);
  StyleJson.put(json, 'shadow', s.shadow, d.shadow);
  StyleJson.put(json, 'barHeight', s.barHeight, d.barHeight);
  StyleJson.put(json, 'cornerRadius', s.cornerRadius, d.cornerRadius);
  StyleJson.put(json, 'sideMargin', s.sideMargin, d.sideMargin);
  StyleJson.put(json, 'bottomGap', s.bottomGap, d.bottomGap);
  StyleJson.putEnum(json, 'fabPlacement', s.fabPlacement, d.fabPlacement);
  StyleJson.putEnum(json, 'labelMode', s.labelMode, d.labelMode);
  StyleJson.put(json, 'iconSize', s.iconSize, d.iconSize);
  StyleJson.putEnum(json, 'indicator', s.indicator, d.indicator);
  return json;
}
