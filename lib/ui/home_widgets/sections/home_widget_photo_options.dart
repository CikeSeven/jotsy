import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/sections/notebook_choice_sheet.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';
import '../../notebooks/viewmodels/notebook_tree_rows.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_button_group.dart';
import 'home_widget_privacy_note.dart';

/// 照片回忆的内容选项：照片来自（全部 / 那年今日 / 某个日记本），是否在照片上显示
/// 日期。
///
/// 日记本只列非私密的（含继承），理由同最近日记；日记本功能关闭或没有能选的本子时
/// 不提供“日记本”。已选的本子失效时选项仍显示原来的选择，小组件按全部取
/// （`homeWidgetPhotoSourceKey`）。
class HomeWidgetPhotoOptions extends ConsumerWidget {
  const HomeWidgetPhotoOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final PhotoMemoriesContent content;
  final ValueChanged<PhotoMemoriesContent> onChanged;

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
    final notebook = notebooks
        .where((notebook) => notebook.id == content.notebookId)
        .firstOrNull;
    final selected =
        content.source == PhotoMemorySource.notebook && notebooks.isEmpty
        ? PhotoMemorySource.all
        : content.source;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetPhotoSource,
              subtitle: selected == PhotoMemorySource.onThisDay
                  ? l10n.homeWidgetPhotoSourceOnThisDayHint
                  : null,
              child: ExpressiveButtonGroup<PhotoMemorySource>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<PhotoMemorySource>>[
                  ButtonSegment(
                    value: PhotoMemorySource.all,
                    label: Text(l10n.exploreValAll),
                  ),
                  ButtonSegment(
                    value: PhotoMemorySource.onThisDay,
                    label: Text(l10n.homeWidgetKindOnThisDay),
                  ),
                  if (notebooks.isNotEmpty)
                    ButtonSegment(
                      value: PhotoMemorySource.notebook,
                      label: Text(l10n.homeWidgetRecentNotebook),
                    ),
                ],
                selected: <PhotoMemorySource>{selected},
                onSelectionChanged: (Set<PhotoMemorySource> value) {
                  final source = value.first;
                  // 第一次选日记本时先选上第一个，小组件立刻有内容。
                  onChanged(
                    content.copyWith(
                      source: source,
                      notebookId:
                          source == PhotoMemorySource.notebook &&
                              notebook == null
                          ? () => notebooks.first.id
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (selected == PhotoMemorySource.notebook)
              SettingsNavTile(
                icon: FontAwesomeIcons.book,
                title: l10n.homeWidgetRecentNotebook,
                value: (notebook ?? notebooks.first).name,
                onTap: () async {
                  final picked = await showNotebookChoiceSheet(
                    context,
                    title: l10n.homeWidgetRecentNotebook,
                    // 树序缩进、可收起；私密的不列（上级私密的子本同样不列）。
                    rows: notebookTreeRows(NotebookTree.fromViews(notebooks)),
                    selectedId: (notebook ?? notebooks.first).id,
                    iconOf: (_) => FontAwesomeIcons.book,
                  );
                  final id = picked?.notebookId;
                  if (id != null) {
                    onChanged(content.copyWith(notebookId: () => id));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetPhotoShowDate,
              value: content.showDate,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showDate: value)),
            ),
          ],
        ),
        const HomeWidgetPrivacyNote(),
      ],
    );
  }
}
