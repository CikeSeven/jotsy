import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/image_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../../widgets/image_viewer_page.dart';
import '../../../widgets/long_image/long_image_cover_alignment.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../../viewmodels/diary_comment_image_layout.dart';
import '../diary_image_source.dart';

/// 一条留言附带的图片：相册式拼贴（版式见 [DiaryCommentImageLayout]），
/// 点按一格经 [openImageViewer] 从这一格飞入看图页，可在这组图片里左右翻。
///
/// - 每格按 cover 裁切、长图顶部对齐（[CoverCroppedImage]），解码经
///   [boundedImageProvider] 按格子大小缩小；
/// - 1 张时按原图比例显示：尺寸只经 [ImageDimensions] 读文件头，已缓存时
///   第一帧就是正确比例，否则先按 4:3 占位、读出后换成原比例；
/// - 读不出的图片（文件缺失、桌面上解不了的格式）显示一个图片图标占位，
///   点按仍打开看图页（那里同样给出失败提示）；
/// - [interactive] 为 false 时（设置页的样式预览）不可点、不建共享元素；
///   长按不在这里处理，交给外层条目的留言菜单。
class DiaryCommentImages extends StatefulWidget {
  const DiaryCommentImages({
    super.key,
    required this.commentId,
    required this.images,
    this.interactive = true,
  });

  /// 所属留言的业务 id：共享元素标签按它区分，同一页里多条留言互不冲突。
  final String commentId;

  /// 图片路径（本地文件；样式预览里为 `asset:` 示例图）。
  final List<String> images;

  final bool interactive;

  @override
  State<DiaryCommentImages> createState() => _DiaryCommentImagesState();
}

class _DiaryCommentImagesState extends State<DiaryCommentImages> {
  /// 1 张图时的原图比例（宽 / 高）；未知为 null。
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(DiaryCommentImages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length ||
        (widget.images.isNotEmpty &&
            oldWidget.images.first != widget.images.first)) {
      _aspect = null;
      _resolveAspect();
    }
  }

  /// 只在 1 张图时需要比例。缓存命中同步取得，不会先画一帧 4:3；否则异步
  /// 读文件头，读完（且仍是同一张图）再重建。
  void _resolveAspect() {
    if (widget.images.length != 1) return;
    final source = widget.images.single;
    if (ImageDimensions.isResolved(source)) {
      _aspect = _aspectOf(ImageDimensions.peek(source));
      return;
    }
    ImageDimensions.resolve(source).then((Size? size) {
      if (!mounted ||
          widget.images.length != 1 ||
          widget.images.single != source) {
        return;
      }
      final aspect = _aspectOf(size);
      if (aspect != null) setState(() => _aspect = aspect);
    });
  }

  static double? _aspectOf(Size? size) =>
      size == null || size.height <= 0 ? null : size.width / size.height;

  Object _heroTag(int index) =>
      ImageViewerHeroTag('diary_comment', '${widget.commentId}#$index');

  void _open(int index, BuildContext tileContext) {
    openImageViewer(
      context,
      items: <ImageViewerItem>[
        for (final source in widget.images) ImageViewerItem(source: source),
      ],
      initialIndex: index,
      hero: ImageViewerHero.capture(tileContext, tag: _heroTag(index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final layout = DiaryCommentImageLayout.compute(
          count: images.length,
          availableWidth: constraints.maxWidth,
          singleAspect: _aspect,
        );
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: <Widget>[
                for (final tile in layout.tiles)
                  Positioned.fromRect(
                    rect: tile.rect,
                    child: _ImageTile(
                      source: images[tile.index],
                      tile: tile,
                      label: context.l10n.diaryCommentImageLabel(
                        tile.index + 1,
                        images.length,
                      ),
                      heroTag: widget.interactive ? _heroTag(tile.index) : null,
                      onTap: widget.interactive
                          ? (BuildContext tileContext) =>
                                _open(tile.index, tileContext)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 一格图片：圆角裁切的缩略图，叠一层透明 Material 画水波纹；有更多图片
/// 没排出来时再叠“+N”。
class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.source,
    required this.tile,
    required this.label,
    required this.heroTag,
    required this.onTap,
  });

  final String source;
  final DiaryCommentImageTile tile;
  final String label;
  final Object? heroTag;
  final void Function(BuildContext tileContext)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final rect = tile.rect;
    // 只按格子的长边给解码目标（另一边交给安全上限、按比例解码），cover
    // 裁切后不发糊；与探索页缩略图同一做法。
    final wide = rect.width >= rect.height;
    final extent = ((wide ? rect.width : rect.height) * dpr).round();
    final image = ClipRRect(
      borderRadius: tile.radius,
      child: ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: CoverCroppedImage(
          image: boundedImageProvider(
            diaryImageProvider(source),
            width: wide ? extent : null,
            height: wide ? null : extent,
          ),
          width: rect.width,
          height: rect.height,
          errorBuilder: (_, _, _) => Center(
            child: FaIcon(
              FontAwesomeIcons.image,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    final overflow = tile.overflow;
    return Semantics(
      button: onTap != null,
      image: true,
      label: overflow > 0 ? '$label +$overflow' : label,
      excludeSemantics: true,
      child: Builder(
        // 格子自己的 context：点按时从这里抓取已绘制的缩略图作为飞入画面。
        builder: (BuildContext tileContext) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ImageViewerHeroSource(
              tag: heroTag,
              borderRadius: tile.radius,
              child: image,
            ),
            if (overflow > 0) _OverflowBadge(count: overflow, tile: tile),
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: tile.radius,
                  ),
                  onTap: () => onTap!(tileContext),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 最后一格上的“+N”：半透明的反色遮罩上写数字，照片仍隐约可见。
class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({required this.count, required this.tile});

  final int count;
  final DiaryCommentImageTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.56),
        borderRadius: tile.radius,
      ),
      child: Center(
        child: Text(
          '+$count',
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
