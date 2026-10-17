import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_presets.dart';
import '../../../l10n/app_localizations.dart';
import 'choice_sheet_parts.dart';
import 'cloud_backup_labels.dart';

/// 面板里选中的备份位置类型：授权类网盘没有预设，WebDAV / S3 带预设。
class CloudBackupChoice {
  const CloudBackupChoice.drive(this.kind) : preset = null;
  CloudBackupChoice.preset(CloudBackupPreset this.preset) : kind = preset.kind;

  final CloudBackupKind kind;
  final CloudBackupPreset? preset;
}

/// 授权类网盘的展示顺序。
const _drives = <CloudBackupKind>[
  CloudBackupKind.googleDrive,
  CloudBackupKind.oneDrive,
  CloudBackupKind.dropbox,
  CloudBackupKind.baiduPan,
  CloudBackupKind.aliyunDrive,
];

/// 打开“添加备份位置”面板，返回所选类型；取消返回 null。
///
/// [isDriveAvailable] 过滤掉此安装包未配置应用密钥的网盘；一个都没有时整组
/// 不显示。点选即返回：授权或填写配置都在之后进行，随时可取消。
Future<CloudBackupChoice?> showCloudBackupProviderSheet(
  BuildContext context, {
  required bool Function(CloudBackupKind kind) isDriveAvailable,
}) {
  return showModalBottomSheet<CloudBackupChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 预设较多，按内容撑高并在内部滚动；最高占屏幕 88%，上方留出可点按关闭
    // 的遮罩。宽度沿用 Material 3 默认的 640 上限。
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => CloudBackupProviderSheet(
      drives: _drives.where(isDriveAvailable).toList(growable: false),
    ),
  );
}

class CloudBackupProviderSheet extends StatelessWidget {
  const CloudBackupProviderSheet({super.key, required this.drives});

  final List<CloudBackupKind> drives;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    void pick(CloudBackupChoice choice) => Navigator.of(context).pop(choice);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.cloudBackupSheetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                l10n.cloudBackupSheetHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (drives.isNotEmpty) ...<Widget>[
              ChoiceSheetSectionHeader(
                icon: FontAwesomeIcons.cloud,
                label: l10n.cloudBackupGroupDrives,
              ),
              ChoiceSheetSectionHint(l10n.cloudBackupGroupDrivesHint),
              ChoiceSheetCompactGrid<CloudBackupKind>(
                items: drives,
                nameOf: (kind) => cloudBackupKindName(l10n, kind),
                iconOf: cloudBackupKindIcon,
                onPick: (kind) => pick(CloudBackupChoice.drive(kind)),
              ),
            ],
            ChoiceSheetSectionHeader(
              icon: FontAwesomeIcons.server,
              label: l10n.cloudBackupGroupWebDav,
            ),
            ChoiceSheetSectionHint(l10n.cloudBackupGroupWebDavHint),
            ChoiceSheetCompactGrid<CloudBackupPreset>(
              items: const [...webDavPresets, customWebDavPreset],
              nameOf: (preset) => cloudBackupPresetName(l10n, preset),
              iconOf: cloudBackupPresetIcon,
              onPick: (preset) => pick(CloudBackupChoice.preset(preset)),
            ),
            ChoiceSheetSectionHeader(
              icon: FontAwesomeIcons.bucket,
              label: l10n.cloudBackupGroupS3,
            ),
            ChoiceSheetSectionHint(l10n.cloudBackupGroupS3Hint),
            ChoiceSheetCompactGrid<CloudBackupPreset>(
              items: const [...s3Presets, customS3Preset],
              nameOf: (preset) => cloudBackupPresetName(l10n, preset),
              iconOf: cloudBackupPresetIcon,
              onPick: (preset) => pick(CloudBackupChoice.preset(preset)),
            ),
          ],
        ),
      ),
    );
  }
}
