import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/cloud_backup_oauth.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/cloud_backup_labels.dart';
import '../widgets/settings_card_group.dart';

/// 授权类网盘的账号卡片：已授权的账号、备份存放位置与“重新授权”入口。
class CloudBackupAccountSection extends StatelessWidget {
  const CloudBackupAccountSection({
    super.key,
    required this.target,
    required this.onReauthorize,
  });

  final CloudBackupTarget target;
  final VoidCallback onReauthorize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final account = CloudDriveCredentials.accountOf(target.config);
    // 账号与说明同属一张卡片的一项，不要组内分割线。
    return SettingsCardGroup(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                0,
              ),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  cloudBackupTargetIcon(target),
                  size: 16,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              title: Text(cloudBackupTargetName(l10n, target)),
              subtitle: Text(
                account == null
                    ? l10n.cloudBackupAccountAuthorized
                    : l10n.cloudBackupAccountConnected(account),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cloudBackupDriveFolderHint(l10n, target.kind),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  OutlinedButton.icon(
                    onPressed: onReauthorize,
                    icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
                    label: Text(l10n.cloudBackupReauthorize),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
