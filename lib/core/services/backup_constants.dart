import 'diary_audio_storage_service.dart';
import 'diary_media_storage_service.dart';

const backupPayloadFileName = 'backup_data.json';
const backupFormatVersion = 1;
const backupMediaDirectories = [
  'diary_covers',
  DiaryMediaStorageService.imagesDirectoryName,
  DiaryAudioStorageService.directoryName,
  DiaryMediaStorageService.videosDirectoryName,
  DiaryMediaStorageService.attachmentsDirectoryName,
];
