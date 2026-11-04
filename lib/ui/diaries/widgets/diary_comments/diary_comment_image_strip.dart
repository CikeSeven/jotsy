import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';
import '../../../widgets/expressive_loading_indicator.dart';
import '../../../widgets/long_image/long_image_cover_alignment.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../../viewmodels/diary_comment_image_layout.dart';
import '../diary_image_source.dart';

/// 写留言面板里已添加的图片：一行 [extent] 见方的缩略图（圆角与留言里的
/// 拼贴外圈一致），角上一个移除按钮；正在复制的图片画成带加载指示的占位格。
///
/// 横向滚动（最多 9 张放不下一行），桌面上经 [DesktopHorizontalScroll] 可用
/// 鼠标拖动与 Shift + 滚轮。只负责显示与点按，增删由面板交给
/// `DiaryCommentImagesController`。
class DiaryCommentImageStrip extends StatelessWidget {
  const DiaryCommentImageStrip({
    super.key,
    required this.images,
    required this.pending,
    required this.onRemove,
  });

  /// 缩略图边长。
  static const double extent = 72;

  final List<String> images;

  /// 正在复制的张数，排在已添加的图片之后。
  final int pending;

  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final count = images.length + pending;
    return SizedBox(
      height: extent,
      child: DesktopHorizontalScroll(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int index) =>
              index < images.length
              ? _Thumbnail(
                  key: ValueKey<String>(images[index]),
                  source: images[index],
                  onRemove: () => onRemove(images[index]),
                )
              : const _PendingThumbnail(),
        ),
      ),
    );
  }
}

const BorderRadius _radius = BorderRadius.all(
  Radius.circular(DiaryCommentImageLayout.outerRadius),
);

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({super.key, required this.source, required this.onRemove});

  final String source;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decodeExtent =
        (DiaryCommentImageStrip.extent * MediaQuery.devicePixelRatioOf(context))
            .round();
    return SizedBox.square(
      dimension: DiaryCommentImageStrip.extent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: _radius,
            child: ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: CoverCroppedImage(
                image: boundedImageProvider(
                  diaryImageProvider(source),
                  width: decodeExtent,
                ),
                width: DiaryCommentImageStrip.extent,
                height: DiaryCommentImageStrip.extent,
                errorBuilder: (_, _, _) => Center(
                  child: FaIcon(
                    FontAwesomeIcons.image,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: _RemoveButton(onPressed: onRemove),
          ),
        ],
      ),
    );
  }
}

/// 角上的移除按钮：看得见的是 22dp 的反色小圆，点按区域放大到 36dp，
/// 不必精确点中。
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = context.l10n.diaryCommentImageRemove;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 36,
            child: Align(
              alignment: const AlignmentDirectional(0.35, -0.35),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.inverseSurface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 22,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 11,
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingThumbnail extends StatelessWidget {
  const _PendingThumbnail();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: DiaryCommentImageStrip.extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: _radius,
        ),
        child: Center(
          child: ExpressiveLoadingIndicator(
            size: 32,
            semanticLabel: context.l10n.diaryCommentImageAdding,
          ),
        ),
      ),
    );
  }
}
