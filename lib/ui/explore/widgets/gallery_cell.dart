import 'package:flutter/material.dart';

import '../../../core/services/app_platform.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../models/explore_view_data.dart';

/// 画廊一格被点按 / 长按时的回调：整体下标与格子自己的 context（看图页从
/// 它抓取已绘制的缩略图作为飞入画面）。
typedef GalleryCellTap = void Function(int index, BuildContext cellContext);

/// 网格里的一行格子：从整体下标 [first] 起的 [count] 张，每格 [extent]
/// 见方、间隔 [gap]，左右留 [padding]。
///
/// 一屏可能有几百格（16 列），这里刻意保持轻量：不用 InkWell（每格一套
/// 焦点 / 悬停 / 水波纹状态）、不用 LayoutBuilder，圆角为 0 时不裁切。
/// [interactive] 为 false 时（捏合途中的目标档预览）不挂手势与看图页的
/// 共享元素，避免与正式网格的 Hero 标签重复。
class GalleryCellRow extends StatelessWidget {
  const GalleryCellRow({
    super.key,
    required this.items,
    required this.first,
    required this.count,
    required this.extent,
    required this.gap,
    required this.padding,
    required this.radius,
    required this.decodeExtent,
    required this.interactive,
    this.heroTagOf,
    this.onTap,
    this.onLongPress,
  });

  final List<ExploreMediaItem> items;
  final int first;
  final int count;
  final double extent;
  final double gap;
  final double padding;
  final double radius;

  /// 解码边长（物理像素），见 `GalleryZoom.decodeReference`。
  final int decodeExtent;
  final bool interactive;
  final Object Function(String source)? heroTagOf;
  final GalleryCellTap? onTap;
  final ValueChanged<int>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainer;
    final children = <Widget>[];
    for (var i = 0; i < count; i++) {
      if (i > 0) children.add(SizedBox(width: gap));
      final index = first + i;
      final source = items[index].source;
      children.add(
        SizedBox(
          width: extent,
          height: extent,
          child: GalleryCell(
            source: source,
            extent: extent,
            decodeExtent: decodeExtent,
            radius: radius,
            placeholder: placeholder,
            heroTag: interactive ? heroTagOf?.call(source) : null,
            onTap: interactive && onTap != null
                ? (BuildContext cellContext) => onTap!(index, cellContext)
                : null,
            onLongPress: interactive && onLongPress != null
                ? () => onLongPress!(index)
                : null,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 一格缩略图：按 [decodeExtent] 等比铺满解码（长图顶部对齐），首次解码
/// 淡入；未解码时为占位底色。
class GalleryCell extends StatelessWidget {
  const GalleryCell({
    super.key,
    required this.source,
    required this.extent,
    required this.decodeExtent,
    required this.radius,
    required this.placeholder,
    this.heroTag,
    this.onTap,
    this.onLongPress,
  });

  final String source;
  final double extent;
  final int decodeExtent;
  final double radius;
  final Color placeholder;
  final Object? heroTag;
  final ValueChanged<BuildContext>? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    Widget image = ColoredBox(
      color: placeholder,
      child: CoverCroppedImage(
        image: boundedImageProvider(
          diaryImageProvider(source),
          width: decodeExtent,
          height: decodeExtent,
          cover: true,
        ),
        width: extent,
        height: extent,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
    final borderRadius = BorderRadius.circular(radius);
    if (radius > 0) {
      image = ClipRRect(borderRadius: borderRadius, child: image);
    }
    final tag = heroTag;
    if (tag != null) {
      image = ImageViewerHeroSource(
        tag: tag,
        borderRadius: borderRadius,
        child: image,
      );
    }
    final tap = onTap;
    if (tap == null && onLongPress == null) {
      return image;
    }
    final Widget detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap == null ? null : () => tap(context),
      onLongPress: onLongPress,
      child: image,
    );
    // 桌面上指针悬停显示为可点（手机上没有指针，不多挂一层）。
    return AppPlatform.isDesktop
        ? MouseRegion(cursor: SystemMouseCursors.click, child: detector)
        : detector;
  }
}
