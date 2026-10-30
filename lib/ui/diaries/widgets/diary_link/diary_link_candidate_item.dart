import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notebooks/widgets/notebook_cover_tile.dart';
import '../../../widgets/long_image/long_image_cover_alignment.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../../models/diary_image_embed_data.dart';
import '../../models/diary_link_candidate.dart';
import '../diary_editor/diary_caret_menu.dart';

/// `@` 菜单与链接对话框里的一行候选：小图 + 名称 + 日期。
///
/// 日记有图时用第一张图（cover 裁切），未解封的胶囊用沙漏，其余用书本
/// 图标；日记本用书架上的小封面。行的外形与 `/` 菜单相同
/// （[DiaryCaretMenuItem]，点按不取得焦点）。
class DiaryLinkCandidateItem extends StatelessWidget {
  const DiaryLinkCandidateItem({
    super.key,
    required this.candidate,
    required this.onTap,
    this.highlighted = false,
  });

  final DiaryLinkCandidate candidate;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final createdAt = candidate.createdAt;
    return DiaryCaretMenuItem(
      onTap: onTap,
      highlighted: highlighted,
      leading: _leading(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (createdAt != null)
            Text(
              DateFormat.yMMMd(context.l10n.localeName).format(createdAt),
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _leading(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notebook = candidate.notebook;
    if (candidate.kind == DiaryLinkKind.notebook && notebook != null) {
      return FittedBox(
        child: NotebookCoverTile.mini(
          icon: notebook.icon,
          color: notebook.color,
          coverPath: notebook.coverPath,
          style: notebook.coverStyle,
          closed: notebook.isClosed,
        ),
      );
    }
    final icon = FaIcon(
      candidate.sealed
          ? FontAwesomeIcons.hourglassHalf
          : FontAwesomeIcons.bookOpen,
      size: 14,
      color: colors.onSecondaryContainer,
    );
    final cover = candidate.cover;
    if (cover == null) return icon;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox.expand(
      child: CoverCroppedImage(
        image: boundedImageProvider(
          resolveDiaryImageProvider(cover),
          width: (32 * dpr).round(),
        ),
        errorBuilder: (_, _, _) => Center(child: icon),
      ),
    );
  }
}
