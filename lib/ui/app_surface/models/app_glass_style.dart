import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'app_surface_enums.dart';
import 'app_surface_limits.dart';

/// 各类组件的材质（经典实色 / 玻璃）与玻璃的外观参数。
///
/// 输入：已解码的 JSON（`AppSurfaceSettings` 里的 `glass`）；输出：不可变
/// 对象。整体材质 [mode] 之外，每类组件可以经 [overrides] 固定为某种材质；
/// 缺省（或 follow）即跟随整体，判断一律经 [isGlass]，渲染层不要自己读
/// [overrides]。
///
/// 兼容策略：认不出的组件键或覆盖值整项忽略（按 follow），数值越界夹紧，
/// 编码稀疏——覆盖表只写不是 follow 的项。
@immutable
class AppGlassStyle {
  const AppGlassStyle({
    this.mode = AppGlassMode.classic,
    this.overrides = const <AppGlassComponent, AppGlassOverride>{},
    this.blurSigma = 20,
    this.tintOpacity = 0.72,
    this.tint = AppGlassTint.neutral,
    this.tintColor,
    this.tintColorDark,
    this.border = true,
  });

  static const AppGlassStyle defaults = AppGlassStyle();

  /// 从已解码的 JSON 构造；不是对象时返回默认（全部经典材质）。
  factory AppGlassStyle.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return defaults;
    const d = defaults;
    return AppGlassStyle(
      mode: StyleJson.enumByName(AppGlassMode.values, json['mode'], d.mode),
      overrides: _decodeOverrides(json['overrides']),
      blurSigma: StyleJson.number(
        json['blurSigma'],
        d.blurSigma,
        AppSurfaceLimits.glassBlurSigma,
      ),
      tintOpacity: StyleJson.number(
        json['tintOpacity'],
        d.tintOpacity,
        AppSurfaceLimits.glassTintOpacity,
      ),
      tint: StyleJson.enumByName(AppGlassTint.values, json['tint'], d.tint),
      // 玻璃的透明度只由 tintOpacity 表达，颜色一律存为不透明色。
      tintColor: StyleJson.argb(json['tintColor']),
      tintColorDark: StyleJson.argb(json['tintColorDark']),
      border: StyleJson.boolean(json['border'], d.border),
    );
  }

  final AppGlassMode mode;

  /// 各类组件的材质覆盖。解码与 [copyWith] / [withOverride] 产生的表只含
  /// 不是 follow 的项且不可修改；比较与编码一律按 [overrideFor] 的实际
  /// 生效值，“没写”与“写了 follow”相等。读取请用 [overrideFor] / [isGlass]。
  final Map<AppGlassComponent, AppGlassOverride> overrides;

  /// 玻璃的模糊半径（sigma）。
  final double blurSigma;

  /// 玻璃底色的不透明度（叠在模糊后的内容上）。
  final double tintOpacity;
  final AppGlassTint tint;

  /// [AppGlassTint.custom] 的浅色主题底色（不透明 ARGB）；为 null 时按中性色
  /// 解读，但解码保留原样，不改写用户的选择。
  final int? tintColor;

  /// 深色主题底色；为 null 时由 [tintColor] 推导（在渲染层）。
  final int? tintColorDark;

  /// 玻璃边缘的细描边：在与底色相近的背景上勾出组件的边界。
  final bool border;

  bool get isDefault => this == defaults;

  AppGlassOverride overrideFor(AppGlassComponent component) =>
      overrides[component] ?? AppGlassOverride.follow;

  /// 某类组件实际是否用玻璃：覆盖为 follow 时取整体材质。
  bool isGlass(AppGlassComponent component) => switch (overrideFor(component)) {
    AppGlassOverride.follow => mode == AppGlassMode.glass,
    AppGlassOverride.classic => false,
    AppGlassOverride.glass => true,
  };

  /// 是否有任何一类组件用玻璃（渲染层据此决定是否需要准备模糊）。
  bool get anyGlass => AppGlassComponent.values.any(isGlass);

  AppGlassStyle withOverride(
    AppGlassComponent component,
    AppGlassOverride value,
  ) {
    final next = Map<AppGlassComponent, AppGlassOverride>.of(overrides);
    if (value == AppGlassOverride.follow) {
      next.remove(component);
    } else {
      next[component] = value;
    }
    return copyWith(overrides: next);
  }

  /// 只换整体材质，各组件的覆盖原样保留。
  AppGlassStyle withMode(AppGlassMode value) => copyWith(mode: value);

  /// 稀疏 JSON：默认编码为空对象。
  Map<String, Object> toJson() {
    const d = defaults;
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'mode', mode, d.mode);
    // 按枚举顺序写出，同一份设置的编码结果稳定（便于比较与测试）。
    final encodedOverrides = <String, Object>{
      for (final component in AppGlassComponent.values)
        if (overrideFor(component) != AppGlassOverride.follow)
          component.name: overrideFor(component).name,
    };
    StyleJson.putObject(json, 'overrides', encodedOverrides);
    StyleJson.put(json, 'blurSigma', blurSigma, d.blurSigma);
    StyleJson.put(json, 'tintOpacity', tintOpacity, d.tintOpacity);
    StyleJson.putEnum(json, 'tint', tint, d.tint);
    StyleJson.putColor(json, 'tintColor', tintColor, d.tintColor);
    StyleJson.putColor(json, 'tintColorDark', tintColorDark, d.tintColorDark);
    StyleJson.put(json, 'border', border, d.border);
    return json;
  }

  /// 可空颜色用 [ValueGetter] 传入，才能区分“不改”（不传）与“清除”
  /// （`() => null`）。
  AppGlassStyle copyWith({
    AppGlassMode? mode,
    Map<AppGlassComponent, AppGlassOverride>? overrides,
    double? blurSigma,
    double? tintOpacity,
    AppGlassTint? tint,
    ValueGetter<int?>? tintColor,
    ValueGetter<int?>? tintColorDark,
    bool? border,
  }) {
    return AppGlassStyle(
      mode: mode ?? this.mode,
      overrides: overrides == null
          ? this.overrides
          : _normalizeOverrides(overrides),
      blurSigma: blurSigma ?? this.blurSigma,
      tintOpacity: tintOpacity ?? this.tintOpacity,
      tint: tint ?? this.tint,
      tintColor: tintColor == null ? this.tintColor : tintColor(),
      tintColorDark: tintColorDark == null
          ? this.tintColorDark
          : tintColorDark(),
      border: border ?? this.border,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppGlassStyle &&
        other.mode == mode &&
        _sameOverrides(other) &&
        other.blurSigma == blurSigma &&
        other.tintOpacity == tintOpacity &&
        other.tint == tint &&
        other.tintColor == tintColor &&
        other.tintColorDark == tintColorDark &&
        other.border == border;
  }

  /// 按实际生效的覆盖比较：直接传入构造函数、带着 follow 项的表与不带的表
  /// 也视为相等。
  bool _sameOverrides(AppGlassStyle other) => AppGlassComponent.values.every(
    (component) => overrideFor(component) == other.overrideFor(component),
  );

  @override
  int get hashCode => Object.hash(
    mode,
    Object.hashAll([
      for (final component in AppGlassComponent.values) overrideFor(component),
    ]),
    blurSigma,
    tintOpacity,
    tint,
    tintColor,
    tintColorDark,
    border,
  );

  /// 解码覆盖表：认不出的组件键或覆盖值整项忽略（按 follow），follow 项不
  /// 存。
  static Map<AppGlassComponent, AppGlassOverride> _decodeOverrides(
    Object? raw,
  ) {
    final json = StyleJson.map(raw);
    if (json == null) return const <AppGlassComponent, AppGlassOverride>{};
    final result = <AppGlassComponent, AppGlassOverride>{};
    for (final component in AppGlassComponent.values) {
      final value = StyleJson.enumByName(
        AppGlassOverride.values,
        json[component.name],
        AppGlassOverride.follow,
      );
      if (value != AppGlassOverride.follow) result[component] = value;
    }
    return Map.unmodifiable(result);
  }

  static Map<AppGlassComponent, AppGlassOverride> _normalizeOverrides(
    Map<AppGlassComponent, AppGlassOverride> raw,
  ) => Map.unmodifiable(<AppGlassComponent, AppGlassOverride>{
    for (final entry in raw.entries)
      if (entry.value != AppGlassOverride.follow) entry.key: entry.value,
  });
}
