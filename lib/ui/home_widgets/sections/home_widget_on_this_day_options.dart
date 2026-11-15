import 'package:flutter/material.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_button_group.dart';
import 'home_widget_privacy_note.dart';

/// 那年今日的内容选项：匹配方式（与探索页的“那年今日”同样三种），是否照片优先、
/// 是否显示正文摘要。
class HomeWidgetOnThisDayOptions extends StatelessWidget {
  const HomeWidgetOnThisDayOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final OnThisDayContent content;
  final ValueChanged<OnThisDayContent> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.exploreOptMatch,
              child: ExpressiveButtonGroup<OnThisDayMatch>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<OnThisDayMatch>>[
                  ButtonSegment(
                    value: OnThisDayMatch.sameDay,
                    label: Text(l10n.exploreValSameDay),
                  ),
                  ButtonSegment(
                    value: OnThisDayMatch.nearby,
                    label: Text(l10n.exploreValNearby),
                  ),
                  ButtonSegment(
                    value: OnThisDayMatch.sameMonth,
                    label: Text(l10n.exploreValSameMonth),
                  ),
                ],
                selected: <OnThisDayMatch>{content.match},
                onSelectionChanged: (Set<OnThisDayMatch> value) =>
                    onChanged(content.copyWith(match: value.first)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetShowPhoto,
              subtitle: l10n.homeWidgetShowPhotoHint,
              value: content.showPhoto,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showPhoto: value)),
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
