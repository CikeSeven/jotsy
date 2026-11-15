// 桌面小组件的外观（每个实例各自一份，见 `HomeWidgetInstance`）。
//
// 只描述用户的选择，不含任何颜色计算：配色角色由 `home_widget_palette.dart`
// 按 [HomeWidgetStyle.palette] 与种子色导出，原生侧按 [toNative] 的口径取用
// （docs/rules/home_widgets.md「快照」）。字段逐个容错解析：一项坏值只让这一项
// 回到默认，不影响其他选择。

import 'dart:ui' show Color;

/// 配色来源。
enum HomeWidgetPalette {
  /// 跟随应用主题色（默认）：与应用内同一个种子色、同一套 Material 配色。
  app,

  /// 跟随壁纸取色（Android 12+ 的系统动态色）；更早的系统按 [app] 显示。
  wallpaper,

  /// 自选种子色（精选色板或自定义 HEX），经同一个配色算法生成明暗两套。
  seed,
}

/// 明暗：跟随系统，或固定为浅色 / 深色。
enum HomeWidgetBrightness { system, light, dark }

/// 底色。
enum HomeWidgetBackground {
  /// 实色：与应用卡片同一层级（浅色 surfaceContainerLowest，深色
  /// surfaceContainerLow）。
  surface,

  /// 色调：主色容器色。
  tonal,

  /// 浓郁：主色铺底、文字反白。
  vivid,

  /// 透明：只有内容，直接放在壁纸上；文字明暗跟 [HomeWidgetBrightness]。
  clear,
}

/// 内容密度：内边距与行距的三档。
enum HomeWidgetDensity { compact, standard, roomy }

/// 强调色：大数字、主按钮与图标用哪一个色槽。
enum HomeWidgetAccent { primary, secondary, tertiary }

class HomeWidgetStyle {
  const HomeWidgetStyle({
    this.palette = HomeWidgetPalette.app,
    this.seed,
    this.brightness = HomeWidgetBrightness.system,
    this.background = HomeWidgetBackground.surface,
    this.opacity = 1,
    this.cornerRadius,
    this.textScale = 1,
    this.density = HomeWidgetDensity.standard,
    this.accent = HomeWidgetAccent.primary,
  });

  static const HomeWidgetStyle defaults = HomeWidgetStyle();

  /// 不透明度的下限：再透明文字就压不住复杂的壁纸了（透明底另有 [clear]）。
  static const double minOpacity = 0.2;

  /// 自定义圆角的上限（dp）；超过后小尺寸的小组件会变成胶囊。
  static const double maxCornerRadius = 32;

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.25;

  final HomeWidgetPalette palette;

  /// [palette] 为 [HomeWidgetPalette.seed] 时的种子色（ARGB）；为空时按
  /// 应用主题色处理。
  final int? seed;

  final HomeWidgetBrightness brightness;
  final HomeWidgetBackground background;

  /// 底色不透明度（[minOpacity]–1）；[HomeWidgetBackground.clear] 时不用。
  final double opacity;

  /// 圆角（dp）；null 为跟随系统（Android 12+ 的系统小组件圆角，更早的系统
  /// 用 16dp）。
  final double? cornerRadius;

  /// 文字缩放（[minTextScale]–[maxTextScale]），叠加在系统字体缩放之上。
  final double textScale;

  final HomeWidgetDensity density;
  final HomeWidgetAccent accent;

  /// 实际生效的种子色：自选种子色缺失时退回应用主题色 [appSeed]。
  Color seedColor(Color appSeed) =>
      palette == HomeWidgetPalette.seed && seed != null
      ? Color(seed!)
      : appSeed;

  /// 快照里配色表的键：`app`、`wallpaper` 或 `seed:AARRGGBB`。原生按它取配色，
  /// Dart 侧按它决定要导出哪些配色（见 `HomeWidgetSnapshotBuilder`）。
  String get paletteKey => switch (palette) {
    HomeWidgetPalette.app => 'app',
    HomeWidgetPalette.wallpaper => 'wallpaper',
    HomeWidgetPalette.seed => seed == null ? 'app' : 'seed:${_hex(seed!)}',
  };

  HomeWidgetStyle copyWith({
    HomeWidgetPalette? palette,
    int? seed,
    HomeWidgetBrightness? brightness,
    HomeWidgetBackground? background,
    double? opacity,
    double? Function()? cornerRadius,
    double? textScale,
    HomeWidgetDensity? density,
    HomeWidgetAccent? accent,
  }) {
    return HomeWidgetStyle(
      palette: palette ?? this.palette,
      seed: seed ?? this.seed,
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      opacity: opacity ?? this.opacity,
      cornerRadius: cornerRadius == null ? this.cornerRadius : cornerRadius(),
      textScale: textScale ?? this.textScale,
      density: density ?? this.density,
      accent: accent ?? this.accent,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'palette': palette.name,
    if (seed != null) 'seed': seed,
    'brightness': brightness.name,
    'background': background.name,
    'opacity': opacity,
    if (cornerRadius != null) 'radius': cornerRadius,
    'textScale': textScale,
    'density': density.name,
    'accent': accent.name,
  };

  /// 发给原生的口径：配色写成配色表的键，圆角 -1 表示跟随系统。
  Map<String, Object?> toNative() => <String, Object?>{
    'palette': paletteKey,
    'brightness': brightness.name,
    'background': background.name,
    'opacity': opacity,
    'radius': cornerRadius ?? -1,
    'textScale': textScale,
    'density': density.name,
    'accent': accent.name,
  };

  static HomeWidgetStyle fromJson(Object? json) {
    if (json is! Map) return defaults;
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    double number(Object? raw, double fallback, double min, double max) {
      if (raw is! num || raw.isNaN) return fallback;
      return raw.toDouble().clamp(min, max);
    }

    final rawSeed = json['seed'];
    final rawRadius = json['radius'];
    return HomeWidgetStyle(
      palette: pick(
        HomeWidgetPalette.values,
        json['palette'],
        defaults.palette,
      ),
      seed: rawSeed is int ? rawSeed & 0xFFFFFFFF : null,
      brightness: pick(
        HomeWidgetBrightness.values,
        json['brightness'],
        defaults.brightness,
      ),
      background: pick(
        HomeWidgetBackground.values,
        json['background'],
        defaults.background,
      ),
      opacity: number(json['opacity'], 1, minOpacity, 1),
      cornerRadius: rawRadius is num && !rawRadius.isNaN
          ? rawRadius.toDouble().clamp(0, maxCornerRadius)
          : null,
      textScale: number(json['textScale'], 1, minTextScale, maxTextScale),
      density: pick(
        HomeWidgetDensity.values,
        json['density'],
        defaults.density,
      ),
      accent: pick(HomeWidgetAccent.values, json['accent'], defaults.accent),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetStyle &&
      other.palette == palette &&
      other.seed == seed &&
      other.brightness == brightness &&
      other.background == background &&
      other.opacity == opacity &&
      other.cornerRadius == cornerRadius &&
      other.textScale == textScale &&
      other.density == density &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(
    palette,
    seed,
    brightness,
    background,
    opacity,
    cornerRadius,
    textScale,
    density,
    accent,
  );
}

String _hex(int argb) =>
    (argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase();
