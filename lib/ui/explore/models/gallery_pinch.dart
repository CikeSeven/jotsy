import 'dart:math' as math;

/// 画廊捏合换档的过渡量（纯计算）。
///
/// 换档途中每张图从当前档的位置与大小线性走向目标档（见
/// `GalleryMorphPlan`）。进度 t 取手指比例 `scale` 相对“当前档 → 目标档
/// 格子边长比” [ratio] 的线性位置：格子边长 = 当前边长 ×
/// `(1 + (ratio − 1) × t)` = 当前边长 × scale，正好跟随手指。
abstract final class GalleryPinch {
  /// 松手时进度达到它就完成换档，否则退回当前档。
  static const double commitThreshold = 0.35;

  /// 已是最大 / 最小一档时继续捏的阻尼指数：手指比例 2 只放大约 11%。
  static const double _rubberBandExponent = 0.15;

  /// 手指比例 [scale] 下从当前档走向目标档的进度：0 为当前档，1 为目标档
  /// 原大；朝反方向捏时为 0，超过目标档时大于 1（由调用方决定继续换下一档）。
  static double progress(double scale, double ratio) {
    if ((ratio - 1).abs() < 1e-6) return 0;
    return math.max(0, (scale - 1) / (ratio - 1));
  }

  /// 起点档的日期标题在前半程淡出、终点档的在后半程淡入（[fromLayer]
  /// 区分），两档标题不会叠在一起。
  static double headerOpacity(double progress, {required bool fromLayer}) {
    final t = progress.clamp(0.0, 1.0);
    final value = fromLayer ? 1 - t * 2 : t * 2 - 1;
    return value.clamp(0.0, 1.0);
  }

  /// 没有下一档可换时的显示比例：跟手但阻尼很大，松手弹回。
  static double rubberBand(double scale) =>
      scale <= 0 ? 1 : math.pow(scale, _rubberBandExponent).toDouble();
}
