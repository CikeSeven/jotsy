import 'package:flutter/material.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_button_group.dart';

/// 写作统计的内容选项：是否显示热力图，以及热力图按篇数还是字数着色（与探索页
/// 热力图的“着色依据”同样两种）。
class HomeWidgetStatsOptions extends StatelessWidget {
  const HomeWidgetStatsOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final WritingStatsContent content;
  final ValueChanged<WritingStatsContent> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetStatsShowHeatmap,
              subtitle: l10n.homeWidgetStatsShowHeatmapHint,
              value: content.showHeatmap,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showHeatmap: value)),
            ),
            if (content.showHeatmap)
              SettingsChoiceTile(
                title: l10n.exploreOptBasis,
                child: ExpressiveButtonGroup<WritingHeatBasis>(
                  minSegmentWidth: 72,
                  segments: <ButtonSegment<WritingHeatBasis>>[
                    ButtonSegment(
                      value: WritingHeatBasis.entries,
                      label: Text(l10n.exploreValEntries),
                    ),
                    ButtonSegment(
                      value: WritingHeatBasis.words,
                      label: Text(l10n.exploreValWords),
                    ),
                  ],
                  selected: <WritingHeatBasis>{content.basis},
                  onSelectionChanged: (Set<WritingHeatBasis> value) =>
                      onChanged(content.copyWith(basis: value.first)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
