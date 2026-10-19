import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../notebooks/widgets/notebook_cover_parts.dart';
import '../models/calendar_marker_filter.dart';

/// 日历卡片里的筛选条：筛选生效时显示当前条件（心情 emoji、彩色 # 标签
/// 名、日记本图标 + 名字），点按重新打开筛选面板，右侧一键清除。
///
/// 输入：当前筛选、全部标签与可筛选的日记本（取名称、颜色与图标，找不到的
/// id 不显示）；无副作用。
/// 只在筛选生效时出现：日期格与统计都只算符合条件的日记，不提示的话很容易
/// 误以为“这些天没写”。
class CalendarFilterBar extends StatelessWidget {
  const CalendarFilterBar({
    super.key,
    required this.filter,
    required this.tags,
    this.notebooks = const <NotebookView>[],
    required this.onTap,
    required this.onClear,
  });

  final CalendarMarkerFilter filter;
  final List<Tag> tags;
  final List<NotebookView> notebooks;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedTags = <Tag>[
      for (final tag in tags)
        if (filter.tagIds.contains(tag.id)) tag,
    ];
    final selectedNotebooks = <NotebookView>[
      for (final notebook in notebooks)
        if (filter.notebookIds.contains(notebook.id)) notebook,
    ];
    final moods = filter.moods.toList(growable: false);
    final description = <String>[
      ...moods,
      for (final tag in selectedTags) '#${tag.name}',
      for (final notebook in selectedNotebooks) notebook.name,
    ].join(' ');
    return Material(
      color: colorScheme.primary.withValues(
        alpha: colorScheme.brightness == Brightness.light ? 0.08 : 0.14,
      ),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const SizedBox(width: AppSpacing.m),
            FaIcon(
              FontAwesomeIcons.filter,
              size: 11,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Semantics(
                label: '${l10n.calendarFilterActive} $description',
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      for (final mood in moods) TextSpan(text: '$mood '),
                      for (final tag in selectedTags) ...<InlineSpan>[
                        TextSpan(
                          text: '#',
                          style: TextStyle(
                            color: Color(tag.color),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: '${tag.name} '),
                      ],
                      for (final notebook in selectedNotebooks) ...<InlineSpan>[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: FaIcon(
                              notebook.icon.data,
                              size: 11,
                              color: notebookAccentColors(
                                notebook.color,
                                colorScheme,
                              ).onContainer,
                            ),
                          ),
                        ),
                        TextSpan(text: '${notebook.name} '),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.calendarFilterClear,
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: FaIcon(
                FontAwesomeIcons.xmark,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
