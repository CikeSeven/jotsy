import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../core/services/image_dimensions.dart';
import '../../widgets/long_image/long_image_policy.dart';
import 'app_background_image_key.dart';

/// 解码（与预模糊）完成的背景图。[image] 是唯一的原始句柄，交给缓存持有；
/// 对外一律给 clone。
class AppBackgroundDecoded {
  const AppBackgroundDecoded(this.image, this.averageColor);

  final ui.Image image;

  /// 整张图的平均颜色（含透明度，未预乘），供对比度兜底估算底色。
  final Color averageColor;
}

/// 背景图的加载管线：读尺寸 → 按 cover 缩小解码 → （模糊时）离屏预模糊 →
/// 求均色。
///
/// - 输入：已解析的托管文件与 [AppBackgroundImageKey]；
/// - 输出：[AppBackgroundDecoded]；文件读不出尺寸或解码失败时抛出，由缓存
///   捕获后按“没有背景”处理；
/// - 副作用：经全局 ImageCache 解码一次，拿到自己的句柄后立即把这一项逐出
///   ImageCache——缓存里只留背景缓存这一份，模糊时原图更不必常驻。
///
/// 模糊只在这里做一次：页面上画的是预先模糊好的位图，不在每帧用
/// `BackdropFilter` / `ImageFiltered` 实时模糊整屏。
abstract final class AppBackgroundImagePipeline {
  /// 求均色时缩到的边长；16×16 足够代表整体色调，读回只有 1KB。
  static const int averageSampleExtent = 16;

  static Future<AppBackgroundDecoded> load(
    File file,
    AppBackgroundImageKey key,
  ) async {
    final size = await ImageDimensions.resolve(file.path);
    if (size == null) {
      throw StateError('Unreadable background image: ${file.path}');
    }
    final target = AppBackgroundDecodePlan.coverSize(
      image: size,
      box: key.bucket,
      scale: key.blurred ? AppBackgroundDecodePlan.blurredScale : 1,
    );
    // 宽高都显式给出：只给一边时另一边按比例推出，仍可能超过纹理上限而被
    // 引擎单独压扁（见 boundedImageProvider）。
    final provider = boundedImageProvider(
      FileImage(file),
      width: target.width,
      height: target.height,
    );
    var image = await _decode(provider);
    unawaited(provider.evict());
    try {
      if (key.blurred) {
        final sigma = AppBackgroundDecodePlan.blurSigma(
          blur: key.blur,
          devicePixelRatio: key.devicePixelRatio,
          box: key.bucket,
          decodedWidth: image.width,
          decodedHeight: image.height,
        );
        if (sigma > 0) {
          final blurred = await blur(image, sigma);
          image.dispose();
          image = blurred;
        }
      }
      return AppBackgroundDecoded(image, await averageColor(image));
    } catch (_) {
      image.dispose();
      rethrow;
    }
  }

  /// 把 [source] 画进同尺寸的离屏位图并模糊一次，返回新图（[source] 由
  /// 调用方释放）。
  ///
  /// 边缘用 [TileMode.mirror]：模糊会采到图片以外的区域，默认的 decal 把
  /// 那里当透明，边缘一圈会变暗发灰；镜像延伸图片自身的内容，四边与中间
  /// 一样自然。
  static Future<ui.Image> blur(ui.Image source, double sigma) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(
      source,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.mirror,
        ),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(source.width, source.height);
    } finally {
      picture.dispose();
    }
  }

  /// 整张图的平均颜色：缩到 [averageSampleExtent] 见方（带 mipmap 的中等
  /// 采样，相当于先做了区域平均）后读回像素求平均。
  ///
  /// 读回的是预乘透明度的 RGBA，先在预乘空间求平均（与合成的口径一致），
  /// 再还原成未预乘的颜色；整张全透明时返回透明色。
  static Future<Color> averageColor(ui.Image image) async {
    const extent = averageSampleExtent;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTWH(0, 0, extent * 1.0, extent * 1.0),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final ui.Image sample;
    try {
      sample = await picture.toImage(extent, extent);
    } finally {
      picture.dispose();
    }
    final ByteData? data;
    try {
      data = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      sample.dispose();
    }
    if (data == null) {
      throw StateError('Background average color readback failed');
    }
    return averageOfPremultipliedRgba(data.buffer.asUint8List());
  }

  /// 预乘 RGBA 字节的平均色（未预乘的 [Color]）；单独拆出便于单测。
  static Color averageOfPremultipliedRgba(Uint8List bytes) {
    final pixels = bytes.length ~/ 4;
    if (pixels == 0) return const Color(0x00000000);
    var r = 0, g = 0, b = 0, a = 0;
    for (var i = 0; i < pixels * 4; i += 4) {
      r += bytes[i];
      g += bytes[i + 1];
      b += bytes[i + 2];
      a += bytes[i + 3];
    }
    if (a == 0) return const Color(0x00000000);
    // 预乘值之和 / 透明度之和 = 按透明度加权的未预乘颜色。
    int channel(int sum) => (sum * 255 / a).round().clamp(0, 255);
    return Color.fromARGB(
      (a / pixels).round(),
      channel(r),
      channel(g),
      channel(b),
    );
  }

  /// 经 ImageStream 解码一次，返回监听者自己的句柄（调用方负责释放）。
  static Future<ui.Image> _decode(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        // 监听者拿到的是 ImageInfo.image 的一份 clone，归自己释放；这里把
        // 它原样交给调用方，ImageInfo 本身不再使用。
        if (completer.isCompleted) {
          info.image.dispose();
          return;
        }
        completer.complete(info.image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
