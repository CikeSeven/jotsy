import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_oauth.dart';
import '../../../core/services/cloud_backup_presets.dart';
import '../../../core/services/cloud_backup_s3.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../core/services/webdav_models.dart';
import '../../../l10n/app_localizations.dart';

/// 网盘、预设与备份位置的展示名称、图标和填写说明。
///
/// 外文服务名是专有名词不翻译；国内服务按中文名，英文界面用其英文名。

String cloudBackupKindName(AppLocalizations l10n, CloudBackupKind kind) {
  return switch (kind) {
    CloudBackupKind.webDav => 'WebDAV',
    CloudBackupKind.s3 => l10n.cloudBackupCustomS3,
    CloudBackupKind.googleDrive => 'Google Drive',
    CloudBackupKind.oneDrive => 'OneDrive',
    CloudBackupKind.dropbox => 'Dropbox',
    CloudBackupKind.baiduPan => l10n.cloudBackupBaiduPan,
    CloudBackupKind.aliyunDrive => l10n.cloudBackupAliyunDrive,
  };
}

FaIconData cloudBackupKindIcon(CloudBackupKind kind) {
  return switch (kind) {
    CloudBackupKind.webDav => FontAwesomeIcons.server,
    CloudBackupKind.s3 => FontAwesomeIcons.bucket,
    CloudBackupKind.googleDrive => FontAwesomeIcons.googleDrive,
    CloudBackupKind.oneDrive => FontAwesomeIcons.microsoft,
    CloudBackupKind.dropbox => FontAwesomeIcons.dropbox,
    CloudBackupKind.baiduPan ||
    CloudBackupKind.aliyunDrive => FontAwesomeIcons.cloud,
  };
}

String cloudBackupPresetName(AppLocalizations l10n, CloudBackupPreset preset) {
  return switch (preset.id) {
    'webdav' => l10n.cloudBackupCustomWebDav,
    's3' => l10n.cloudBackupCustomS3,
    'jianguoyun' => l10n.cloudBackupJianguoyun,
    '123pan' => l10n.cloudBackup123pan,
    'openlist' => 'Alist / OpenList',
    'clouddrive2' => 'CloudDrive2',
    'nextcloud' => 'Nextcloud',
    'owncloud' => 'ownCloud',
    'seafile' => 'Seafile',
    'synology' => l10n.cloudBackupSynology,
    'qnap' => l10n.cloudBackupQnap,
    'koofr' => 'Koofr',
    'pcloud' => 'pCloud',
    'pcloudEu' => 'pCloud (EU)',
    'infinicloud' => 'InfiniCLOUD',
    'hetzner' => 'Hetzner Storage Box',
    'kdrive' => 'kDrive',
    'yandex' => 'Yandex Disk',
    'mailru' => 'Mail.ru Cloud',
    'aliyunOss' => l10n.cloudBackupAliyunOss,
    'tencentCos' => l10n.cloudBackupTencentCos,
    'qiniuKodo' => l10n.cloudBackupQiniuKodo,
    'huaweiObs' => l10n.cloudBackupHuaweiObs,
    'volcengineTos' => l10n.cloudBackupVolcengineTos,
    'baiduBos' => l10n.cloudBackupBaiduBos,
    'jdcloudOss' => l10n.cloudBackupJdcloudOss,
    'awsS3' => 'Amazon S3',
    'awsS3China' => l10n.cloudBackupAwsChina,
    'cloudflareR2' => 'Cloudflare R2',
    'backblazeB2' => 'Backblaze B2',
    'wasabi' => 'Wasabi',
    'digitalOceanSpaces' => 'DigitalOcean Spaces',
    'scaleway' => 'Scaleway',
    'storj' => 'Storj',
    'idriveE2' => 'IDrive e2',
    'akamaiLinode' => 'Akamai (Linode)',
    'oracleOci' => 'Oracle Cloud',
    'googleCloudStorage' => 'Google Cloud Storage',
    'minio' => 'MinIO',
    _ => cloudBackupKindName(l10n, preset.kind),
  };
}

FaIconData cloudBackupPresetIcon(CloudBackupPreset preset) {
  return switch (preset.id) {
    'awsS3' || 'awsS3China' => FontAwesomeIcons.aws,
    'cloudflareR2' => FontAwesomeIcons.cloudflare,
    'digitalOceanSpaces' => FontAwesomeIcons.digitalOcean,
    'akamaiLinode' => FontAwesomeIcons.linode,
    'googleCloudStorage' => FontAwesomeIcons.google,
    'yandex' => FontAwesomeIcons.yandex,
    'synology' || 'qnap' || 'hetzner' => FontAwesomeIcons.hardDrive,
    'openlist' || 'clouddrive2' => FontAwesomeIcons.networkWired,
    'jianguoyun' ||
    '123pan' ||
    'koofr' ||
    'pcloud' ||
    'pcloudEu' ||
    'infinicloud' ||
    'kdrive' ||
    'mailru' => FontAwesomeIcons.cloud,
    _ => cloudBackupKindIcon(preset.kind),
  };
}

/// 配置表单下方的填写说明；没有专门说明时用该类型的通用说明。
String cloudBackupPresetHint(AppLocalizations l10n, CloudBackupPreset? preset) {
  final hint = switch (preset?.id) {
    'jianguoyun' => l10n.cloudBackupHintJianguoyun,
    '123pan' => l10n.cloudBackupHint123pan,
    'openlist' => l10n.cloudBackupHintOpenList,
    'clouddrive2' => l10n.cloudBackupHintCloudDrive2,
    'nextcloud' => l10n.cloudBackupHintNextcloud,
    'owncloud' => l10n.cloudBackupHintOwncloud,
    'seafile' => l10n.cloudBackupHintSeafile,
    'synology' => l10n.cloudBackupHintSynology,
    'qnap' => l10n.cloudBackupHintQnap,
    'koofr' => l10n.cloudBackupHintKoofr,
    'pcloud' || 'pcloudEu' => l10n.cloudBackupHintPcloud,
    'infinicloud' => l10n.cloudBackupHintInfinicloud,
    'hetzner' => l10n.cloudBackupHintHetzner,
    'kdrive' => l10n.cloudBackupHintKdrive,
    'yandex' => l10n.cloudBackupHintYandex,
    'mailru' => l10n.cloudBackupHintMailru,
    'aliyunOss' => l10n.cloudBackupHintAliyunOss,
    'tencentCos' => l10n.cloudBackupHintTencentCos,
    'qiniuKodo' => l10n.cloudBackupHintQiniuKodo,
    'cloudflareR2' => l10n.cloudBackupHintR2,
    'backblazeB2' => l10n.cloudBackupHintB2,
    'digitalOceanSpaces' => l10n.cloudBackupHintDigitalOcean,
    'minio' => l10n.cloudBackupHintMinio,
    'googleCloudStorage' => l10n.cloudBackupHintGcs,
    'oracleOci' => l10n.cloudBackupHintOracle,
    _ => null,
  };
  if (hint != null) return hint;
  return preset?.kind == CloudBackupKind.s3
      ? l10n.cloudBackupS3Hint
      : l10n.webDavHint;
}

/// 授权类网盘的备份存放位置说明。
String cloudBackupDriveFolderHint(AppLocalizations l10n, CloudBackupKind kind) {
  return switch (kind) {
    CloudBackupKind.googleDrive => l10n.cloudBackupFolderGoogleDrive,
    CloudBackupKind.oneDrive => l10n.cloudBackupFolderOneDrive,
    CloudBackupKind.dropbox => l10n.cloudBackupFolderDropbox,
    CloudBackupKind.baiduPan => l10n.cloudBackupFolderBaidu,
    CloudBackupKind.aliyunDrive => l10n.cloudBackupFolderAliyun,
    CloudBackupKind.webDav || CloudBackupKind.s3 => '',
  };
}

String cloudBackupTargetName(AppLocalizations l10n, CloudBackupTarget target) {
  final preset = cloudBackupPresetById(target.presetId);
  return preset == null
      ? cloudBackupKindName(l10n, target.kind)
      : cloudBackupPresetName(l10n, preset);
}

FaIconData cloudBackupTargetIcon(CloudBackupTarget target) {
  final preset = cloudBackupPresetById(target.presetId);
  return preset == null
      ? cloudBackupKindIcon(target.kind)
      : cloudBackupPresetIcon(preset);
}

/// 列表副标题：账号、主机或存储桶，帮助区分同类型的多个位置。
String cloudBackupTargetSummary(
  AppLocalizations l10n,
  CloudBackupTarget target,
) {
  switch (target.kind) {
    case CloudBackupKind.webDav:
      final config = WebDavConfig.fromJson(target.config);
      final host = Uri.tryParse(config.serverUrl.trim())?.host ?? '';
      return [
        if (config.username.trim().isNotEmpty) config.username.trim(),
        if (host.isNotEmpty) host,
      ].join(' · ');
    case CloudBackupKind.s3:
      final config = S3BackupConfig.fromJson(target.config);
      return [
        if (config.bucket.trim().isNotEmpty) config.bucket.trim(),
        if (config.region.trim().isNotEmpty) config.region.trim(),
      ].join(' · ');
    default:
      return CloudDriveCredentials.accountOf(target.config) ??
          l10n.cloudBackupAccountAuthorized;
  }
}
