import 'dart:io';

import 'package:flutter/material.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

ImageProvider _fileImage(String path) => FileImage(File(path));

/// 把长图分片按原图比例拼回一整张，铺满自身盒子（盒子比例应等于原图比例）。
///
/// 只构建与可见范围 [visibleStart]～[visibleEnd]（占原图高度的比例，0 为顶、
/// 1 为底）相交的分片，其余分片不解码：正文折叠只露出顶部，看图页随滚动换段。
/// 分片之间在原生侧多切了 2 像素的重叠，后一段画在前一段之上，落在小数坐标
/// 时也不会露出发丝缝。
///
/// 每段按 [decodeWidth] 像素宽保持比例解码（[boundedImageProvider]），解码
/// 完成后淡入；尚未解码的区域透出下层（调用方的占位底色或来源画面）。
class LongImageTilesView extends StatelessWidget {
  const LongImageTilesView({
    super.key,
    required this.tiles,
    required this.decodeWidth,
    this.visibleStart = 0,
    this.visibleEnd = 1,
    this.providerOf = _fileImage,
  });

  final LongImageTiles tiles;
  final int decodeWidth;
  final double visibleStart;
  final double visibleEnd;

  /// 分片路径到图片来源；整张退路的“分片”可能是 `data:` URI，由调用方解析。
  final ImageProvider Function(String path) providerOf;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final height = constraints.maxHeight;
        final total = tiles.height.toDouble();
        final children = <Widget>[];
        for (final tile in tiles.tiles) {
          final start = tile.top / total;
          final end = (tile.top + tile.height) / total;
          if (end < visibleStart || start > visibleEnd) {
            continue;
          }
          children.add(
            Positioned(
              key: ValueKey<String>(tile.path),
              left: 0,
              right: 0,
              top: height * start,
              height: height * (end - start),
              child: Image(
                image: boundedImageProvider(
                  providerOf(tile.path),
                  width: decodeWidth,
                ),
                fit: BoxFit.fill,
                gaplessPlayback: true,
                frameBuilder: expressiveImageFrameBuilder,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}
