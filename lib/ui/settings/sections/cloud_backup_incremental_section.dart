import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/cloud_backup_incremental_state.dart';
import '../../../core/services/cloud_backup_options.dart';
import '../../../core/services/cloud_backup_service.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_button_group.dart';
import '../widgets/cloud_backup_labels.dart';
import '../widgets/cloud_backup_state_builder.dart';
import '../widgets/settings_card_group.dart';
import '../widgets/settings_option_tiles.dart';
import '../widgets/settings_reveal.dart';

/// 单个备份位置页的“增量备份”分组：保留份数、自动备份（开关、频率与上次
/// 结果）与重新设置密码。
///
/// 选项实时跟随已保存的位置（[CloudBackupService.targets] 的通知：备份成功
/// 后记住的链、在别处改的选项都会立即反映），上次自动备份的结果跟随本机
/// 状态的 [CloudBackupLocalState.revision]。自动备份只有在已经成功做过一次
/// 增量备份后才能开启：第一次的大上传与密码设定由用户手动完成。
class CloudBackupIncrementalSection extends StatelessWidget {
  const CloudBackupIncrementalSection({
    super.key,
    required this.service,
    required this.targetId,
    required this.onUpdateOptions,
    required this.onForgetChain,
  });

  final CloudBackupService service;
  final String targetId;
  final void Function(
    CloudBackupTarget target,
    CloudBackupOptions Function(CloudBackupOptions options) update,
  )
  onUpdateOptions;
  final ValueChanged<CloudBackupTarget> onForgetChain;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CloudBackupTarget>>(
      valueListenable: service.targets.targetsNotifier,
      builder: (context, _, _) => CloudBackupTargetStateBuilder(
        service: service,
        targetId: targetId,
        builder: _buildContent,
      ),
    );
  }

  Widget _buildContent(BuildContext context, CloudBackupTargetState state) {
    final target = service.targets.targetById(targetId);
    if (target == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final options = target.options;
    final autoOn = options.autoBackup && options.hasChain;
    final status = cloudAutoBackupStatusText(l10n, state.lastAuto);
    final failed =
        state.lastAuto?.outcome == CloudAutoBackupOutcome.failed ||
        state.lastAuto?.outcome == CloudAutoBackupOutcome.needsManual;
    void update(CloudBackupOptions Function(CloudBackupOptions) change) =>
        onUpdateOptions(target, change);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.cloudIncrementalSectionTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.cloudIncrementalSectionHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        SettingsCardGroup(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.cloudIncrementalKeepTitle,
              subtitle: l10n.cloudIncrementalKeepSubtitle,
              child: ExpressiveButtonGroup<int>(
                minSegmentWidth: 64,
                segments: <ButtonSegment<int>>[
                  for (final value in CloudBackupOptions.keepChoices)
                    ButtonSegment<int>(
                      value: value,
                      label: Text(
                        value == 0
                            ? l10n.cloudIncrementalKeepAll
                            : l10n.cloudIncrementalKeepCount(value),
                      ),
                    ),
                ],
                selected: <int>{options.keepSnapshots},
                onSelectionChanged: (selection) => update(
                  (current) =>
                      current.copyWith(keepSnapshots: selection.single),
                ),
              ),
            ),
            // 自动备份与其下的频率、状态合成分组里的一项：分组按位置复用
            // 子项，单独增删会让后面的行接手它的状态。
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SettingsSwitchTile(
                  title: l10n.cloudAutoBackupTitle,
                  subtitle: options.hasChain
                      ? l10n.cloudAutoBackupSubtitle
                      : l10n.cloudAutoBackupNeedsChain,
                  value: autoOn,
                  onChanged: options.hasChain
                      ? (value) => update(
                          (current) => current.copyWith(autoBackup: value),
                        )
                      : null,
                ),
                SettingsReveal(
                  visible: autoOn,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      settingsNestedDivider,
                      SettingsChoiceTile(
                        nested: true,
                        title: l10n.cloudAutoBackupIntervalTitle,
                        child: ExpressiveButtonGroup<CloudAutoBackupInterval>(
                          minSegmentWidth: 72,
                          segments: <ButtonSegment<CloudAutoBackupInterval>>[
                            ButtonSegment(
                              value: CloudAutoBackupInterval.daily,
                              label: Text(l10n.cloudAutoBackupDaily),
                            ),
                            ButtonSegment(
                              value: CloudAutoBackupInterval.weekly,
                              label: Text(l10n.cloudAutoBackupWeekly),
                            ),
                          ],
                          selected: <CloudAutoBackupInterval>{
                            options.autoInterval,
                          },
                          onSelectionChanged: (selection) => update(
                            (current) => current.copyWith(
                              autoInterval: selection.single,
                            ),
                          ),
                        ),
                      ),
                      if (status != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            SettingsSwitchTile.nestedIndent,
                            0,
                            16,
                            16,
                          ),
                          child: Text(
                            status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: failed
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (options.hasChain)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.key, size: 16),
                title: Text(l10n.cloudIncrementalForgetChain),
                onTap: () => onForgetChain(target),
              ),
          ],
        ),
      ],
    );
  }
}
