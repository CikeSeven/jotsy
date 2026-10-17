import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
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

/// 正文图片按独立块渲染，圆角、微边框与上下留白和视频/附件卡片保持同一节奏。
///
/// 上游 [QuillEditorImageEmbedBuilder] 把图片当作行内 WidgetSpan 放进文本行：
/// 直角、贴着文字基线、没有段间距。这里只接管显示层：
/// - 编辑页点击仍复用上游构建出的回调，保留缩放/复制/删除/保存菜单（上游菜单
///   未导出，无法在这里直接构造）；
/// - 只读正文提供 [onImageOpen] 时由这里接管点击：图片作为看图页的共享元素
///   来源，点按瞬间抓取画面并交给回调，看图页从图片原位展开；
/// - 缩放菜单写入的宽高只作为上限，见 [diaryImageEmbedBounds]；比列宽窄的
///   图片（缩小过或原图就小）靠行首对齐，所在行设了居中/居右时从之，见
///   [diaryImageEmbedAlignment]；
/// - 长图（高 ≥ 宽 × 3）折叠显示，见 [DiaryLongImageFold]。
class DiaryImageEmbedBuilder extends QuillEditorImageEmbedBuilder {
  DiaryImageEmbedBuilder({required super.config, this.onImageOpen});

  final void Function(String imageSource, ImageViewerHero? hero)? onImageOpen;

  /// 图片独占一行时走 EmbedProxy 块级布局；与文字同行的旧数据 Quill 仍按行内渲染。
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final upstream = super.build(context, embedContext);
    // 升级后若上游不再以 GestureDetector 包裹，退回原样渲染，至少不丢点击菜单。
    if (upstream is! GestureDetector) return upstream;
    final source = embedContext.node.value.data.toString();
    final open = embedContext.readOnly ? onImageOpen : null;
    // 标签按 embed 在文档中的位置区分：同一张图可能在正文里出现多次。
    final heroTag = open == null
        ? null
        : ImageViewerHeroTag('diary_body', embedContext.node.documentOffset);
    final image = Builder(
      builder: (imageContext) => GestureDetector(
        onTap: open == null
            ? upstream.onTap
            : () => open(
                source,
                ImageViewerHero.capture(imageContext, tag: heroTag!),
              ),
        child: DiaryEmbeddedImage(
          source: source,
          bounds: diaryImageEmbedBounds(embedContext.node),
          heroTag: heroTag,
        ),
      ),
    );
    if (embedContext.inline) return image;
    // 比列宽窄的图片靠行首（与正文文字左缘对齐），不再一律居中；heightFactor
    // 防止有界高度下 Align 撑满整行。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: diaryImageEmbedAlignment(embedContext.node),
        heightFactor: 1,
        child: image,
      ),
    );
  }
}

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
  });

  final String source;
  final BoxConstraints bounds;

  /// 看图页共享元素标签；为 null（编辑页）时不建立 Hero。
  final Object? heroTag;

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

  /// 解码宽度（物理像素）：正文列不会宽于屏幕，缩放菜单的宽度上限更窄时取它。
  int _decodeWidth(BuildContext context) {
    final width = math.min(
      MediaQuery.sizeOf(context).width,
      widget.bounds.maxWidth,
    );
    return (width * MediaQuery.devicePixelRatioOf(context)).ceil();
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
