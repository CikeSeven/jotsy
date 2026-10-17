import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_options_menu.dart';
import 'package:node_diary/ui/diaries/widgets/diary_long_image_fold.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_source_builder.dart';

/// 正文图片按独立块渲染，圆角、微边框与上下留白和视频/附件卡片保持同一节奏。
///
/// 上游 `QuillEditorImageEmbedBuilder` 把图片当作行内 WidgetSpan 放进文本行：
/// 直角、贴着文字基线、没有段间距，点按弹出的菜单里“缩放”打开它自带的
/// PhotoView 页面。这里整体接管：
/// - 只读正文提供 [onImageOpen] 时点按直接进看图页：图片作为看图页的共享元素
///   来源，点按瞬间抓取画面并交给回调，看图页从图片原位展开；
/// - 其余情况（编辑页、发布页预览）点按弹出 [showDiaryImageOptions]：查看、
///   调整大小、复制、保存到相册、删除（只读时没有调整大小与删除）；
/// - 缩放菜单写入的宽高只作为上限，见 [diaryImageEmbedBounds]；比列宽窄的
///   图片（缩小过或原图就小）靠行首对齐，所在行设了居中/居右时从之，见
///   [diaryImageEmbedAlignment]；
/// - 长图（高 ≥ 宽 × 3）默认折叠显示（[DiaryLongImageFold]）；[foldLongImages]
///   为 false（预览页“长图显示：完整显示”）时按列宽完整展开
///   （[DiaryLongImageFull]）。
class DiaryImageEmbedBuilder extends quill.EmbedBuilder {
  const DiaryImageEmbedBuilder({this.onImageOpen, this.foldLongImages = true});

  final void Function(String imageSource, ImageViewerHero? hero)? onImageOpen;
  final bool foldLongImages;

  @override
  String get key => quill.BlockEmbed.imageType;

  /// 图片独占一行时走 EmbedProxy 块级布局；与文字同行的旧数据 Quill 仍按行内渲染。
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final source = embedContext.node.value.data.toString();
    final open = embedContext.readOnly ? onImageOpen : null;
    // 标签按 embed 在文档中的位置区分：同一张图可能在正文里出现多次。
    final heroTag = open == null
        ? null
        : ImageViewerHeroTag('diary_body', embedContext.node.documentOffset);
    final image = Builder(
      builder: (imageContext) => GestureDetector(
        onTap: open == null
            ? () => unawaited(
                showDiaryImageOptions(
                  imageContext,
                  controller: embedContext.controller,
                  node: embedContext.node,
                  source: source,
                  readOnly: embedContext.readOnly,
                ),
              )
            : () => open(source, _captureHero(imageContext, heroTag!)),
        child: DiaryEmbeddedImage(
          source: source,
          bounds: diaryImageEmbedBounds(embedContext.node),
          heroTag: heroTag,
          foldLongImages: foldLongImages,
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

  /// 抓取看图页的飞入画面；图片没有建立来源 Hero 时（完整展开的长图）返回
  /// null：那样的画面只是可见的某一段分片，垫在看图页顶部会错位。
  static ImageViewerHero? _captureHero(BuildContext context, Object tag) {
    var hasHero = false;
    void visit(Element element) {
      if (hasHero) return;
      final widget = element.widget;
      if (widget is Hero && widget.tag == tag) {
        hasHero = true;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return hasHero ? ImageViewerHero.capture(context, tag: tag) : null;
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
