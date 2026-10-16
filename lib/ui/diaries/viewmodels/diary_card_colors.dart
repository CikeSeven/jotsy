import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 自定义颜色在卡片上的用途；深色推导按用途取不同的明度区间。
enum DiaryCardColorRole { surface, accent, text }

/// 卡片自定义颜色的纯函数工具：对比度、可读色挑选与深色推导。
///
/// 用户可以为卡片底色、文字等指定任意颜色（含只设了浅色值的情况），这里
/// 负责把“用户想要的颜色”落到当前明暗主题下仍然可读的具体颜色上。
abstract final class DiaryCardColors {
  /// WCAG 2.x 对比度（1~21）。只看不透明分量：半透明颜色需由调用方先叠到
  /// 背景上（`Color.alphaBlend`）再比较。
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// [foreground] 叠在 [background] 上之后与背景的对比度。
  static double contrastOver(Color foreground, Color background) =>
      contrastRatio(Color.alphaBlend(foreground, background), background);

  /// 候选色中与 [background] 对比度最高的一个；[candidates] 不能为空。
  static Color bestContrast(List<Color> candidates, Color background) {
    var best = candidates.first;
    var bestRatio = contrastOver(best, background);
    for (final candidate in candidates.skip(1)) {
      final ratio = contrastOver(candidate, background);
      if (ratio > bestRatio) {
        best = candidate;
        bestRatio = ratio;
      }
    }
    return best;
  }

  /// 由浅色主题下的自定义色推导深色主题下的对应色：保持色相，按用途调整
  /// 明度与饱和度。
  ///
  /// - surface：压到 0.13~0.21 的低明度并大幅降低饱和度——暗色模式下的
  ///   卡片应是带一点原色调的深灰，而不是刺眼的高饱和色块或发脏的橄榄色；
  /// - accent：明度夹在 0.55~0.80，保证在深色卡片上看得见；
  /// - text：明度取反并夹在 0.70~0.95，深色文字变为浅色文字。
  static Color deriveDark(Color color, DiaryCardColorRole role) {
    final hsl = HSLColor.fromColor(color);
    final derived = switch (role) {
      DiaryCardColorRole.surface =>
        hsl
            .withLightness(0.13 + hsl.lightness * 0.08)
            .withSaturation(hsl.saturation * 0.3),
      DiaryCardColorRole.accent => hsl.withLightness(
        hsl.lightness.clamp(0.55, 0.8).toDouble(),
      ),
      DiaryCardColorRole.text => hsl.withLightness(
        (1 - hsl.lightness).clamp(0.7, 0.95).toDouble(),
      ),
    };
    return derived.toColor().withValues(alpha: color.a);
  }
}
