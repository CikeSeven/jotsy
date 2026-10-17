import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_scroll_range.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_tiles_view.dart';

/// 正文里的长图：折叠为宽 : 高 = 2 : 3 的盒子，只露出顶部，右下角标“长图”。
///
/// 长截图按列宽铺满会占七八屏，正文被它截断；折叠后与一张竖拍照片差不多高，
/// 只读页点按经看图页按屏宽从顶部开始竖向滚动阅读，编辑页点按仍是图片菜单
/// （缩放 / 复制 / 删除）。
///
/// - 宽度：可用宽度、缩放菜单写入的上限 [bounds] 与原图像素宽三者取小（与普通
///   图片一样不放大小图）；高度由比例决定，[bounds] 的高度上限同样生效；
/// - 内容：分片拼回原图比例后顶部对齐、超出部分裁掉，只构建落在折叠范围内的
///   分片；分片未就绪（首次切片中）时只显示占位底色；
/// - 圆角、描边与普通正文图片一致；来源 Hero 包住整个盒子，看图页从这里展开。
class DiaryLongImageFold extends StatelessWidget {
  const DiaryLongImageFold({
    super.key,
    required this.size,
    required this.tiles,
    required this.decodeWidth,
    required this.providerOf,
    this.bounds = const BoxConstraints(),
    this.heroTag,
  });

  /// 折叠盒子的高宽比。
  static const double foldHeightFactor = 1.5;

  /// 原图像素尺寸。
  final Size size;

  /// 分片；null 表示还在切片。
  final LongImageTiles? tiles;
  final int decodeWidth;
  final ImageProvider Function(String path) providerOf;
  final BoxConstraints bounds;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final tiles = this.tiles;
    // 折叠盒子露出原图顶部这么高的比例（宽 × 1.5 / 原图高）。
    final visibleEnd = math.min(
      1.0,
      size.width * foldHeightFactor / size.height,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(bounds.maxWidth, size.width),
        maxHeight: bounds.maxHeight,
      ),
      child: ImageViewerHeroSource(
        tag: heroTag,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: AspectRatio(
          aspectRatio: 1 / foldHeightFactor,
          child: DiaryLongImageFrame(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (tiles != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AspectRatio(
                      aspectRatio: size.width / size.height,
                      child: LongImageTilesView(
                        tiles: tiles,
                        decodeWidth: decodeWidth,
                        visibleEnd: visibleEnd,
                        providerOf: providerOf,
                      ),
                    ),
                  ),
                const PositionedDirectional(
                  end: 8,
                  bottom: 8,
                  child: _LongImagePill(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 正文里完整展开的长图（预览页“长图显示：完整显示”）：按原图比例铺满列宽，
/// 随滚动只构建视口附近的分片（[LongImageScrollRange]），不带“长图”角标。
///
/// - 宽度规则与折叠盒子相同（列宽、缩放上限、原图宽三者取小）；缩放菜单写入
///   的高度上限在这里不生效：上游滑条总会顺带写入一个屏幕高的高度，按它限高
///   会把“完整显示”的长图缩成一条；
/// - 不做共享元素：整张图可能比屏幕高好几倍，从这样的盒子飞进看图页只会是
///   一闪而过的巨大缩放，点按后看图页直接淡入、从顶部开始。
class DiaryLongImageFull extends StatelessWidget {
  const DiaryLongImageFull({
    super.key,
    required this.size,
    required this.tiles,
    required this.decodeWidth,
    required this.providerOf,
    this.bounds = const BoxConstraints(),
  });

  /// 原图像素尺寸。
  final Size size;

  /// 分片；null 表示还在切片。
  final LongImageTiles? tiles;
  final int decodeWidth;
  final ImageProvider Function(String path) providerOf;
  final BoxConstraints bounds;

  @override
  Widget build(BuildContext context) {
    final tiles = this.tiles;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(bounds.maxWidth, size.width),
      ),
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: DiaryLongImageFrame(
          child: tiles == null
              ? const SizedBox.expand()
              : LongImageScrollRange(
                  builder: (BuildContext context, double start, double end) =>
                      LongImageTilesView(
                        tiles: tiles,
                        decodeWidth: decodeWidth,
                        visibleStart: start,
                        visibleEnd: end,
                        providerOf: providerOf,
                      ),
                ),
        ),
      ),
    );
  }
}

/// 正文长图的外框：与普通正文图片同样的 16dp 圆角与微边框，分片解码前透出
/// `surfaceContainerHighest` 占位底色。
class DiaryLongImageFrame extends StatelessWidget {
  const DiaryLongImageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.fromBorderSide(
            ExpressiveSurfaces.cardBorderSide(colors),
          ),
        ),
        child: ColoredBox(color: colors.surfaceContainerHighest, child: child),
      ),
    );
  }
}

/// “长图”小胶囊：表面色半透明底（与“这天拍的照片”的时间胶囊同一做法），
/// 明暗主题下都与图片拉开对比。
class _LongImagePill extends StatelessWidget {
  const _LongImagePill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          context.l10n.diaryLongImageBadge,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
