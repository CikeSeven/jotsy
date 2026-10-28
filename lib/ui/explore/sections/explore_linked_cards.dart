import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../../core/database/app_database.dart';
import '../../anniversaries/providers/anniversary_providers.dart';
import '../../anniversaries/viewmodels/anniversary_countdown.dart';
import '../../anniversaries/viewmodels/anniversary_rule.dart';
import '../../anniversaries/widgets/anniversary_labels.dart';
import '../../anniversaries/widgets/anniversary_list_card.dart';
import '../../diaries/providers/diary_draft_providers.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../notebooks/widgets/notebook_cover_tile.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../controllers/explore_module_actions.dart';
import '../controllers/explore_stats_builder.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_options.dart';
import '../providers/explore_providers.dart';
import '../viewmodels/explore_entry.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

// 关联功能卡：纪念日、时间胶囊、日记本、草稿箱。它们的数据来自各自模块
// 现成的 provider（只在卡片显示时订阅），跳转经 [ExploreActionsScope]。
// 功能管理里关掉的功能，这里的卡片由页面整张不显示（见 ExploreModuleSpec）。

/// 纪念日：最近的几个（不含已经过去的倒数日），按距今天数由近到远；点按
/// 进入详情，标题行尾进入列表。没有纪念日时可直接添加。
class ExploreAnniversariesCard extends ConsumerWidget {
  const ExploreAnniversariesCard({
    super.key,
    required this.config,
    required this.now,
  });

  final ExploreModuleConfig config;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = ExploreActionsScope.of(context);
    final rows = ref.watch(anniversaryListProvider).value;
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = <(Anniversary, AnniversaryCountdown)>[
      for (final row in rows ?? const <Anniversary>[])
        if (AnniversaryRule.fromRow(row) case final rule?)
          (row, AnniversaryCountdown.of(rule, today)),
    ]..removeWhere((item) => item.$2.phase == AnniversaryPhase.past);
    upcoming.sort((a, b) {
      final diff = a.$2.daysUntilNext!.compareTo(b.$2.daysUntilNext!);
      return diff != 0 ? diff : a.$1.title.compareTo(b.$1.title);
    });
    final shown = upcoming.take(
      config.count(ExploreOptions.anniversariesCount),
    );
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.heart,
            title: l10n.exploreModuleAnniversaries,
            trailing: ExploreHeaderArrow(
              tooltip: l10n.exploreAnniversariesAll,
              onPressed: actions.openAnniversaryList,
            ),
          ),
          if (rows == null)
            const SizedBox(height: 40)
          else if (upcoming.isEmpty)
            ExploreInlineHint(
              message: l10n.exploreAnniversariesEmpty,
              actionLabel: l10n.exploreAnniversariesAdd,
              onAction: actions.addAnniversary,
            )
          else
            for (final (row, countdown) in shown)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => actions.openAnniversary(row),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          AnniversaryLabels.iconFor(countdown.rule),
                          size: 13,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              AnniversaryListCard.dateLineOf(l10n, countdown),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: AnniversaryDayCount(
                          countdown: countdown,
                          numberStyle: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 时间胶囊：还有几个没开启、接下来的 3 个（标题、开启日期与倒数），以及
/// 最近 30 天开启的（可关）。点按经打开日记的流程进入（未解封的进封存页）。
class ExploreCapsulesCard extends ConsumerWidget {
  const ExploreCapsulesCard({
    super.key,
    required this.config,
    required this.recent,
    required this.now,
  });

  final ExploreModuleConfig config;

  /// 最近开启的胶囊（新 → 旧，最多 3 篇）。
  final List<ExploreEntry> recent;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final actions = ExploreActionsScope.of(context);
    final locked = ref.watch(exploreLockedCapsulesProvider).value;
    final showRecent =
        config.toggle(ExploreOptions.capsulesRecent) && recent.isNotEmpty;
    final today = DateTime(now.year, now.month, now.day);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    Widget row({
      required FaIconData icon,
      required String title,
      required String meta,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              FaIcon(icon, size: 13, color: look.accentOf(scheme)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.trim().isEmpty ? l10n.autoT0065 : title.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(meta, style: metaStyle),
            ],
          ),
        ),
      );
    }

    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.hourglassHalf,
            title: l10n.exploreModuleCapsules,
          ),
          if (locked == null)
            const SizedBox(height: 40)
          else if (locked.isEmpty && !showRecent)
            ExploreInlineHint(message: l10n.exploreCapsulesEmpty)
          else ...<Widget>[
            if (locked.isNotEmpty) ...<Widget>[
              Text(
                l10n.exploreCapsulesWaiting(locked.length),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              for (final capsule in locked.take(3))
                row(
                  icon: FontAwesomeIcons.lock,
                  title: capsule.title,
                  meta: () {
                    final unlock = capsule.unlockAt.toLocal();
                    final days = exploreDaysBetween(today, unlock);
                    return days <= 0
                        ? l10n.exploreCapsuleOpensToday
                        : l10n.exploreCapsuleOpensIn(days);
                  }(),
                  onTap: () => actions.openDiary(capsule.diaryId),
                ),
            ],
            if (showRecent) ...<Widget>[
              if (locked.isNotEmpty) const SizedBox(height: 8),
              Text(
                l10n.exploreCapsulesRecent,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final entry in recent)
                row(
                  icon: FontAwesomeIcons.envelopeOpen,
                  title: entry.title,
                  meta: l10n.formatMonthDay(entry.created),
                  onTap: () => actions.openDiary(entry.diaryId),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 日记本：书架上可见的本子（可见性为 normal，私密本不出现）排成一条可横向
/// 滚动的封面条，按书架顺序、最近更新或篇数排序；点按打开这本。
class ExploreNotebooksCard extends ConsumerWidget {
  const ExploreNotebooksCard({super.key, required this.config});

  final ExploreModuleConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ExploreActionsScope.of(context);
    final notebooks = ref.watch(notebooksProvider).value;
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final visible = <NotebookView>[
      for (final notebook in notebooks ?? const <NotebookView>[])
        if (notebook.effectiveVisibility == NotebookVisibility.normal &&
            !notebook.isClosed)
          notebook,
    ];
    switch (config.choice(ExploreOptions.notebooksSort)) {
      case ExploreNotebookSort.shelf:
        break;
      case ExploreNotebookSort.recent:
        visible.sort((a, b) => b.row.updatedAt.compareTo(a.row.updatedAt));
      case ExploreNotebookSort.entries:
        visible.sort(
          (a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0),
        );
    }
    final limit = config.count(ExploreOptions.notebooksCount);
    final shown = limit <= 0 ? visible : visible.take(limit).toList();
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.book,
            title: l10n.exploreModuleNotebooks,
            trailing: ExploreHeaderArrow(
              tooltip: l10n.exploreNotebooksManage,
              onPressed: actions.openNotebooks,
            ),
          ),
          if (notebooks == null)
            const SizedBox(height: 40)
          else if (shown.isEmpty)
            ExploreInlineHint(message: l10n.exploreNotebooksEmpty)
          else
            SizedBox(
              height: 128,
              child: DesktopHorizontalScroll(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final notebook = shown[index];
                    return SizedBox(
                      width: 96,
                      child: _NotebookTile(
                        notebook: notebook,
                        counts: counts,
                        onTap: () => actions.openNotebook(notebook),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotebookTile extends ConsumerWidget {
  const _NotebookTile({
    required this.notebook,
    required this.counts,
    required this.onTap,
  });

  final NotebookView notebook;
  final Map<String, int> counts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotebookCoverTile.fromView(
      notebook,
      count: watchNotebookDisplayCount(ref, notebook, counts),
      onTap: onTap,
    );
  }
}

/// 草稿箱：有草稿时才出现（页面在没有草稿时不排这张卡），写份数与最近一份
/// 的标题；“继续写”走新建流程（会先弹草稿面板），“管理”进入草稿箱。
class ExploreDraftsCard extends ConsumerWidget {
  const ExploreDraftsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = ExploreActionsScope.of(context);
    final drafts = ref.watch(diaryDraftsProvider).value ?? const [];
    final latest = drafts.isEmpty ? null : drafts.first;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.filePen,
            title: l10n.exploreModuleDrafts,
          ),
          Text(
            l10n.exploreDraftsCount(drafts.length),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (latest != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              latest.displayTitle ??
                  (latest.snippet.isEmpty ? l10n.autoT0065 : latest.snippet),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: actions.createDiary,
                icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14),
                label: Text(l10n.exploreDraftsContinue),
              ),
              TextButton(
                onPressed: actions.openDrafts,
                child: Text(l10n.exploreDraftsManage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
