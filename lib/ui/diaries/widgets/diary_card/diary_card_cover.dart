import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/image_viewer_hero.dart';

/// 卡片封面图（自动区分网络图、本地文件与内置示例资源）。
///
/// 解码尺寸只限定一条边：同时给出宽高会按 ResizeImagePolicy.exact 把原图
/// 压成卡片比例而变形，BoxFit.cover 负责绘制时裁切。
/// - 宽度有限：按宽度解码；
/// - 宽度为 infinity（通栏封面）：用 LayoutBuilder 取实际列宽解码，不再退化
///   为只限高——那样竖图只解码出约 140dp 宽，拉伸到整列后发糊；
/// - [lowResolution]：未解封胶囊的模糊封面，按极小尺寸解码，配合模糊既省
///   内存又无需高清细节。
///
/// `asset:` 前缀只用于设置页预览的内置示例图，不会出现在用户数据里。
class DiaryCardCoverImage extends StatelessWidget {
  const DiaryCardCoverImage({
    super.key,
    required this.source,
    this.width,
    required this.height,
    required this.radius,
    this.lowResolution = false,
  });

  static const String assetScheme = 'asset:';

  /// 未解封胶囊封面的解码宽度（逻辑像素，不乘 dpr）：模糊后无需细节。
  static const double sealedDecodeWidth = 48;

  final String source;
  final double? width;
  final double height;

  /// 圆角；0 表示不裁切（通栏封面由外层卡片圆角裁切）。
  final double radius;
  final bool lowResolution;

  @override
  Widget build(BuildContext context) {
    final hasFiniteWidth = width != null && width!.isFinite && width! > 0;
    if (!hasFiniteWidth && !lowResolution) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final resolvedWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null;
          return _buildImage(context, decodeWidth: resolvedWidth);
        },
      );
    }
    return _buildImage(
      context,
      decodeWidth: lowResolution ? sealedDecodeWidth : width,
    );
  }

  Widget _buildImage(BuildContext context, {required double? decodeWidth}) {
    final dpr = lowResolution ? 1.0 : MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        decodeWidth != null && decodeWidth.isFinite && decodeWidth > 0
        ? (decodeWidth * dpr).round()
        : null;
    final cacheHeight = cacheWidth == null && height.isFinite && height > 0
        ? (height * dpr).round()
        : null;
    // 低清封面放大绘制时用双线性插值，避免出现马赛克块。
    final filterQuality = lowResolution
        ? FilterQuality.medium
        : FilterQuality.low;
    final trimmed = source.trim();
    final uri = Uri.tryParse(trimmed);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) => const DiaryCardCoverErrorPlaceholder();

    // 封面解码完成才出画面：用统一淡入替代“啪”地冒出，缓存命中（滚回已显示过
    // 的卡片）则直接显示，不会重复闪烁。
    final Widget imageWidget;
    if (trimmed.startsWith(assetScheme)) {
      imageWidget = Image.asset(
        trimmed.substring(assetScheme.length),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
        frameBuilder: expressiveImageFrameBuilder,
        errorBuilder: errorBuilder,
      );
    } else if (isNetwork) {
      imageWidget = Image.network(
        trimmed,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
        frameBuilder: expressiveImageFrameBuilder,
        errorBuilder: errorBuilder,
      );
    } else {
      imageWidget = Image.file(
        File(trimmed),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
        frameBuilder: expressiveImageFrameBuilder,
        errorBuilder: errorBuilder,
      );
    }

    final sized = SizedBox(width: width, height: height, child: imageWidget);
    if (radius <= 0) {
      return sized;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: sized);
  }
}

/// 封面加载失败占位图（暗色模式自适应）。
class DiaryCardCoverErrorPlaceholder extends StatelessWidget {
  const DiaryCardCoverErrorPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: FaIcon(
        FontAwesomeIcons.image,
        size: 20,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

/// 封面的共享元素来源：点按卡片时从这里抓取已绘制的封面画面，预览页头图
/// 以它为落点。[borderRadius] 是封面在卡片上的可见圆角，飞行从同样的形状
/// 起步。[anchor] 为 null（如设置页预览）时不参与共享元素。
class DiaryCardCoverHero extends StatelessWidget {
  const DiaryCardCoverHero({
    super.key,
    required this.diaryId,
    required this.anchor,
    required this.borderRadius,
    required this.child,
  });

  final String diaryId;
  final ImageViewerHeroAnchor? anchor;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anchor = this.anchor;
    if (anchor == null) {
      return child;
    }
    // 只记录封面子树的 context：抓取画面时不会误抓天气图标等其他图片。
    anchor.context = context;
    return ImageViewerHeroSource(
      tag: diaryCoverHeroTag(diaryId),
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// 顶部通栏的多图拼贴：两张时左右平分，三张时左侧大图、右侧上下两张。
/// 共享元素只挂在第一张（即预览页头图）上，由调用方包裹。
class DiaryCardCollage extends StatelessWidget {
  const DiaryCardCollage({
    super.key,
    required this.first,
    required this.others,
    required this.height,
  });

  /// 第一张图（已包好共享元素来源）。
  final Widget first;
  final List<String> others;
  final double height;

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final rest = others.take(2).toList(growable: false);
    final Widget side;
    if (rest.length == 1) {
      side = DiaryCardCoverImage(source: rest.first, height: height, radius: 0);
    } else {
      final tileHeight = (height - _gap) / 2;
      side = Column(
        children: <Widget>[
          DiaryCardCoverImage(source: rest[0], height: tileHeight, radius: 0),
          const SizedBox(height: _gap),
          DiaryCardCoverImage(source: rest[1], height: tileHeight, radius: 0),
        ],
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(flex: rest.length == 1 ? 1 : 2, child: first),
          const SizedBox(width: _gap),
          Expanded(child: side),
        ],
      ),
    );
  }
}
