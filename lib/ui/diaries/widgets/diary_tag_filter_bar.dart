import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import 'tag_filter_chip.dart';

class DiaryTagFilterBar extends StatelessWidget {
  const DiaryTagFilterBar({
    super.key,
    required this.tags,
    required this.selectedTagFilterIds,
    required this.onToggleTagFilter,
    required this.onClearTagFilters,
  });

  final List<Tag> tags;
  final Set<int> selectedTagFilterIds;
  final void Function(int tagId, bool selected) onToggleTagFilter;
  final VoidCallback onClearTagFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = selectedTagFilterIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tags.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return TagFilterChip(
                label: '全部',
                leading: FaIcon(FontAwesomeIcons.filter, size: 12),
                selected: !hasSelection,
                selectedColor: colorScheme.primaryContainer,
                selectedForegroundColor: colorScheme.onPrimaryContainer,
                unselectedColor: colorScheme.surfaceContainerHigh,
                unselectedForegroundColor: colorScheme.onSurfaceVariant,
                onTap: onClearTagFilters,
              );
            }

            final tag = tags[index - 1];
            final selected = selectedTagFilterIds.contains(tag.id);
            return TagFilterChip(
              label: tag.name,
              colorDot: Color(tag.color),
              selected: selected,
              selectedColor: colorScheme.primaryContainer,
              selectedForegroundColor: colorScheme.onPrimaryContainer,
              unselectedColor: colorScheme.surfaceContainerHigh,
              unselectedForegroundColor: colorScheme.onSurface,
              onTap: () => onToggleTagFilter(tag.id, !selected),
            );
          },
        ),
      ),
    );
  }
}
