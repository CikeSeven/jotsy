import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';

/// 卡片密度：内边距与卡片间距。
enum ExploreDensity { compact, standard, relaxed }

/// 卡片标题的样式。
enum ExploreHeadingStyle { badge, icon, text, hidden }

/// 卡片表面（材质设为玻璃时一律是玻璃，见 `ExploreCard`）。
enum ExploreCardSurface { filled, tonal, outlined }

/// 图表与数字的强调色。
enum ExploreAccent { primary, secondary, tertiary }

/// 宽窗口的列数；[auto] 为内容宽 ≥ 720 时两列。
enum ExploreWideColumns { auto, one, two, three }

/// 宽窗口里半宽卡片的排布：对齐成行，或交替放进各列（错落，不留高度差的
/// 空白）。
enum ExploreWideFlow { rows, staggered }

/// 探索页自身的外观。
///
/// 默认值即改版前的外观：标准密度（内边距 18、间距 12）、圆角 24、徽章式
/// 标题、填充卡片、主色、完整数字、播放生长动画、宽窗口自动两列对齐成行。
/// 解码逐字段容错、编码稀疏（[StyleJson]）。
@immutable
class ExploreAppearance {
  const ExploreAppearance({
    this.density = ExploreDensity.standard,
    this.radius = defaultRadius,
    this.heading = ExploreHeadingStyle.badge,
    this.surface = ExploreCardSurface.filled,
    this.accent = ExploreAccent.primary,
    this.compactNumbers = false,
    this.animations = true,
    this.columns = ExploreWideColumns.auto,
    this.flow = ExploreWideFlow.rows,
  });

  static const ExploreAppearance defaults = ExploreAppearance();
  static const double defaultRadius = 24;

  /// 卡片圆角的范围（编辑页滑块与解码夹取共用）。
  static const StyleRange radiusRange = StyleRange(8, 32, 2);

  factory ExploreAppearance.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return defaults;
    return ExploreAppearance(
      density: StyleJson.enumByName(
        ExploreDensity.values,
        json['density'],
        defaults.density,
      ),
      radius: StyleJson.number(json['radius'], defaultRadius, radiusRange),
      heading: StyleJson.enumByName(
        ExploreHeadingStyle.values,
        json['heading'],
        defaults.heading,
      ),
      surface: StyleJson.enumByName(
        ExploreCardSurface.values,
        json['surface'],
        defaults.surface,
      ),
      accent: StyleJson.enumByName(
        ExploreAccent.values,
        json['accent'],
        defaults.accent,
      ),
      compactNumbers: StyleJson.boolean(
        json['compact'],
        defaults.compactNumbers,
      ),
      animations: StyleJson.boolean(json['animate'], defaults.animations),
      columns: StyleJson.enumByName(
        ExploreWideColumns.values,
        json['columns'],
        defaults.columns,
      ),
      flow: StyleJson.enumByName(
        ExploreWideFlow.values,
        json['flow'],
        defaults.flow,
      ),
    );
  }

  final ExploreDensity density;
  final double radius;
  final ExploreHeadingStyle heading;
  final ExploreCardSurface surface;
  final ExploreAccent accent;

  /// 大数字缩写（1.2 万 / 12K）。
  final bool compactNumbers;

  /// 图表生长与数字递增动画（系统减少动画时一律不播）。
  final bool animations;
  final ExploreWideColumns columns;
  final ExploreWideFlow flow;

  bool get isDefault => this == defaults;

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'density', density, defaults.density);
    StyleJson.put(json, 'radius', radius, defaultRadius);
    StyleJson.putEnum(json, 'heading', heading, defaults.heading);
    StyleJson.putEnum(json, 'surface', surface, defaults.surface);
    StyleJson.putEnum(json, 'accent', accent, defaults.accent);
    StyleJson.put(json, 'compact', compactNumbers, defaults.compactNumbers);
    StyleJson.put(json, 'animate', animations, defaults.animations);
    StyleJson.putEnum(json, 'columns', columns, defaults.columns);
    StyleJson.putEnum(json, 'flow', flow, defaults.flow);
    return json;
  }

  ExploreAppearance copyWith({
    ExploreDensity? density,
    double? radius,
    ExploreHeadingStyle? heading,
    ExploreCardSurface? surface,
    ExploreAccent? accent,
    bool? compactNumbers,
    bool? animations,
    ExploreWideColumns? columns,
    ExploreWideFlow? flow,
  }) {
    return ExploreAppearance(
      density: density ?? this.density,
      radius: radius == null ? this.radius : radiusRange.clamp(radius),
      heading: heading ?? this.heading,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      compactNumbers: compactNumbers ?? this.compactNumbers,
      animations: animations ?? this.animations,
      columns: columns ?? this.columns,
      flow: flow ?? this.flow,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreAppearance &&
      other.density == density &&
      other.radius == radius &&
      other.heading == heading &&
      other.surface == surface &&
      other.accent == accent &&
      other.compactNumbers == compactNumbers &&
      other.animations == animations &&
      other.columns == columns &&
      other.flow == flow;

  @override
  int get hashCode => Object.hash(
    density,
    radius,
    heading,
    surface,
    accent,
    compactNumbers,
    animations,
    columns,
    flow,
  );
}
