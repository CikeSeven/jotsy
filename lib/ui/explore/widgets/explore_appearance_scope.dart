import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/explore_appearance.dart';

/// 把探索页外观（[ExploreAppearance]）交给页面里的卡片与图表。
///
/// 卡片外壳、标题、数字与图表一律经 [ExploreAppearanceScope.of] 读取；不在
/// 探索页里（日记本统计页复用这些组件）时为默认外观，与改版前一致。
class ExploreAppearanceScope extends InheritedWidget {
  const ExploreAppearanceScope({
    super.key,
    required this.appearance,
    required super.child,
  });

  final ExploreAppearance appearance;

  static ExploreAppearance of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ExploreAppearanceScope>()
          ?.appearance ??
      ExploreAppearance.defaults;

  @override
  bool updateShouldNotify(ExploreAppearanceScope oldWidget) =>
      appearance != oldWidget.appearance;
}

/// 外观到具体数值与颜色的换算（DESIGN §5.24）。
extension ExploreAppearanceResolve on ExploreAppearance {
  /// 卡片内边距。
  double get cardPadding => switch (density) {
    ExploreDensity.compact => 14,
    ExploreDensity.standard => 18,
    ExploreDensity.relaxed => 22,
  };

  /// 卡片之间的间距（横竖一致）。
  double get cardGap => switch (density) {
    ExploreDensity.compact => 8,
    ExploreDensity.standard => 12,
    ExploreDensity.relaxed => 16,
  };

  /// 卡片标题与内容之间的间距。
  double get headerGap => switch (density) {
    ExploreDensity.compact => 10,
    ExploreDensity.standard => 12,
    ExploreDensity.relaxed => 14,
  };

  /// 图表与数字的强调色。
  Color accentOf(ColorScheme scheme) => switch (accent) {
    ExploreAccent.primary => scheme.primary,
    ExploreAccent.secondary => scheme.secondary,
    ExploreAccent.tertiary => scheme.tertiary,
  };

  /// 强调色的容器色与其上的文字色（徽章、提示块）。
  Color accentContainerOf(ColorScheme scheme) => switch (accent) {
    ExploreAccent.primary => scheme.primaryContainer,
    ExploreAccent.secondary => scheme.secondaryContainer,
    ExploreAccent.tertiary => scheme.tertiaryContainer,
  };

  Color onAccentContainerOf(ColorScheme scheme) => switch (accent) {
    ExploreAccent.primary => scheme.onPrimaryContainer,
    ExploreAccent.secondary => scheme.onSecondaryContainer,
    ExploreAccent.tertiary => scheme.onTertiaryContainer,
  };

  /// 数字的写法：开了“大数字缩写”时为 1.2万 / 12K，否则带千分位。
  String formatNumber(int value, String localeName) =>
      compactNumbers && value.abs() >= 10000
      ? NumberFormat.compact(locale: localeName).format(value)
      : NumberFormat.decimalPattern(localeName).format(value);
}
