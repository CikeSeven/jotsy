import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';

/// 看图页的原图：本地路径或网络 URL，解码完成后淡入
/// （[expressiveImageFrameBuilder]）。
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

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        placeholderBehind ? const SizedBox.shrink() : const _ImageFallback();
    if (isRemote) {
      return Image.network(
        source,
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
    return Image.file(
      File(source),
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
