import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/app_glass_style.dart';
import '../viewmodels/app_glass_resolved.dart';

export '../models/app_surface_enums.dart' show AppGlassComponent;
export '../viewmodels/app_glass_resolved.dart';

/// 把组件材质设置 [AppGlassStyle] 交给整个应用。
///
/// 只在 `MaterialApp.builder` 里挂一次（Theme 之下、Navigator 之上，所以
/// 页面、底部面板与对话框都在它下面）；组件一律经 [AppGlass.of] 读取解析
/// 好的结果，不直接读本类。设置不变时不通知依赖者。
class AppGlassScope extends InheritedWidget {
  const AppGlassScope({super.key, required this.style, required super.child});

  final AppGlassStyle style;

  @override
  bool updateShouldNotify(AppGlassScope oldWidget) => style != oldWidget.style;
}

/// 组件读取材质的唯一入口。
abstract final class AppGlass {
  /// 当前位置的材质解析结果：取最近 [AppGlassScope] 的设置，按此处的
  /// `Theme.of(context).colorScheme`（子树里换过主题的地方，如样式预览的
  /// 亮 / 暗切换，会得到对应明暗的颜色）与系统高对比度解析。
  ///
  /// 没有 scope（单独测试的组件、MaterialApp 之外）时按默认设置——全部
  /// 经典材质，组件走原来的画法，行为与接入前完全相同。
  ///
  /// 会让调用方依赖 scope、Theme 与 MediaQuery 的高对比度一项。
  static AppGlassResolved of(BuildContext context) {
    final style = styleOf(context);
    final scheme = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return _resolveCached(style, scheme, highContrast);
  }

  /// 最近 [AppGlassScope] 的原始设置；没有 scope 时为默认（全部经典）。
  static AppGlassStyle styleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppGlassScope>()?.style ??
      AppGlassStyle.defaults;

  /// 小缓存：一屏几十块卡片都会在同一帧里解析，(样式, 配色, 高对比度) 绝大
  /// 多数相同；明暗各一份、预览里再多一两份，4 项足够。按最近使用淘汰。
  static final LinkedHashMap<
    (AppGlassStyle, ColorScheme, bool),
    AppGlassResolved
  >
  _cache =
      LinkedHashMap<(AppGlassStyle, ColorScheme, bool), AppGlassResolved>();
  static const int _cacheSize = 4;

  static AppGlassResolved _resolveCached(
    AppGlassStyle style,
    ColorScheme scheme,
    bool highContrast,
  ) {
    final key = (style, scheme, highContrast);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final resolved = AppGlassResolved.resolve(
      style,
      scheme,
      highContrast: highContrast,
    );
    _cache[key] = resolved;
    if (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return resolved;
  }
}
