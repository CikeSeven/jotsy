import 'package:flutter/foundation.dart';

import 'app_surface_enums.dart';

/// 区域“单独设置”的背景里，图片 / 参数跟随的来源：全局背景或另一个区域。
///
/// 持久化为名字：全局为 [globalName]，区域为区域枚举名（两者不会重名）。
/// 认不出的名字按全局处理——旧版本写不出别的值，手改或更新版本写的未知
/// 区域退回全局最安全（全局总是存在、不会成环）。
@immutable
class AppBackgroundSource {
  const AppBackgroundSource._(this.area);

  /// 跟随某个区域。
  const AppBackgroundSource.area(AppBackgroundArea this.area);

  static const AppBackgroundSource global = AppBackgroundSource._(null);
  static const String globalName = 'global';

  /// 全局在前，其后各区域按枚举顺序（来源面板的列表顺序）。
  static final List<AppBackgroundSource> all =
      List.unmodifiable(<AppBackgroundSource>[
        global,
        for (final area in AppBackgroundArea.values)
          AppBackgroundSource.area(area),
      ]);

  /// 解析持久化的名字；不是字符串或认不出时为全局。
  factory AppBackgroundSource.parse(Object? raw) {
    if (raw is String) {
      for (final area in AppBackgroundArea.values) {
        if (area.name == raw) return AppBackgroundSource.area(area);
      }
    }
    return global;
  }

  /// 来源区域；null 为全局。
  final AppBackgroundArea? area;

  bool get isGlobal => area == null;

  String get name => area?.name ?? globalName;

  @override
  bool operator ==(Object other) =>
      other is AppBackgroundSource && other.area == area;

  @override
  int get hashCode => area.hashCode;

  @override
  String toString() => 'AppBackgroundSource($name)';
}
