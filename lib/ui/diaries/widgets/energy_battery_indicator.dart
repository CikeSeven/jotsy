import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 精力电池指示器（连续值，范围 1~5）。
///
/// 设计目标：
/// - 用统一图标语义表达精力强弱，避免不同页面出现不一致映射；
/// - 同时支持“仅图标”与“图标+文案”两种展示形态，方便在标题行或信息区复用。
class EnergyBatteryIndicator extends StatelessWidget {
  const EnergyBatteryIndicator({
    super.key,
    required this.value,
    this.iconSize = 14,
    this.showLabel = false,
    this.labelStyle,
    this.labelSpacing = 4,
  });

  final double value;
  final double iconSize;
  final bool showLabel;
  final TextStyle? labelStyle;
  final double labelSpacing;

  /// 将外部输入统一规整到 1~5，避免历史数据或异常值导致 UI 显示越界。
  static double normalizeValue(num rawValue) {
    final value = rawValue.toDouble();
    if (value < 1) {
      return 1;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }

  /// 连续值映射为电池档位图标（空/四分之一/半/四分之三/满）。
  ///
  /// 图标本身是离散资源，因此按阈值分桶；
  /// 颜色仍按连续值做渐变，以保留“连续拖动”的反馈。
  static IconData iconForValue(num rawValue) {
    final value = normalizeValue(rawValue);
    if (value < 1.8) {
      return FontAwesomeIcons.batteryEmpty;
    }
    if (value < 2.6) {
      return FontAwesomeIcons.batteryQuarter;
    }
    if (value < 3.4) {
      return FontAwesomeIcons.batteryHalf;
    }
    if (value < 4.2) {
      return FontAwesomeIcons.batteryThreeQuarters;
    }
    return FontAwesomeIcons.batteryFull;
  }

  /// 电池颜色按精力值做红 -> 绿连续渐变。
  static Color colorForValue(num rawValue) {
    final value = normalizeValue(rawValue);
    final t = (value - 1) / 4;
    return Color.lerp(const Color(0xFFE53935), const Color(0xFF2E7D32), t)!;
  }

  /// 数值格式化：最多保留一位小数，尾随 `.0` 自动省略。
  static String formatValue(num rawValue) {
    final value = normalizeValue(rawValue);
    final oneDecimal = value.toStringAsFixed(1);
    if (oneDecimal.endsWith('.0')) {
      return oneDecimal.substring(0, oneDecimal.length - 2);
    }
    return oneDecimal;
  }

  /// 将连续值映射为用户可读的精力文案（从低到高）。
  static String descriptionForValue(num rawValue, {bool isZh = true}) {
    final value = normalizeValue(rawValue);
    if (!isZh) {
      if (value < 1.8) {
        return 'Exhausted';
      }
      if (value < 2.6) {
        return 'A bit tired';
      }
      if (value < 3.4) {
        return 'So-so';
      }
      if (value < 4.2) {
        return 'Pretty good';
      }
      return 'Fully charged';
    }
    if (value < 1.8) {
      return '疲惫不堪';
    }
    if (value < 2.6) {
      return '有点疲惫';
    }
    if (value < 3.4) {
      return '状态一般';
    }
    if (value < 4.2) {
      return '精力不错';
    }
    return '精力满满';
  }

  /// 电量连续映射到 [0, 1]，用于控制填充宽度。
  static double fillPercent(num rawValue) {
    final value = normalizeValue(rawValue);
    return ((value - 1) / 4).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeValue(value);
    final iconColor = colorForValue(normalized);
    final bodyHeight = iconSize;
    final bodyWidth = iconSize * 1.8;
    final capWidth = (iconSize * 0.18).clamp(2.0, 6.0);
    final fill = fillPercent(normalized);
    final borderColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: bodyWidth,
              height: bodyHeight,
              padding: EdgeInsets.all((iconSize * 0.11).clamp(1.2, 2.4)),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1.4),
                borderRadius: BorderRadius.circular((iconSize * 0.2).clamp(2, 6)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(
                        (iconSize * 0.1).clamp(1.2, 3),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            SizedBox(width: (iconSize * 0.08).clamp(1.0, 3.0)),
            Container(
              width: capWidth,
              height: bodyHeight * 0.42,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular((iconSize * 0.08).clamp(1, 2)),
              ),
            ),
          ],
        ),
        if (showLabel) ...<Widget>[
          SizedBox(width: labelSpacing),
          Text(
            '${formatValue(normalized)}/5',
            style: labelStyle ?? Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
