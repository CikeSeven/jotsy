import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/models/diary_thumbnail_rows.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_fallback.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_thumbnail.dart';
import 'package:node_diary/ui/diaries/widgets/diary_long_image_fold.dart';
import 'package:node_diary/ui/diaries/widgets/diary_media_viewport_gate.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_source_builder.dart';
import 'package:node_diary/ui/widgets/width_layout_builder.dart';

/// 正文图片本体。provider 按来源缓存在 State 中：编辑器每次改动都会重建
/// 文本行，若每次构建新 provider，base64 图片会反复解码并闪烁。
///
/// 先经 [LongImageSourceBuilder] 读出原图尺寸（只读文件头）再决定怎么显示：
/// 长图折叠（[DiaryLongImageFold]），其余按可用列宽保持比例解码
/// （[boundedImageProvider]）——不再把几千像素的原图整张解码，超过纹理上限的
/// 一边也不会被引擎单独压扁。
///
/// 尺寸未读出前与离屏时都保留非零占位高度，已读出尺寸后在解码完成前也按精确
/// 显示尺寸占位：避免虚拟列表因 0 高度塌陷把整篇几十张图片和视频一齐挂载，
/// 同时离开视口或路由被遮挡时经 [DiaryMediaViewportGate] 释放活着的 `Image`
/// 监听，防止大量原图解码纹理常驻内存导致卡死或 OOM。
/// 设为小图时整个交给 [DiaryImageThumbnail]（方格，不走长图分片；边长见
/// [diaryThumbnailExtentFor]）。
class DiaryEmbeddedImage extends StatefulWidget {
  const DiaryEmbeddedImage({
    super.key,
    required this.source,
    this.bounds = const BoxConstraints(),
    this.heroTag,
    this.foldLongImages = true,
    this.thumbnail = false,
  });

  final String source;
  final BoxConstraints bounds;

  /// 看图页共享元素标签；为 null（编辑页）时不建立 Hero。
  final Object? heroTag;

  /// 长图折叠（默认）还是完整展开。
  final bool foldLongImages;

  /// 以方形小图显示（[DiaryImageThumbnail]）：优先于 [bounds] 与长图的
  /// 折叠 / 完整显示，两者都不生效。
  final bool thumbnail;

  @override
  State<DiaryEmbeddedImage> createState() => _DiaryEmbeddedImageState();
}

class _DiaryEmbeddedImageState extends State<DiaryEmbeddedImage> {
  /// 尺寸未知时的默认占位高上限（逻辑像素），与一张普通 4:3 照片相近，既能让
  /// 虚拟列表只挂视口附近几项，也不会把短图撑得过高。
  static const double _maxDefaultPlaceholderHeight = 320;
  static const double _defaultPlaceholderAspect = 4 / 3;

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

  /// 解码宽度（物理像素）：按正文列宽与屏宽的较小值解码，宽屏/桌面不再按整屏
  /// 过度解码。
  ///
  /// 不跟缩放菜单的宽度上限走：拖动滑条时上限逐帧变化，解码尺寸跟着变就是
  /// 每帧一个新的缓存键，新尺寸解码完成前图片一直是空白，只偶尔闪出一帧。
  int _decodeWidth(BuildContext context, double columnWidth) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetWidth = math.min(columnWidth, screenWidth);
    return (targetWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  Size _defaultPlaceholderSize(double columnWidth) {
    final width = math.min(
      columnWidth,
      widget.bounds.maxWidth.isFinite ? widget.bounds.maxWidth : columnWidth,
    );
    final safeWidth = width.isFinite && width > 0 ? width : 240.0;
    final maxHeight = widget.bounds.maxHeight.isFinite
        ? math.min(widget.bounds.maxHeight, _maxDefaultPlaceholderHeight)
        : _maxDefaultPlaceholderHeight;
    final height = (safeWidth / _defaultPlaceholderAspect)
        .clamp(1.0, math.max(1.0, maxHeight))
        .toDouble();
    return Size(safeWidth, height);
  }

  /// 计算离屏或占位期间保留的盒尺寸：已读出原图尺寸时与真实显示完全一致，
  /// 离开视口释放纹理后正文高度不变，回滚不跳动。
  Size _reservedSize({
    required Size? size,
    required bool isLong,
    required double columnWidth,
  }) {
    if (size == null) return _defaultPlaceholderSize(columnWidth);
    if (isLong && !widget.foldLongImages) {
      final width = math.min(
        columnWidth,
        math.min(widget.bounds.maxWidth, size.width),
      );
      return Size(width, width * size.height / size.width);
    }
    if (isLong) {
      final maxWidth = math.min(
        columnWidth,
        math.min(widget.bounds.maxWidth, size.width),
      );
      final height = widget.bounds.maxHeight.isFinite
          ? math.min(
              maxWidth * DiaryLongImageFold.foldHeightFactor,
              widget.bounds.maxHeight,
            )
          : maxWidth * DiaryLongImageFold.foldHeightFactor;
      return Size(height / DiaryLongImageFold.foldHeightFactor, height);
    }
    return _fittedImageSize(
      size,
      maxWidth: math.min(columnWidth, widget.bounds.maxWidth),
      maxHeight: widget.bounds.maxHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnail) {
      Widget thumbnail(double extent) => DiaryImageThumbnail(
        source: widget.source,
        provider: _provider,
        extent: extent,
        heroTag: widget.heroTag,
      );
      // 并排时用整排算好的边长；单独一张时按自己的可用宽度算同一个边长，
      // 与并排的几张大小一致。
      final rowExtent = DiaryThumbnailExtent.maybeOf(context);
      if (rowExtent != null) return thumbnail(rowExtent);
      return WidthLayoutBuilder(
        builder: (context, width) => thumbnail(diaryThumbnailExtentFor(width)),
      );
    }
    return WidthLayoutBuilder(
      builder: (context, availableWidth) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final columnWidth = availableWidth.isFinite && availableWidth > 0
            ? availableWidth
            : screenWidth;
        final decodeWidth = _decodeWidth(context, columnWidth);
        return DiaryMediaViewportGate(
          builder: (BuildContext context, bool active) =>
              LongImageSourceBuilder(
                source: widget.source,
                enabled: active,
                builder: (BuildContext context, LongImageSnapshot snapshot) {
                  final size = snapshot.size;
                  if (!active) {
                    return _buildPlaceholder(
                      context,
                      _reservedSize(
                        size: size,
                        isLong: snapshot.isLong,
                        columnWidth: columnWidth,
                      ),
                    );
                  }
                  if (!snapshot.sizeResolved) {
                    return _buildPlaceholder(
                      context,
                      _defaultPlaceholderSize(columnWidth),
                    );
                  }
                  if (size != null &&
                      snapshot.isLong &&
                      !widget.foldLongImages) {
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
                  final displaySize = size == null
                      ? null
                      : _fittedImageSize(
                          size,
                          maxWidth: math.min(
                            columnWidth,
                            widget.bounds.maxWidth,
                          ),
                          maxHeight: widget.bounds.maxHeight,
                        );
                  return _buildPlain(context, decodeWidth, displaySize);
                },
              ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, Size size) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: radius,
          border: Border.fromBorderSide(
            ExpressiveSurfaces.cardBorderSide(colors),
          ),
        ),
      ),
    );
  }

  Widget _buildPlain(BuildContext context, int decodeWidth, Size? displaySize) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    return ConstrainedBox(
      constraints: widget.bounds,
      child: ImageViewerHeroSource(
        tag: widget.heroTag,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: _buildImage(colors, radius, decodeWidth, displaySize),
      ),
    );
  }

  Widget _buildImage(
    ColorScheme colors,
    BorderRadius radius,
    int decodeWidth,
    Size? displaySize,
  ) {
    return Image(
      image: boundedImageProvider(_provider, width: decodeWidth),
      // 已测出原图尺寸时直接给 Image 指定贴合原比例的宽高：像素解码完成前
      // 不会塌成 0×0，失败时 errorBuilder 仍按整宽展开而不受此尺寸约束。
      width: displaySize?.width,
      height: displaySize?.height,
      fit: displaySize == null ? null : BoxFit.contain,
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
      errorBuilder: (context, error, stackTrace) =>
          DiaryImageFallback(source: widget.source),
    );
  }

  /// 按 `BoxFit.scaleDown` 计算原图在最大宽高约束内的贴合尺寸（不放大）。
  /// 在受限轴上直接取约束值，避免 `width * (maxWidth / width)` 的浮点尾差。
  static Size _fittedImageSize(
    Size natural, {
    required double maxWidth,
    required double maxHeight,
  }) {
    if (natural.width <= 0 || natural.height <= 0) return Size.zero;
    final fitsWidth = !maxWidth.isFinite || natural.width <= maxWidth;
    final fitsHeight = !maxHeight.isFinite || natural.height <= maxHeight;
    if (fitsWidth && fitsHeight) return natural;
    final widthRatio = maxWidth.isFinite
        ? maxWidth / natural.width
        : double.infinity;
    final heightRatio = maxHeight.isFinite
        ? maxHeight / natural.height
        : double.infinity;
    if (widthRatio <= heightRatio) {
      return Size(maxWidth, natural.height * maxWidth / natural.width);
    }
    return Size(natural.width * maxHeight / natural.height, maxHeight);
  }
}
