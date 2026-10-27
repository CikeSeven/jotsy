import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'app_background.dart';
import 'app_surface_enums.dart';

/// 某个区域（`AppBackgroundArea`）的背景设置。
///
/// [mode] 不是 custom 时 [custom] 仍原样保留、照常编码：用户临时改回“跟随
/// 全局”或“关闭”，再切回“单独设置”时之前调好的背景还在。也因此
/// `AppSurfaceSettings.referencedImages` 要把这些暂不启用的图片算作仍被引用。
@immutable
class AppAreaBackground {
  const AppAreaBackground({
    this.mode = AppAreaBackgroundMode.follow,
    this.custom = AppBackground.defaults,
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
    );
  }

  final AppAreaBackgroundMode mode;
  final AppBackground custom;

  bool get isDefault => this == defaults;

  /// 稀疏 JSON：默认编码为空对象。
  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'mode', mode, defaults.mode);
    StyleJson.putObject(json, 'background', custom.toJson());
    return json;
  }

  AppAreaBackground copyWith({
    AppAreaBackgroundMode? mode,
    AppBackground? custom,
  }) =>
      AppAreaBackground(mode: mode ?? this.mode, custom: custom ?? this.custom);

  @override
  bool operator ==(Object other) =>
      other is AppAreaBackground &&
      other.mode == mode &&
      other.custom == custom;

  @override
  int get hashCode => Object.hash(mode, custom);
}
