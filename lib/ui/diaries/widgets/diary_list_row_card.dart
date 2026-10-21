import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/expressive_state_blend.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import 'diary_card/diary_card_cover.dart';
import 'diary_image_source.dart';

/// 草稿箱与回收站共用的可多选列表行：标题、摘要、底行小字，右侧可选缩略图。
///
/// 卡片表面 + 0.8dp 微边框、16dp 圆角；[selectionMode] 时左侧勾选框横向展开
/// 出现（`fast`，退出时收回），选中态的底色与描边经 [ExpressiveStateBlend]
/// 补间到 `secondaryContainer` / `secondary`。[compact] 用于面板：摘要只留
/// 一行、行距更紧。只负责展示与点按回调，展示什么（含私密、未解封胶囊时
/// 隐去摘要与缩略图）由调用方决定。
class DiaryListRowCard extends StatelessWidget {
  const DiaryListRowCard({
    super.key,
    required this.title,
    required this.footer,
    required this.onTap,
    this.titleMuted = false,
    this.titleIcon,
    this.snippet = '',
    this.thumbnail,
    this.onLongPress,
    this.compact = false,
    this.selectionMode = false,
    this.selected = false,
  });

  static const double _thumbnailSize = 56;
  static const double _compactThumbnailSize = 44;

  final String title;

  /// 标题是占位（如“无标题”）时以 `onSurfaceVariant` 显示。
  final bool titleMuted;

  /// 标题前的小图标（如私密日记的锁）。
  final FaIconData? titleIcon;

  /// 单行化的摘要；为空时不占行。
  final String snippet;
  final String footer;

  /// 缩略图路径（封面或正文第一张图）；null 时不显示。
  final String? thumbnail;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final secondary = colorScheme.onSurfaceVariant;
    final titleIcon = this.titleIcon;
    final thumbnail = this.thumbnail;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: compact ? AppSpacing.m : AppSpacing.l,
      ),
      child: Row(
        children: <Widget>[
          // 勾选框横向展开而不是一帧挤进来：右侧文字随宽度平滑让位。首帧
          // 不播放（回收站一打开就带勾选框）。
          AnimatedSize(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            curve: ExpressiveMotion.effects,
            alignment: AlignmentDirectional.centerStart,
            child: selectionMode
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    // 勾选框只是选中态的显示，点按整行切换，避免两处点击区域
                    // 重叠。
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Checkbox(value: selected, onChanged: (_) {}),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (titleIcon != null) ...<Widget>[
                      FaIcon(titleIcon, size: 13, color: secondary),
                      const SizedBox(width: AppSpacing.s),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: titleMuted ? secondary : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (snippet.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    snippet,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
          if (thumbnail != null) ...<Widget>[
            const SizedBox(width: AppSpacing.m),
            _RowThumbnail(
              source: thumbnail,
              size: compact ? _compactThumbnailSize : _thumbnailSize,
            ),
          ],
        ],
      ),
    );

    final radius = BorderRadius.circular(AppRadii.input);
    return ExpressiveStateBlend(
      active: selected,
      builder: (BuildContext context, double t, Widget? child) {
        return Material(
          color: Color.lerp(
            ExpressiveSurfaces.cardColor(colorScheme),
            colorScheme.secondaryContainer,
            t,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: Color.lerp(
                ExpressiveSurfaces.cardBorderColor(colorScheme),
                colorScheme.secondary,
                t,
              )!,
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Semantics(
        selected: selectionMode ? selected : null,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
      ),
    );
  }
}

/// 行尾缩略图：按显示尺寸保持比例缩小解码，cover 裁切（长图顶部对齐），
/// 首次解码淡入，加载失败显示占位图标。
class _RowThumbnail extends StatelessWidget {
  const _RowThumbnail({required this.source, required this.size});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final extent = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.m),
      child: SizedBox.square(
        dimension: size,
        child: CoverCroppedImage(
          // 只限宽度（另一边由 boundedImageProvider 限在纹理上限内）：同时限高
          // 会让长图按比例缩成细条，再裁成正方形时发虚。宽度取 2 倍，横图裁
          // 成正方形后高度也够用。
          image: boundedImageProvider(
            diaryImageProvider(source),
            width: extent * 2,
          ),
          errorBuilder: (context, _, _) =>
              const DiaryCardCoverErrorPlaceholder(),
        ),
      ),
    );
  }
}
