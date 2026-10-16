import 'package:flutter/material.dart';

/// 心情分段配色：十档心情合并成五段，只取 colorScheme 语义色。
///
/// - 低落用 error、偏低用 tertiary、平静用 outline、不错与开心用两档 primary；
/// - 日历年视图的心情像素与日记卡片的“心情色”共用这一套，同一心情在两处
///   颜色一致。
abstract final class MoodBandPalette {
  /// 五段由低到高的代表档位（1~10 中每段的上沿），图例用它取对应 emoji。
  static const List<int> bandWeights = <int>[2, 4, 6, 8, 10];

  /// 心情档位（1~10）所在的段（0~4）。
  static int bandForWeight(int weight) => ((weight.clamp(1, 10) - 1) ~/ 2);

  /// 第 [band] 段（0~4，由低到高）的颜色；年视图小格直接使用，带各段的
  /// 透明度层次。
  static Color color(ColorScheme colorScheme, int band) {
    return switch (band) {
      0 => colorScheme.error.withValues(alpha: 0.85),
      1 => colorScheme.tertiary.withValues(alpha: 0.75),
      2 => colorScheme.outline.withValues(alpha: 0.7),
      3 => colorScheme.primary.withValues(alpha: 0.55),
      _ => colorScheme.primary,
    };
  }
}
