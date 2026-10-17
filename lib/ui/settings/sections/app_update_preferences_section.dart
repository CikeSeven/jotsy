import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/app_update_labels.dart';
import '../widgets/settings_card_group.dart';
import '../widgets/settings_option_tiles.dart';

/// 更新设置：自动检查开关与下载线路入口（点按打开线路面板）。
class AppUpdatePreferencesSection extends StatelessWidget {
  const AppUpdatePreferencesSection({
    super.key,
    required this.preferences,
    required this.onAutoCheckChanged,
    required this.onPickSource,
  });

  final AppUpdatePreferences preferences;
  final ValueChanged<bool> onAutoCheckChanged;
  final VoidCallback onPickSource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.l),
      child: SettingsCardGroup(
        title: l10n.appUpdateSettingsTitle,
        children: <Widget>[
          SettingsSwitchTile(
            title: l10n.appUpdateAutoCheck,
            subtitle: l10n.appUpdateAutoCheckSubtitle,
            value: preferences.autoCheck,
            onChanged: onAutoCheckChanged,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            title: Text(l10n.appUpdateSource),
            subtitle: Text(appUpdatePreferredSourceLabel(l10n, preferences)),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: onPickSource,
          ),
        ],
      ),
    );
  }
}
