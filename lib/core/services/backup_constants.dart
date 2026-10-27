import 'app_background_storage_service.dart';
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

/// 由设置（而不是日记）引用的托管目录，目前只有背景图。
///
/// 与 [backupMediaDirectories] 分开，是因为那份列表同时是日记媒体引用识别与
/// 回收（`diary_media_sweeper.dart`）的范围：放进去，不被日记引用的背景图会
/// 被当作孤儿删除。这里的目录：
/// - 随完整备份整目录导出，日记包不带；
/// - 只在覆盖恢复、且备份设置里有对应键（[backupSettingsKeyOf]）时才整目录
///   换入——设置原样保留时本机的文件也要原样保留，否则设置指向的图片会
///   消失；合并导入从不恢复设置，也就不落回这些文件；
/// - 换入与失败回滚与日记媒体走同一个 `BackupMediaTransaction`。
const backupSettingsMediaDirectories = [
  AppBackgroundStorageService.directoryName,
];

/// [backupSettingsMediaDirectories] 中目录对应的备份设置字段：备份设置里有
/// 这个键（值可以是 null，即恢复为默认）才会恢复该设置，也才换入目录。
String backupSettingsKeyOf(String directoryName) => switch (directoryName) {
  AppBackgroundStorageService.directoryName => 'appSurfaceRaw',
  _ => throw ArgumentError.value(directoryName, 'directoryName'),
};
