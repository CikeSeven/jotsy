import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

/// 看图页的原图：本地路径或网络 URL，解码完成后淡入
/// （[expressiveImageFrameBuilder]）。
///
/// 按比例缩小到长边不超过 [maxDecodeExtent] 再解码：放大到 4 倍仍够清晰，
/// 5000 万像素的照片也只占约 50MB，而不是两百多 MB；超过 GPU 纹理上限的一边
/// 也不会被引擎单独压扁。长图不走这里，见 `ImageViewerImagePage`。
///
/// [placeholderBehind] 为 true 时下方已有来源画面垫底（共享元素飞入的初始页）：
/// 不再显示网络加载指示，加载失败也保持来源画面，而不是在画面上再叠一个失败
/// 图标。
class ImageViewerFullImage extends StatelessWidget {
  const ImageViewerFullImage({
    super.key,
    required this.source,
    required this.fit,
    required this.placeholderBehind,
  });

  final String source;
  final BoxFit fit;
  final bool placeholderBehind;

  /// 解码后长边的上限（像素）。
  static const int maxDecodeExtent = 4096;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        placeholderBehind ? const SizedBox.shrink() : const _ImageFallback();
    if (isRemote) {
      return Image(
        image: boundedImageProvider(
          NetworkImage(source),
          width: maxDecodeExtent,
          height: maxDecodeExtent,
        ),
        fit: fit,
        frameBuilder: expressiveImageFrameBuilder,
        // 下载中的网络图只在等待超过 300ms 时才出现指示器。
        loadingBuilder: placeholderBehind
            ? null
            : (context, child, loadingProgress) => loadingProgress == null
                  ? child
                  : const DelayedLoadingIndicator(size: 48),
        errorBuilder: fallback,
      );
    }
    return Image(
      image: boundedImageProvider(
        FileImage(File(source)),
        width: maxDecodeExtent,
        height: maxDecodeExtent,
      ),
      fit: fit,
      frameBuilder: expressiveImageFrameBuilder,
      errorBuilder: fallback,
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FaIcon(
        FontAwesomeIcons.image,
        size: 28,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
