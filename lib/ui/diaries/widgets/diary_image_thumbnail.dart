import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_fallback.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_cover_alignment.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

/// 正文图片的小图显示（图片块 `data.thumbnail == true`）：[extent] 见方
/// （由 [DiaryEmbeddedImage] 按正文列宽或所在那排给出，最大
/// [kDiaryImageThumbnailExtent]，一排三张放得下）、cover 裁切（长图顶部
/// 对齐，经 [CoverCroppedImage]），圆角与微边框同正文图片。点按由外层媒体块
/// 处理，与普通图片相同（只读正文进看图页，编辑页弹出图片菜单）。
///
/// 尺寸固定：一开始就占好方格，解码完成后画面淡入，不会在尺寸读出时把正文
/// 往下推。长图不折叠、不切片——小格子里只露出开头，整张解码一次即可。
///
/// 解码器从编码头取得原图尺寸后按短边铺满方格，不再先额外读取文件头。
/// 横图与竖图都只解码一次，长图仍受统一的边长与像素预算限制。
class DiaryImageThumbnail extends StatelessWidget {
  const DiaryImageThumbnail({
    super.key,
    required this.source,
    required this.provider,
    this.extent = kDiaryImageThumbnailExtent,
    this.heroTag,
  });

  final String source;

  /// 方格边长（逻辑像素）。
  final double extent;

  /// 来源的原始 provider，由 [DiaryEmbeddedImage] 按来源缓存后传入，正文
  /// 重建时缓存键不变，不会重新解码。
  final ImageProvider provider;

  /// 看图页共享元素标签；为 null（编辑页）时不建立 Hero。
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(kDiaryImageThumbnailRadius);
    final pixels = (extent * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ImageViewerHeroSource(
      tag: heroTag,
      borderRadius: radius,
      child: CoverCroppedImage(
        image: boundedImageProvider(
          provider,
          width: pixels,
          height: pixels,
          cover: true,
        ),
        width: extent,
        height: extent,
        // 原图在小格子里缩得很多，low 档的采样会出锯齿。
        filterQuality: FilterQuality.medium,
        // 裁切与描边只包画面：失败时的说明占位按原样铺开，不被挤进小方格。
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return expressiveImageFrameBuilder(
            context,
            ClipRRect(
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
            ),
            frame,
            wasSynchronouslyLoaded,
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            DiaryImageFallback(source: source),
      ),
    );
  }
}

/// 并排的一排小图给出的方格边长（见 `DiaryThumbnailRowView`）：一排的几张
/// 各占一格，按整排的宽度算好后经这里交给每张小图。不在一排里时
/// [DiaryEmbeddedImage] 按自己的可用宽度算出同一个边长。
class DiaryThumbnailExtent extends InheritedWidget {
  const DiaryThumbnailExtent({
    super.key,
    required this.extent,
    required super.child,
  });

  final double extent;

  static double? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiaryThumbnailExtent>()
      ?.extent;

  @override
  bool updateShouldNotify(DiaryThumbnailExtent oldWidget) =>
      oldWidget.extent != extent;
}
