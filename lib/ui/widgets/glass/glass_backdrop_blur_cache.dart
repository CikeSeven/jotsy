import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'glass_backdrop_sample.dart';

/// 预模糊背景的缓存：同一张背景在同样的尺寸、对齐与模糊参数下只生成一次。
///
/// - 输入：[GlassBackdropSample]（图、对齐、底色）、Leader 尺寸、模糊半径与
///   饱和度；输出：模糊好的位图（逻辑像素 × [_scaleFor] 的分辨率，画时由
///   双线性插值放大——内容已经模糊，放大看不出颗粒）；
/// - 生成：先把“底色 + cover 图”画成一张图，再带模糊（clamp 边缘，与贴着
///   屏幕边缘的背景模糊一致）与饱和度矩阵画一遍；只在 UI 线程录制，光栅
///   线程做一次；
/// - 最多保留 [_capacity] 项，淘汰最久未用的一项并释放缓存自己的句柄（已经
///   录进画面的引用由引擎计数，不受影响）。每项留一份源图的 clone 用来
///   比对“还是不是同一张图”，淘汰时一并释放。
abstract final class GlassBackdropBlurCache {
  static const int _capacity = 4;
  static const int _maxBytes = 32 * 1024 * 1024;
  static final List<_BlurEntry> _entries = <_BlurEntry>[];

  /// 生成次数（测试用，确认同样的输入不会重复生成）。
  @visibleForTesting
  static int debugGenerations = 0;

  @visibleForTesting
  static void debugClear() {
    for (final entry in _entries) {
      entry.dispose();
    }
    _entries.clear();
    debugGenerations = 0;
  }

  /// 取（必要时生成）预模糊图；源图句柄已被背景层释放（换图的那一帧还没
  /// 重建到这里）时返回 null，这一帧不画取样。
  static ui.Image? resolve({
    required GlassBackdropSample sample,
    required Size size,
    required double sigma,
    required double saturation,
  }) {
    if (size.isEmpty || !size.isFinite) return null;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.matches(sample, size, sigma, saturation)) {
        if (i != _entries.length - 1) {
          _entries
            ..removeAt(i)
            ..add(entry);
        }
        return entry.blurred;
      }
    }
    final ui.Image source;
    try {
      source = sample.image.clone();
    } on StateError {
      return null;
    }
    final entry = _BlurEntry(
      source: source,
      alignment: sample.alignment,
      underColor: sample.underColor,
      scrim: sample.scrim,
      size: size,
      sigma: sigma,
      saturation: saturation,
      blurred: _generate(source, sample, size, sigma, saturation),
    );
    _entries.add(entry);
    // 源图 clone 不复制像素，但会延长源图寿命，仍计入预算；至少保留当前
    // 一项，超预算的单张源图本来就由正在显示的页面持有。
    var bytes = _entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
    while (_entries.length > 1 &&
        (_entries.length > _capacity || bytes > _maxBytes)) {
      bytes -= _entries.first.bytes;
      _entries.removeAt(0).dispose();
    }
    return entry.blurred;
  }

  /// 预模糊图相对逻辑像素的分辨率：模糊半径在位图里至少约 6 像素，放大时
  /// 不出现块状；最低 1/4、最高 1（不超过逻辑分辨率）。
  static double _scaleFor(double sigma) =>
      sigma <= 0 ? 1 : (6 / sigma).clamp(0.25, 1.0);

  static ui.Image _generate(
    ui.Image image,
    GlassBackdropSample sample,
    Size size,
    double sigma,
    double saturation,
  ) {
    debugGenerations++;
    // 限制总像素而不是分别裁短两边：超宽/高窗口仍保持 cover 比例，单项
    // 最多约 4 MiB（四项上限约 16 MiB），避免低模糊半径占用整屏分辨率。
    final scale = math.min(
      _scaleFor(sigma),
      math.min(
        math.sqrt(1048576 / (size.width * size.height)),
        4096 / math.max(size.width, size.height),
      ),
    );
    final width = (size.width * scale).ceil().clamp(1, 4096);
    final height = (size.height * scale).ceil().clamp(1, 4096);
    final bounds = Offset.zero & size;

    final composeRecorder = ui.PictureRecorder();
    final compose = Canvas(composeRecorder)..scale(scale);
    compose.drawRect(bounds, Paint()..color = sample.underColor);
    paintImage(
      canvas: compose,
      rect: bounds,
      image: image,
      fit: BoxFit.cover,
      alignment: sample.alignment,
      filterQuality: FilterQuality.medium,
    );
    final composePicture = composeRecorder.endRecording();
    final composed = composePicture.toImageSync(width, height);
    composePicture.dispose();

    final blurRecorder = ui.PictureRecorder();
    final blurCanvas = Canvas(blurRecorder);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (sigma > 0) {
      paint.imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma * scale,
        sigmaY: sigma * scale,
        tileMode: TileMode.clamp,
      );
    }
    if (saturation != 1) {
      paint.colorFilter = ColorFilter.matrix(saturationMatrix(saturation));
    }
    blurCanvas.drawImage(composed, Offset.zero, paint);
    // 遮罩一起烘进缓存，淡入时只对完整结果应用一次透明度。分开画会在
    // 淡入中途叠两遍遮罩，使取样区比周围背景更深。
    final scrim = sample.scrim;
    if (scrim != null && scrim.a > 0) {
      blurCanvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = saturate(scrim, saturation),
      );
    }
    final blurPicture = blurRecorder.endRecording();
    final blurred = blurPicture.toImageSync(width, height);
    blurPicture.dispose();
    composed.dispose();
    return blurred;
  }

  /// 饱和度矩阵（与玻璃背景模糊上叠的那一层相同，Rec. 709 亮度权重）。
  static List<double> saturationMatrix(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final k = 1 - s;
    return <double>[
      r * k + s, g * k, b * k, 0, 0, //
      r * k, g * k + s, b * k, 0, 0, //
      r * k, g * k, b * k + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  /// 把 [saturationMatrix] 作用到一个颜色上（遮罩随背景一起调饱和度）。
  static Color saturate(Color color, double s) {
    if (s == 1) return color;
    final m = saturationMatrix(s);
    double channel(int row) =>
        (m[row * 5] * color.r +
                m[row * 5 + 1] * color.g +
                m[row * 5 + 2] * color.b)
            .clamp(0.0, 1.0);
    return Color.from(
      alpha: color.a,
      red: channel(0),
      green: channel(1),
      blue: channel(2),
    );
  }
}

class _BlurEntry {
  _BlurEntry({
    required this.source,
    required this.alignment,
    required this.underColor,
    required this.scrim,
    required this.size,
    required this.sigma,
    required this.saturation,
    required this.blurred,
  });

  final ui.Image source;
  final Alignment alignment;
  final Color underColor;
  final Color? scrim;
  final Size size;
  final double sigma;
  final double saturation;
  final ui.Image blurred;

  int get bytes =>
      (source.width * source.height + blurred.width * blurred.height) * 4;

  bool matches(
    GlassBackdropSample sample,
    Size size,
    double sigma,
    double saturation,
  ) =>
      source.isCloneOf(sample.image) &&
      alignment == sample.alignment &&
      underColor == sample.underColor &&
      scrim == sample.scrim &&
      this.size == size &&
      this.sigma == sigma &&
      this.saturation == saturation;

  void dispose() {
    source.dispose();
    blurred.dispose();
  }
}
