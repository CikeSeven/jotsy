import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/widgets/diary_long_image_fold.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_source_builder.dart';

/// 正文图片本体。provider 按来源缓存在 State 中：编辑器每次改动都会重建
/// 文本行，若每次构建新 provider，base64 图片会反复解码并闪烁。
///
/// 先经 [LongImageSourceBuilder] 读出原图尺寸（只读文件头）再决定怎么显示：
/// 长图折叠（[DiaryLongImageFold]），其余按显示宽度保持比例解码
/// （[boundedImageProvider]）——不再把几千像素的原图整张解码，超过纹理上限的
/// 一边也不会被引擎单独压扁。尺寸未读出前不占位，与原先图片解码前一样。
class DiaryEmbeddedImage extends StatefulWidget {
  const DiaryEmbeddedImage({
    super.key,
    required this.source,
    this.bounds = const BoxConstraints(),
    this.heroTag,
    this.foldLongImages = true,
  });

  final String source;
  final BoxConstraints bounds;

  /// 看图页共享元素标签；为 null（编辑页）时不建立 Hero。
  final Object? heroTag;

  /// 长图折叠（默认）还是完整展开。
  final bool foldLongImages;

  @override
  State<DiaryEmbeddedImage> createState() => _DiaryEmbeddedImageState();
}

class _DiaryEmbeddedImageState extends State<DiaryEmbeddedImage> {
  late ImageProvider _provider = resolveDiaryImageProvider(widget.source);

  @override
  void didUpdateWidget(DiaryEmbeddedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _provider = resolveDiaryImageProvider(widget.source);
    }
  }

  /// 分片路径到 provider；整张退路的“分片”就是来源本身，复用缓存的 provider。
  ImageProvider _providerOf(String path) =>
      path == widget.source ? _provider : FileImage(File(path));

  /// 解码宽度（物理像素）：正文列不会宽于屏幕，按屏宽解码即可。
  ///
  /// 不跟缩放菜单的宽度上限走：拖动滑条时上限逐帧变化，解码尺寸跟着变就是
  /// 每帧一个新的缓存键，新尺寸解码完成前图片一直是空白，只偶尔闪出一帧。
  /// 缩小显示的图片多占的那点内存远不值这个代价。
  int _decodeWidth(BuildContext context) {
    return (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .ceil();
  }

  @override
  Widget build(BuildContext context) {
    final decodeWidth = _decodeWidth(context);
    return LongImageSourceBuilder(
      source: widget.source,
      builder: (BuildContext context, LongImageSnapshot snapshot) {
        if (!snapshot.sizeResolved) {
          return const SizedBox.shrink();
        }
        final size = snapshot.size;
        if (size != null && snapshot.isLong && !widget.foldLongImages) {
          return DiaryLongImageFull(
            size: size,
            tiles: snapshot.tiles,
            decodeWidth: decodeWidth,
            providerOf: _providerOf,
            bounds: widget.bounds,
          );
        }
        if (size != null && snapshot.isLong) {
          return DiaryLongImageFold(
            size: size,
            tiles: snapshot.tiles,
            decodeWidth: decodeWidth,
            providerOf: _providerOf,
            bounds: widget.bounds,
            heroTag: widget.heroTag,
          );
        }
        return _buildPlain(context, decodeWidth);
      },
    );
  }

  Widget _buildPlain(BuildContext context, int decodeWidth) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    // 不给 Image 指定宽高：RenderImage 会在约束内按原始比例取尺寸，
    // 裁切与边框因此贴合画面本身。
    return ConstrainedBox(
      constraints: widget.bounds,
      child: ImageViewerHeroSource(
        tag: widget.heroTag,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: _buildImage(colors, radius, decodeWidth),
      ),
    );
  }

  Widget _buildImage(ColorScheme colors, BorderRadius radius, int decodeWidth) {
    return Image(
      image: boundedImageProvider(_provider, width: decodeWidth),
      // 换解码尺寸（转屏、分屏改变屏宽）时保留旧画面，直到新尺寸解码完成。
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final framed = ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.fromBorderSide(
                ExpressiveSurfaces.cardBorderSide(colors),
              ),
            ),
            child: child,
          ),
        );
        // 已在缓存中的图片直接显示；首次解码时淡入，避免尺寸确定瞬间硬切。
        return expressiveImageFrameBuilder(
          context,
          framed,
          frame,
          wasSynchronouslyLoaded,
        );
      },
      errorBuilder: (context, error, stackTrace) => const _DiaryImageFallback(),
    );
  }
}

/// 文件被删除或来源失效时的占位，避免正文里出现空白或框架默认错误块。
class _DiaryImageFallback extends StatelessWidget {
  const _DiaryImageFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(colors),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.image,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.l10n.imageLoadFailed,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
