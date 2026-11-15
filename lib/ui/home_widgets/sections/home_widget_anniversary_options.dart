import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/providers/anniversary_providers.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_button_group.dart';

/// 纪念日小组件的内容选项：显示一个还是列表；一个时显示哪一个（默认“最近的
/// 一个”，跟着日子走）；是否显示日期与第几周年。
class HomeWidgetAnniversaryOptions extends ConsumerWidget {
  const HomeWidgetAnniversaryOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final AnniversaryContent content;
  final ValueChanged<AnniversaryContent> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rows =
        ref.watch(anniversaryListProvider).value ?? const <Anniversary>[];
    final chosen = rows
        .where((row) => row.anniversaryId == content.anniversaryId)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetAnniversaryDisplay,
              child: ExpressiveButtonGroup<AnniversaryDisplay>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<AnniversaryDisplay>>[
                  ButtonSegment(
                    value: AnniversaryDisplay.single,
                    label: Text(l10n.homeWidgetAnniversarySingle),
                  ),
                  ButtonSegment(
                    value: AnniversaryDisplay.list,
                    label: Text(l10n.homeWidgetAnniversaryList),
                  ),
                ],
                selected: <AnniversaryDisplay>{content.display},
                onSelectionChanged: (Set<AnniversaryDisplay> value) =>
                    onChanged(content.copyWith(display: value.first)),
              ),
            ),
            if (content.display == AnniversaryDisplay.single)
              SettingsNavTile(
                icon: FontAwesomeIcons.heart,
                title: l10n.homeWidgetAnniversaryWhich,
                value: chosen?.title ?? l10n.homeWidgetAnniversaryNextUp,
                onTap: () async {
                  final picked = await _pick(context, rows, chosen);
                  if (picked == null) return;
                  onChanged(
                    content.copyWith(
                      anniversaryId: () => picked.isEmpty ? null : picked,
                    ),
                  );
                },
              ),
            SettingsSwitchTile(
              title: l10n.homeWidgetAnniversaryShowDate,
              value: content.showDate,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showDate: value)),
            ),
          ],
        ),
      ],
    );
  }

  /// 选一个纪念日；空串为“最近的一个”，划掉关闭为 null。
  Future<String?> _pick(
    BuildContext context,
    List<Anniversary> rows,
    Anniversary? current,
  ) {
    final l10n = context.l10n;
    return showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext sheetContext) {
        final theme = Theme.of(sheetContext);
        Widget check(bool selected) => selected
            ? FaIcon(
                FontAwesomeIcons.check,
                size: 14,
                color: theme.colorScheme.primary,
              )
            : const SizedBox.shrink();
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.homeWidgetAnniversaryWhich,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 16,
                ),
                title: Text(l10n.homeWidgetAnniversaryNextUp),
                trailing: check(current == null),
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              for (final row in rows)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: FaIcon(
                    row.isPinned
                        ? FontAwesomeIcons.thumbtack
                        : FontAwesomeIcons.heart,
                    size: 16,
                  ),
                  title: Text(row.title),
                  trailing: check(row.anniversaryId == current?.anniversaryId),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(row.anniversaryId),
                ),
            ],
          ),
        );
      },
    );
  }
}
