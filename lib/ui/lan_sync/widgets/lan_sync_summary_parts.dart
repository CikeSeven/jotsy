// 同步完成摘要里的区块（DESIGN.md §5.27“同步完成摘要”）：两列统计卡与
// 冲突副本提示块。只负责画与转发点按，面板骨架在 lan_sync_summary_sheet.dart。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../models/lan_sync_session_summary.dart';
import 'lan_sync_well_color.dart';

/// 一列统计卡：彩色标签（“↓ 收到”为 `tertiary`、“↑ 发出”为 `primary`）、
/// 34 / w800 等宽篇数与下方的 新增 / 更新 / 删除 / 媒体 四行。
///
/// 篇数首次出现时从 0 递增（`long` + `effects`，同 DESIGN §4.3 探索页数字），
/// 等宽数字避免递增时宽度抖动；读屏只读最终值；减少动画时直接显示。
/// 底色经 [lanSyncWellColor]（暗色面板本身就是 surfaceContainerLow）。
class LanSyncSummaryStatCard extends StatelessWidget {
  const LanSyncSummaryStatCard({
    super.key,
    required this.label,
    required this.accent,
    required this.counts,
  });

  final String label;
  final Color accent;
  final LanSyncChangeCounts counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    const tabular = <FontFeature>[FontFeature.tabularFigures()];
    final rowLabel = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.onSurfaceVariant,
    );
    final rowValue = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
      fontFeatures: tabular,
    );
    Widget row(String name, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          // 标签只有两三个字，按自身宽度靠左；值占用剩下的宽度靠右，放不下
          // 时整体等比缩小（“4 个 · 3.0 MB”截掉一半就没用了）。
          Text(name, style: rowLabel),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(value, maxLines: 1, style: rowValue),
            ),
          ),
        ],
      ),
    );
    final diaries = counts.diaries;
    final media = counts.mediaCount == 0
        ? '0'
        : l10n.lanSyncSummaryMediaValue(
            counts.mediaCount,
            l10n.formatByteSize(counts.mediaBytes),
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lanSyncWellColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: '$diaries ${l10n.lanSyncSummaryDiaryUnit(diaries)}',
            // 四位数以上的篇数在窄屏的半宽卡片里放不下：整体等比缩小，
            // 不截断数字。
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: diaries.toDouble()),
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.long,
                      ),
                      curve: ExpressiveMotion.effects,
                      builder: (BuildContext context, double value, _) => Text(
                        '${value.round()}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: colors.onSurface,
                          fontFeatures: tabular,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.lanSyncSummaryDiaryUnit(diaries),
                      style: rowLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          row(l10n.lanSyncSummaryAdded, '${counts.added}'),
          row(l10n.lanSyncSummaryUpdated, '${counts.updated}'),
          row(l10n.lanSyncSummaryDeleted, '${counts.deleted}'),
          row(l10n.lanSyncSummaryMedia, media),
        ],
      ),
    );
  }
}

/// 冲突副本提示块：`tertiaryContainer` 20 圆角的说明，下面每条副本一行
/// 卡片色 14 圆角可点（标题 + “原日记保留较新的版本”）。
class LanSyncConflictCopies extends StatelessWidget {
  const LanSyncConflictCopies({
    super.key,
    required this.copies,
    required this.onOpen,
  });

  final List<LanSyncConflictCopy> copies;

  /// 点按一条副本（参数为副本的日记业务 id）。
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    const radius = BorderRadius.all(Radius.circular(14));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.lanSyncSummaryConflicts(copies.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onTertiaryContainer,
            ),
          ),
          for (final copy in copies) ...<Widget>[
            const SizedBox(height: 8),
            Material(
              color: ExpressiveSurfaces.cardColor(colors),
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: () => onOpen(copy.diaryId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              copy.title.trim().isEmpty
                                  ? l10n.lanSyncUntitled
                                  : copy.title.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.lanSyncSummaryConflictHint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
