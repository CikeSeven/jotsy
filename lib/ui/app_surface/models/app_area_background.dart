import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'app_background.dart';
import 'app_background_source.dart';
import 'app_surface_enums.dart';

/// 某个区域（`AppBackgroundArea`）的背景设置。
///
/// [mode] 不是 custom 时 [custom] 仍原样保留、照常编码：用户临时改回“跟随
/// 全局”或“关闭”，再切回“单独设置”时之前调好的背景还在。也因此
/// `AppSurfaceSettings.referencedImages` 要把这些暂不启用的图片算作仍被引用。
///
/// 单独设置时，图片与参数（焦点、模糊、浅色 / 深色遮罩）两块可以各自跟随
/// [source]：[followImage] / [followParams] 打开的那一块取来源当前显示的
/// 值，[custom] 里自己的那一份原样保留（关掉跟随即回到它）。参数只能整块
/// 跟随，不逐项区分。跟随怎样解析、怎样防止成环见 `AppSurfaceSettings`。
@immutable
class AppAreaBackground {
  const AppAreaBackground({
    this.mode = AppAreaBackgroundMode.follow,
    this.custom = AppBackground.defaults,
    this.source = AppBackgroundSource.global,
    this.followImage = false,
    this.followParams = false,
  });

  static const AppAreaBackground defaults = AppAreaBackground();

  /// 从已解码的 JSON 构造；不是对象时返回默认（跟随全局）。
  factory AppAreaBackground.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return defaults;
    return AppAreaBackground(
      mode: StyleJson.enumByName(
        AppAreaBackgroundMode.values,
        json['mode'],
        defaults.mode,
      ),
      custom: AppBackground.fromJson(json['background']),
      source: AppBackgroundSource.parse(json['source']),
      followImage: StyleJson.boolean(json['followImage'], defaults.followImage),
      followParams: StyleJson.boolean(
        json['followParams'],
        defaults.followParams,
      ),
    );
  }

  final AppAreaBackgroundMode mode;
  final AppBackground custom;

  /// 图片 / 参数跟随的来源（全局或另一个区域）。
  final AppBackgroundSource source;

  /// 图片是否跟随 [source]。
  final bool followImage;

  /// 参数（焦点、模糊、浅色 / 深色遮罩）是否整块跟随 [source]。
  final bool followParams;

  bool get isDefault => this == defaults;

  /// 是否有任何一块在跟随来源。
  bool get followsSource => followImage || followParams;

  /// 稀疏 JSON：默认编码为空对象。
  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'mode', mode, defaults.mode);
    StyleJson.putObject(json, 'background', custom.toJson());
    if (source != defaults.source) json['source'] = source.name;
    StyleJson.put(json, 'followImage', followImage, defaults.followImage);
    StyleJson.put(json, 'followParams', followParams, defaults.followParams);
    return json;
  }

  AppAreaBackground copyWith({
    AppAreaBackgroundMode? mode,
    AppBackground? custom,
    AppBackgroundSource? source,
    bool? followImage,
    bool? followParams,
  }) => AppAreaBackground(
    mode: mode ?? this.mode,
    custom: custom ?? this.custom,
    source: source ?? this.source,
    followImage: followImage ?? this.followImage,
    followParams: followParams ?? this.followParams,
  );

  @override
  bool operator ==(Object other) =>
      other is AppAreaBackground &&
      other.mode == mode &&
      other.custom == custom &&
      other.source == source &&
      other.followImage == followImage &&
      other.followParams == followParams;

  @override
  int get hashCode =>
      Object.hash(mode, custom, source, followImage, followParams);
}
