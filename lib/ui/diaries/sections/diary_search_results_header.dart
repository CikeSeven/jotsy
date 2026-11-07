import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../models/diary_search_preferences.dart';

/// 搜索结果上方的一行（DESIGN.md §5.33）：左侧“共 N 篇”，右侧排序菜单
/// （三项单选，`ExpressiveMenuAnchor`，当前项带勾）。
///
/// 计数还没到时（新条件的第一次查询）左侧留空、行高不变，结果不跳动。
class DiarySearchResultsHeader extends StatelessWidget {
  const DiarySearchResultsHeader({
    super.key,
    required this.count,
    required this.sort,
    required this.onSortChanged,
  });

  final int? count;
  final DiarySearchSort sort;
  final ValueChanged<DiarySearchSort> onSortChanged;

  static String sortLabel(AppLocalizations l10n, DiarySearchSort sort) =>
      switch (sort) {
        DiarySearchSort.updatedDesc => l10n.diarySearchSortUpdated,
        DiarySearchSort.createdDesc => l10n.diarySearchSortNewest,
        DiarySearchSort.createdAsc => l10n.diarySearchSortOldest,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = this.count;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: <Widget>[
          Expanded(
            child: count == null
                ? const SizedBox.shrink()
                : Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.diarySearchResultCount(count),
                      key: const ValueKey<String>('search_result_count'),
                      style: AppPageBackdrop.onBackgroundTextStyle(
                        context,
                        theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
          ExpressiveMenuAnchor(
            menuChildren: <Widget>[
              for (final option in DiarySearchSort.values)
                ExpressiveMenuItem(
                  selected: option == sort,
                  onPressed: () => onSortChanged(option),
                  child: Text(sortLabel(l10n, option)),
                ),
            ],
            builder:
                (
                  BuildContext context,
                  ExpressiveMenuAnchorState menu,
                  Widget? _,
                ) => Tooltip(
                  message: l10n.diarySearchSortTooltip,
                  child: TextButton.icon(
                    key: const ValueKey<String>('search_sort_button'),
                    onPressed: menu.toggle,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowDownWideShort,
                      size: 13,
                    ),
                    label: Text(sortLabel(l10n, sort)),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
