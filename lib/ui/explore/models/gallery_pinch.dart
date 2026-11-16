import 'dart:math' as math;

/// 画廊捏合换档的过渡量（纯计算）。
///
/// 捏合时当前档与目标档两层同时画：当前档按手指比例 `scale` 缩放，目标档
/// 按 `scale / ratio` 缩放（[ratio] 为目标档格子与当前档格子的边长比），
/// 两层随进度交叉淡入。手指比例正好等于 [ratio] 时目标档恰好是原大、当前
/// 档完全淡出，此刻换成目标档的正式网格，画面不跳。
abstract final class GalleryPinch {
  /// 松手时进度达到它就完成换档，否则退回当前档。
  static const double commitThreshold = 0.35;

  /// 已是最大 / 最小一档时继续捏的阻尼指数：手指比例 2 只放大约 11%。
  static const double _rubberBandExponent = 0.15;

  /// 手指比例 [scale] 下从当前档走向目标档的进度（0–1）：按对数比例换算
  /// （缩放的感知是乘法的，放大与缩小对称）。
  static double progress(double scale, double ratio) {
    if (scale <= 0 || ratio <= 0 || (ratio - 1).abs() < 1e-6) return 0;
    return (math.log(scale) / math.log(ratio)).clamp(0.0, 1.0);
  }

  /// 目标档那一层的不透明度：进度 0.2 之前只有当前档、0.8 之后只有目标档，
  /// 中间平滑交叉，两层都半透明（重影）的时间尽量短。
  static double fade(double progress) {
    final t = ((progress - _fadeStart) / (_fadeEnd - _fadeStart)).clamp(
      0.0,
      1.0,
    );
    return t * t * (3 - 2 * t);
  }

  static const double _fadeStart = 0.2;
  static const double _fadeEnd = 0.8;

  /// 没有下一档可换时当前档的显示比例：跟手但阻尼很大，松手弹回。
  static double rubberBand(double scale) =>
      scale <= 0 ? 1 : math.pow(scale, _rubberBandExponent).toDouble();

  /// 在 [from] 与 [to] 之间按对数插值（[t] 可略超出 0–1，弹簧过冲）。
  static double lerpScale(double from, double to, double t) {
    if (from <= 0 || to <= 0) return to;
    final a = math.log(from);
    return math.exp(a + (math.log(to) - a) * t);
  }
}
