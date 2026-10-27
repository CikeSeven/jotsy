import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'app_area_background.dart';
import 'app_background.dart';
import 'app_glass_style.dart';
import 'app_surface_enums.dart';

export 'app_area_background.dart';
export 'app_background.dart';
export 'app_glass_style.dart';
export 'app_surface_enums.dart';
export 'app_surface_limits.dart';

/// “背景与材质”设置的整体：全局背景、各区域背景与组件材质。
///
/// 持久化为单个 JSON 键（`app.settings.app_surface`，备份字段
/// `appSurfaceRaw`）：
/// `{"v":1,"global":{…},"areas":{"editor":{"mode":"custom","background":{…}}},
/// "glass":{"mode":"glass","overrides":{"toolbar":"classic"},…}}`。
/// 放在一个键里，备份恢复与失败回滚都是原子的，也只需一个通知源。全为默认
/// 时编码为 null，由设置服务删除该键。
///
/// 兼容策略：整体坏 JSON 回落默认；各部分逐字段容错（见各子模型），认不出
/// 的区域键整项忽略；编码稀疏，与默认相同的区域不写。
@immutable
class AppSurfaceSettings {
  const AppSurfaceSettings({
    this.global = AppBackground.defaults,
    this.areas = const <AppBackgroundArea, AppAreaBackground>{},
    this.glass = AppGlassStyle.defaults,
  });

  static const AppSurfaceSettings defaults = AppSurfaceSettings();
  static const int schemaVersion = 1;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认设置。
  static AppSurfaceSettings decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // 损坏的配置按默认外观展示，不能让背景偏好阻断启动。
      return defaults;
    }
    final json = StyleJson.map(decoded);
    if (json == null) return defaults;
    return AppSurfaceSettings(
      global: AppBackground.fromJson(json['global']),
      areas: _decodeAreas(json['areas']),
      glass: AppGlassStyle.fromJson(json['glass']),
    );
  }

  /// 全局背景：区域为 follow 时用它。
  final AppBackground global;

  /// 各区域的背景设置；缺省即 [AppAreaBackground.defaults]（跟随全局）。
  /// 读取请用 [areaOf]，比较按实际生效值，“没写”与“写了默认值”相等。
  final Map<AppBackgroundArea, AppAreaBackground> areas;

  final AppGlassStyle glass;

  bool get isDefault => this == defaults;

  AppAreaBackground areaOf(AppBackgroundArea area) =>
      areas[area] ?? AppAreaBackground.defaults;

  /// 某个区域实际使用的背景：follow 取全局，off 为无背景，custom 取区域
  /// 自己的背景。
  AppBackground backgroundFor(AppBackgroundArea area) {
    final setting = areaOf(area);
    return switch (setting.mode) {
      AppAreaBackgroundMode.follow => global,
      AppAreaBackgroundMode.off => AppBackground.defaults,
      AppAreaBackgroundMode.custom => setting.custom,
    };
  }

  /// 设置里提到的全部背景图文件名，供清理托管目录时保留。
  ///
  /// 不论种类是否为图片、区域是否处于 custom，都算作引用：这些值只是暂不
  /// 启用，用户切回时还要用，提前删掉文件就再也找不回来了。
  Set<String> get referencedImages => <String>{
    ?_nonEmpty(global.image),
    for (final area in AppBackgroundArea.values)
      ?_nonEmpty(areaOf(area).custom.image),
  };

  AppSurfaceSettings withGlobal(AppBackground value) =>
      AppSurfaceSettings(global: value, areas: areas, glass: glass);

  AppSurfaceSettings withGlass(AppGlassStyle value) =>
      AppSurfaceSettings(global: global, areas: areas, glass: value);

  /// 替换某个区域的设置；设为默认值即从表中移除，保持稀疏。
  AppSurfaceSettings withArea(AppBackgroundArea area, AppAreaBackground value) {
    final next = Map<AppBackgroundArea, AppAreaBackground>.of(areas);
    if (value.isDefault) {
      next.remove(area);
    } else {
      next[area] = value;
    }
    return AppSurfaceSettings(
      global: global,
      areas: Map.unmodifiable(next),
      glass: glass,
    );
  }

  /// 默认设置编码为 null（删除键）。
  String? encode() {
    if (isDefault) return null;
    final json = <String, Object>{'v': schemaVersion};
    StyleJson.putObject(json, 'global', global.toJson());
    // 按枚举顺序写出，同一份设置的编码结果稳定。
    final encodedAreas = <String, Object>{
      for (final area in AppBackgroundArea.values)
        if (!areaOf(area).isDefault) area.name: areaOf(area).toJson(),
    };
    StyleJson.putObject(json, 'areas', encodedAreas);
    StyleJson.putObject(json, 'glass', glass.toJson());
    return jsonEncode(json);
  }

  @override
  bool operator ==(Object other) {
    return other is AppSurfaceSettings &&
        other.global == global &&
        AppBackgroundArea.values.every(
          (area) => areaOf(area) == other.areaOf(area),
        ) &&
        other.glass == glass;
  }

  @override
  int get hashCode => Object.hash(
    global,
    Object.hashAll([for (final area in AppBackgroundArea.values) areaOf(area)]),
    glass,
  );

  /// 解码区域表：认不出的区域键整项忽略，与默认相同的项不存。
  static Map<AppBackgroundArea, AppAreaBackground> _decodeAreas(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return const <AppBackgroundArea, AppAreaBackground>{};
    final result = <AppBackgroundArea, AppAreaBackground>{};
    for (final area in AppBackgroundArea.values) {
      if (!json.containsKey(area.name)) continue;
      final value = AppAreaBackground.fromJson(json[area.name]);
      if (!value.isDefault) result[area] = value;
    }
    return Map.unmodifiable(result);
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
