import 'package:flutter/material.dart';

import 'explore_bar.dart';
import 'explore_reveal.dart';

/// 分布条的一行：行首（emoji、图标或文字）、条长与行尾文字。
@immutable
class ExploreShareRow {
  const ExploreShareRow({
    required this.leading,
    required this.count,
    required this.share,
    required this.trailing,
    this.onTap,
  });

  final Widget leading;

  /// 条长按 [count] 相对最多的一行。
  final int count;

  /// 占比（0~1）：决定条的不透明度档位（[ExploreChartColors.alphaForShare]）。
  final double share;
  final String trailing;
  final VoidCallback? onTap;
}

/// 一组横向分布条（心情分布、标签排行、常去地点、天气……）：每行一条 12dp
/// 横条，长度相对最多的那一行，颜色按占比取强调色的四档不透明度；首次出现
/// 时依次生长（[reveal]）。给了 [ExploreShareRow.onTap] 的行整行可点。
class ExploreShareBars extends StatelessWidget {
  const ExploreShareBars({
    super.key,
    required this.rows,
    required this.reveal,
    this.color,
    this.leadingWidth = 28,
    this.trailingWidth = 72,
  });

  final List<ExploreShareRow> rows;
  final double reveal;

  /// 条的颜色（不透明度另按占比分档）；默认 `primary`。
  final Color? color;
  final double leadingWidth;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = color ?? scheme.primary;
    var maxCount = 1;
    for (final row in rows) {
      if (row.count > maxCount) maxCount = row.count;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++)
          _buildRow(context, theme, scheme, base, rows[i], i, maxCount),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    Color base,
    ExploreShareRow row,
    int index,
    int maxCount,
  ) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(width: leadingWidth, child: row.leading),
          Expanded(
            child: ExploreBar(
              fraction:
                  row.count /
                  maxCount *
                  ExploreReveal.staggered(reveal, index, rows.length),
              color: base.withValues(
                alpha: ExploreChartColors.alphaForShare(row.share),
              ),
              track: ExploreChartColors.track(scheme),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: trailingWidth,
            child: Text(
              row.trailing,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
    final onTap = row.onTap;
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}
