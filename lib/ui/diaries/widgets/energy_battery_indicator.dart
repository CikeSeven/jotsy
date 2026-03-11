import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 精力电池指示器（1~5 档）。
///
/// 设计目标：
/// - 用统一图标语义表达精力强弱，避免不同页面出现不一致映射；
/// - 同时支持“仅图标”与“图标+文案”两种展示形态，方便在标题行或信息区复用。
class EnergyBatteryIndicator extends StatelessWidget {
  const EnergyBatteryIndicator({
    super.key,
    required this.level,
    this.iconSize = 14,
    this.showLabel = false,
    this.labelStyle,
    this.labelSpacing = 4,
  });

  final int level;
  final double iconSize;
  final bool showLabel;
  final TextStyle? labelStyle;
  final double labelSpacing;

  /// 将外部输入统一规整到 1~5，避免历史数据或异常值导致 UI 显示越界。
  static int normalizeLevel(int value) {
    return value.clamp(1, 5).toInt();
  }

  /// 1~5 档对应 FontAwesome 电池图标。
  static IconData iconForLevel(int value) {
    switch (normalizeLevel(value)) {
      case 1:
        return FontAwesomeIcons.batteryEmpty;
      case 2:
        return FontAwesomeIcons.batteryQuarter;
      case 3:
        return FontAwesomeIcons.batteryHalf;
      case 4:
        return FontAwesomeIcons.batteryThreeQuarters;
      case 5:
        return FontAwesomeIcons.batteryFull;
      default:
        return FontAwesomeIcons.batteryHalf;
    }
  }

  /// 电池颜色采用“低=警示，中=提醒，高=积极”的统一语义。
  static Color colorForLevel(BuildContext context, int value) {
    final level = normalizeLevel(value);
    final scheme = Theme.of(context).colorScheme;
    if (level <= 2) {
      return scheme.error;
    }
    if (level == 3) {
      return scheme.tertiary;
    }
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeLevel(level);
    final iconColor = colorForLevel(context, normalized);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FaIcon(
          iconForLevel(normalized),
          size: iconSize,
          color: iconColor,
        ),
        if (showLabel) ...<Widget>[
          SizedBox(width: labelSpacing),
          Text(
            '$normalized/5',
            style: labelStyle ?? Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
