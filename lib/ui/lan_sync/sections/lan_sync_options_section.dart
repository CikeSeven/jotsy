import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_card_surface.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../widgets/lan_sync_section_header.dart';

/// “同步选项”分组：自动同步、同步设置两个开关。
class LanSyncOptionsSection extends StatelessWidget {
  const LanSyncOptionsSection({
    super.key,
    required this.autoSync,
    required this.syncSettings,
    required this.onAutoSyncChanged,
    required this.onSyncSettingsChanged,
  });

  final bool autoSync;
  final bool syncSettings;
  final ValueChanged<bool> onAutoSyncChanged;
  final ValueChanged<bool> onSyncSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LanSyncSectionHeader(title: l10n.lanSyncSectionOptions),
        AppCardSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SettingsSwitchTile(
                title: l10n.lanSyncAutoSync,
                subtitle: l10n.lanSyncAutoSyncSubtitle,
                value: autoSync,
                onChanged: onAutoSyncChanged,
              ),
              const SettingsCardGroupDivider(),
              SettingsSwitchTile(
                title: l10n.lanSyncSyncSettings,
                subtitle: l10n.lanSyncSyncSettingsSubtitle,
                value: syncSettings,
                onChanged: onSyncSettingsChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
