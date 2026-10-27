import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// 一份解码好的背景图的身份：文件名 + 模糊 + 尺寸档 + 像素密度。
///
/// 背景按路由（窗口）的物理尺寸解码，但不按精确尺寸：桌面拖动窗口时尺寸
/// 每帧都在变，若每帧换一个键就要每帧重解码。这里把物理宽、高各自向上取整
/// 到 [bucketStep] 的倍数作为“档”（[bucket]），同一档内共用一份解码结果，
/// 跨档时由渲染层先保留旧图、新档解码完再换上。
///
/// 为什么宽高都分档，而不是只取长边：cover 需要按目标框的宽高比计算缩放。
/// 只对长边分档、短边仍是精确值时，拖动窗口改变短边照样每帧换键；若干脆
/// 按“长边 × 长边”的正方形算 cover，横竖都不用重解码，但竖屏手机上一张
/// 竖拍照片的解码面积约为实际需要的两倍。两边各自分档，最多多解码 255
/// 物理像素，手机旋转换一次档（旧档留在缓存里，转回来直接命中）。
///
/// 像素密度参与比较：模糊半径按逻辑像素给出，换算到解码像素时要用它。
@immutable
class AppBackgroundImageKey {
  const AppBackgroundImageKey({
    required this.fileName,
    required this.blur,
    required this.bucket,
    required this.devicePixelRatio,
  });

  /// 按显示区域的逻辑尺寸与像素密度取键。
  factory AppBackgroundImageKey.forDisplay({
    required String fileName,
    required double blur,
    required Size logicalSize,
    required double devicePixelRatio,
  }) {
    return AppBackgroundImageKey(
      fileName: fileName,
      blur: blur,
      bucket: bucketFor(logicalSize, devicePixelRatio),
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// 尺寸档的步长（物理像素）。
  static const int bucketStep = 256;

  /// 逻辑尺寸 × 像素密度后，宽、高各自向上取整到 [bucketStep] 的倍数（至少
  /// 一档）。尺寸为 0（首帧之前、测试里没有窗口）时也给一档，不产生 0 宽高。
  static Size bucketFor(Size logicalSize, double devicePixelRatio) {
    int up(double extent) {
      final steps = (extent * devicePixelRatio / bucketStep).ceil();
      return math.max(1, steps) * bucketStep;
    }

    return Size(
      up(logicalSize.width).toDouble(),
      up(logicalSize.height).toDouble(),
    );
  }

  /// 托管目录 `app_backgrounds/` 里的文件名。
  final String fileName;

  /// 模糊半径（逻辑像素下的 sigma），0 为不模糊。
  final double blur;

  /// 物理像素下的显示框尺寸档，宽高都是 [bucketStep] 的倍数。
  final Size bucket;

  final double devicePixelRatio;

  bool get blurred => blur > 0;

  /// 与 [other] 是否是同一张图的同一种处理（只差尺寸档或像素密度）：渲染层
  /// 据此决定换图时直接替换（同一画面换个清晰度）还是交叉淡入。
  bool sameImageAs(AppBackgroundImageKey other) =>
      other.fileName == fileName && other.blur == blur;

  @override
  bool operator ==(Object other) {
    return other is AppBackgroundImageKey &&
        other.fileName == fileName &&
        other.blur == blur &&
        other.bucket == bucket &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(fileName, blur, bucket, devicePixelRatio);

  @override
  String toString() =>
      'AppBackgroundImageKey($fileName, blur: $blur, bucket: $bucket, '
      'dpr: $devicePixelRatio)';
}

/// 背景图的解码尺寸与模糊换算（纯函数，单测覆盖）。
abstract final class AppBackgroundDecodePlan {
  /// 有模糊时的解码比例：模糊会抹掉高频细节，半分辨率解码后放大显示看不出
  /// 差别，内存与模糊的开销都只有四分之一。
  static const double blurredScale = 0.5;

  /// 按 cover 铺满 [box] 时需要的解码尺寸（保持原图比例）。
  ///
  /// 缩放取 `max(框宽 / 图宽, 框高 / 图高)`，即较短的一边恰好铺满；不放大
  /// （小图按原尺寸解码，显示时由 GPU 放大），再乘以 [scale]（模糊时为
  /// [blurredScale]）。结果向上取整、至少 1 像素。
  static ({int width, int height}) coverSize({
    required Size image,
    required Size box,
    double scale = 1,
  }) {
    if (image.width <= 0 || image.height <= 0) {
      return (width: 1, height: 1);
    }
    final cover = math.max(box.width / image.width, box.height / image.height);
    final factor = math.min(cover, 1.0) * scale;
    // 向上取整前减去一点浮点误差：恰好铺满的一边（如 3000 × 2560 / 3000）
    // 不会因为 2560.0000001 而多出 1 像素。
    int extent(double value) => math.max(1, (value - 1e-6).ceil());
    return (
      width: extent(image.width * factor),
      height: extent(image.height * factor),
    );
  }

  /// 把逻辑像素下的模糊半径换算成解码图上的 sigma。
  ///
  /// 解码图按 cover 铺满物理尺寸为 [box] 的框时，一个解码像素在屏幕上占
  /// `max(框宽 / 解码宽, 框高 / 解码高)` 个物理像素；逻辑半径先乘像素密度
  /// 得到物理半径，再除以这个放大倍数。这样无论按半分辨率解码、还是原图
  /// 比屏幕小，屏幕上看到的模糊程度都与设置一致。
  static double blurSigma({
    required double blur,
    required double devicePixelRatio,
    required Size box,
    required int decodedWidth,
    required int decodedHeight,
  }) {
    if (blur <= 0 || decodedWidth <= 0 || decodedHeight <= 0) return 0;
    final displayScale = math.max(
      box.width / decodedWidth,
      box.height / decodedHeight,
    );
    if (displayScale <= 0) return 0;
    return blur * devicePixelRatio / displayScale;
  }
}
