import 'package:flutter/painting.dart';

/// 高不小于宽的这个倍数即视为长图（长截图、长条漫画）：正文折叠、看图页按屏宽
/// 竖向滚动、封面与缩略图顶部对齐。普通竖拍照片约 1.33～2.2，不受影响。
const double kLongImageAspectThreshold = 3;

/// 解码后任一边的安全上限（像素）。
///
/// Impeller 解码时把宽、高分别夹到 GPU 最大纹理尺寸（不保持比例），超出的一边
/// 会被单独压缩而变形。现代手机多为 16384，部分旧机型只有 8192，取后者。
const int kSafeImageDecodeExtent = 8192;

bool isLongImageSize(Size size) =>
    size.width > 0 && size.height >= size.width * kLongImageAspectThreshold;

/// 来源是否是本地文件（不是网络图，也不是 `data:` URI）。
bool isLocalImageSource(String source) {
  if (source.contains('base64,')) {
    return false;
  }
  final uri = Uri.tryParse(source);
  return !(uri != null && (uri.isScheme('http') || uri.isScheme('https')));
}

/// 保持比例地缩小解码：宽不超过 [width]、高不超过 [height]，未给的一边取
/// [kSafeImageDecodeExtent]；小图不放大。
///
/// 只给一边的 `cacheWidth` / `ResizeImage.resizeIfNeeded` 会按比例算出另一边，
/// 长图的那一边仍可能超过纹理上限而被压扁，所以所有展示型解码都经这里。
/// [image] 不能本身就是 [ResizeImage]（两层 getTargetSize 不能叠加）。
ImageProvider boundedImageProvider(
  ImageProvider image, {
  int? width,
  int? height,
}) {
  return ResizeImage(
    image,
    width: _clampExtent(width),
    height: _clampExtent(height),
    policy: ResizeImagePolicy.fit,
  );
}

int _clampExtent(int? extent) {
  if (extent == null || extent > kSafeImageDecodeExtent) {
    return kSafeImageDecodeExtent;
  }
  return extent < 1 ? 1 : extent;
}
