// 设备详情页的“同步记录”时间线（DESIGN.md §5.28“设备详情页”）。
//
// 每条：左侧 12 宽节点列（10dp 圆点：成功 `primary`、失败 `error`、首次同步
// `outline`；圆点下一条 2dp `outlineVariant` 竖线连到下一条，最后一条没有），
// 右侧第一行“时间”14.5 / w600 + 右侧灰字（自动同步为“自动”，否则为用时），
// 第二行成功为等宽数字的摘要“↓ 收到 N 篇 · ↑ 发出 N 篇 · 媒体 N MB”（没有
// 媒体时省略那一段），失败为 `error` 色短原因；有冲突副本时再加一枚
// `tertiaryContainer` 小胶囊。最多显示最近 20 条（控制器给出的顺序即新的
// 在前）。没有记录时卡片里只有一行灰字。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_card_surface.dart';
import '../models/lan_sync_session_view.dart';
import '../widgets/lan_sync_labels.dart';
import '../widgets/lan_sync_section_header.dart';

/// 时间线最多显示的条数。
const int kLanSyncHistoryLimit = 20;

class LanSyncHistorySection extends StatelessWidget {
  const LanSyncHistorySection({
    super.key,
    required this.history,
    required this.now,
  });

  final List<LanSyncHistoryEntryView> history;

  /// 换算时间文字（今天只写时分）的当前时间。
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final entries = history.take(kLanSyncHistoryLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LanSyncSectionHeader(title: l10n.lanSyncHistoryTitle),
        AppCardSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.lanSyncHistoryEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < entries.length; i++)
                        LanSyncHistoryEntry(
                          entry: entries[i],
                          now: now,
                          last: i == entries.length - 1,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// 时间线里的一条。
class LanSyncHistoryEntry extends StatelessWidget {
  const LanSyncHistoryEntry({
    super.key,
    required this.entry,
    required this.now,
    required this.last,
  });

  final LanSyncHistoryEntryView entry;
  final DateTime now;

  /// 最后一条：节点下不画竖线。
  final bool last;

  static const double _dot = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final reason = entry.failureReason;
    final nodeColor = reason != null
        ? colors.error
        : (entry.firstSync ? colors.outline : colors.primary);
    final duration = entry.duration;
    final String? aside = entry.automatic
        ? l10n.lanSyncHistoryAutomatic
        : (duration == null
              ? null
              : l10n.lanSyncHistoryDuration(lanSyncDurationSeconds(duration)));
    final caption = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.onSurfaceVariant,
    );
    final summary = <String>[
      l10n.lanSyncHistoryReceived(entry.receivedDiaries),
      l10n.lanSyncHistorySent(entry.sentDiaries),
      if (entry.mediaBytes > 0)
        l10n.lanSyncHistoryMedia(l10n.formatByteSize(entry.mediaBytes)),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 12,
            child: Column(
              children: <Widget>[
                // 圆点与第一行文字的中线对齐（14.5 字号的行高约 20）。
                const SizedBox(height: 5),
                Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: colors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.formatPreciseDateTime(entry.at, now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (aside != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(aside, style: caption),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (reason != null)
                    Text(
                      lanSyncSyncReasonText(l10n, reason),
                      style: caption?.copyWith(color: colors.error),
                    )
                  else
                    Text(
                      summary,
                      style: caption?.copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  if (entry.conflictCopies > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.lanSyncHistoryConflicts(entry.conflictCopies),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
