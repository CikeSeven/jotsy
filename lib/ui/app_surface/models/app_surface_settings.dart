import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'app_area_background.dart';
import 'app_background.dart';
import 'app_background_source.dart';
import 'app_glass_style.dart';
import 'app_surface_enums.dart';

export 'app_area_background.dart';
export 'app_background.dart';
export 'app_background_source.dart';
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
///
/// 跟随（区域单独设置时图片 / 参数取自 `AppAreaBackground.source`）：
/// - 取的是来源**当前显示**的背景：来源跟随全局即取全局，来源不显示背景即
///   取默认（没有图片），来源单独设置即取它解析后的结果（它自己也可能在
///   跟随，沿来源链继续往下）；图片只在来源显示的是图片时才有；
/// - 界面经 [canFollow] 不让来源链成环；手改的备份仍可能成环，解析时一旦
///   回到走过的区域就不再跟随，用区域自己的那一份。
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
  /// 单独设置的背景（图片 / 参数按跟随取值，见 [resolvedCustom]）。
  AppBackground backgroundFor(AppBackgroundArea area) =>
      _resolveArea(area, <AppBackgroundArea>{});

  /// [area] 单独设置的背景按跟随解析后的结果，不看区域当前的取值方式——
  /// 编辑器在切换取值方式的收起动画里仍按单独设置显示。
  AppBackground resolvedCustom(AppBackgroundArea area) =>
      _resolveCustom(area, <AppBackgroundArea>{area});

  /// [source] 当前显示的背景（全局即全局背景，区域同 [backgroundFor]）。
  AppBackground backgroundOfSource(AppBackgroundSource source) {
    final area = source.area;
    return area == null ? global : backgroundFor(area);
  }

  /// [area] 能否以 [source] 为跟随来源：不能是自己，也不能是来源链（沿各
  /// 区域保存的来源一路往下）会绕回 [area] 的区域。
  ///
  /// 来源链按保存的来源判断，不管那些区域此刻是否单独设置、是否打开了跟随：
  /// 它们随时可能切回来，到时候不能突然成环。
  bool canFollow(AppBackgroundArea area, AppBackgroundSource source) {
    final seen = <AppBackgroundArea>{};
    var next = source.area;
    while (next != null) {
      if (next == area) return false;
      // 已有的环（只可能来自手改的备份）不会经过 area，走到这里即可停下。
      if (!seen.add(next)) return true;
      next = areaOf(next).source.area;
    }
    return true;
  }

  /// [visiting]：这条来源链上已经解析过的区域（防环）。
  AppBackground _resolveArea(
    AppBackgroundArea area,
    Set<AppBackgroundArea> visiting,
  ) {
    return switch (areaOf(area).mode) {
      AppAreaBackgroundMode.follow => global,
      AppAreaBackgroundMode.off => AppBackground.defaults,
      AppAreaBackgroundMode.custom => _resolveCustom(area, visiting..add(area)),
    };
  }

  AppBackground _resolveCustom(
    AppBackgroundArea area,
    Set<AppBackgroundArea> visiting,
  ) {
    final setting = areaOf(area);
    final own = setting.custom;
    if (!setting.followsSource) return own;
    final sourceArea = setting.source.area;
    final AppBackground from;
    if (sourceArea == null) {
      from = global;
    } else if (visiting.contains(sourceArea)) {
      // 成环：不再跟随，用自己的那一份。
      return own;
    } else {
      from = _resolveArea(sourceArea, visiting);
    }
    var result = own;
    if (setting.followImage) {
      result = result.copyWith(
        image: () => from.kind == AppBackgroundKind.image ? from.image : null,
      );
    }
    if (setting.followParams) {
      result = result.copyWith(
        alignX: from.alignX,
        alignY: from.alignY,
        blur: from.blur,
        scrimLight: from.scrimLight,
        scrimDark: from.scrimDark,
      );
    }
    return result;
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

  /// 解码区域表：认不出的区域键整项忽略，与默认相同的项不存；以自己为
  /// 来源的（手改的备份）改回全局。
  static Map<AppBackgroundArea, AppAreaBackground> _decodeAreas(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return const <AppBackgroundArea, AppAreaBackground>{};
    final result = <AppBackgroundArea, AppAreaBackground>{};
    for (final area in AppBackgroundArea.values) {
      if (!json.containsKey(area.name)) continue;
      var value = AppAreaBackground.fromJson(json[area.name]);
      if (value.source.area == area) {
        value = value.copyWith(source: AppBackgroundSource.global);
      }
      if (!value.isDefault) result[area] = value;
    }
    return Map.unmodifiable(result);
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
