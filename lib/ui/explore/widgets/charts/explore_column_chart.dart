import 'package:flutter/material.dart';

import 'explore_reveal.dart';

/// 柱状图的一根柱。
@immutable
class ExploreColumn {
  const ExploreColumn({
    required this.value,
    required this.label,
    this.sublabel,
    this.valueLabel,
    this.color,
  });

  final num value;

  /// 这根柱单独的颜色（心情柱按心情分段着色）；null 时用整张图的颜色。
  final Color? color;

  /// 柱下的文字（月份、星期……）。
  final String label;

  /// 柱下第二行（如 1 月的柱下写年份）；所有柱都为 null 时不占这一行。
  final String? sublabel;

  /// 柱顶文字；null 时值为 0 写空、否则写整数。
  final String? valueLabel;
}

/// 柱状图：圆角轨道里从底部长出的柱，柱顶写数值、柱下写标签。
///
/// 探索页（写作节奏、写作习惯、精力）与日记本统计页（写作节奏）共用。柱宽
/// 均分可用宽度，窄屏下文字经 [FittedBox] 缩小不换行；有数值的柱至少露出
/// [minBarHeight]，看得出来。[reveal] 为 [ExploreReveal] 给出的共享进度，各柱
/// 错峰生长。读屏只读 [semanticsLabel]（整张图一句话）。
class ExploreColumnChart extends StatelessWidget {
  const ExploreColumnChart({
    super.key,
    required this.columns,
    required this.reveal,
    this.height = 72,
    this.minBarHeight = 6,
    this.color,
    this.showValues = true,
    this.semanticsLabel,
    this.maxValue,
  });

  final List<ExploreColumn> columns;
  final double reveal;

  /// 柱区（轨道）高度。
  final double height;
  final double minBarHeight;

  /// 柱色；默认 `primary`。
  final Color? color;

  /// 是否在柱顶写数值。
  final bool showValues;
  final String? semanticsLabel;

  /// 柱高的满格值（心情 10、精力 5）；null 时取最高的一根。
  final num? maxValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barColor = color ?? scheme.primary;
    var maxValue = this.maxValue?.toDouble() ?? 0.0;
    for (final column in columns) {
      if (column.value > maxValue) maxValue = column.value.toDouble();
    }
    if (maxValue <= 0) maxValue = 1;
    final hasSublabels = columns.any((column) => column.sublabel != null);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      color: scheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    Widget smallText(String text, TextStyle? style) => SizedBox(
      height: 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
    final chart = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (var i = 0; i < columns.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: <Widget>[
                  if (showValues) ...<Widget>[
                    smallText(
                      columns[i].valueLabel ??
                          (columns[i].value > 0
                              ? '${columns[i].value.round()}'
                              : ''),
                      labelStyle?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Container(
                    height: height,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: ExploreChartColors.track(scheme),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: columns[i].value <= 0
                        ? null
                        : Container(
                            height:
                                (minBarHeight +
                                    (height - minBarHeight) *
                                        columns[i].value /
                                        maxValue) *
                                ExploreReveal.staggered(
                                  reveal,
                                  i,
                                  columns.length,
                                ),
                            decoration: BoxDecoration(
                              color: columns[i].color ?? barColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  smallText(columns[i].label, labelStyle),
                  if (hasSublabels)
                    smallText(columns[i].sublabel ?? '', labelStyle),
                ],
              ),
            ),
          ),
      ],
    );
    final label = semanticsLabel;
    if (label == null) return chart;
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: chart),
    );
  }
}
