import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/widgets/tag_filter_chip.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/notebook_add_filter.dart';
import '../../widgets/desktop_horizontal_scroll.dart';

/// 添加日记页的筛选条：时间（单选：全部 / 最近 30 天 / 今年）在前，用户的
/// 标签（多选）在后，一行横向滚动。
class NotebookAddFilterBar extends StatelessWidget {
  const NotebookAddFilterBar({
    super.key,
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.tags,
    required this.selectedTagIds,
    required this.onToggleTag,
  });

  final NotebookAddTimeFilter timeFilter;
  final ValueChanged<NotebookAddTimeFilter> onTimeFilterChanged;
  final List<Tag> tags;
  final Set<int> selectedTagIds;
  final ValueChanged<int> onToggleTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    // 时间筛选未选中时为玻璃底色（有玻璃描边时描边也用它）；选中色不变。
    final glassField = AppGlassField.of(context);
    Widget timeChip(NotebookAddTimeFilter filter, String label) {
      final selected = timeFilter == filter;
      return TagFilterChip(
        label: label,
        selected: selected,
        selectedColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        selectedBorderColor: scheme.secondary,
        unselectedColor: glassField?.fill ?? scheme.surfaceContainerHigh,
        unselectedForegroundColor: scheme.onSurfaceVariant,
        unselectedBorderColor:
            glassField?.border?.color ?? scheme.outlineVariant,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        animateBorder: true,
        onTap: () => onTimeFilterChanged(filter),
      );
    }

    // 标签与首页标签栏同一套配色（标签色的淡底与描边）。
    Widget tagChip(Tag tag) {
      final selected = selectedTagIds.contains(tag.id);
      final tagColor = Color(tag.color);
      return TagFilterChip(
        label: tag.name,
        colorDot: tagColor,
        selected: selected,
        selectedColor: tagColor.withValues(alpha: isLight ? 0.22 : 0.36),
        selectedForegroundColor: scheme.onSurface,
        selectedBorderColor: tagColor,
        unselectedColor: tagColor.withValues(alpha: isLight ? 0.08 : 0.16),
        unselectedForegroundColor: scheme.onSurface,
        unselectedBorderColor: tagColor.withValues(
          alpha: isLight ? 0.22 : 0.32,
        ),
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        animateBorder: true,
        onTap: () => onToggleTag(tag.id),
      );
    }

    final chips = <Widget>[
      timeChip(NotebookAddTimeFilter.all, l10n.notebookAddFilterAll),
      timeChip(NotebookAddTimeFilter.recent, l10n.notebookAddFilterRecent),
      timeChip(NotebookAddTimeFilter.thisYear, l10n.notebookAddFilterThisYear),
      for (final tag in tags) tagChip(tag),
    ];
    return SizedBox(
      height: 40,
      child: DesktopHorizontalScroll(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
          itemBuilder: (_, index) => Center(child: chips[index]),
        ),
      ),
    );
  }
}

/// 添加日记页的一行：日期眉题、标题（没写标题为“无标题”）与一行摘要，
/// 行尾勾选。已在本子里的行停用并注明；未解封的时间胶囊只显示标题。
class NotebookAddDiaryRow extends StatelessWidget {
  const NotebookAddDiaryRow({
    super.key,
    required this.diary,
    required this.selected,
    required this.alreadyIn,
    required this.onToggle,
  });

  final Diary diary;
  final bool selected;
  final bool alreadyIn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = diary.title.trim();
    final sealed = TimeCapsuleState.fromFields(
      lockedAt: diary.capsuleLockedAt,
      unlockAt: diary.capsuleUnlockAt,
      now: DateTime.now(),
    ).isLocked;
    final excerpt = sealed
        ? ''
        : diary.contentText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final checked = selected || alreadyIn;
    final eyebrow = l10n.formatFullDate(diary.createdAt.toLocal());
    final muted = scheme.onSurfaceVariant;
    // 玻璃时未勾选的行为玻璃底色 + 玻璃描边（随勾选淡出），勾选色不变；
    // 经典时原样。
    final glassField = AppGlassField.of(context);
    final restingSide = glassField?.border ?? BorderSide.none;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Semantics(
        checked: checked,
        enabled: !alreadyIn,
        child: ExpressiveStateBlend(
          active: selected,
          builder: (context, t, child) => Material(
            color: Color.lerp(
              glassField?.fill ??
                  scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              scheme.secondaryContainer,
              t,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.input),
              side: BorderSide.lerp(restingSide, BorderSide.none, t),
            ),
            child: child,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.input),
            onTap: alreadyIn ? null : onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          alreadyIn
                              ? '$eyebrow · ${l10n.notebookAddAlreadyIn}'
                              : eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title.isEmpty ? l10n.autoT0033 : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: alreadyIn ? muted : null,
                          ),
                        ),
                        if (excerpt.isNotEmpty)
                          Text(
                            excerpt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  ExpressiveIconSwap(
                    switchKey: checked,
                    child: FaIcon(
                      checked
                          ? FontAwesomeIcons.solidCircleCheck
                          : FontAwesomeIcons.circle,
                      size: 18,
                      color: alreadyIn
                          ? scheme.outline
                          : checked
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
