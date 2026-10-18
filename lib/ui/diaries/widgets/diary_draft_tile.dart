import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/expressive_state_blend.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../viewmodels/diary_draft_list_item.dart';
import 'diary_card/diary_card_cover.dart';
import 'diary_image_source.dart';

/// 一份草稿的列表行：标题、摘要、“编辑于 … · N 字”，有封面或图片时右侧显示
/// 缩略图。草稿箱页与新建时的草稿选择面板共用。
///
/// [compact] 用于选择面板：摘要只留一行，行距更紧。[selectionMode] 时左侧
/// 出现勾选框，选中态的底色与描边经 [ExpressiveStateBlend] 补间。只负责展示
/// 与点按回调，不读写数据。
class DiaryDraftTile extends StatelessWidget {
  const DiaryDraftTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
    this.selectionMode = false,
    this.selected = false,
    this.now,
  });

  static const double _thumbnailSize = 56;
  static const double _compactThumbnailSize = 44;

  final DiaryDraftListItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool selectionMode;
  final bool selected;

  /// 计算“今天 / 同年”的参照时间；测试注入固定时间，默认取当前时间。
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final title = item.displayTitle ?? l10n.autoT0033;
    final words = NumberFormat.decimalPattern(
      l10n.localeName,
    ).format(item.wordCount);
    final footer = l10n.diaryDraftEditedAt(
      l10n.formatPreciseDateTime(item.updatedAt, now ?? DateTime.now()),
      words,
    );
    final thumbnail = item.thumbnail;
    final secondary = colorScheme.onSurfaceVariant;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: compact ? AppSpacing.m : AppSpacing.l,
      ),
      child: Row(
        children: <Widget>[
          if (selectionMode) ...<Widget>[
            // 勾选框只是选中态的显示，点按整行切换，避免两处点击区域重叠。
            ExcludeSemantics(
              child: IgnorePointer(
                child: Checkbox(value: selected, onChanged: (_) {}),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: item.displayTitle == null ? secondary : null,
                  ),
                ),
                if (item.snippet.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    item.snippet,
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
            _DraftThumbnail(
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

/// 草稿缩略图：按显示尺寸保持比例缩小解码，cover 裁切（长图顶部对齐），
/// 首次解码淡入，加载失败显示占位图标。
class _DraftThumbnail extends StatelessWidget {
  const _DraftThumbnail({required this.source, required this.size});

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
