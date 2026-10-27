import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/widgets/tag_filter_chip.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../notebooks/widgets/notebook_cover_parts.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/calendar_marker_filter.dart';
import 'calendar_options_controls.dart';

/// 打开日历筛选面板（按心情、标签或日记本）。
///
/// 与显示选项面板同一套交互：点选即生效、面板保持打开，浅遮罩下能看到
/// 网格随筛选变化；下拉或点遮罩关闭。筛选是页面临时状态，由页面经
/// [onChanged] 保存，不写入设置。
Future<void> showCalendarFilterSheet(
  BuildContext context, {
  required CalendarMarkerFilter filter,
  required List<String> moodOptions,
  required ValueChanged<CalendarMarkerFilter> onChanged,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.16),
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => CalendarFilterSheet(
      initialFilter: filter,
      moodOptions: moodOptions,
      onChanged: onChanged,
    ),
  );
}

/// 日历筛选面板内容：心情、标签与日记本三组可多选的胶囊。
///
/// 选中态由面板自己维护（初值取打开时的筛选）：面板是独立路由，打开期间
/// 筛选只能经由面板修改。标签与日记本列表直接 watch [tagListProvider] /
/// [notebooksProvider]，面板打开时新建或删除的也能及时反映。日记本只列
/// [calendarFilterNotebooks] 认可的（普通、非私密），一本都没有时整组隐藏。
class CalendarFilterSheet extends ConsumerStatefulWidget {
  const CalendarFilterSheet({
    super.key,
    required this.initialFilter,
    required this.moodOptions,
    required this.onChanged,
  });

  final CalendarMarkerFilter initialFilter;
  final List<String> moodOptions;
  final ValueChanged<CalendarMarkerFilter> onChanged;

  @override
  ConsumerState<CalendarFilterSheet> createState() =>
      _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends ConsumerState<CalendarFilterSheet> {
  late CalendarMarkerFilter _filter = widget.initialFilter;

  void _update(CalendarMarkerFilter next) {
    if (next == _filter) {
      return;
    }
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tags = ref.watch(tagListProvider).asData?.value ?? const <Tag>[];
    // 日记本功能关闭时隐藏入口，数据保留：不订阅书架，日记本一组不出现。
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final notebooks = notebooksEnabled
        ? calendarFilterNotebooks(
            ref.watch(notebooksProvider).asData?.value ??
                const <NotebookView>[],
          )
        : const <NotebookView>[];
    final filter = _filter;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.calendarFilterTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: filter.isActive
                      ? () => _update(const CalendarMarkerFilter())
                      : null,
                  child: Text(l10n.calendarFilterClear),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.calendarFilterDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsSectionHeader(
              icon: FontAwesomeIcons.faceSmile,
              label: l10n.calendarFilterMoods,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: <Widget>[
                for (final mood in widget.moodOptions)
                  _buildMoodChip(
                    colorScheme,
                    mood,
                    filter.moods.contains(mood),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsSectionHeader(
              icon: FontAwesomeIcons.tag,
              label: l10n.calendarFilterTags,
            ),
            const SizedBox(height: AppSpacing.s),
            if (tags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  l10n.calendarFilterNoTags,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  for (final tag in tags)
                    _buildTagChip(theme, tag, filter.tagIds.contains(tag.id)),
                ],
              ),
            if (notebooks.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.l),
              CalendarOptionsSectionHeader(
                icon: FontAwesomeIcons.book,
                label: l10n.calendarFilterNotebooks,
              ),
              const SizedBox(height: AppSpacing.s),
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  for (final notebook in notebooks)
                    _buildNotebookChip(
                      colorScheme,
                      notebook,
                      filter.notebookIds.contains(notebook.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChip(ColorScheme colorScheme, String mood, bool selected) {
    final isLight = colorScheme.brightness == Brightness.light;
    return TagFilterChip(
      label: mood,
      selected: selected,
      selectedColor: colorScheme.primary.withValues(
        alpha: isLight ? 0.16 : 0.28,
      ),
      selectedForegroundColor: colorScheme.onSurface,
      selectedBorderColor: colorScheme.primary,
      unselectedColor: colorScheme.surfaceContainerHigh,
      unselectedForegroundColor: colorScheme.onSurface,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      animateBorder: true,
      onTap: () => _update(_filter.toggleMood(mood)),
    );
  }

  /// 标签胶囊配色与日记列表的标签筛选条一致（标签色浅底 + 彩色 #）。
  Widget _buildTagChip(ThemeData theme, Tag tag, bool selected) {
    final colorScheme = theme.colorScheme;
    final tagColor = Color(tag.color);
    final isLight = theme.brightness == Brightness.light;
    return TagFilterChip(
      label: tag.name,
      colorDot: tagColor,
      selected: selected,
      selectedColor: tagColor.withValues(alpha: isLight ? 0.22 : 0.36),
      selectedForegroundColor:
          isLight &&
              ThemeData.estimateBrightnessForColor(tagColor) == Brightness.dark
          ? tagColor
          : colorScheme.onSurface,
      selectedBorderColor: tagColor,
      unselectedColor: tagColor.withValues(alpha: isLight ? 0.08 : 0.16),
      unselectedForegroundColor: colorScheme.onSurface,
      unselectedBorderColor: tagColor.withValues(alpha: isLight ? 0.22 : 0.32),
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      animateBorder: true,
      onTap: () => _update(_filter.toggleTag(tag.id)),
    );
  }

  /// 日记本胶囊：本子图标 + 名字，配色取本子的强调色（与书架封面同源），
  /// 选中时为容器色实底。已合上的本子排在最后并略微变淡：它们仍装着日记，
  /// 可以筛选，只是不常用。
  Widget _buildNotebookChip(
    ColorScheme colorScheme,
    NotebookView notebook,
    bool selected,
  ) {
    final accent = notebookAccentColors(notebook.color, colorScheme);
    final isLight = colorScheme.brightness == Brightness.light;
    final chip = TagFilterChip(
      label: notebook.name,
      leading: FaIcon(notebook.icon.data, size: 11),
      selected: selected,
      selectedColor: accent.container,
      selectedForegroundColor: accent.onContainer,
      selectedBorderColor: accent.onContainer,
      unselectedColor: accent.container.withValues(alpha: isLight ? 0.4 : 0.5),
      unselectedForegroundColor: colorScheme.onSurface,
      unselectedBorderColor: accent.onContainer.withValues(
        alpha: isLight ? 0.18 : 0.28,
      ),
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      animateBorder: true,
      onTap: () => _update(_filter.toggleNotebook(notebook.id)),
    );
    if (!notebook.isClosed) {
      return chip;
    }
    return Semantics(
      value: context.l10n.notebookStateClosed,
      child: Opacity(opacity: 0.6, child: chip),
    );
  }
}
