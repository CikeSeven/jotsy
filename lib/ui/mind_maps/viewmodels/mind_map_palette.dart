import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/mind_map_markers.dart';
import '../models/mind_map_themes.dart';

/// 一个分支的颜色：强调色（连线、下划线、实色底）及其上的文字色，容器色
/// 及其上的文字色。
@immutable
final class MindMapBranchColors {
  const MindMapBranchColors({
    required this.accent,
    required this.onAccent,
    required this.container,
    required this.onContainer,
  });

  final Color accent;
  final Color onAccent;
  final Color container;
  final Color onContainer;
}

/// 一套主题在当前明暗与应用配色下解析出的颜色。
///
/// 种子色经 `ColorScheme.fromSeed(dynamicSchemeVariant: fidelity)` 换算（与
/// 心情强调色、待办优先级同一做法）：保住种子的色相与彩度，亮色取较深的
/// 色调、暗色取较浅的，`on*` 色与底色的对比由配色算法保证。按 (主题, 应用
/// 配色) 缓存，列表里大量缩略图同时绘制时不重复换算。
final class MindMapPalette {
  MindMapPalette._({
    required this.root,
    required this.inverse,
    required this.branches,
    required this.single,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.selection,
    required this.dot,
  });

  factory MindMapPalette.of(MindMapThemeSpec spec, ColorScheme scheme) {
    final key = (spec.id, scheme);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final palette = _resolve(spec, scheme);
    _cache[key] = palette;
    while (_cache.length > 24) {
      _cache.remove(_cache.keys.first);
    }
    return palette;
  }

  /// 根节点的颜色（由根种子色换算；跟随应用时为应用主色）。
  final MindMapBranchColors root;

  /// 反色（亮色下深底浅字），反色根节点用。
  final MindMapBranchColors inverse;

  /// 彩虹分支依次取用的颜色（循环）。
  final List<MindMapBranchColors> branches;

  /// 不分彩虹时所有分支共用的颜色。
  final MindMapBranchColors single;

  /// 描边节点的底色（与卡片同一层级）。
  final Color surface;

  /// 画布上的文字色（无底色的节点）。
  final Color onSurface;

  /// 占位文字、次要标记。
  final Color onSurfaceVariant;

  /// 选中环。
  final Color selection;

  /// 画布点阵。
  final Color dot;

  MindMapBranchColors branch(int index, {required bool rainbow}) {
    if (!rainbow || index < 0 || branches.isEmpty) return single;
    return branches[index % branches.length];
  }

  /// 节点自定义的分支色（`style.branch`）换算出的一组颜色。
  MindMapBranchColors custom(Color seed) {
    final key = (seed.toARGB32(), surface.computeLuminance() < 0.5);
    return _customCache[key] ??= _seedColors(
      seed,
      surface.computeLuminance() < 0.5 ? Brightness.dark : Brightness.light,
    );
  }

  /// 贴纸颜色（固定种子按明暗换算，与主题无关）。
  MindMapBranchColors marker(MindMapMarkerColor color) =>
      custom(Color(color.seed));

  final Map<(int, bool), MindMapBranchColors> _customCache =
      <(int, bool), MindMapBranchColors>{};

  static final LinkedHashMap<(MindMapThemeId, ColorScheme), MindMapPalette>
  _cache = LinkedHashMap<(MindMapThemeId, ColorScheme), MindMapPalette>();

  static MindMapPalette _resolve(MindMapThemeSpec spec, ColorScheme scheme) {
    final brightness = scheme.brightness;
    final dark = brightness == Brightness.dark;
    final surface = dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    final appColors = MindMapBranchColors(
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      container: scheme.primaryContainer,
      onContainer: scheme.onPrimaryContainer,
    );
    final neutral = MindMapBranchColors(
      accent: scheme.onSurfaceVariant,
      onAccent: scheme.surface,
      container: scheme.surfaceContainerHighest,
      onContainer: scheme.onSurface,
    );
    final List<MindMapBranchColors> branches;
    if (spec.monochrome) {
      branches = <MindMapBranchColors>[neutral];
    } else if (spec.seeds.isEmpty) {
      // 跟随应用：以应用主色为起点，色相每次转 47°（与相邻分支拉开、
      // 转一圈不重复），再按 fidelity 换算成可读的明暗。
      final base = HSLColor.fromColor(scheme.primary);
      branches = <MindMapBranchColors>[
        appColors,
        for (var i = 1; i < 8; i++)
          _seedColors(
            base
                .withHue((base.hue + 47.0 * i) % 360)
                .withSaturation(base.saturation.clamp(0.45, 0.85))
                .toColor(),
            brightness,
          ),
      ];
    } else {
      branches = <MindMapBranchColors>[
        for (final seed in spec.seeds) _seedColors(Color(seed), brightness),
      ];
    }
    final single = spec.monochrome
        ? neutral
        : spec.seeds.isEmpty
        ? appColors
        : spec.rootSeed != null
        ? _seedColors(Color(spec.rootSeed!), brightness)
        : branches.first;
    final root = spec.monochrome
        ? neutral
        : spec.rootSeed != null
        ? _seedColors(Color(spec.rootSeed!), brightness)
        : spec.seeds.isEmpty
        ? appColors
        : branches.first;
    final inverse = MindMapBranchColors(
      accent: scheme.inverseSurface,
      onAccent: scheme.onInverseSurface,
      container: scheme.inverseSurface,
      onContainer: scheme.onInverseSurface,
    );
    return MindMapPalette._(
      root: root,
      inverse: inverse,
      branches: branches,
      single: single,
      surface: surface,
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
      selection: scheme.primary,
      dot: scheme.outlineVariant.withValues(alpha: dark ? 0.32 : 0.55),
    );
  }

  static MindMapBranchColors _seedColors(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return MindMapBranchColors(
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      container: scheme.primaryContainer,
      onContainer: scheme.onPrimaryContainer,
    );
  }
}
