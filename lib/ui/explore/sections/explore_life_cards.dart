import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/on_glass.dart';
import '../../widgets/qweather_icon.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../models/explore_view_data.dart';
import '../widgets/charts/explore_bar.dart';
import '../widgets/charts/explore_reveal.dart';
import '../widgets/charts/explore_share_bars.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';
import '../widgets/explore_tag_capsule.dart';

/// 标签：标签云（按次数放大字号）或排行（横条）；点按带着这个标签进入
/// 搜索。跟随统计范围。
class ExploreTagsCard extends StatelessWidget {
  const ExploreTagsCard({super.key, required this.config, required this.tags});

  final ExploreModuleConfig config;
  final List<ExploreTagUsage> tags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final actions = ExploreActionsScope.of(context);
    final style = config.choice(ExploreOptions.tagsStyle);
    var maxCount = 1;
    for (final tag in tags) {
      if (tag.count > maxCount) maxCount = tag.count;
    }
    final total = tags.fold<int>(0, (sum, tag) => sum + tag.count);
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.tags,
              title: l10n.exploreModuleTags,
            ),
            if (tags.isEmpty)
              ExploreInlineHint(message: l10n.autoT0199)
            else if (style == ExploreTagStyle.ranking)
              ExploreShareBars(
                reveal: reveal,
                color: look.accentOf(scheme),
                leadingWidth: 112,
                trailingWidth: 64,
                rows: <ExploreShareRow>[
                  for (final tag in tags)
                    ExploreShareRow(
                      leading: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ExploreTagCapsule(
                            name: tag.name,
                            color: tag.color,
                          ),
                        ),
                      ),
                      count: tag.count,
                      share: total == 0 ? 0 : tag.count / total,
                      trailing: l10n.exploreUnitEntries(tag.count),
                      onTap: () => actions.openTagSearch(tag.id),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final tag in tags)
                    ExploreTagCapsule(
                      name: tag.name,
                      color: tag.color,
                      count: tag.count,
                      scale: 0.92 + 0.3 * (tag.count / maxCount),
                      onTap: () => actions.openTagSearch(tag.id),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 足迹：常去的地点，次数多的在前；每行地点名、篇数与一条细横条，点按按
/// 发表时间新 → 旧翻看在那里写的日记。跟随统计范围。
class ExplorePlacesCard extends StatelessWidget {
  const ExplorePlacesCard({super.key, required this.places});

  final List<ExploreGroupCount> places;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final actions = ExploreActionsScope.of(context);
    final accent = look.accentOf(scheme);
    final maxCount = places.isEmpty ? 1 : places.first.count;
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.locationDot,
              title: l10n.exploreModulePlaces,
            ),
            if (places.isEmpty)
              ExploreInlineHint(message: l10n.explorePlacesEmpty)
            else
              for (var i = 0; i < places.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => actions.openDiary(
                    places[i].diaryIds.first,
                    sequence: places[i].diaryIds,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            FaIcon(
                              FontAwesomeIcons.locationDot,
                              size: 12,
                              color: accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                places[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              l10n.exploreUnitEntries(places[i].count),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ExploreBar(
                          fraction:
                              places[i].count /
                              maxCount *
                              ExploreReveal.staggered(reveal, i, places.length),
                          color: accent.withValues(
                            alpha: ExploreChartColors.alphaForShare(
                              places[i].count / maxCount,
                            ),
                          ),
                          track: ExploreChartColors.track(scheme),
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// 天气：各种天气的次数，图标格（每格图标 + 名称 + 次数）或排行；点按翻看
/// 那种天气下写的日记。跟随统计范围。
class ExploreWeatherCard extends StatelessWidget {
  const ExploreWeatherCard({
    super.key,
    required this.config,
    required this.groups,
  });

  final ExploreModuleConfig config;
  final List<ExploreGroupCount> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final actions = ExploreActionsScope.of(context);
    final style = config.choice(ExploreOptions.weatherStyle);
    final total = groups.fold<int>(0, (sum, group) => sum + group.count);
    Widget icon(ExploreGroupCount group, double size) => QWeatherIcon(
      iconCode: group.iconCode,
      weatherText: group.label,
      size: size,
      fallbackColor: look.accentOf(scheme),
      semanticLabel: group.label.isEmpty
          ? l10n.exploreModuleWeather
          : group.label,
    );
    void open(ExploreGroupCount group) =>
        actions.openDiary(group.diaryIds.first, sequence: group.diaryIds);
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.cloudSun,
              title: l10n.exploreModuleWeather,
            ),
            if (groups.isEmpty)
              ExploreInlineHint(message: l10n.exploreWeatherEmpty)
            else if (style == ExploreWeatherStyle.ranking)
              ExploreShareBars(
                reveal: reveal,
                color: look.accentOf(scheme),
                leadingWidth: 96,
                rows: <ExploreShareRow>[
                  for (final group in groups.take(8))
                    ExploreShareRow(
                      leading: Row(
                        children: <Widget>[
                          icon(group, 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              group.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      count: group.count,
                      share: total == 0 ? 0 : group.count / total,
                      trailing: l10n.exploreUnitEntries(group.count),
                      onTap: () => open(group),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final group in groups.take(12))
                    Material(
                      // 玻璃卡片里改为半透明凹槽色，不留一块块实色补丁。
                      color: OnGlass.of(context)
                          ? OnGlass.wellColor(scheme)
                          : theme.brightness == Brightness.light
                          ? scheme.surfaceContainerLow
                          : scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => open(group),
                        child: SizedBox(
                          width: 76,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            child: Column(
                              children: <Widget>[
                                icon(group, 26),
                                const SizedBox(height: 6),
                                Text(
                                  group.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium,
                                ),
                                Text(
                                  l10n.exploreUnitTimes(group.count),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
