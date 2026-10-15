import 'diary_audio_storage_service.dart';
import 'diary_media_storage_service.dart';

const backupPayloadFileName = 'backup_data.json';

/// 日记包（单篇日记导出）的载荷文件名，结构与完整备份相同但不含设置。
///
/// 刻意不与完整备份同名：旧版应用只认 [backupPayloadFileName]，并且一律按
/// “覆盖全部”恢复；日记包若沿用同名文件，旧版导入会清空本机、只剩包内几篇
/// 日记。换名后旧版以“缺少 backup_data.json”拒绝，不触碰任何数据。
const diaryPackagePayloadFileName = 'diary_package.json';
const backupFormatVersion = 1;
const backupMediaDirectories = [
  'diary_covers',
  DiaryMediaStorageService.imagesDirectoryName,
  DiaryAudioStorageService.directoryName,
  DiaryMediaStorageService.videosDirectoryName,
  DiaryMediaStorageService.attachmentsDirectoryName,
];
