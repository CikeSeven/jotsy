import 'cloud_backup_aliyun.dart';
import 'cloud_backup_baidu.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_dropbox.dart';
import 'cloud_backup_google_drive.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_onedrive.dart';

/// 授权类网盘的登记表：新增网盘时在这里加一项。
Map<CloudBackupKind, CloudDriveProvider> defaultCloudDriveProviders() {
  final providers = <CloudDriveProvider>[
    GoogleDriveProvider(),
    OneDriveProvider(),
    DropboxProvider(),
    BaiduPanProvider(),
    AliyunDriveProvider(),
  ];
  return {for (final provider in providers) provider.kind: provider};
}
