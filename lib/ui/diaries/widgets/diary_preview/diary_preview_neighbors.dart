import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import 'diary_pager_view.dart';

/// 相邻的一篇：标题（未知时为 null，只显示“上一篇 / 下一篇”）与翻过去的入口。
@immutable
class DiaryPreviewNeighbor {
  const DiaryPreviewNeighbor({required this.title, required this.onOpen});

  final String? title;
  final VoidCallback onOpen;
}

/// 一篇预览在翻页顺序里的位置：顶栏“位置”标题，以及正文末尾的上一篇 /
/// 下一篇。单篇打开时没有这一项（顶栏“位置”退回“日记”）。
@immutable
class DiaryPreviewPaging {
  const DiaryPreviewPaging({
    required this.position,
    required this.positionSemantics,
    this.previous,
    this.next,
  });

  /// 由翻页器的位置构造。[hasMore] 为列表还有没接上的部分（标题带“+”）；
  /// [titleAt] 给出某个序号的标题，还不知道时返回 null。
  factory DiaryPreviewPaging.of(
    AppLocalizations l10n,
    DiaryPagerPosition position, {
    required bool hasMore,
    required String? Function(int index) titleAt,
  }) {
    final number = position.index + 1;
    final count = position.count;
    final onPrevious = position.onPrevious;
    final onNext = position.onNext;
    return DiaryPreviewPaging(
      position: hasMore
          ? l10n.diaryPreviewPositionMore(number, count)
          : l10n.diaryPreviewPosition(number, count),
      positionSemantics: hasMore
          ? l10n.diaryPreviewPositionSemanticsMore(number, count)
          : l10n.diaryPreviewPositionSemantics(number, count),
      previous: onPrevious == null
          ? null
          : DiaryPreviewNeighbor(
              title: titleAt(position.index - 1),
              onOpen: onPrevious,
            ),
      next: onNext == null
          ? null
          : DiaryPreviewNeighbor(
              title: titleAt(position.index + 1),
              onOpen: onNext,
            ),
    );
  }

  final String position;
  final String positionSemantics;
  final DiaryPreviewNeighbor? previous;
  final DiaryPreviewNeighbor? next;

  bool get hasNeighbors => previous != null || next != null;
}

/// 正文末尾的“上一篇 / 下一篇”：两张等宽的小卡片，只有一侧时另一侧留空，
/// 位置与翻页方向一致。底色是正文色的淡淡一层，任何纸色上都看得清。
class DiaryPreviewNeighborCards extends StatelessWidget {
  const DiaryPreviewNeighborCards({
    super.key,
    required this.paging,
    this.textColor,
  });

  final DiaryPreviewPaging paging;

  /// 正文颜色；null 时取主题正文色。
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textColor = this.textColor ?? Theme.of(context).colorScheme.onSurface;
    final previous = paging.previous;
    final next = paging.next;
    // 两张卡片等高（标题一行一张两行时不参差）；子树很小，固有高度的
    // 额外布局可以接受。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: previous == null
                ? const SizedBox.shrink()
                : _NeighborCard(
                    label: l10n.diaryPreviewPrevious,
                    neighbor: previous,
                    textColor: textColor,
                    atEnd: false,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: next == null
                ? const SizedBox.shrink()
                : _NeighborCard(
                    label: l10n.diaryPreviewNext,
                    neighbor: next,
                    textColor: textColor,
                    atEnd: true,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NeighborCard extends StatelessWidget {
  const _NeighborCard({
    required this.label,
    required this.neighbor,
    required this.textColor,
    required this.atEnd,
  });

  final String label;
  final DiaryPreviewNeighbor neighbor;
  final Color textColor;
  final bool atEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = neighbor.title?.trim();
    final shownTitle = title == null
        ? null
        : title.isEmpty
        ? context.l10n.autoT0033
        : title;
    final radius = BorderRadius.circular(16);
    final align = atEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final muted = textColor.withValues(alpha: 0.72);
    final icon = FaIcon(
      atEnd ? FontAwesomeIcons.angleRight : FontAwesomeIcons.angleLeft,
      size: 12,
      color: muted,
    );
    return Semantics(
      button: true,
      label: shownTitle == null ? label : '$label: $shownTitle',
      excludeSemantics: true,
      child: Material(
        color: textColor.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: neighbor.onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: align,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!atEnd) ...<Widget>[icon, const SizedBox(width: 6)],
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                    if (atEnd) ...<Widget>[const SizedBox(width: 6), icon],
                  ],
                ),
                if (shownTitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    shownTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: atEnd ? TextAlign.end : TextAlign.start,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
