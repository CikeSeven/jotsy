import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_button_group.dart';
import 'home_widget_choice_sheet.dart';
import 'home_widget_privacy_note.dart';

/// 最近日记的内容选项：来源（全部 / 某个日记本 / 某个标签 / 置顶），是否显示缩略图
/// 与正文摘要。
///
/// 日记本只列非私密的（含继承）：私密本子里的日记不能出现在桌面上。日记本功能关闭
/// 或还没有能选的本子 / 标签时不提供对应的来源；已选的来源失效（本子被删除、变成
/// 私密，标签被删除）时选项仍显示原来的选择，小组件按全部日记显示
/// （`homeWidgetRecentSourceKey`）。
class HomeWidgetRecentOptions extends ConsumerWidget {
  const HomeWidgetRecentOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final RecentDiariesContent content;
  final ValueChanged<RecentDiariesContent> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final features = ref.watch(appFeaturesProvider);
    final notebooks = features.notebooks
        ? <NotebookView>[
            for (final notebook
                in ref.watch(notebooksProvider).value ?? const <NotebookView>[])
              if (!notebook.isPrivate) notebook,
          ]
        : const <NotebookView>[];
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];
    final notebook = notebooks
        .where((notebook) => notebook.id == content.notebookId)
        .firstOrNull;
    final tag = tags.where((tag) => tag.name == content.tagName).firstOrNull;
    final available = <RecentDiariesSource>{
      RecentDiariesSource.all,
      if (notebooks.isNotEmpty) RecentDiariesSource.notebook,
      if (tags.isNotEmpty) RecentDiariesSource.tag,
      RecentDiariesSource.pinned,
    };
    final selected = available.contains(content.source)
        ? content.source
        : RecentDiariesSource.all;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetRecentSource,
              child: ExpressiveButtonGroup<RecentDiariesSource>(
                minSegmentWidth: 64,
                segments: <ButtonSegment<RecentDiariesSource>>[
                  for (final source in RecentDiariesSource.values)
                    if (available.contains(source))
                      ButtonSegment(
                        value: source,
                        label: Text(switch (source) {
                          RecentDiariesSource.all => l10n.exploreValAll,
                          RecentDiariesSource.notebook =>
                            l10n.homeWidgetRecentNotebook,
                          RecentDiariesSource.tag => l10n.homeWidgetRecentTag,
                          RecentDiariesSource.pinned => l10n.diaryPinnedBadge,
                        }),
                      ),
                ],
                selected: <RecentDiariesSource>{selected},
                onSelectionChanged: (Set<RecentDiariesSource> value) {
                  final source = value.first;
                  // 第一次选日记本 / 标签时先选上第一个，小组件立刻有内容。
                  onChanged(
                    content.copyWith(
                      source: source,
                      notebookId:
                          source == RecentDiariesSource.notebook &&
                              notebook == null
                          ? () => notebooks.first.id
                          : null,
                      tagName: source == RecentDiariesSource.tag && tag == null
                          ? () => tags.first.name
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (selected == RecentDiariesSource.notebook)
              SettingsNavTile(
                icon: FontAwesomeIcons.book,
                title: l10n.homeWidgetRecentNotebook,
                value: (notebook ?? notebooks.first).name,
                onTap: () async {
                  final picked = await showHomeWidgetChoiceSheet<String>(
                    context,
                    title: l10n.homeWidgetRecentNotebook,
                    selected: notebook?.id,
                    choices: <HomeWidgetChoice<String>>[
                      for (final item in notebooks)
                        HomeWidgetChoice<String>(
                          value: item.id,
                          label: item.name,
                          icon: FontAwesomeIcons.book,
                          depth: item.depth,
                        ),
                    ],
                  );
                  if (picked != null) {
                    onChanged(content.copyWith(notebookId: () => picked));
                  }
                },
              ),
            if (selected == RecentDiariesSource.tag)
              SettingsNavTile(
                icon: FontAwesomeIcons.hashtag,
                title: l10n.homeWidgetRecentTag,
                value: (tag ?? tags.first).name,
                onTap: () async {
                  final picked = await showHomeWidgetChoiceSheet<String>(
                    context,
                    title: l10n.homeWidgetRecentTag,
                    selected: tag?.name,
                    choices: <HomeWidgetChoice<String>>[
                      for (final item in tags)
                        HomeWidgetChoice<String>(
                          value: item.name,
                          label: item.name,
                          icon: FontAwesomeIcons.hashtag,
                        ),
                    ],
                  );
                  if (picked != null) {
                    onChanged(content.copyWith(tagName: () => picked));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetRecentShowPhotos,
              subtitle: l10n.homeWidgetRecentShowPhotosHint,
              value: content.showPhotos,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showPhotos: value)),
            ),
            SettingsSwitchTile(
              title: l10n.homeWidgetShowExcerpt,
              value: content.showExcerpt,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showExcerpt: value)),
            ),
          ],
        ),
        const HomeWidgetPrivacyNote(),
      ],
    );
  }
}
